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
; task's INT 08h and switches round robin every QUANTUM ticks (the task
; with the keys:  FGQUANT, three times as many by default, as DESQview's
; foreground and background ticks 9 and 3), but only
; at a safe point:  DOS not busy (SDA critical error flag and InDOS), no
; INT 13h in progress, no other IRQ handler in service (PIC ISR) and the
; interrupted code not 386MAX's own V86 code (its segment is the QPI entry
; segment):  an IRQ taken while 386MAX works in protected mode returns
; through such a stub, and that frame belongs to the interrupted task.
; A task that waits (INT 16h read without a key, DOS idle INT 28h) yields
; at once; then DOS may be busy with console input, safe as the whole SDA
; (with the DOS stacks) is swapped.
; Per task:  all registers (on the task's stack), the IVT, 40:F0-FF (as
; DESQview), the DOS SDA
; (INT 21h 5D06h, the in-DOS size; the current drive is in it), the DOS
; current directories (the CDS), the BIOS key buffer and cursor data.
; Also MAXVTSR's per-task state (its D707h block:  API level, critical
; nesting, OSTACK, ...), as DESQview keeps it per window.
; CDS and SDA (4KB) are kept in the task's own memory, a block behind its
; stub PSP (task 0's in the kernel data):  the table holds 1.7KB a task,
; up to MAXTASK (30) of them, as many as the caller asks (mvk_datasize).
; QPI 08h is called on a shared kernel stack:  the task's stack is gone
; once the context changes, and the SDA swap may overwrite a DOS stack.
;
; Screen and keys:  one task is the foreground (owns the display; the
; colour text memory B8000h-BFFFFh, NVPG pages, else private), one
; has the key focus (the foreground but for windows:  task 0 shows the
; others' screens, mvk_peek, in windows and gives the keys to one,
; mvk_focus).  The text page B8000h of
; every other task is a private page (QPI 0Ah); a foreground change copies
; the screens and remaps them.  INT 10h of a background task leaves the
; hardware alone (mode, cursor shape, page, palette; the CRTC cursor goes
; back to the foreground's).  A background task's own CRTC and DAC OUTs do
; not reach the hardware either (QPI 0Dh/0Eh, crtset):  its cursor address
; goes to its BIOS cursor, the rest is dropped.  IRQ1 runs the foreground's INT 09h with its
; key buffer; Ctrl+Alt+1..9 makes task 1..9 the foreground, Ctrl+Alt+0
; task 0; with mvk_dvkey also Alt pressed and released alone (DESQview's
; key).  These come by the BIOS keyboard intercept (INT 15h AH=4Fh).  A task in a DOS critical error (INT 24h:  no switching until it
; is answered) becomes the foreground, and stays it until then.
;
; A task starts in TASK_ENTRY:  a stub PSP of its own at the task base,
; then DOS EXEC of its program; when that ends, the task is DONE and its
; slot free for a new task (mvk_create also while running).  mvk_kill ends
; a task:  outside DOS its frame goes to KILL_ENTRY, which ends program
; after program (INT 21h 4Ch, the terminate address of each set to itself)
; down to the stub PSP; in DOS (console input) a Ctrl-C in its key buffer
; and an INT 23h of ours get it out of DOS first.
;
; Open Watcom register convention (small model):  first argument in AX,
; second in DX; result in AX.

        .model  small
        .386

MAXTASK         equ 30          ; task 0 (the caller) + 29 at most (the
                                ; table has mvk_datasize's count)
MAXPAGE         equ 160         ; private pages per task (640KB)
STUBPARA        equ 40h         ; stub PSP + task stack (1KB)
KSTACK          equ 512         ; kernel stack (QPI 08h)
SDAMAX          equ 2048        ; DOS SDA swapped
CDSMAX          equ 26*58h      ; DOS current directories (CDS) swapped
DVSTMAX         equ 3520        ; MAXVTSR's per-task state (INT 2Fh D707h)
DVINITMAX       equ 160         ;   the part a new task inherits (the rest,
                                ;   its GETMEM pool, starts zero)
SAVEPARA        equ (CDSMAX + SDAMAX + DVSTMAX + 15) / 16 ; CDS, SDA and
                                ; MAXVTSR's state saved, behind the stub PSP
                                ; in each task's own memory
NVPG            equ 8           ; text pages B8000h-BFFFFh private per task
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
MVE_DVST        equ 8           ; MAXVTSR's per-task state too big

TASK    struc
T_STATE dw      ?
T_PT    dw      ?               ; physical page of its page table
T_SS    dw      ?
T_SP    dw      ?
T_NPG   dw      ?               ; # private pages
T_EXIT  dw      ?               ; EXEC result:  AX of 4Dh, FFFFh = EXEC failed
T_KILL  dw      ?               ; 1:  end it, 2:  Ctrl-C sent
T_CRIT  dw      ?               ; DESQview critical sections open
T_MODE  db      ?               ; video mode (40:49) and rows - 1 (40:84)
T_ROWS  db      ?               ;   when it was last the foreground
T_VESA  dw      ?               ; VESA mode set (4F02h), 0:  none
T_HOLD  dw      ?               ; 1:  graphics in the background, held
T_FRZ   dw      ?               ; 1:  frozen (runs only with the keys)
T_EXCL  dw      ?               ; 1:  with the keys the others wait
T_PARENT dw     ?               ; a DESQview subtask (thread):  its task's
                                ; number + 1 (its memory, page table and
                                ; screen); 0:  a task of its own
T_PB    dw      7 dup (?)       ; EXEC parameter block
T_PROG  db      80 dup (?)      ; program path (ASCIIZ)
T_TAIL  db      130 dup (?)     ; command tail (length, text, CR)
T_VPG   dw      NVPG dup (?)    ; private frames of the text pages B8000h..
T_XSAVE dd      ?               ; its CDS, SDA (at CDSMAX), MAXVTSR's state
                                ; (at CDSMAX + SDAMAX):  in its own
                                ; memory (seen only in its context)
T_KBD   db      KBDLEN dup (?)
T_VID   db      VIDLEN dup (?)
T_ICA   db      16 dup (?)      ; 40:F0-FF (per window under DESQview too)
T_IVT   db      1024 dup (?)
T_FRAME dw      MAXPAGE dup (?) ; private page frames
TASK    ends

; kernel data:  a DOS block of the caller's below the task base (shared by
; all tasks; mvk_datasize, mvk_init); the IRQ handlers find it by CS:KSEG
MVKDATA segment para at 0
cdtab   dd      8 dup (?)       ; IRQ0-7 calldown table (QPI copies it)
kstk    db      KSTACK dup (?)
kstktop label   word
istk    db      ISTACK dup (?)
istktop label   word
vbuf    db      4096 dup (?)    ; a text page on its way (foreground change)
origivt dd      256 dup (?)     ; the IVT at mvk_start:  a task whose vector
                                ; differs has hooked it
cprog   db      80 dup (?)      ; mvk_create arguments
ctail   db      128 dup (?)
t0save  db      CDSMAX + SDAMAX + DVSTMAX dup (?) ; task 0's (root context)
                                ; T_XSAVE
dvinit  db      DVINITMAX dup (?) ; MAXVTSR's state at mvk_init:  new tasks
tasks   TASK    MAXTASK dup (<>) ; (last:  mvk_datasize's count of them)
kdata_end label byte
MVKDATA ends
KDATASIZE equ   MAXTASK*(size TASK) + 32 + KSTACK + ISTACK + 4096 + 1024 + 80 + 128 + CDSMAX + SDAMAX + DVSTMAX + DVINITMAX
        .erre   KDATASIZE LE 0FFF0h, <kernel data over 64KB:  MAXTASK, SDAMAX, CDSMAX>

        .code
        assume  ds:MVKDATA

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
        public  mvk_dvcolors_
        public  mvk_kill_
        public  mvk_yield_
        public  mvk_dvkey_
        public  mvk_focus_
        public  mvk_focused_
        public  mvk_freeze_
        public  mvk_share_
        public  mvk_peek_
        public  mvk_datasize_
        public  mvk_tune_

; kernel data in CS:  the IRQ handlers find it without DS
qpi_entry dd    0
qpi_seg  dw     0               ; 386MAX's V86 code segment
kseg   dw     0
sda_ptr  dd     0
sda_size dw     0
cds_ptr  dd     0               ; DOS CDS array (List of Lists +16h)
cds_size dw     0               ; LASTDRIVE * entry size
base_seg dw     0               ; task base (4KB aligned)
priv_end dw     0               ; end of the private pages (segment)
free_end dw     0               ; end of the root's free block at the base
free_typ db     0               ; its MCB type ('M' or 'Z')
         db     0
root_pt  dw     0
ntasks   dw     0
cur      dw     0
irqown   dw     8 dup (0)       ; IRQ0-7:  the TASK (offset) that hooked its
                                ; vector last (0:  none), as under DESQview
                                ; the window that hooked an IRQ last gets it
scur     dw     0               ; whose screen cur has (its parent's for a
                                ; subtask)
running  dw     0
crtok    db     0               ; QPI 0Eh took our cursor callbacks
crtmode  db     0               ; QPI 0Dh now:  0 off, 1 mono, 2 colour
dvst_ptr dd     0               ; MAXVTSR's per-task state block
dvst_size dw    0               ;   (0:  none)
dvst_init dw    0               ;   what new tasks inherit of it
nslots   dw     8               ; slots in the table (mvk_datasize)
quantum  dw     2
fgquant  dw     6               ; for the task with the keys
qleft    dw     2
i13busy  dw     0
actpt    dw     0               ; page table active now
idepth   dw     0               ; IRQ handlers of other tasks running
nswitch  dd     0
fg       dw     0               ; foreground task
newfg    dw     0               ; wanted (hotkey)
kfocus   dw     0               ; task getting the keys
wantsw   dw     0               ; scheduler:  switch tasks
yieldf   dw     0               ; scheduler:  the task waits
altpend  dw     0               ; Alt pressed, no other key since
dvkey    dw     0               ; Alt alone:  task 0
dvcol    dw     0               ; DESQview's window colours (fgpal), off:
                                ; programs show their own colours
fgss     dw     0
fgsp     dw     0
old10    dd     0
in10     dw     0               ; calls in the video BIOS
insched  dw     0               ; setfg running (it calls the video BIOS)
hwmode   db     0               ; the display's mode, rows and VESA mode as
hwrows   db     0               ;   the last foreground left them
hwvesa   dw     0
vidsave  db     VIDLEN dup (0)  ; cursor data over a mode set
ecols    dw     0               ; emu10:  the task's text layout
erows    dw     0
epsize   dw     0               ;   page size
eattr    dw     0               ;   attribute to write, FFFFh:  keep
edir     db     0               ;   scroll:  0 up, 1 down
etop     db     0
ebot     db     0
eleft    db     0
ewid     dw     0
ecnt     db     0
eatr     db     0
old13    dd     0
old16    dd     0
old28    dd     0
old15    dd     0
; vector * 4, handler, old vector:  in every task's IVT while running
hooktab  dw     10h*4, offset int10, offset old10
         dw     13h*4, offset int13, offset old13
         dw     16h*4, offset int16, offset old16
         dw     28h*4, offset int28, offset old28
         dw     15h*4, offset int15, offset old15
NHOOK    equ    5

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

; CF:  task DX (TASK at BX, DS = kernel data) has not the keys (a subtask:
; its task) and is frozen, or the task with them does not share the CPU
frozen  proc near
        push    ax
        push    bx
        mov     ax,dx
        cmp     [bx].T_PARENT,0
        je      @F
        mov     ax,[bx].T_PARENT
        dec     ax
        mov     bx,ax
        call    taskptr
@@:     cmp     ax,cs:kfocus
        je      fz_no
        cmp     [bx].T_FRZ,0
        jne     fz_yes
        mov     bx,cs:kfocus
        call    taskptr
        cmp     [bx].T_EXCL,0
        je      fz_no
        cmp     [bx].T_STATE,TS_READY
        jne     fz_no
fz_yes: stc
        jmp     short fz_ret
fz_no:  clc
fz_ret: pop     bx
        pop     ax
        ret
frozen  endp

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
        cmp     cs:running,0
        mov     bx,ax
        mov     ax,MVE_STATE
        jne     init_ret
        mov     cs:base_seg,bx
        mov     cs:kseg,dx
        mov     ds,dx
        mov     es,dx           ; a DOS block:  zeros first (as large as
        mov     ax,size TASK    ; mvk_datasize made it)
        mul     cs:nslots
        add     ax,offset tasks + 1
        shr     ax,1
        mov     cx,ax
        xor     di,di
        xor     ax,ax
        cld
        rep     stosw
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
        ; current directories:  the CDS (List of Lists +16h, LASTDRIVE at
        ; +21h; entries of 58h bytes, 51h before DOS 4)
        push    ds
        mov     ah,30h
        int     21h
        mov     cl,al
        mov     ah,52h
        int     21h
        mov     ax,es:[bx+16h]
        mov     word ptr cs:cds_ptr,ax
        mov     ax,es:[bx+18h]
        mov     word ptr cs:cds_ptr+2,ax
        mov     al,es:[bx+21h]
        xor     ah,ah
        mov     dx,58h
        cmp     cl,4
        jae     @F
        mov     dx,51h
@@:     mul     dx
        cmp     ax,CDSMAX
        jbe     @F
        mov     ax,CDSMAX
@@:     mov     cs:cds_size,ax
        pop     ds
        ; task 0:  the caller in the root context, the foreground
        mov     cs:cur,0
        mov     cs:scur,0
        mov     cs:fg,0
        mov     cs:newfg,0
        mov     cs:kfocus,0
        xor     bx,bx
        call    taskptr
        mov     di,bx
        call    vpg_alloc       ; its text pages while in the background
        mov     ax,MVE_MEM
        jc      init_ret
        push    es
        mov     ax,40h
        mov     es,ax
        mov     al,es:[49h]
        and     al,7Fh
        mov     [bx].T_MODE,al
        mov     al,es:[84h]
        mov     [bx].T_ROWS,al
        pop     es
        mov     [bx].T_VESA,0
        mov     [bx].T_HOLD,0
        mov     [bx].T_FRZ,0
        mov     [bx].T_EXCL,0
        mov     [bx].T_STATE,TS_READY
        mov     ax,cs:root_pt
        mov     [bx].T_PT,ax
        mov     word ptr [bx].T_XSAVE,offset t0save
        mov     ax,cs:kseg
        mov     word ptr [bx].T_XSAVE+2,ax
        mov     [bx].T_NPG,0
        mov     cs:ntasks,1
        ; MAXVTSR's per-task state (INT 2Fh D707h):  swapped as the SDA;
        ; new tasks start with the state of now
        mov     cs:dvst_size,0
        push    es
        mov     ax,0D707h
        xor     cx,cx
        int     2Fh
        or      ax,ax               ; (no MAXVTSR:  nothing to swap)
        jnz     init_nodv
        cmp     cx,DVSTMAX          ; a MAXVTSR this core cannot swap:  its
        ja      init_dvbad          ; tasks would share one state
        cmp     dx,DVINITMAX
        ja      init_dvbad
        cmp     dx,cx
        ja      init_dvbad
        mov     word ptr cs:dvst_ptr,bx
        mov     word ptr cs:dvst_ptr+2,es
        mov     cs:dvst_size,cx
        mov     cs:dvst_init,dx
        mov     cx,dx
        push    ds
        push    si
        push    di
        mov     ax,ds
        lds     si,cs:dvst_ptr
        mov     es,ax
        mov     di,offset dvinit
        cld
        rep     movsb
        pop     di
        pop     si
        pop     ds
init_nodv:
        pop     es
        xor     ax,ax
        jmp     short init_ret
init_dvbad:
        pop     es
        mov     ax,MVE_DVST
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
create_k proc near
        push    bx
        push    cx
        push    si
        push    di
        push    es
        push    bp
        mov     bp,sp
        push    ax              ; [bp-2] prog
        push    dx              ; [bp-4] tail
        pushf                   ; [bp-6]
        push    ax              ; [bp-8] task #
        cli                     ; (contexts change below)
        mov     ax,MVE_STATE
        cmp     cs:cur,0
        jne     cr_err
        cmp     cs:ntasks,0
        je      cr_err
        ; a slot:  a free or done one (not the foreground), else a new one
        mov     bx,1
cr_slot:
        cmp     bx,cs:ntasks
        jae     cr_new
        push    bx
        call    taskptr
        mov     di,bx
        pop     bx
        cmp     [di].T_STATE,TS_READY
        je      cr_snext
        cmp     bx,cs:fg
        je      cr_snext
        cmp     bx,cs:newfg
        je      cr_snext
        call    task_free
        jmp     short cr_have
cr_snext:
        inc     bx
        jmp     cr_slot
cr_new: mov     ax,MVE_FULL
        cmp     bx,cs:nslots
        jae     cr_err
        push    bx
        call    taskptr
        mov     di,bx           ; DI ==> TASK
        pop     bx
cr_have:
        mov     [bp-8],bx
        mov     [di].T_KILL,0
        mov     [di].T_CRIT,0
        mov     [di].T_NPG,0
        mov     [di].T_PT,0
        mov     [di].T_VPG,0    ; (vpg_alloc fills them all)
        mov     [di].T_VESA,0
        mov     [di].T_HOLD,0
        mov     [di].T_FRZ,0
        mov     [di].T_EXCL,0
        mov     [di].T_PARENT,0
        mov     word ptr [di].T_XSAVE,0 ; behind its stub PSP
        mov     ax,cs:base_seg
        add     ax,STUBPARA+1
        mov     word ptr [di].T_XSAVE+2,ax
        push    di              ; 40:F0-FF:  zero
        lea     di,[di].T_ICA
        mov     cx,8
        xor     ax,ax
@@:     mov     [di],ax
        add     di,2
        loop    @B
        pop     di
        push    es              ; video mode:  the text mode of now, else 80x25
        mov     ax,40h
        mov     es,ax
        mov     al,es:[49h]
        and     al,7Fh
        mov     ah,es:[84h]
        pop     es
        cmp     al,3
        jbe     @F
        mov     ax,1803h
@@:     mov     [di].T_MODE,al
        mov     [di].T_ROWS,ah
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
        call    vpg_alloc       ; text pages (it starts in the background)
        jc      cr_mem
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
        xor     bx,bx           ; its text pages, blank
@@:     mov     cx,0B8h
        add     cx,bx
        push    bx
        shl     bx,1
        mov     dx,[di+bx].T_VPG
        pop     bx
        mov     ax,0A00h
        qpi
        jc      cr_rootmem
        inc     bx
        cmp     bx,NVPG
        jb      @B
        push    di
        mov     ax,0B800h
        mov     es,ax
        xor     di,di
        mov     ax,0720h
        mov     cx,NVPG*2048
        cld
        rep     stosw
        pop     di
        ; the task's MCB chain:  stub block, free block, shared tail
        mov     ax,cs:base_seg
        mov     es,ax
        mov     byte ptr es:[0],'M'
        inc     ax
        mov     es:[1],ax       ; owner:  the stub PSP
        mov     word ptr es:[3],STUBPARA+SAVEPARA
        mov     ax,cs:base_seg
        add     ax,STUBPARA+SAVEPARA+1
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
        mov     cx,cs:dvst_init ; MAXVTSR's state:  that of mvk_init, its
        cmp     cs:dvst_size,0  ; GETMEM pool free
        je      cr_dvdone
        push    si
        push    di
        push    es
        les     di,[di].T_XSAVE
        add     di,CDSMAX+SDAMAX
        mov     si,offset dvinit
        cld
        rep     movsb
        mov     cx,cs:dvst_size
        sub     cx,cs:dvst_init
        xor     al,al
        rep     stosb
        pop     es
        pop     di
        pop     si
cr_dvdone:
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
        mov     ax,[bp-8]
        cmp     ax,cs:ntasks
        jb      cr_ret
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
        lea     sp,[bp-6]
        popf
        mov     sp,bp
        pop     bp
        pop     es
        pop     di
        pop     si
        pop     cx
        pop     bx
        ret
create_k endp

; free the pages and the page table of the task at DI (root context active)
task_free proc near
        push    ax
        push    cx
        push    dx
        push    si
        xor     si,si           ; its IRQs owned by none
@@:     cmp     cs:irqown[si],di
        jne     tf_irq
        mov     cs:irqown[si],0
tf_irq: add     si,2
        cmp     si,16
        jb      @B
        cmp     [di].T_PARENT,0 ; a subtask:  nothing of its own
        je      @F
        mov     [di].T_PARENT,0
        mov     [di].T_PT,0
        mov     [di].T_STATE,TS_FREE
        jmp     short tf_ret
@@:     mov     cx,[di].T_NPG
        lea     si,[di].T_FRAME
        jcxz    tf_pt
@@:     mov     dx,[si]
        mov     ax,0500h
        qpi
        add     si,2
        loop    @B
tf_pt:  mov     [di].T_NPG,0
        call    vpg_free
        mov     dx,[di].T_PT
        or      dx,dx
        jz      @F
        mov     ax,0500h
        qpi
@@:     mov     [di].T_PT,0
        mov     [di].T_STATE,TS_FREE
tf_ret: pop     si
        pop     dx
        pop     cx
        pop     ax
        ret
task_free endp

; IVT, SDA, key buffer and cursor data into the TASK at DI (DS = DGROUP;
; its context active:  CDS and SDA go to its own memory, T_XSAVE)
save_ivtsda proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,ds
        mov     es,ax
        cld
        call    irqhook
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
        push    di
        lea     di,[di].T_ICA
        mov     si,4F0h
        mov     cx,8
        rep     movsw
        pop     di
        mov     es,cs:kseg
        les     di,es:[di].T_XSAVE ; its save area:  CDS, SDA, MAXVTSR's
        push    di
        lds     si,cs:cds_ptr
        mov     cx,cs:cds_size
        rep     movsb
        pop     di
        push    di
        add     di,CDSMAX
        lds     si,cs:sda_ptr
        mov     cx,cs:sda_size
        rep     movsb
        pop     di
        add     di,CDSMAX+SDAMAX
        lds     si,cs:dvst_ptr
        mov     cx,cs:dvst_size
        rep     movsb
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
save_ivtsda endp

; The IRQ1-7 vectors the TASK at DI (DS = DGROUP, its IVT the one in
; memory) has hooked since its IVT was loaded:  it owns those IRQs now
; (irqown)
irqhook proc near
        push    eax
        push    bx
        push    es
        xor     bx,bx
        mov     es,bx
        mov     bx,9*4
ih_vec: mov     eax,es:[bx]
        cmp     eax,dword ptr [bx+di].T_IVT
        je      ih_next
        cmp     eax,origivt[bx]
        je      ih_next
        push    bx
        shr     bx,1            ; ((vector - 8) * 2)
        mov     cs:irqown[bx-16],di
        pop     bx
ih_next:
        add     bx,4
        cmp     bx,10h*4
        jb      ih_vec
        pop     es
        pop     bx
        pop     eax
        ret
irqhook endp

; IVT, SDA, key buffer and cursor data from the TASK at DI (DS = DGROUP;
; its context active)
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
        lea     si,[di].T_ICA
        mov     di,4F0h
        mov     cx,8
        rep     movsw
        pop     di
        push    di
        push    ds
        lds     si,[di].T_XSAVE ; its save area:  CDS, SDA, MAXVTSR's
        les     di,cs:cds_ptr
        mov     cx,cs:cds_size
        push    si
        rep     movsb
        pop     si
        push    si
        add     si,CDSMAX
        les     di,cs:sda_ptr
        mov     cx,cs:sda_size
        rep     movsb
        pop     si
        add     si,CDSMAX+SDAMAX
        les     di,cs:dvst_ptr
        mov     cx,cs:dvst_size
        rep     movsb
        pop     ds
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

; the private text page frames of the TASK at DI:  allocate (CF:  failed;
; the ones got stay for vpg_free), free
vpg_alloc proc near
        push    ax
        push    bx
        push    dx
        xor     bx,bx
@@:     mov     [di+bx].T_VPG,0
        add     bx,2
        cmp     bx,NVPG*2
        jb      @B
        xor     bx,bx
@@:     mov     ax,0400h
        qpi
        jc      @F
        mov     [di+bx].T_VPG,dx
        add     bx,2
        cmp     bx,NVPG*2
        jb      @B
        clc
@@:     pop     dx
        pop     bx
        pop     ax
        ret
vpg_alloc endp

vpg_free proc near
        push    ax
        push    bx
        push    dx
        xor     bx,bx
@@:     mov     dx,[di+bx].T_VPG
        or      dx,dx
        jz      vf_next
        mov     ax,0500h
        qpi
        mov     [di+bx].T_VPG,0
vf_next:
        add     bx,2
        cmp     bx,NVPG*2
        jb      @B
        pop     dx
        pop     bx
        pop     ax
        ret
vpg_free endp

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

; the foreground (TASK at DI) leaves the display:  its mode recorded; in
; VGA graphics it is held (the screen is another's now)
fgleave proc near
        push    ax
        push    es
        mov     ax,40h
        mov     es,ax
        mov     al,es:[49h]
        and     al,7Fh
        mov     [di].T_MODE,al
        mov     cs:hwmode,al
        mov     al,es:[84h]
        mov     [di].T_ROWS,al
        mov     cs:hwrows,al
        mov     ax,[di].T_VESA
        mov     cs:hwvesa,ax
        call    isgfx
        jnc     @F
        mov     [di].T_HOLD,1
        mov     cs:wantsw,1
@@:     pop     es
        pop     ax
        ret
fgleave endp

; CF:  the TASK at DI is in VGA (or VESA) graphics
isgfx   proc near
        cmp     [di].T_VESA,0
        jne     @F
        cmp     [di].T_MODE,0Dh
        cmc
        ret
@@:     stc
        ret
isgfx   endp

; the text (or CGA) mode of the TASK at DI, unless the display has it
; (memory kept:  the pages are copied after)
txtmode proc near
        pusha
        cmp     cs:hwvesa,0
        jne     @F
        mov     al,[di].T_MODE
        cmp     al,cs:hwmode
        jne     @F
        mov     al,[di].T_ROWS
        cmp     al,cs:hwrows
        je      tm_ret
@@:     call    vidkeep
        cmp     [di].T_MODE,3
        ja      tm_mode
        mov     ax,1202h        ; scan lines:  400 (25, 50 rows), 350 (43)
        cmp     [di].T_ROWS,24
        je      tm_scan
        cmp     [di].T_ROWS,49
        je      tm_scan
        mov     ax,1201h
        cmp     [di].T_ROWS,42
        jne     tm_mode
tm_scan:
        mov     bl,30h
        call    bios10
tm_mode:
        mov     al,[di].T_MODE
        or      al,80h
        xor     ah,ah
        call    bios10
        cmp     [di].T_MODE,3
        ja      tm_vid
        cmp     [di].T_ROWS,42  ; 43 or 50 rows:  the 8x8 font
        je      @F
        cmp     [di].T_ROWS,49
        jne     tm_vid
@@:     mov     ax,1112h
        xor     bl,bl
        call    bios10
tm_vid: call    vidback
tm_ret: popa
        ret
txtmode endp

; the graphics mode of the TASK at DI (a blank screen:  it draws again)
gfxmode proc near
        pusha
        call    vidkeep
        mov     bx,[di].T_VESA
        mov     ax,4F02h
        or      bx,bx
        jnz     @F
        mov     al,[di].T_MODE
        xor     ah,ah
@@:     call    bios10
        call    vidback
        popa
        ret
gfxmode endp

; the video BIOS (AX, BX as for INT 10h), counted
bios10  proc near
        inc     cs:in10
        pushf
        call    dword ptr cs:old10
        dec     cs:in10
        ret
bios10  endp

; the cursor data of the running task (40:50-61) over a mode set
vidkeep proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,cs
        mov     es,ax
        mov     ax,40h
        mov     ds,ax
        mov     si,50h
        mov     di,offset vidsave
        mov     cx,VIDLEN
        cld
        rep     movsb
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
vidkeep endp

vidback proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,cs
        mov     ds,ax
        mov     ax,40h
        mov     es,ax
        mov     si,offset vidsave
        mov     di,50h
        mov     cx,VIDLEN
        cld
        rep     movsb
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        ret
vidback endp

; text page BX (0:  B8000h) <-> vbuf (DS = kernel data)
scr2buf proc near
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ax,ds
        mov     es,ax
        mov     ax,bx
        add     ax,0B8h
        xchg    al,ah
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
        mov     ax,bx
        add     ax,0B8h
        xchg    al,ah
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
; MAXVTSR (INT 2Fh D70Ah):  the foreground task is DX (FFFFh:  none known),
; its pointer objects take the mouse.
fgtell  proc near
        push    ax
        push    bx
        mov     bx,dx
        mov     ax,0D70Ah
        int     2Fh
        pop     bx
        pop     ax
        ret
fgtell  endp

setfg   proc near
        pusha
        push    es
        mov     cs:kfocus,dx    ; full screen:  the keys too
        cmp     dx,cs:fg
        je      sfg_ret
        inc     cs:insched
        call    crtoff          ; (modes and the cursor on the hardware)
        push    cs:actpt        ; the context to come back to
        push    dx
        mov     bx,cs:fg
        call    taskptr
        mov     di,bx
        call    fgleave
        mov     dx,[di].T_PT    ; the old foreground:  its pages private
        call    setctx
        xor     bx,bx
@@:     call    scr2buf
        mov     cx,0B8h
        add     cx,bx
        push    bx
        shl     bx,1
        mov     dx,[di+bx].T_VPG
        pop     bx
        mov     ax,0A00h
        qpi
        call    buf2scr
        inc     bx
        cmp     bx,NVPG
        jb      @B
        pop     bx              ; the new one:  the display's
        push    bx
        call    taskptr
        mov     di,bx
        call    isgfx           ; text and CGA:  its mode before the pages
        jc      sfg_t1          ; (memory kept), graphics after them
        call    txtmode
sfg_t1: mov     dx,[di].T_PT
        call    setctx
        xor     bx,bx
@@:     call    scr2buf
        mov     cx,0B8h
        add     cx,bx
        mov     dx,cx
        mov     ax,0A00h
        qpi
        call    buf2scr
        inc     bx
        cmp     bx,NVPG
        jb      @B
        call    isgfx
        jnc     sfg_g1
        call    gfxmode
sfg_g1: mov     [di].T_HOLD,0
        pop     dx
        mov     cs:fg,dx
        call    fgtell
        pop     dx
        call    setctx
        call    fgcursor
        call    crtset
        call    fgpal
        dec     cs:insched
sfg_ret:
        pop     es
        popa
        ret
setfg   endp

; DESQview's window colours on the screen (dvcol):  the foreground task's
; window (task N, a subtask its parent's) has DV 2.80's colours for its
; number, 31h 61h 47h 21h and again (background, foreground); colour 0 and
; the background, 7 and the foreground, 8 and 15 and their bright ones
; swapped, as DV shows a window (07h as 31h in window 1):  the attribute
; controller's 16 palette registers permuted so.  Task 0, mono, graphics:
; the standard palette.
fgpal   proc near
        cmp     cs:dvcol,0
        je      fp_none
        pusha
        sub     sp,16
        mov     bp,sp
        xor     si,si
@@:     mov     ax,si
        mov     byte ptr ss:[bp+si],al  ; (the identity)
        inc     si
        cmp     si,16
        jb      @B
        mov     bx,cs:fg
        or      bx,bx
        jz      fp_set
        push    bx
        call    taskptr
        mov     di,bx
        pop     bx
        call    isgfx
        jc      fp_set
        cmp     [di].T_MODE,7
        je      fp_set
        mov     ax,[di].T_PARENT ; a subtask:  its task's window (+1)
        or      ax,ax
        jz      @F
        mov     bx,ax
        dec     bx
@@:     dec     bx
        and     bx,3
        mov     al,cs:fp_win[bx]
        mov     ah,al
        shr     ah,4            ; AH background, AL foreground
        and     al,0Fh
        movzx   si,ah
        mov     byte ptr ss:[bp],ah     ; 0 <-> background
        mov     byte ptr ss:[bp+si],0
        mov     cl,ah
        or      cl,8
        mov     byte ptr ss:[bp+8],cl   ; 8 <-> bright background
        movzx   si,cl
        mov     byte ptr ss:[bp+si],8
        cmp     al,7
        je      fp_set
        mov     byte ptr ss:[bp+7],al   ; 7 <-> foreground
        movzx   si,al
        mov     byte ptr ss:[bp+si],7
        mov     cl,al
        or      cl,8
        mov     byte ptr ss:[bp+15],cl  ; 15 <-> bright foreground
        movzx   si,cl
        mov     byte ptr ss:[bp+si],15
fp_set: pushf
        cli
        mov     dx,3DAh         ; (the flip-flop to the index)
        in      al,dx
        mov     dx,3C0h
        xor     di,di
@@:     mov     ax,di
        out     dx,al
        movzx   si,byte ptr ss:[bp+di]
        mov     al,cs:fp_std[si]
        out     dx,al
        inc     di
        cmp     di,16
        jb      @B
        mov     al,20h          ; the screen on again
        out     dx,al
        popf
        add     sp,16
        popa
fp_none:
        ret
fgpal   endp
fp_win  db      31h,61h,47h,21h ; DV 2.80's window colours, by number
fp_std  db      0,1,2,3,4,5,14h,7,38h,39h,3Ah,3Bh,3Ch,3Dh,3Eh,3Fh

; void mvk_dvcolors(unsigned on):  DESQview's window colours (fgpal) on
; the screen of the task in front (default off:  Open MaxView shows a
; program's own colours).
mvk_dvcolors_ proc near
        mov     cs:dvcol,ax
        ret
mvk_dvcolors_ endp

; QPI 0Dh for the task now running (cur):  the foreground's own CRTC and
; DAC, a background task's trapped (cursor address to crtget/crtset, the
; rest dropped, as DESQview keeps background programs off them with QEMM)
crtset  proc near
        cmp     cs:crtok,0
        je      cs_ret
        push    ax
        push    es
        xor     ax,ax
        mov     es,ax
        mov     ax,cs:scur
        cmp     ax,cs:fg
        mov     al,0
        je      @F
        mov     al,2
        cmp     word ptr es:[463h],3B4h ; mono CRTC
        jne     @F
        mov     al,1
@@:     cmp     al,cs:crtmode
        je      @F
        call    crtmode_set
@@:     pop     es
        pop     ax
cs_ret: ret
crtset  endp

; the trapping off (the kernel programs the hardware itself)
crtoff  proc near
        cmp     cs:crtmode,0
        je      @F
        push    ax
        xor     al,al
        call    crtmode_set
        pop     ax
@@:     ret
crtoff  endp

crtmode_set proc near            ; AL = the 0Dh mode
        push    ax
        mov     cs:crtmode,al
        mov     ah,0Dh
        qpi
        pop     ax
        ret
crtmode_set endp

; QPI cursor callbacks (in the running task, V86):  BX = the CRTC cursor
; address it reads (from its BIOS cursor, 40:50h) or writes (into it)
crtget  proc far
        push    ax
        push    dx
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     bl,ds:[62h]     ; the active page's cursor
        xor     bh,bh
        shl     bx,1
        mov     dx,ds:[50h+bx]  ; DH row, DL column
        mov     al,dh
        mul     byte ptr ds:[4Ah]
        xor     dh,dh
        add     ax,dx
        mov     bx,ds:[4Eh]     ; + the page start
        shr     bx,1
        add     bx,ax
        pop     ds
        pop     dx
        pop     ax
        ret
crtget  endp

crtsetcb proc far
        push    ax
        push    dx
        push    si
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     ax,bx
        mov     dx,ds:[4Eh]
        shr     dx,1
        sub     ax,dx
        jb      csc_ret
        xor     dx,dx
        mov     si,ds:[4Ah]
        or      si,si
        jz      csc_ret
        div     si              ; AX row, DX column
        cmp     ax,0FFh
        ja      csc_ret
        mov     dh,al
        mov     al,ds:[62h]
        xor     ah,ah
        mov     si,ax
        shl     si,1
        mov     ds:[50h+si],dx
csc_ret:
        pop     ds
        pop     si
        pop     dx
        pop     ax
        ret
crtsetcb endp

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
        mov     ax,cs:kseg
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
        mov     bx,cs:kseg
        mov     ds,bx
        mov     ax,0FFFFh
        jc      task_end
task_done::                     ; (KILL_ENTRY:  the program is gone)
        mov     bx,cs:kseg
        mov     ds,bx
        mov     ah,4Dh
        int     21h
task_end::
        mov     bx,cs:cur       ; its subtasks end with it
        inc     bx
        call    end_subtasks
        push    ax              ; MAXVTSR:  its mailboxes and GETMEM blocks go
        mov     bx,cs:cur       ; (as DESQview frees them with the window)
        mov     ax,0D708h
        int     2Fh
        pop     ax
        mov     bx,cs:cur
        call    taskptr
        mov     [bx].T_EXIT,ax
        mov     [bx].T_KILL,0
        mov     [bx].T_STATE,TS_DONE
        dbg     'D'
        mov     ax,cs:cur
        cmp     ax,cs:fg
        jne     @F
        mov     cs:newfg,0      ; its screen:  task 0's back
@@:     mov     ax,cs:cur
        cmp     ax,cs:kfocus
        jne     @F
        mov     cs:kfocus,0     ; its keys too
@@:     sti
        call    yield           ; for good:  it is no longer ready
        jmp     @B
task_entry endp

; mvk_kill:  ends the programs of the current task down to its stub PSP
kill_entry proc far
        sti
        dbg     'K'
        mov     ah,51h
        int     21h
        mov     ax,cs:base_seg
        inc     ax
        cmp     bx,ax
        je      ke_stub
        mov     es,bx           ; its end comes back here
        mov     word ptr es:[0Ah],offset kill_entry
        mov     es:[0Ch],cs
        cmp     es:[16h],bx     ; its own parent (COMMAND.COM):  ours
        jne     @F
        mov     es:[16h],ax
@@:
        mov     ax,4CFFh
        int     21h
ke_stub:
        jmp     task_done
kill_entry endp

; INT 23h of a task to be killed (DOS out of its console input)
kill23  proc far
        jmp     kill_entry
kill23  endp

; the task at DI to be killed, just switched to (its context, its stack
; with the frame the scheduler pops; DS = DGROUP)
killtask proc near
        push    bp
        mov     bp,sp           ; [bp+4]:  GS FS ES DS, PUSHAD, IRET frame
        push    ax
        push    bx
        push    es
        les     bx,cs:sda_ptr
        cmp     word ptr es:[bx],0 ; in DOS?
        jne     kt_dos
        mov     word ptr [bp+4+40],offset kill_entry
        mov     [bp+4+42],cs
        mov     [di].T_KILL,0
        jmp     short kt_ret
kt_dos: cmp     [di].T_KILL,2
        je      kt_ret          ; Ctrl-C on its way
        mov     [di].T_KILL,2
        xor     ax,ax
        mov     es,ax
        mov     word ptr es:[23h*4],offset kill23
        mov     es:[23h*4+2],cs
        mov     bx,es:[41Ch]    ; Ctrl-C into its key buffer
        mov     ax,bx
        add     ax,2
        cmp     ax,es:[482h]
        jb      @F
        mov     ax,es:[480h]
@@:     cmp     ax,es:[41Ah]
        je      kt_ret          ; full
        mov     word ptr es:[400h+bx],2E03h
        mov     es:[41Ch],ax
kt_ret: pop     es
        pop     bx
        pop     ax
        pop     bp
        ret
killtask endp

;----------------------------------------------------------------------------
; IRQ0 calldown:  timer, then maybe the next task or another foreground
irq0    proc far
        int     08h             ; the task's timer chain (BIOS:  EOI)
        dbg     '.'
        cmp     cs:running,0
        je      irq0_out
        cmp     cs:insched,0    ; in setfg (a video BIOS mode set)
        jne     irq0_out
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
        mov     ax,cs:kseg     ; the task table
        mov     ds,ax
        ; a critical error:  its task must be answered, in the foreground
        les     bx,cs:sda_ptr
        cmp     byte ptr es:[bx],0
        je      @F
        mov     ax,cs:cur
        mov     cs:newfg,ax
        mov     cs:kfocus,ax
@@:
        ; another foreground:  not inside 386MAX nor another task's handler
        mov     ax,cs:newfg
        cmp     ax,cs:fg
        je      sc_nofg
        mov     ax,[bp+40+2]
        cmp     ax,cs:qpi_seg
        je      sc_nofg
        cmp     cs:idepth,0
        jne     sc_nofg
        cmp     cs:in10,0       ; (setfg may set a video mode)
        jne     sc_nofg
        mov     cs:fgss,ss
        mov     cs:fgsp,sp
        mov     ax,cs:kseg
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
        mov     bx,cs:cur       ; a DESQview critical section
        call    taskptr
        cmp     [bx].T_CRIT,0
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
        jne     irq0_skip
        cmp     [bx].T_HOLD,0   ; held, frozen:  only to end it
        jne     irq0_held
        call    frozen
        jnc     irq0_found
irq0_held:
        cmp     [bx].T_KILL,0
        jne     irq0_found
irq0_skip:
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
        jmp     irq0_no
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
        mov     ax,cs:kseg
        mov     ss,ax           ; shared kernel stack (the SDA swap may
        mov     sp,offset kstktop ; overwrite the DOS stack in use)
        xchg    di,bx
        call    save_ivtsda     ; (in its context)
        xchg    di,bx
        push    dx
        mov     dx,[di].T_PT
        mov     ax,0800h
        qpi
        mov     cs:actpt,dx
        pop     dx
        call    load_ivtsda     ; (in the new one's)
        mov     cs:cur,dx
        mov     ax,[di].T_PARENT
        dec     ax
        jns     @F
        mov     ax,dx
@@:     mov     cs:scur,ax
        call    crtset
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
        cmp     [di].T_KILL,0
        je      @F
        call    killtask
@@:     call    slice
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

; AX = the time slice (ticks) of the task now running:  FGQUANT for the
; one with the keys (as DESQview favours the foreground), else QUANTUM
slice   proc near
        mov     ax,cs:cur
        cmp     ax,cs:kfocus
        mov     ax,cs:quantum
        jne     @F
        mov     ax,cs:fgquant
@@:     ret
slice   endp

; the running task (TASK at BX, DS = kernel data) is held until it is the
; foreground again (setfg sets its mode then)
hold    proc near
        mov     [bx].T_HOLD,1
@@:     call    yield
        cmp     [bx].T_HOLD,0
        jne     @B
        ret
hold    endp

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

; INT 15h while running:  the DESQview calls about scheduling, per task
; (PAUSE yields; BEGINC/ENTERC, ENDC, GETCRIT:  critical sections, no task
; switch while one is open; APPNUM:  the task #); the rest goes on to the
; DESQview API (MAXVTSR).  AH=4Fh (the BIOS keyboard intercept, AL = scan
; code):  the switch keys.  Ctrl+Alt+1..9, 0:  that task to the foreground (key
; dropped:  CF = 0); Alt released alone:  task 0 (with mvk_dvkey).  Not
; during a critical error.  (Port 60h is not read again:  386MAX's
; keyboard controller emulation would give the next byte of an E0 key.)
int15   proc far
        cmp     cs:running,0
        je      i15_old
        cmp     ah,4Fh
        je      i15_key
        cmp     ax,1000h        ; DESQview PAUSE
        je      i15_pause
        cmp     ax,101Bh        ; BEGINC
        je      i15_beginc
        cmp     ax,0DE1Ch       ; ENTERC
        je      i15_beginc
        cmp     ax,101Ch        ; ENDC
        je      i15_endc
        cmp     ax,0DE13h       ; GETCRIT
        je      i15_getcrit
        cmp     ax,0DEF0h       ; (MAXVTSR:  a subtask)
        je      i15_thread
        cmp     ax,0DEF1h       ; (MAXVTSR:  its end)
        je      i15_tkill
        cmp     ax,0DE07h       ; APPNUM
        jne     i15_old
        mov     ax,cs:cur
        iret
i15_thread:
        call    thread_k
        retf    2
i15_tkill:
        call    tkill_k
        retf    2
i15_pause:
        call    yield
        iret
i15_beginc:                     ; per task:  no switch while open
        push    bx
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        cmp     [bx].T_CRIT,0FFFFh
        je      @F
        inc     [bx].T_CRIT
@@:     pop     ds
        pop     bx
        iret
i15_endc:
        push    bx
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        cmp     [bx].T_CRIT,0
        je      @F
        dec     [bx].T_CRIT
@@:     pop     ds
        pop     bx
        iret
i15_getcrit:
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        mov     bx,[bx].T_CRIT
        pop     ds
        iret
i15_key:
        push    ax
        push    bx
        push    ds
        push    es
        mov     ds,cs:kseg
        les     bx,cs:sda_ptr
        cmp     byte ptr es:[bx],0
        jne     i15_chain
        cmp     al,0B8h         ; Alt released
        jne     i15_alt
        xor     bx,bx
        xchg    bx,cs:altpend   ; alone?
        or      bx,bx
        jz      i15_chain
        cmp     cs:dvkey,0
        je      i15_chain
        mov     cs:newfg,0
        mov     cs:kfocus,0
        dbg     'A'
        jmp     short i15_chain
i15_alt:
        test    al,80h          ; another key pressed:  no Alt alone
        jnz     i15_ctl
        xor     bx,bx
        cmp     al,38h
        jne     @F
        inc     bx
@@:     mov     cs:altpend,bx
i15_ctl:
        cmp     al,02h
        jb      i15_chain
        cmp     al,0Bh
        ja      i15_chain
        xor     bx,bx
        mov     es,bx
        mov     bl,es:[417h]
        and     bl,0Ch
        cmp     bl,0Ch          ; Ctrl and Alt
        jne     i15_chain
        dec     al
        xor     ah,ah
        cmp     al,10
        jne     @F
        xor     ax,ax
@@:     cmp     ax,cs:ntasks
        jae     i15_chain
        mov     bx,ax
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        jne     i15_chain
        cmp     [bx].T_PARENT,0 ; (a subtask has its task's screen)
        jne     i15_chain
        mov     cs:newfg,ax
        mov     cs:kfocus,ax
        dbg     'F'
        pop     es
        pop     ds
        pop     bx
        pop     ax
        clc                     ; the key is ours
        retf    2
i15_chain:
        pop     es
        pop     ds
        pop     bx
        pop     ax
i15_old:
        jmp     dword ptr cs:old15
int15   endp

; INT 15h AX=DEF0h (MAXVTSR, for a DESQview subtask:  NEW of a window with
; an entry point):  a task in the current one's memory (its page table)
; and screen, started at ES:BX with SS = DS = ES = SI, SP = DI, DX:CX
; (the parent's handle), AX = BX = SI = DI = BP = 0, as DESQview starts
; them.  Its CDS, SDA and MAXVTSR's state go to a DOS block of the
; current program's; it starts with those of now (MAXVTSR's:  as a new
; task's).  A far return from its entry ends it.  AX = its number, CF
; clear; else CF set.  (IF = 0, the caller's context.)
thread_k proc near
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        push    bp
        mov     bp,sp
        push    es              ; [bp-2] entry segment
        push    bx              ; [bp-4] entry offset
        push    si              ; [bp-6] stack segment
        push    di              ; [bp-8] stack pointer
        push    cx              ; [bp-10] parent handle (offset)
        push    dx              ; [bp-12]   (segment)
        mov     ds,cs:kseg
        mov     ah,48h          ; its save area
        mov     bx,SAVEPARA
        int     21h
        jnc     th_area
        mov     ah,51h          ; none free:  the program's block (a .COM
        int     21h             ; has all) less it, if it keeps 64KB
        mov     es,bx
        dec     bx
        push    ds
        mov     ds,bx
        mov     bx,ds:[3]
        pop     ds
        cmp     bx,1000h+SAVEPARA+1
        jb      th_err
        sub     bx,SAVEPARA+1
        mov     ah,4Ah
        int     21h
        jc      th_err
        mov     ah,48h
        mov     bx,SAVEPARA
        int     21h
        jc      th_err
th_area:
        push    ax              ; [bp-14]
        mov     bx,1            ; a slot:  a free or done one (not the
th_slot:                        ; foreground), else a new one
        cmp     bx,cs:ntasks
        jae     th_new
        push    bx
        call    taskptr
        mov     di,bx
        pop     bx
        cmp     [di].T_STATE,TS_READY
        je      th_snext
        cmp     bx,cs:fg
        je      th_snext
        cmp     bx,cs:newfg
        je      th_snext
        mov     ax,cs:cur       ; an ended subtask of this task:  its save
        inc     ax              ; area back (its memory is this one's)
        cmp     [di].T_PARENT,ax
        jne     @F
        push    es
        mov     es,word ptr [di].T_XSAVE+2
        mov     ah,49h
        int     21h
        pop     es
@@:     call    task_free
        jmp     short th_have
th_snext:
        inc     bx
        jmp     th_slot
th_new: cmp     bx,cs:nslots
        jae     th_full
        push    bx
        call    taskptr
        mov     di,bx
        pop     bx
th_have:
        push    bx              ; [bp-16] its number
        mov     bx,cs:cur
        call    taskptr
        mov     si,bx           ; SI ==> the parent's TASK
        mov     ax,cs:cur
        inc     ax
        mov     [di].T_PARENT,ax
        mov     ax,[si].T_PT
        mov     [di].T_PT,ax
        mov     ax,word ptr [si].T_MODE
        mov     word ptr [di].T_MODE,ax
        mov     [di].T_NPG,0
        mov     [di].T_KILL,0
        mov     [di].T_CRIT,0
        mov     [di].T_VESA,0
        mov     [di].T_HOLD,0
        mov     [di].T_FRZ,0
        mov     [di].T_EXCL,0
        mov     [di].T_EXIT,0FFFFh
        mov     [di].T_PROG,0
        mov     [di].T_TAIL,0
        push    si
        push    di
        mov     cx,NVPG
@@:     mov     ax,[si].T_VPG
        mov     [di].T_VPG,ax
        add     si,2
        add     di,2
        loop    @B
        pop     di
        pop     si
        mov     word ptr [di].T_XSAVE,0
        mov     ax,[bp-14]
        mov     word ptr [di].T_XSAVE+2,ax
        call    save_ivtsda     ; IVT, SDA, ... of now
        mov     cx,cs:dvst_init ; MAXVTSR's state:  a new task's
        cmp     cs:dvst_size,0
        je      th_dvdone
        push    si
        push    di
        les     di,[di].T_XSAVE
        add     di,CDSMAX+SDAMAX
        mov     si,offset dvinit
        cld
        rep     movsb
        mov     cx,cs:dvst_size
        sub     cx,cs:dvst_init
        xor     al,al
        rep     stosb
        pop     di
        pop     si
th_dvdone:
        mov     ax,word ptr [di].T_KBD ; its key buffer empty
        mov     word ptr [di].T_KBD+2,ax
        ; its stack:  thread_end (far), IRET frame to the entry, the
        ; registers the switch pops
        mov     es,[bp-6]
        mov     bx,[bp-8]
        sub     bx,2
        mov     es:[bx],cs
        sub     bx,2
        mov     word ptr es:[bx],offset thread_end
        sub     bx,2
        mov     word ptr es:[bx],0202h ; FLAGS (IF)
        sub     bx,2
        mov     ax,[bp-2]
        mov     es:[bx],ax
        sub     bx,2
        mov     ax,[bp-4]
        mov     es:[bx],ax
        sub     bx,32           ; PUSHAD:  ECX, EDX the parent's handle
        push    di
        mov     di,bx
        mov     cx,16
        xor     ax,ax
        cld
        rep     stosw
        pop     di
        mov     ax,[bp-10]
        mov     es:[bx+24],ax
        mov     ax,[bp-12]
        mov     es:[bx+20],ax
        sub     bx,8            ; GS FS ES DS
        mov     ax,es
        mov     es:[bx],ax
        mov     es:[bx+2],ax
        mov     es:[bx+4],ax
        mov     es:[bx+6],ax
        mov     [di].T_SS,es
        mov     [di].T_SP,bx
        mov     [di].T_STATE,TS_READY
        pop     ax              ; its number
        add     sp,2
        cmp     ax,cs:ntasks
        jb      @F
        inc     cs:ntasks
@@:     clc
        jmp     short th_ret
th_full:
        pop     es              ; the save area back
        mov     ah,49h
        int     21h
th_err: stc
th_ret: mov     sp,bp
        pop     bp
        pop     es
        pop     ds
        pop     dx              ; (DI)
        mov     di,dx
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret
thread_k endp

; a subtask's entry returned:  its end
thread_end proc far
        mov     bx,cs:kseg
        mov     ds,bx
        xor     ax,ax
        jmp     task_end
thread_end endp

; INT 15h AX=DEF1h, BX = a subtask's number (MAXVTSR:  FREE of it):  it
; ends (the current one:  at once, for good).  CF set:  not a subtask.
tkill_k proc near
        push    bx
        push    ds
        mov     ds,cs:kseg
        cmp     bx,cs:ntasks
        jae     tk_no
        push    bx
        call    taskptr
        cmp     [bx].T_PARENT,0
        pop     bx
        je      tk_no
        cmp     bx,cs:cur
        jne     @F
        sti                     ; itself
        xor     ax,ax
        jmp     task_end
@@:     push    cx
        mov     cx,bx           ; that one only
        call    end_one
        pop     cx
        clc
        jmp     short tk_ret
tk_no:  stc
tk_ret: pop     ds
        pop     bx
        ret
tkill_k endp

; the subtasks of task BX - 1 end (DS = kernel data)
end_subtasks proc near
        push    ax
        push    cx
        push    di
        mov     cx,1
est_next:
        cmp     cx,cs:ntasks
        jae     est_done
        push    bx
        mov     bx,cx
        call    taskptr
        mov     di,bx
        pop     bx
        cmp     [di].T_PARENT,bx
        jne     @F
        call    end_one
@@:     inc     cx
        jmp     est_next
est_done:
        pop     di
        pop     cx
        pop     ax
        ret
end_subtasks endp

; subtask CX (not the current one) ends:  done, MAXVTSR frees its objects
end_one proc near
        push    ax
        push    bx
        push    di
        mov     bx,cx
        call    taskptr
        mov     di,bx
        cmp     [di].T_STATE,TS_READY
        jne     eo_ret
        mov     [di].T_STATE,TS_DONE
        mov     [di].T_EXIT,0
        mov     bx,cx
        mov     ax,0D708h
        int     2Fh
        cmp     cx,cs:newfg
        jne     @F
        mov     cs:newfg,0
@@:     cmp     cx,cs:kfocus
        jne     eo_ret
        mov     cs:kfocus,0
eo_ret: pop     di
        pop     bx
        pop     ax
        ret
end_one endp

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
        mov     ax,cs:scur
        cmp     ax,cs:fg
        pop     ax
        je      i10_fg
        cmp     ax,4F02h
        je      i10_vesa
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
        call    emuchk          ; the display in another mode:  ours
        jc      emu10
i10_bios:
        inc     cs:in10
        pushf
        call    dword ptr cs:old10
        pushf
        dec     cs:in10
        cmp     cs:crtmode,0    ; trapped:  the CRTC is the foreground's
        jne     @F
        push    ds
        mov     ds,cs:kseg
        call    fgcursor
        pop     ds
@@:     popf
        retf    2
i10_mode:                       ; mode set:  recorded for the foreground;
        push    ax              ; text and CGA:  a blank screen, VGA
        push    bx              ; graphics:  held until then
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        mov     ah,al
        and     al,7Fh
        mov     [bx].T_MODE,al
        mov     [bx].T_ROWS,24
        mov     [bx].T_VESA,0
        cmp     al,0Dh
        jb      i10_blank
        call    hold
        jmp     short i10_mx
i10_blank:
        test    ah,80h          ; memory kept
        jnz     i10_mx
        push    cx
        push    di
        push    es
        mov     cx,4000
        mov     bx,0720h
        cmp     al,4
        jb      @F
        cmp     al,6
        ja      @F
        mov     cx,8000
        xor     bx,bx
@@:     mov     ax,0B800h
        mov     es,ax
        xor     di,di
        mov     ax,bx
        cld
        rep     stosw
        mov     ax,40h
        mov     es,ax
        mov     word ptr es:[50h],0
        pop     es
        pop     di
        pop     cx
i10_mx: pop     ds
        pop     bx
        pop     ax
        iret
i10_vesa:                       ; VESA mode set:  held for the foreground
        push    bx
        push    ds
        mov     ds,cs:kseg
        and     bx,3FFFh
        push    bx
        mov     bx,cs:cur
        call    taskptr
        pop     [bx].T_VESA
        call    hold
        pop     ds
        pop     bx
        mov     ax,004Fh
        iret
i10_fg: push    ax              ; the foreground:  the BIOS, then its VESA
        inc     cs:in10         ; mode recorded
        pushf
        call    dword ptr cs:old10
        pushf
        dec     cs:in10
        push    bp
        mov     bp,sp           ; [bp+2] flags, [bp+4] AX, [bp+6] IRET
        push    bx
        push    ds
        cmp     byte ptr [bp+5],0
        je      i10_f0
        cmp     word ptr [bp+4],4F02h
        jne     i10_fx
        cmp     ax,004Fh
        jne     i10_fx
        and     bx,3FFFh
        cmp     bx,100h
        jae     i10_f1
i10_f0: xor     bx,bx
i10_f1: mov     ds,cs:kseg
        push    bx
        mov     bx,cs:cur
        call    taskptr
        pop     [bx].T_VESA
i10_fx: mov     bx,[bp+2]       ; the BIOS's flags to the caller
        mov     [bp+10],bx
        pop     ds
        pop     bx
        pop     bp
        add     sp,4
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

; the text functions of a background task whose mode the display has not
; (VGA graphics, other rows or columns):  on its own pages, in its own
; layout, interrupts off (the e.. variables)
emu10:  cli
        push    ds
        push    es
        pushad
        mov     bp,sp           ; EDI ESI EBP ESP EBX EDX ECX EAX, ES, DS
        call    elayout
        mov     ah,[bp+29]
        cmp     ah,02h
        je      e_setcur
        cmp     ah,03h
        je      e_getcur
        cmp     ah,06h
        je      e_scroll
        cmp     ah,07h
        je      e_scroll
        cmp     ah,08h
        je      e_read
        cmp     ah,09h
        je      e_wca
        cmp     ah,0Ah
        je      e_wc
        cmp     ah,0Eh
        je      e_tty
        cmp     ah,0Fh
        je      e_mode
        cmp     ah,13h
        je      e_str
        popad                   ; the others:  the BIOS
        pop     es
        pop     ds
        jmp     i10_bios
e_setcur:
        mov     bl,[bp+17]
        mov     dx,[bp+20]
        call    putcur
        jmp     e_done
e_getcur:
        mov     bl,[bp+17]
        call    getcur
        mov     [bp+20],dx
        push    40h
        pop     es
        mov     ax,es:[60h]
        mov     [bp+24],ax
        jmp     e_done
e_scroll:
        mov     al,[bp+29]
        sub     al,6
        mov     cs:edir,al
        mov     al,[bp+28]
        mov     bh,[bp+17]
        mov     cx,[bp+24]
        mov     dx,[bp+20]
        call    escroll
        jmp     e_done
e_read: mov     bl,[bp+17]
        call    getcur
        call    eaddr
        mov     ax,es:[di]
        mov     [bp+28],ax
        jmp     e_done
e_wca:  mov     bl,[bp+17]
        call    getcur
        call    eaddr
        mov     al,[bp+28]
        mov     ah,[bp+16]
        mov     cx,[bp+24]
        cld
        rep     stosw
        jmp     e_done
e_wc:   mov     bl,[bp+17]
        call    getcur
        call    eaddr
        mov     al,[bp+28]
        mov     cx,[bp+24]
        jcxz    @F
e_wc1:  mov     es:[di],al
        add     di,2
        loop    e_wc1
@@:     jmp     e_done
e_tty:  xor     bl,bl           ; (the BIOS:  the active page)
        call    getcur
        mov     cs:eattr,0FFFFh
        mov     al,[bp+28]
        call    eput
        call    putcur
        jmp     e_done
e_mode: mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        mov     al,[bx].T_MODE
        mov     [bp+28],al
        mov     al,byte ptr cs:ecols
        mov     [bp+29],al
        mov     byte ptr [bp+17],0
        jmp     e_done
e_str:  mov     bl,[bp+17]      ; page
        mov     dx,[bp+20]      ; position
        mov     cx,[bp+24]
        mov     si,[bp+8]       ; ES:BP string
        mov     fs,[bp+32]
        mov     al,[bp+16]
        xor     ah,ah
        mov     cs:eattr,ax
        or      cx,cx
        jz      e_strend
e_strc: mov     al,fs:[si]
        inc     si
        test    byte ptr [bp+28],2
        jz      @F
        mov     ah,fs:[si]      ; char, attribute pairs
        inc     si
        mov     byte ptr cs:eattr,ah
@@:     call    eput
        dec     cx
        jnz     e_strc
e_strend:
        test    byte ptr [bp+28],1
        jz      e_done
        call    putcur
e_done: popad
        pop     es
        pop     ds
        iret
int10   endp

; CF:  the running (background) task's text output must not go to the
; video BIOS:  it is in a text mode the display has not
emuchk  proc near
        push    ax
        push    bx
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:fg
        call    taskptr
        mov     ax,[bx].T_VESA
        mov     bx,cs:cur
        call    taskptr
        cmp     [bx].T_MODE,3
        ja      ec_no
        or      ax,ax
        jnz     ec_yes
        push    es
        mov     ax,40h
        mov     es,ax
        mov     al,es:[49h]
        and     al,7Fh
        mov     ah,es:[84h]
        pop     es
        cmp     al,[bx].T_MODE
        jne     ec_yes
        cmp     ah,[bx].T_ROWS
        jne     ec_yes
ec_no:  clc
        jmp     short ec_ret
ec_yes: stc
ec_ret: pop     ds
        pop     bx
        pop     ax
        ret
emuchk  endp

; the running task's text layout:  ecols, erows, epsize
elayout proc near
        push    ax
        push    bx
        push    dx
        push    ds
        mov     ds,cs:kseg
        mov     bx,cs:cur
        call    taskptr
        mov     ax,80
        cmp     [bx].T_MODE,1
        ja      @F
        mov     ax,40
@@:     mov     cs:ecols,ax
        movzx   ax,[bx].T_ROWS
        inc     ax
        cmp     ax,2
        jae     @F
        mov     ax,25
@@:     mov     cs:erows,ax
        mul     cs:ecols
        shl     ax,1
        add     ax,2047
        and     ax,not 2047
        mov     cs:epsize,ax
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        ret
elayout endp

; BL page, DH row, DL column -> ES:DI
eaddr   proc near
        push    ax
        push    cx
        push    dx
        mov     cx,dx
        movzx   ax,bl
        and     al,7
        mul     cs:epsize
        shr     ax,4
        add     ax,0B800h
        mov     es,ax
        movzx   ax,ch
        mul     cs:ecols
        movzx   cx,cl
        add     ax,cx
        shl     ax,1
        mov     di,ax
        pop     dx
        pop     cx
        pop     ax
        ret
eaddr   endp

; cursor of page BL:  DX (DH row, DL column) from, to the BIOS data
getcur  proc near
        push    bx
        push    es
        push    40h
        pop     es
        and     bx,7
        shl     bx,1
        mov     dx,es:[50h+bx]
        pop     es
        pop     bx
        ret
getcur  endp

putcur  proc near
        push    bx
        push    es
        push    40h
        pop     es
        and     bx,7
        shl     bx,1
        mov     es:[50h+bx],dx
        pop     es
        pop     bx
        ret
putcur  endp

; character AL on page BL at DX (eattr:  its attribute, FFFFh the one
; there) as TTY output:  BEL, BS, CR, LF; DX moved, the page scrolled
eput    proc near
        push    ax
        push    di
        push    es
        cmp     al,7
        je      ep_ret
        cmp     al,8
        jne     @F
        or      dl,dl
        jz      ep_ret
        dec     dl
        jmp     short ep_ret
@@:     cmp     al,13
        jne     @F
        xor     dl,dl
        jmp     short ep_ret
@@:     cmp     al,10
        je      ep_lf
        call    eaddr
        mov     es:[di],al
        cmp     cs:eattr,0FFFFh
        je      @F
        mov     ah,byte ptr cs:eattr
        mov     es:[di+1],ah
@@:     inc     dl
        cmp     dl,byte ptr cs:ecols
        jb      ep_ret
        xor     dl,dl
ep_lf:  inc     dh
        cmp     dh,byte ptr cs:erows
        jb      ep_ret
        dec     dh
        push    cx
        push    dx
        push    bx
        mov     cs:edir,0       ; the whole page up a line
        mov     al,1
        mov     bh,07h
        xor     cx,cx
        mov     dh,byte ptr cs:erows
        dec     dh
        mov     dl,byte ptr cs:ecols
        dec     dl
        call    escrollp
        pop     bx
        pop     dx
        pop     cx
ep_ret: pop     es
        pop     di
        pop     ax
        ret
eput    endp

; scroll (edir) the window CH,CL - DH,DL of page 0 (escrollp:  page BL)
; by AL lines (0:  clear), new lines in attribute BH
escroll proc near
        xor     bl,bl
escrollp::
        pushad
        push    ds
        push    es
        cmp     dl,byte ptr cs:ecols
        jb      @F
        mov     dl,byte ptr cs:ecols
        dec     dl
@@:     cmp     dh,byte ptr cs:erows
        jb      @F
        mov     dh,byte ptr cs:erows
        dec     dh
@@:     cmp     ch,dh
        ja      es_ret
        cmp     cl,dl
        ja      es_ret
        mov     ah,dh
        sub     ah,ch
        inc     ah              ; height
        or      al,al
        jz      @F
        cmp     al,ah
        jbe     es_n
@@:     mov     al,ah
es_n:   mov     cs:ecnt,al
        mov     cs:eatr,bh
        mov     cs:etop,ch
        mov     cs:ebot,dh
        mov     cs:eleft,cl
        movzx   ax,dl
        sub     al,cl
        inc     ax
        mov     cs:ewid,ax
        push    dx
        xor     dx,dx
        call    eaddr           ; ES = the page
        pop     dx
        push    es
        pop     ds
        cld
        mov     dh,cs:etop      ; up:  rows top..bottom
        mov     dl,1
        cmp     cs:edir,0
        je      es_row
        mov     dh,cs:ebot      ; down:  bottom..top
        mov     dl,-1
es_row: mov     al,dh           ; source row
        add     al,cs:ecnt
        cmp     dl,1
        je      @F
        mov     al,dh
        sub     al,cs:ecnt
        jc      es_fill
        cmp     al,cs:etop
        jb      es_fill
        jmp     short es_copy
@@:     jc      es_fill
        cmp     al,cs:ebot
        ja      es_fill
es_copy:
        push    dx
        mov     dh,al
        mov     dl,cs:eleft
        call    eaddr
        mov     si,di
        pop     dx
        push    dx
        mov     dl,cs:eleft
        call    eaddr
        pop     dx
        mov     cx,cs:ewid
        rep     movsw
        jmp     short es_next
es_fill:
        push    dx
        mov     dl,cs:eleft
        call    eaddr
        pop     dx
        mov     al,' '
        mov     ah,cs:eatr
        mov     cx,cs:ewid
        rep     stosw
es_next:
        cmp     dl,1
        jne     @F
        cmp     dh,cs:ebot
        je      es_ret
        inc     dh
        jmp     es_row
@@:     cmp     dh,cs:etop
        je      es_ret
        dec     dh
        jmp     es_row
es_ret: pop     es
        pop     ds
        popad
        ret
escroll endp

; IRQ1-7:  to the task that hooked the vector (its IVT entry differs from
; the one at mvk_start) last, as DESQview 2.80 gives an IRQ to the window
; that hooked it last, in front or not (irqown; the current task when it
; hooked it while running); else the current task first; none:  the
; current IVT
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
        mov     bx,cs:kseg
        mov     ds,bx
        xor     ah,ah
        shl     ax,1
        shl     ax,1
        movzx   esi,ax          ; ESI = vector * 4
        cmp     si,9*4
        je      irqd_kbd
        xor     ax,ax
        mov     es,ax
        ; the task that hooked it last
        mov     bx,cs:cur
        call    taskptr
        mov     eax,es:[si]
        cmp     eax,dword ptr [bx+si].T_IVT
        je      @F
        cmp     eax,origivt[si]
        jne     irqd_here       ; the current one, while running
@@:     mov     dx,bx
        mov     bx,si
        shr     bx,1
        mov     di,cs:irqown[bx-16]
        or      di,di
        jz      irqd_cur
        cmp     di,dx
        je      irqd_cur
        cmp     [di].T_STATE,TS_READY
        jne     irqd_cur
        movzx   edi,di
        mov     eax,dword ptr [edi+esi].T_IVT
        cmp     eax,origivt[si]
        je      irqd_cur        ; (unhooked again)
        jmp     irqd_other
irqd_cur:
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
        cmp     [di].T_STATE,TS_READY
        jne     irqd_skip
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
irqk_fg:
        ; to the foreground task:  its INT 09h with its key buffer
        xor     ax,ax
        mov     es,ax
        mov     bx,cs:kfocus
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
        mov     cx,cs:kseg
        mov     ss,cx
        mov     sp,offset istktop
@@:     inc     cs:idepth
        push    ax              ; old SS:SP
        push    bx
        push    cs:actpt
        mov     ax,0800h
        qpi
        mov     cs:actpt,dx
        mov     ax,cs:kseg
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
start_k proc near
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
        lea     ax,[edx+edx*2]
        mov     cs:fgquant,ax
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
        mov     cs:irqown,0
        mov     word ptr cs:irqown+2,0
        mov     dword ptr cs:irqown+4,0
        mov     dword ptr cs:irqown+8,0
        mov     dword ptr cs:irqown+12,0
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
        push    bx              ; MAXVTSR:  READ may wait now
        mov     bx,1
        mov     ax,0D709h
        int     2Fh
        pop     bx
        push    dx
        mov     dx,cs:fg
        call    fgtell
        pop     dx
        push    bx              ; QPI 0Eh:  our cursor callbacks (a
        push    dx              ; background task's CRTC trapped, crtset)
        push    ds
        push    es
        mov     ax,cs
        mov     es,ax
        mov     ds,ax
        mov     bx,offset crtget
        mov     dx,offset crtsetcb
        mov     ax,0E00h
        qpi
        pop     es
        pop     ds
        pop     dx
        pop     bx
        jc      @F
        mov     cs:crtok,1
@@:
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
start_k endp

;----------------------------------------------------------------------------
; void mvk_stop(void):  from task 0 only.  Stops switching, removes the
; calldowns and the INT 13h hook, frees all tasks.
stop_k proc near
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
        call    crtoff
        mov     cs:crtok,0
        sti
        push    bx              ; MAXVTSR:  no more waits
        xor     bx,bx
        mov     ax,0D709h
        int     2Fh
        pop     bx
        push    dx
        mov     dx,0FFFFh
        call    fgtell
        pop     dx
        mov     ax,1C00h
        qpi
        xor     ax,ax
        mov     es,ax
        cli
        call    hook_remove
        sti
        xor     bx,bx
        call    taskptr
        mov     di,bx
        call    vpg_free
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
stop_k endp

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
setfg_k proc near
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
setfg_k endp

; int mvk_kill(unsigned task):  end the task (from task 0).  0 or MVE_x.
kill_k proc near
        push    bx
        mov     bx,ax
        mov     ax,MVE_STATE
        cmp     cs:cur,0
        jne     kl_ret
        or      bx,bx
        jz      kl_ret
        cmp     bx,cs:ntasks
        jae     kl_ret
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        jne     kl_ret
        cmp     [bx].T_KILL,0
        jne     @F
        mov     [bx].T_KILL,1
@@:     xor     ax,ax
kl_ret: pop     bx
        ret
kill_k endp

; void mvk_yield(void):  the other tasks now (a waiting task)
mvk_yield_ proc near
        cmp     cs:running,0
        je      @F
        call    yield
@@:     ret
mvk_yield_ endp

; void mvk_dvkey(unsigned on):  Alt pressed and released alone switches to
; task 0
mvk_dvkey_ proc near
        mov     cs:dvkey,ax
        ret
mvk_dvkey_ endp

; int mvk_focus(unsigned task):  the keys to the task (0 or ready), the
; display stays (windows of task 0).  0 or MVE_x.
focus_k proc near
        push    bx
        mov     bx,ax
        mov     ax,MVE_STATE
        cmp     bx,cs:ntasks
        jae     fc_ret
        push    bx
        call    taskptr
        cmp     [bx].T_STATE,TS_READY
        pop     bx
        jne     fc_ret
        mov     cs:kfocus,bx
        xor     ax,ax
fc_ret: pop     bx
        ret
focus_k endp

; int mvk_freeze(unsigned task, unsigned on):  task (1..) frozen:  it and
; its subtasks run only while it has the keys (DESQview's Freeze, Put
; Aside); 0 or MVE_STATE
mvk_freeze_ proc near
        push    bx
        push    ds
        mov     ds,cs:kseg
        mov     bx,ax
        mov     ax,MVE_STATE
        or      bx,bx
        jz      frz_ret
        cmp     bx,cs:ntasks
        jae     frz_ret
        call    taskptr
        mov     [bx].T_FRZ,dx
        xor     ax,ax
frz_ret: pop    ds
        pop     bx
        ret
mvk_freeze_ endp

; int mvk_share(unsigned task, unsigned on):  off:  while task (1..) has
; the keys the others wait (DESQview's "Share CPU when in foreground");
; 0 or MVE_STATE
mvk_share_ proc near
        push    bx
        push    ds
        mov     ds,cs:kseg
        mov     bx,ax
        mov     ax,MVE_STATE
        or      bx,bx
        jz      shr_ret
        cmp     bx,cs:ntasks
        jae     shr_ret
        call    taskptr
        xor     dx,1
        and     dx,1
        mov     [bx].T_EXCL,dx
        xor     ax,ax
shr_ret: pop    ds
        pop     bx
        ret
mvk_share_ endp

; unsigned mvk_focused(void):  the task getting the keys
mvk_focused_ proc near
        mov     ax,cs:kfocus
        ret
mvk_focused_ endp

; unsigned mvk_peek(unsigned task, unsigned short *buf):  the task's text
; screen (80x25 cells) into buf (DGROUP, shared); returns its cursor (high
; row, low column), FFFFh:  no such task.  From task 0.
mvk_peek_ proc near
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        push    ds
        push    ds
        pop     es              ; ES:DI ==> buf (the caller's DS)
        mov     ds,cs:kseg
        mov     bx,ax
        mov     di,dx
        mov     ax,0FFFFh
        cmp     cs:cur,0
        jne     pk_ret
        or      bx,bx
        jz      pk_ret
        cmp     bx,cs:ntasks
        jae     pk_ret
        call    taskptr
        cmp     [bx].T_STATE,TS_FREE
        je      pk_ret
        pushf
        cli
        push    cs:actpt
        mov     dx,[bx].T_PT
        call    setctx
        push    ds
        mov     ax,0B800h
        mov     ds,ax
        xor     si,si
        mov     cx,2000
        cld
        rep     movsw
        pop     ds
        pop     dx
        call    setctx
        popf
        mov     ax,word ptr [bx].T_VID
pk_ret: pop     ds
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        ret
mvk_peek_ endp

; unsigned mvk_fg(void):  the foreground task
mvk_fg_ proc near
        mov     ax,cs:fg
        ret
mvk_fg_ endp

; unsigned mvk_state(unsigned task)
state_k proc near
        push    bx
        mov     bx,ax
        xor     ax,ax
        cmp     bx,cs:ntasks
        jae     @F
        call    taskptr
        mov     ax,[bx].T_STATE
@@:     pop     bx
        ret
state_k endp

; unsigned mvk_exit(unsigned task):  EXEC result of a DONE task
exit_k proc near
        push    bx
        mov     bx,ax
        mov     ax,0FFFFh
        cmp     bx,cs:ntasks
        jae     @F
        call    taskptr
        mov     ax,[bx].T_EXIT
@@:     pop     bx
        ret
exit_k endp

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

;----------------------------------------------------------------------------
; the C interface:  DS = the kernel data for the work
mvk_create_ proc near           ; prog, tail:  copied into the kernel data
        push    ds
        push    es
        push    si
        push    di
        push    cx
        mov     es,cs:kseg
        cld
        mov     si,ax
        mov     di,offset cprog
        mov     cx,79
@@:     lodsb
        stosb
        or      al,al
        loopnz  @B
        mov     byte ptr es:[di],0
        mov     si,dx
        mov     di,offset ctail
        mov     cx,127
@@:     lodsb
        stosb
        or      al,al
        loopnz  @B
        mov     byte ptr es:[di],0
        pop     cx
        pop     di
        pop     si
        pop     es
        mov     ds,cs:kseg
        mov     ax,offset cprog
        mov     dx,offset ctail
        call    create_k
        pop     ds
        ret
mvk_create_ endp

mvk_start_ proc near
        push    ds
        mov     ds,cs:kseg
        call    start_k
        pop     ds
        ret
mvk_start_ endp

; void mvk_tune(unsigned fg, unsigned bg):  the time slices in ticks of
; the task with the keys and of the others (0:  unchanged), as DESQview's
; Tune Performance; after mvk_start (it sets 3 * quantum and quantum).
mvk_tune_ proc near
        or      dx,dx
        jz      @F
        mov     cs:quantum,dx
@@:     or      ax,ax
        jz      @F
        mov     cs:fgquant,ax
@@:     ret
mvk_tune_ endp

mvk_stop_ proc near
        push    ds
        mov     ds,cs:kseg
        call    stop_k
        pop     ds
        ret
mvk_stop_ endp

mvk_state_ proc near
        push    ds
        mov     ds,cs:kseg
        call    state_k
        pop     ds
        ret
mvk_state_ endp

mvk_exit_ proc near
        push    ds
        mov     ds,cs:kseg
        call    exit_k
        pop     ds
        ret
mvk_exit_ endp

mvk_setfg_ proc near
        push    ds
        mov     ds,cs:kseg
        call    setfg_k
        pop     ds
        ret
mvk_setfg_ endp

mvk_kill_ proc near
        push    ds
        mov     ds,cs:kseg
        call    kill_k
        pop     ds
        ret
mvk_kill_ endp

mvk_focus_ proc near
        push    ds
        mov     ds,cs:kseg
        call    focus_k
        pop     ds
        ret
mvk_focus_ endp

; unsigned mvk_datasize(unsigned ntask):  paragraphs of kernel data for
; mvk_init with ntask slots (task 0 included; 2..MAXTASK, 0:  8)
mvk_datasize_ proc near
        push    dx
        or      ax,ax
        jnz     @F
        mov     ax,8
@@:     cmp     ax,2
        jae     @F
        mov     ax,2
@@:     cmp     ax,MAXTASK
        jbe     @F
        mov     ax,MAXTASK
@@:     mov     cs:nslots,ax
        mov     dx,size TASK
        mul     dx
        add     ax,offset tasks + 15
        shr     ax,4
        pop     dx
        ret
mvk_datasize_ endp

        end
