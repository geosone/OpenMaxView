; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView multitasking core:  concurrent DOS tasks on Open 386MAX (or
; QEMM) through the QEMM programming interface, as DESQview does it.
;
; Memory:  everything below the task base (DOS, drivers, this program) is
; shared.  From the task base (4KB aligned, right behind this program) up
; to the top of conventional memory each task has pages of its own:  a
; QPI mapping context (06h clone of the 0-4MB page table), private pages
; (04h) installed with 0Ah, and an MCB chain of its own in them.  Task 0
; is the caller itself in the root context.
;
; Scheduling:  the IRQ0 V86 calldown (QPI 1C01h) chains the timer to the
; task's INT 08h and switches round robin every QUANTUM ticks, but only
; at a safe point:  DOS not busy (SDA critical error flag and InDOS), no
; INT 13h in progress, no other IRQ handler in service (PIC ISR) and the
; interrupted code not 386MAX's own V86 code (its segment is the QPI entry
; segment):  an IRQ taken while 386MAX works in protected mode returns
; through such a stub, and that frame belongs to the interrupted task.
; A task that waits (INT 16h read without a key, DOS idle INT 28h) yields
; at once; then DOS may be busy with console input, safe as the whole SDA
; (with the DOS stacks) is swapped.
; Per task:  all registers (on the task's stack), the IVT, the DOS SDA
; (INT 21h 5D06h, the in-DOS size), the BIOS key buffer and cursor data.
; QPI 08h is called on a shared kernel stack:  the task's stack is gone
; once the context changes, and the SDA swap may overwrite a DOS stack.
;
; Screen and keys:  one task is the foreground.  The text page B8000h of
; every other task is a private page (QPI 0Ah); a foreground change copies
; the screens and remaps them.  INT 10h of a background task leaves the
; hardware alone (mode, cursor shape, page, palette; the CRTC cursor goes
; back to the foreground's).  IRQ1 runs the foreground's INT 09h with its
; key buffer; Ctrl+Alt+1..9 makes task 1..9 the foreground, Ctrl+Alt+0
; task 0.
;
; A task starts in TASK_ENTRY:  a stub PSP of its own at the task base,
; then DOS EXEC of its program; when that ends, the task is DONE.
;
; Open Watcom register convention (small model):  first argument in AX,
; second in DX; result in AX.

        .model  small
        .386

MAXTASK         equ 8           ; task 0 (the caller) + 7
MAXPAGE         equ 160         ; private pages per task (640KB)
STUBPARA        equ 40h         ; stub PSP + task stack (1KB)
KSTACK          equ 512         ; kernel stack (QPI 08h)
SDAMAX          equ 2048        ; DOS SDA swapped
KBDLEN          equ 36          ; 40:1A-40:3D key buffer head, tail, buffer
VIDLEN          equ 18          ; 40:50-40:61 cursor positions and shape
ISTACK          equ 1024        ; IRQ stack (a handler in another task)

ifndef MVDEBUG
MVDEBUG         equ 0           ; 1:  trace characters to port E9h (QEMU
endif                           ; -debugcon, Bochs)

; trace a character (keeps all registers and flags)
dbg     macro   c
if MVDEBUG
        pushf
        push    ax
        mov     al,c
        out     0E9h,al
        pop     ax
        popf
endif
        endm

TS_FREE         equ 0
TS_READY        equ 1
TS_DONE         equ 2

; errors (mvk_init, mvk_create, mvk_start)
MVE_NOQPI       equ 1           ; no QPI entry point
MVE_BASE        equ 2           ; no free MCB at the task base
MVE_SDA         equ 3           ; no DOS SDA
MVE_FULL        equ 4           ; task table full
MVE_MEM         equ 5           ; QPI 04h/06h/08h/0Ah failed
MVE_IRQ         equ 6           ; QPI 1C01h failed
MVE_STATE       equ 7           ; not allowed now (running/not initialized)

TASK    struc
T_STATE dw      ?
T_PT    dw      ?               ; physical page of its page table
T_SS    dw      ?
T_SP    dw      ?
T_NPG   dw      ?               ; # private pages
T_EXIT  dw      ?               ; EXEC result:  AX of 4Dh, FFFFh = EXEC failed
T_PB    dw      7 dup (?)       ; EXEC parameter block
T_PROG  db      80 dup (?)      ; program path (ASCIIZ)
T_TAIL  db      130 dup (?)     ; command tail (length, text, CR)
T_VPG   dw      ?               ; private frame of the text page B8000h
T_SDA   db      SDAMAX dup (?)
T_KBD   db      KBDLEN dup (?)
T_VID   db      VIDLEN dup (?)
T_IVT   db      1024 dup (?)
T_FRAME dw      MAXPAGE dup (?) ; private page frames
TASK    ends

        .data

tasks   TASK    MAXTASK dup (<>)
cdtab   dd      8 dup (?)       ; IRQ0-7 calldown table (QPI copies it)
kstk    db      KSTACK dup (?)
kstktop label   word
istk    db      ISTACK dup (?)
istktop label   word
vbuf    db      4096 dup (?)    ; a text page on its way (foreground change)
origivt dd      256 dup (?)     ; the IVT at mvk_start:  a task whose vector
                                ; differs has hooked it

        .code

        public  mvk_init_
        public  mvk_create_
        public  mvk_start_
        public  mvk_stop_
        public  mvk_state_
        public  mvk_exit_
        public  mvk_switches_
        public  mvk_base_
        public  mvk_setfg_
        public  mvk_fg_

; kernel data in CS:  the IRQ handlers find it without DS
qpi_entry dd    0
qpi_seg  dw     0               ; 386MAX's V86 code segment
dgseg   dw     0
sda_ptr  dd     0
sda_size dw     0
base_seg dw     0               ; task base (4KB aligned)
priv_end dw     0               ; end of the private pages (segment)
free_end dw     0               ; end of the root's free block at the base
free_typ db     0               ; its MCB type ('M' or 'Z')
         db     0
root_pt  dw     0
ntasks   dw     0
cur      dw     0
running  dw     0
quantum  dw     2
qleft    dw     2
i13busy  dw     0
actpt    dw     0               ; page table active now
idepth   dw     0               ; IRQ handlers of other tasks running
nswitch  dd     0
fg       dw     0               ; foreground task
newfg    dw     0               ; wanted (hotkey)
wantsw   dw     0               ; scheduler:  switch tasks
yieldf   dw     0               ; scheduler:  the task waits
fgss     dw     0
fgsp     dw     0
old10    dd     0
old13    dd     0
old16    dd     0
old28    dd     0
; vector * 4, handler, old vector:  in every task's IVT while running
hooktab  dw     10h*4, offset int10, offset old10
         dw     13h*4, offset int13, offset old13
         dw     16h*4, offset int16, offset old16
         dw     28h*4, offset int28, offset old28
NHOOK    equ    4

; QPI call:  AX = function, other registers as the function wants
qpi     macro
        pushf
        call    dword ptr cs:qpi_entry
        inc     sp              ; drop the flags pushed (INC keeps CF)
        inc     sp
        endm

; BX = task # -> BX = offset of its TASK
taskptr proc near
        imul    bx,bx,size TASK
        add     bx,offset tasks
        ret
taskptr endp

;----------------------------------------------------------------------------
; int mvk_init(unsigned base):  base = task base segment (4KB aligned, a free
; MCB there).  Returns 0 or MVE_x.
mvk_init_ proc near
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        push    ds
        mov     cs:base_seg,ax
        mov     cs:dgseg,ds
        cmp     cs:running,0
        mov     ax,MVE_STATE
        jne     init_ret
        ; QPI entry (INT 67h AH=3Fh, CX='QE', DX='MM')
        xor     di,di
        mov     es,di
        mov     ax,3F00h
        mov     cx,5145h
        mov     dx,4D4Dh
        int     67h
        mov     ax,es
        or      ax,di
        mov     ax,MVE_NOQPI
        jz      init_ret
        mov     word ptr cs:qpi_entry,di
        mov     word ptr cs:qpi_entry+2,es
        mov     cs:qpi_seg,es
        mov     ax,0700h        ; root context
        qpi
        mov     ax,MVE_NOQPI
        jc      init_ret
        mov     cs:root_pt,dx
        mov     cs:actpt,dx
        ; top of conventional memory and the private range
        int     12h
        shl     ax,6            ; KB -> paragraphs
        and     ax,0FF00h
        mov     cs:priv_end,ax
        ; the free block at the base
        mov     es,cs:base_seg
        mov     ax,MVE_BASE
        test    cs:base_seg,0FFh
        jnz     init_ret
        mov     dx,cs:base_seg
        cmp     dx,cs:priv_end
        jae     init_ret
        mov     cl,es:[0]
        cmp     cl,'M'
        je      @F
        cmp     cl,'Z'
        jne     init_ret
@@:     cmp     word ptr es:[1],0
        jne     init_ret
        mov     cs:free_typ,cl
        add     dx,es:[3]
        inc     dx
        mov     cs:free_end,dx
        cmp     dx,cs:priv_end
        jae     @F
        and     dx,0FF00h       ; the private range must lie in it (DOS=UMB:
        mov     cs:priv_end,dx  ; the UMB link MCB below the top)
@@:     mov     dx,cs:priv_end
        sub     dx,cs:base_seg
        cmp     dx,1000h        ; at least 64KB per task
        jb      init_ret
        ; DOS SDA
        push    ds
        mov     ax,5D06h
        int     21h
        mov     ax,ds
        pop     ds
        jc      init_sdabad
        mov     word ptr cs:sda_ptr,si
        mov     word ptr cs:sda_ptr+2,ax
        cmp     cx,dx           ; the in-DOS size (it holds the DOS stacks)
        jae     @F
        mov     cx,dx
@@:     cmp     cx,SDAMAX
        ja      init_sdabad
        mov     cs:sda_size,cx
        ; task 0:  the caller in the root context, the foreground
        mov     cs:cur,0
        mov     cs:fg,0
        mov     cs:newfg,0
        xor     bx,bx
        call    taskptr
        mov     ax,0400h        ; its text page while in the background
        qpi
        mov     ax,MVE_MEM
        jc      init_ret
        mov     [bx].T_VPG,dx
        mov     [bx].T_STATE,TS_READY
        mov     ax,cs:root_pt
        mov     [bx].T_PT,ax
        mov     [bx].T_NPG,0
        mov     cs:ntasks,1
        xor     ax,ax
        jmp     short init_ret
init_sdabad:
        mov     ax,MVE_SDA
init_ret:
        pop     ds
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret
mvk_init_ endp

;----------------------------------------------------------------------------
; int mvk_create(const char *prog, const char *tail):  a new task that runs
; prog (full path) with the command tail (text, at most 126 characters).
; Returns the task # (1-7) or -MVE_x.
mvk_create_ proc near
        push    bx
        push    cx
        push    si
        push    di
        push    es
        push    bp
        mov     bp,sp
        push    ax              ; [bp-2] prog
        push    dx              ; [bp-4] tail
        mov     ax,MVE_STATE
        cmp     cs:running,0
        jne     cr_err
        cmp     cs:ntasks,0
        je      cr_err
        mov     ax,MVE_FULL
        mov     bx,cs:ntasks
        cmp     bx,MAXTASK
        jae     cr_err
        call    taskptr
        mov     di,bx           ; DI ==> TASK
        mov     [di].T_NPG,0
        mov     [di].T_PT,0
        mov     [di].T_VPG,0
        mov     [di].T_EXIT,0FFFFh
        ; program and tail
        mov     si,[bp-2]
        lea     bx,[di].T_PROG
        mov     cx,79
@@:     lodsb
        mov     [bx],al
        inc     bx
        or      al,al
        loopnz  @B
        mov     byte ptr [bx],0
        mov     si,[bp-4]
        lea     bx,[di].T_TAIL+1
        xor     cx,cx
@@:     lodsb
        or      al,al
        jz      @F
        cmp     cx,126
        jae     @F
        mov     [bx],al
        inc     bx
        inc     cx
        jmp     @B
@@:     mov     byte ptr [bx],13
        mov     [di].T_TAIL,cl
        ; page table:  allocate, clone the root
        mov     ax,0400h
        qpi
        jc      cr_mem
        mov     [di].T_PT,dx
        mov     ax,0600h
        qpi
        jc      cr_mem
        ; private pages
        mov     cx,cs:priv_end
        sub     cx,cs:base_seg
        shr     cx,8            ; # pages
        lea     si,[di].T_FRAME
@@:     mov     ax,0400h
        qpi
        jc      cr_mem
        mov     [si],dx
        add     si,2
        inc     [di].T_NPG
        loop    @B
        mov     ax,0400h        ; text page (the task starts in the
        qpi                     ; background)
        jc      cr_mem
        mov     [di].T_VPG,dx
        ; into the new context:  install the pages
        mov     dx,[di].T_PT
        mov     ax,0800h
        qpi
        jc      cr_mem
        mov     cx,[di].T_NPG
        lea     si,[di].T_FRAME
        mov     bx,cs:base_seg
        shr     bx,8            ; first linear page
@@:     push    cx
        mov     cx,bx
        mov     dx,[si]
        mov     ax,0A00h
        qpi
        pop     cx
        jc      cr_rootmem
        inc     bx
        add     si,2
        loop    @B
        mov     cx,0B8h         ; its text page, blank
        mov     dx,[di].T_VPG
        mov     ax,0A00h
        qpi
        jc      cr_rootmem
        push    di
        mov     ax,0B800h
        mov     es,ax
        xor     di,di
        mov     ax,0720h
        mov     cx,2048
        cld
        rep     stosw
        pop     di
        ; the task's MCB chain:  stub block, free block, shared tail
        mov     ax,cs:base_seg
        mov     es,ax
        mov     byte ptr es:[0],'M'
        inc     ax
        mov     es:[1],ax       ; owner:  the stub PSP
        mov     word ptr es:[3],STUBPARA
        mov     ax,cs:base_seg
        add     ax,STUBPARA+1
        mov     es,ax           ; free block
        mov     cl,cs:free_typ
        mov     dx,cs:priv_end
        cmp     dx,cs:free_end
        je      @F
        mov     cl,'M'          ; the shared tail follows
@@:     mov     es:[0],cl
        mov     word ptr es:[1],0
        sub     dx,ax
        dec     dx
        mov     es:[3],dx
        mov     ax,cs:priv_end
        cmp     ax,cs:free_end
        je      @F
        mov     es,ax           ; shared tail:  system block
        mov     cl,cs:free_typ
        mov     es:[0],cl
        mov     word ptr es:[1],8
        mov     dx,cs:free_end
        sub     dx,ax
        dec     dx
        mov     es:[3],dx
        mov     word ptr es:[8],'CS'
@@:
        ; initial stack:  IRET frame to TASK_ENTRY, then what the switch pops
        mov     ax,cs:base_seg
        inc     ax
        mov     es,ax           ; ES = stub segment = task stack
        mov     bx,STUBPARA*16
        sub     bx,2
        mov     word ptr es:[bx],0202h ; FLAGS (IF)
        sub     bx,2
        mov     es:[bx],cs
        sub     bx,2
        mov     word ptr es:[bx],offset task_entry
        sub     bx,32           ; PUSHAD
        push    di
        mov     di,bx
        push    cx
        mov     cx,16
        xor     ax,ax
        rep     stosw
        pop     cx
        pop     di
        mov     ax,ds
        sub     bx,8            ; DS ES FS GS
        mov     es:[bx],ax
        mov     es:[bx+2],ax
        mov     es:[bx+4],ax
        mov     es:[bx+6],ax
        mov     [di].T_SS,es
        mov     [di].T_SP,bx
        ; IVT and SDA:  those of now; key buffer empty, cursors home
        call    save_ivtsda
        mov     ax,word ptr [di].T_KBD
        mov     word ptr [di].T_KBD+2,ax
        push    di
        push    es
        push    ds
        pop     es
        lea     di,[di].T_VID
        xor     ax,ax
        mov     cx,8
        rep     stosw
        pop     es
        pop     di
        ; back to the root
        mov     dx,cs:root_pt
        mov     ax,0800h
        qpi
        mov     [di].T_STATE,TS_READY
        mov     ax,cs:ntasks
        inc     cs:ntasks
        jmp     short cr_ret
cr_rootmem:
        mov     dx,cs:root_pt
        mov     ax,0800h
        qpi
cr_mem:
        call    task_free
        mov     ax,-MVE_MEM
        jmp     short cr_ret
cr_err:
        neg     ax
cr_ret:
        mov     sp,bp
        pop     bp
        pop     es
        pop     di
        pop     si
        pop     cx
        pop     bx
        ret
mvk_create_ endp

; free the pages and the page table of the task at DI (root context active)
task_free proc near
        push    ax
        push    cx
        push    dx
        push    si
        mov     cx,[di].T_NPG
        lea     si,[di].T_FRAME
        jcxz    tf_pt
@@:     mov     dx,[si]
        mov     ax,0500h
        qpi
        add     si,2
        loop    @B
tf_pt:  mov     [di].T_NPG,0
        mov     dx,[di].T_VPG
        or      dx,dx
        jz      @F
        mov     ax,0500h
        qpi
@@:     mov     [di].T_VPG,0
        mov     dx,[di].T_PT
        or      dx,dx
        jz      @F
        mov     ax,0500h
        qpi
@@:     mov     [di].T_PT,0
        mov     [di].T_STATE,TS_FREE
        pop     si
        pop     dx
        pop     cx
        pop     ax
        ret
task_free endp

; IVT, SDA, key buffer and cursor data into the TASK at DI (DS = DGROUP)
save_ivtsda proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,ds
        mov     es,ax
        cld
        push    di
        lea     di,[di].T_IVT
        xor     si,si
        mov     ds,si
        mov     cx,512
        rep     movsw
        pop     di
        push    di
        lea     di,[di].T_KBD   ; DS = 0
        mov     si,41Ah
        mov     cx,KBDLEN/2
        rep     movsw
        pop     di
        push    di
        lea     di,[di].T_VID
        mov     si,450h
        mov     cx,VIDLEN/2
        rep     movsw
        pop     di
        lea     di,[di].T_SDA
        lds     si,cs:sda_ptr
        mov     cx,cs:sda_size
        rep     movsb
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
save_ivtsda endp

; IVT, SDA, key buffer and cursor data from the TASK at DI (DS = DGROUP)
load_ivtsda proc near
        push    cx
        push    si
        push    di
        push    es
        cld
        push    di
        lea     si,[di].T_IVT
        xor     di,di
        mov     es,di
        mov     cx,512
        rep     movsw
        pop     di
        push    di
        lea     si,[di].T_KBD   ; ES = 0
        mov     di,41Ah
        mov     cx,KBDLEN/2
        rep     movsw
        pop     di
        push    di
        lea     si,[di].T_VID
        mov     di,450h
        mov     cx,VIDLEN/2
        rep     movsw
        pop     di
        push    di
        lea     si,[di].T_SDA
        les     di,cs:sda_ptr
        mov     cx,cs:sda_size
        rep     movsb
        pop     di
        pop     es
        pop     di
        pop     si
        pop     cx
        ret
load_ivtsda endp

; live key buffer into the TASK at BX (DS = DGROUP)
kbdsave proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        push    ds
        pop     es
        lea     di,[bx].T_KBD
        xor     si,si
        mov     ds,si
        mov     si,41Ah
        mov     cx,KBDLEN/2
        cld
        rep     movsw
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
kbdsave endp

; key buffer of the TASK at BX live (DS = DGROUP)
kbdload proc near
        push    cx
        push    si
        push    di
        push    es
        lea     si,[bx].T_KBD
        xor     di,di
        mov     es,di
        mov     di,41Ah
        mov     cx,KBDLEN/2
        cld
        rep     movsw
        pop     es
        pop     di
        pop     si
        pop     cx
        ret
kbdload endp

; DX = page table:  active (QPI 08h unless it is already)
setctx  proc near
        cmp     dx,cs:actpt
        je      @F
        push    ax
        mov     ax,0800h
        qpi
        pop     ax
        mov     cs:actpt,dx
@@:     ret
setctx  endp

; text page B8000h <-> vbuf (DS = DGROUP)
scr2buf proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,ds
        mov     es,ax
        mov     ax,0B800h
        mov     ds,ax
        xor     si,si
        mov     di,offset vbuf
        mov     cx,2048
        cld
        rep     movsw
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
scr2buf endp

buf2scr proc near
        push    cx
        push    si
        push    di
        push    es
        mov     ax,0B800h
        mov     es,ax
        mov     si,offset vbuf
        xor     di,di
        mov     cx,2048
        cld
        rep     movsw
        pop     es
        pop     di
        pop     si
        pop     cx
        ret
buf2scr endp

; DX = the new foreground task.  Its screen to the display, the old one's
; into its private page.  IF = 0, DS = DGROUP, on a shared stack.
setfg   proc near
        pusha
        push    es
        cmp     dx,cs:fg
        je      sfg_ret
        push    cs:actpt        ; the context to come back to
        push    dx
        mov     bx,cs:fg
        call    taskptr
        mov     di,bx
        mov     dx,[di].T_PT    ; the old foreground
        call    setctx
        call    scr2buf
        mov     cx,0B8h
        mov     dx,[di].T_VPG
        mov     ax,0A00h
        qpi
        call    buf2scr
        pop     bx              ; the new one
        push    bx
        call    taskptr
        mov     di,bx
        mov     dx,[di].T_PT
        call    setctx
        call    scr2buf
        mov     cx,0B8h
        mov     dx,cx
        mov     ax,0A00h
        qpi
        call    buf2scr
        pop     dx
        mov     cs:fg,dx
        pop     dx
        call    setctx
        call    fgcursor
sfg_ret:
        pop     es
        popa
        ret
setfg   endp

; the CRTC cursor of the foreground task (DS = DGROUP)
fgcursor proc near
        pusha
        push    es
        mov     bx,cs:fg
        cmp     bx,cs:cur
        jne     @F
        mov     ax,40h          ; the current task's:  live
        mov     es,ax
        mov     si,50h
        jmp     short fgc_1
@@:     call    taskptr
        lea     si,[bx].T_VID
        push    ds
        pop     es
fgc_1:  mov     cx,es:[si+10h]  ; shape:  CH start, CL end
        mov     bx,es:[si]      ; page 0:  BH row, BL column
        mov     ax,40h
        mov     es,ax
        mov     al,bh
        mul     byte ptr es:[4Ah]
        xor     bh,bh
        add     bx,ax
        mov     ax,es:[4Eh]
        shr     ax,1
        add     bx,ax
        mov     dx,es:[63h]
        mov     al,0Eh
        mov     ah,bh
        out     dx,ax
        mov     al,0Fh
        mov     ah,bl
        out     dx,ax
        mov     al,0Ah
        mov     ah,ch
        out     dx,ax
        mov     al,0Bh
        mov     ah,cl
        out     dx,ax
        pop     es
        popa
        ret
fgcursor endp

;----------------------------------------------------------------------------
; A task's first instructions (in its context, on its stack, IF=1)
task_entry proc far
        dbg     'E'
        mov     ax,cs:dgseg
        mov     ds,ax
        mov     bx,cs:cur
        call    taskptr
        mov     di,bx
        ; stub PSP at the task base + 1, current PSP
        mov     dx,cs:base_seg
        inc     dx
        mov     si,cs:priv_end
        mov     ah,55h
        int     21h
        mov     bx,cs:base_seg
        inc     bx
        mov     ah,50h
        int     21h
        ; EXEC the program
        mov     [di].T_PB,0     ; environment of the stub PSP
        lea     ax,[di].T_TAIL
        mov     [di].T_PB+2,ax
        mov     [di].T_PB+4,ds
        mov     [di].T_PB+6,5Ch
        mov     [di].T_PB+8,bx
        mov     [di].T_PB+10,6Ch
        mov     [di].T_PB+12,bx
        push    ds
        pop     es
        lea     bx,[di].T_PB
        lea     dx,[di].T_PROG
        dbg     'X'
        mov     ax,4B00h
        int     21h
        dbg     'R'
        mov     ax,cs:dgseg
        mov     ds,ax
        mov     ax,0FFFFh
        jc      @F
        mov     ah,4Dh
        int     21h
@@:     mov     bx,cs:cur
        call    taskptr
        mov     [bx].T_EXIT,ax
        mov     [bx].T_STATE,TS_DONE
@@:     sti
        jmp     @B              ; until the scheduler leaves it for good
task_entry endp

;----------------------------------------------------------------------------
; IRQ0 calldown:  timer, then maybe the next task or another foreground
irq0    proc far
        int     08h             ; the task's timer chain (BIOS:  EOI)
        dbg     '.'
        cmp     cs:running,0
        je      irq0_out
        mov     cs:yieldf,0
        dec     cs:qleft
        jz      irq0_q
        mov     cs:wantsw,0
        push    ax
        mov     ax,cs:newfg
        cmp     ax,cs:fg
        pop     ax
        jne     sched           ; only the foreground
        iret
irq0_q: mov     cs:qleft,1      ; not now:  try again next tick
        mov     cs:wantsw,1
; IRET frame on the stack, IF = 0:  the scheduler
sched:: pushad
        push    ds
        push    es
        push    fs
        push    gs
        mov     bp,sp
        mov     ax,cs:dgseg     ; the task table
        mov     ds,ax
        ; another foreground:  not inside 386MAX nor another task's handler
        mov     ax,cs:newfg
        cmp     ax,cs:fg
        je      sc_nofg
        mov     ax,[bp+40+2]
        cmp     ax,cs:qpi_seg
        je      sc_nofg
        cmp     cs:idepth,0
        jne     sc_nofg
        mov     cs:fgss,ss
        mov     cs:fgsp,sp
        mov     ax,cs:dgseg
        mov     ss,ax
        mov     sp,offset kstktop
        mov     dx,cs:newfg
        call    setfg
        mov     ss,cs:fgss
        mov     sp,cs:fgsp
sc_nofg:
        cmp     cs:wantsw,0
        je      irq0_no
        ; interrupted CS (IRET frame behind the 40 bytes saved)
        mov     ax,[bp+40+2]
        cmp     ax,cs:qpi_seg
        je      irq0_nocs
        cmp     cs:i13busy,0
        jne     irq0_no13
        cmp     cs:idepth,0
        jne     irq0_no13
        les     bx,cs:sda_ptr
        cmp     cs:yieldf,0
        je      @F
        cmp     byte ptr es:[bx],0 ; waiting (maybe in DOS):  no critical
        jne     irq0_nodos      ; error
        jmp     short irq0_pic
@@:     cmp     word ptr es:[bx],0 ; critical error flag, InDOS
        jne     irq0_nodos
irq0_pic:
        mov     al,0Bh          ; PIC in-service registers
        out     20h,al
        in      al,20h
        mov     ah,al
        mov     al,0Bh
        out     0A0h,al
        in      al,0A0h
        or      ah,al
        mov     al,0Ah          ; back to IRR reads
        out     20h,al
        out     0A0h,al
        or      ah,ah
        jnz     irq0_nopic
        ; next ready task
        mov     cx,cs:ntasks
        mov     dx,cs:cur
@@:     inc     dx
        cmp     dx,cs:ntasks
        jb      short irq0_chk
        xor     dx,dx
irq0_chk:
        mov     bx,dx
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        je      irq0_found
        loop    @B
        dbg     'n'
        jmp     irq0_no
irq0_nocs:
        dbg     'c'
        jmp     irq0_no
irq0_no13:
        dbg     'i'
        jmp     irq0_no
irq0_nodos:
        dbg     'd'
        jmp     short irq0_no
irq0_nopic:
        dbg     'p'
        jmp     short irq0_no
irq0_found:
        cmp     dx,cs:cur
        je      irq0_no
        mov     di,bx           ; DI ==> next TASK
        mov     bx,cs:cur
        call    taskptr         ; BX ==> current TASK
        mov     [bx].T_SS,ss
        mov     [bx].T_SP,sp
        mov     ax,cs:dgseg
        mov     ss,ax           ; shared kernel stack (the SDA swap may
        mov     sp,offset kstktop ; overwrite the DOS stack in use)
        xchg    di,bx
        call    save_ivtsda
        xchg    di,bx
        call    load_ivtsda
        push    dx
        mov     dx,[di].T_PT
        mov     ax,0800h
        qpi
        mov     cs:actpt,dx
        pop     dx
        mov     cs:cur,dx
        dbg     'T'
if MVDEBUG
        push    ax
        mov     al,'0'
        add     al,dl
        out     0E9h,al
        pop     ax
endif
        add     dword ptr cs:nswitch,1
        mov     ss,[di].T_SS
        mov     sp,[di].T_SP
        mov     ax,cs:quantum
        mov     cs:qleft,ax
irq0_no:
        pop     gs
        pop     fs
        pop     es
        pop     ds
        popad
irq0_out:
        iret
irq0    endp

; a task waits:  the others now (IRET frame to the caller)
yield   proc near
        pushf
        push    cs
        call    yield1
        ret
yield1: cli
        mov     cs:wantsw,1
        mov     cs:yieldf,1
        jmp     sched
yield   endp

; INT 16h:  a read without a key waits in the other tasks
int16   proc far
        cmp     cs:running,0
        je      i16_old
        cmp     ah,00h
        je      i16_wait
        cmp     ah,10h
        je      i16_wait
        cmp     ah,20h
        jne     i16_old
i16_wait:
        push    ax
i16_poll:
        pop     ax
        push    ax
        inc     ah              ; status
        pushf
        call    dword ptr cs:old16
        jnz     i16_key
        call    yield
        jmp     i16_poll
i16_key:
        pop     ax
i16_old:
        jmp     dword ptr cs:old16
int16   endp

; INT 28h (DOS idle):  the other tasks
int28   proc far
        cmp     cs:running,0
        je      @F
        call    yield
@@:     jmp     dword ptr cs:old28
int28   endp

; INT 10h of a background task:  its private text page; no mode, cursor
; shape, page or palette change; the CRTC cursor stays the foreground's
int10   proc far
        cmp     cs:running,0
        je      i10_old
        push    ax
        mov     ax,cs:cur
        cmp     ax,cs:fg
        pop     ax
        je      i10_old
        cmp     ah,00h
        je      i10_mode
        cmp     ah,01h
        je      i10_shape
        cmp     ah,05h
        je      i10_ret
        cmp     ah,0Bh
        je      i10_ret
        cmp     ah,10h
        je      i10_ret
        cmp     ah,11h
        je      i10_ret
        pushf
        call    dword ptr cs:old10
        pushf
        push    ds
        mov     ds,cs:dgseg
        call    fgcursor
        pop     ds
        popf
        retf    2
i10_mode:                       ; mode set:  a blank screen
        push    ax
        push    cx
        push    di
        push    es
        mov     ax,0B800h
        mov     es,ax
        xor     di,di
        mov     ax,0720h
        mov     cx,2000
        cld
        rep     stosw
        mov     ax,40h
        mov     es,ax
        mov     word ptr es:[50h],0
        pop     es
        pop     di
        pop     cx
        pop     ax
        iret
i10_shape:
        push    es
        push    ax
        mov     ax,40h
        mov     es,ax
        mov     es:[60h],cx
        pop     ax
        pop     es
i10_ret:
        iret
i10_old:
        jmp     dword ptr cs:old10
int10   endp

; IRQ1-7:  to the task that hooked the vector (its IVT entry differs from
; the one at mvk_start), the current task first; none:  the current IVT
irq1:   push    ax
        mov     al,09h
        jmp     short irqdisp
irq2:   push    ax
        mov     al,0Ah
        jmp     short irqdisp
irq3:   push    ax
        mov     al,0Bh
        jmp     short irqdisp
irq4:   push    ax
        mov     al,0Ch
        jmp     short irqdisp
irq5:   push    ax
        mov     al,0Dh
        jmp     short irqdisp
irq6:   push    ax
        mov     al,0Eh
        jmp     short irqdisp
irq7:   push    ax
        mov     al,0Fh

irqdisp:
        push    bx
        push    cx
        push    dx
        push    esi             ; (32 bits:  used for addressing)
        push    edi
        push    bp
        push    ds
        push    es
        mov     bx,cs:dgseg
        mov     ds,bx
        xor     ah,ah
        shl     ax,1
        shl     ax,1
        movzx   esi,ax          ; ESI = vector * 4
        cmp     si,9*4
        je      irqd_kbd
        xor     ax,ax
        mov     es,ax
        ; the current task's vector (in the IVT now)
        mov     ax,es:[si]
        mov     dx,es:[si+2]
        cmp     ax,word ptr origivt[si]
        jne     irqd_here
        cmp     dx,word ptr origivt[si+2]
        jne     irqd_here
        ; another task's
        mov     cx,cs:ntasks
        xor     bx,bx
irqd_next:
        cmp     bx,cs:cur
        je      irqd_skip
        push    bx
        call    taskptr
        movzx   edi,bx
        pop     bx
        cmp     [di].T_STATE,TS_FREE
        je      irqd_skip
        mov     ax,word ptr [edi+esi].T_IVT
        cmp     ax,word ptr origivt[si]
        jne     irqd_other
        mov     ax,word ptr [edi+esi].T_IVT+2
        cmp     ax,word ptr origivt[si+2]
        jne     irqd_other
irqd_skip:
        inc     bx
        loop    irqd_next
irqd_here:
        pushf
        call    dword ptr es:[si]
        jmp     irqd_ret
irqd_other:
        call    irqd_ctx
        jmp     irqd_ret
irqd_kbd:
        ; Ctrl+Alt+1..9, 0:  that task to the foreground (key consumed)
        in      al,60h
        cmp     al,02h
        jb      irqk_fg
        cmp     al,0Bh
        ja      irqk_fg
        xor     bx,bx
        mov     es,bx
        mov     bl,es:[417h]
        and     bl,0Ch
        cmp     bl,0Ch
        jne     irqk_fg
        dec     al
        xor     ah,ah
        cmp     al,10
        jne     @F
        xor     ax,ax
@@:     cmp     ax,cs:ntasks
        jae     irqk_fg
        mov     bx,ax
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        jne     irqk_fg
        mov     cs:newfg,ax
        dbg     'F'
        mov     al,20h
        out     20h,al
        jmp     irqd_ret
irqk_fg:
        ; to the foreground task:  its INT 09h with its key buffer
        xor     ax,ax
        mov     es,ax
        mov     bx,cs:fg
        cmp     bx,cs:cur
        je      irqd_here
        call    taskptr
        movzx   edi,bx
        mov     bx,cs:cur
        call    taskptr
        call    kbdsave
        push    bx
        mov     bx,di
        call    kbdload
        call    irqd_ctx
        mov     bx,di
        call    kbdsave
        pop     bx
        call    kbdload
        jmp     irqd_ret

; the handler (vector ESI/4) of the TASK at DI in its context, on the IRQ
; stack (DS = DGROUP)
irqd_ctx proc near
        mov     dx,[di].T_PT
        cmp     dx,cs:actpt
        jne     @F
        pushf                   ; its context is active already
        call    dword ptr [edi+esi].T_IVT
        ret
@@:     mov     ax,ss
        mov     bx,sp
        cmp     cs:idepth,0
        jne     @F              ; on the IRQ stack already
        mov     cx,cs:dgseg
        mov     ss,cx
        mov     sp,offset istktop
@@:     inc     cs:idepth
        push    ax              ; old SS:SP
        push    bx
        push    cs:actpt
        mov     ax,0800h
        qpi
        mov     cs:actpt,dx
        mov     ax,cs:dgseg
        mov     ds,ax
        pushf
        call    dword ptr [edi+esi].T_IVT
        pop     dx              ; back to the context before
        mov     ax,0800h
        qpi
        mov     cs:actpt,dx
        pop     bx
        pop     ax
        dec     cs:idepth
        mov     ss,ax
        mov     sp,bx
        ret
irqd_ctx endp

irqd_ret:
        pop     es
        pop     ds
        pop     bp
        pop     edi
        pop     esi
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret

; INT 13h:  no task switch while the disk BIOS works
int13   proc far
        inc     cs:i13busy
        pushf
        call    dword ptr cs:old13
        pushf
        dec     cs:i13busy
        popf
        retf    2
int13   endp

;----------------------------------------------------------------------------
; int mvk_start(unsigned quantum):  start switching (quantum in ticks).
; Returns 0 or MVE_x.
mvk_start_ proc near
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        mov     dx,ax
        mov     ax,MVE_STATE
        cmp     cs:running,0
        jne     st_ret
        cmp     cs:ntasks,0
        je      st_ret
        or      dx,dx
        jnz     @F
        inc     dx
@@:     mov     cs:quantum,dx
        mov     cs:qleft,dx
        xor     ax,ax
        mov     es,ax
        cli
        push    ds              ; the IVT now:  the one tasks start from
        push    es
        push    si
        push    di
        push    cx
        mov     ax,ds
        mov     cx,es
        mov     es,ax
        mov     ds,cx
        xor     si,si
        mov     di,offset origivt
        mov     cx,512
        cld
        rep     movsw
        pop     cx
        pop     di
        pop     si
        pop     es
        pop     ds
        call    hook_install
        ; calldown table
        mov     word ptr cdtab,offset irq0
        mov     word ptr cdtab+4,offset irq1
        mov     word ptr cdtab+8,offset irq2
        mov     word ptr cdtab+12,offset irq3
        mov     word ptr cdtab+16,offset irq4
        mov     word ptr cdtab+20,offset irq5
        mov     word ptr cdtab+24,offset irq6
        mov     word ptr cdtab+28,offset irq7
        mov     cx,8
        mov     di,offset cdtab+2
@@:     mov     [di],cs
        add     di,4
        loop    @B
        push    es
        push    ds              ; QPI 1C01h reads the table at ES:DI
        pop     es
        mov     di,offset cdtab
        mov     ax,1C01h
        qpi
        pop     es
        jc      st_irqbad
        mov     cs:running,1
        dbg     'S'
        sti
        xor     ax,ax
        jmp     short st_ret
st_irqbad:
        call    hook_remove
        sti
        mov     ax,MVE_IRQ
st_ret:
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        ret
mvk_start_ endp

;----------------------------------------------------------------------------
; void mvk_stop(void):  from task 0 only.  Stops switching, removes the
; calldowns and the INT 13h hook, frees all tasks.
mvk_stop_ proc near
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        cmp     cs:ntasks,0
        je      sp_ret
        cli
        xor     dx,dx           ; our screen back
        call    setfg
        mov     cs:newfg,dx
        mov     cs:running,0
        sti
        mov     ax,1C00h
        qpi
        xor     ax,ax
        mov     es,ax
        cli
        call    hook_remove
        sti
        xor     bx,bx
        call    taskptr
        mov     dx,[bx].T_VPG
        mov     ax,0500h
        qpi
        mov     cx,cs:ntasks
        dec     cx
        jcxz    sp_done
        mov     bx,1
@@:     push    bx
        call    taskptr
        mov     di,bx
        call    task_free
        pop     bx
        inc     bx
        loop    @B
sp_done:
        mov     cs:ntasks,0
sp_ret:
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
mvk_stop_ endp

; hooks (hooktab) into the live IVT (ES = 0) and every task's
hook_install proc near
        pusha
        mov     si,offset hooktab
        mov     cx,NHOOK
hi_next:
        push    cx
        mov     di,cs:[si]      ; vector * 4
        mov     bx,cs:[si+4]    ; ==> old vector
        mov     ax,es:[di]
        mov     cs:[bx],ax
        mov     ax,es:[di+2]
        mov     cs:[bx+2],ax
        mov     ax,cs:[si+2]    ; handler
        mov     es:[di],ax
        mov     es:[di+2],cs
        mov     cx,cs:ntasks
        xor     bx,bx
@@:     push    bx
        call    taskptr
        mov     word ptr [bx+di].T_IVT,ax
        mov     word ptr [bx+di].T_IVT+2,cs
        pop     bx
        inc     bx
        loop    @B
        pop     cx
        add     si,6
        loop    hi_next
        popa
        ret
hook_install endp

; the old vectors back into the live IVT (ES = 0)
hook_remove proc near
        pusha
        mov     si,offset hooktab
        mov     cx,NHOOK
hr_next:
        mov     di,cs:[si]
        mov     bx,cs:[si+4]
        mov     ax,cs:[bx]
        or      ax,cs:[bx+2]
        jz      @F
        mov     ax,cs:[bx]
        mov     es:[di],ax
        mov     ax,cs:[bx+2]
        mov     es:[di+2],ax
@@:     add     si,6
        loop    hr_next
        popa
        ret
hook_remove endp

; int mvk_setfg(unsigned task):  the task shown and getting the keys (from
; task 0).  0 or MVE_x.
mvk_setfg_ proc near
        push    bx
        push    dx
        mov     dx,ax
        mov     ax,MVE_STATE
        cmp     cs:cur,0
        jne     sf_ret
        cmp     dx,cs:ntasks
        jae     sf_ret
        mov     bx,dx
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        jne     sf_ret
        pushf
        cli
        call    setfg
        mov     cs:newfg,dx
        popf
        xor     ax,ax
sf_ret: pop     dx
        pop     bx
        ret
mvk_setfg_ endp

; unsigned mvk_fg(void):  the foreground task
mvk_fg_ proc near
        mov     ax,cs:fg
        ret
mvk_fg_ endp

; unsigned mvk_state(unsigned task)
mvk_state_ proc near
        push    bx
        mov     bx,ax
        xor     ax,ax
        cmp     bx,cs:ntasks
        jae     @F
        call    taskptr
        mov     ax,[bx].T_STATE
@@:     pop     bx
        ret
mvk_state_ endp

; unsigned mvk_exit(unsigned task):  EXEC result of a DONE task
mvk_exit_ proc near
        push    bx
        mov     bx,ax
        mov     ax,0FFFFh
        cmp     bx,cs:ntasks
        jae     @F
        call    taskptr
        mov     ax,[bx].T_EXIT
@@:     pop     bx
        ret
mvk_exit_ endp

; unsigned long mvk_switches(void)  (DX:AX)
mvk_switches_ proc near
        mov     ax,word ptr cs:nswitch
        mov     dx,word ptr cs:nswitch+2
        ret
mvk_switches_ endp

; unsigned mvk_base(void):  task base after mvk_init
mvk_base_ proc near
        mov     ax,cs:base_seg
        ret
mvk_base_ endp

        end
