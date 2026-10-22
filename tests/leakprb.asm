; SPDX-License-Identifier: GPL-3.0-or-later
; What becomes of a task's DESQview objects when it ends (tests/qemu):
;   LEAKPRB C file    counts what it gets (16 at most each), frees it all
;                     and writes "sys S", "com C", "mbx M", "tmr T" (a
;                     line each), then "cfree B" (DE04h free common bytes
;                     after it all came back):  256-byte
;                     GETMEM (DE0Ch) and GETCOMMON (DE19h) blocks, NEW
;                     mailboxes (1200h 0109h) and timers (1200h 010Bh)
;   LEAKPRB L file    takes one of each, writes "leak", then "sys 1" etc.
;                     (1 = got it) and ends without giving them back
;   LEAKPRB S file    stack effect of the object messages, nothing on the
;                     stack before:  "new N" (NEW mailbox), "handle N"
;                     (HANDLE 01h, own window), "handle0 N" (HANDLE 00h
;                     of that window, its DWORD pushed), "free N" (FREE of that
;                     mailbox, its DWORD pushed):  N = bytes pushed (4) or
;                     popped (-4) by the call, 0:  none
;   LEAKPRB H file    takes all GETMEM blocks (16 at most), writes "hold
;                     N" and waits (PAUSE) until it is ended
;   LEAKPRB D file    as C, 3 s later (with H in another task:  the blocks
;                     it gets are its own if the pool is per task)
;   LEAKPRB V file    (in a task of the multitasking core) 3 s later
;                     "live N N ..":
;                     the task numbers whose task handles ISOBJ accepts (the
;                     own handle - 2 * APPNUM is task 0's)
; Run C, then L in a task that ends, then C again:  the same counts if
; the end of a task frees its objects.

        .model tiny
        .386
        .code
        org 100h

NMAX    equ     16

start:
        mov     si,81h
@@:     lodsb
        cmp     al,' '
        je      @B
        and     al,0DFh
        mov     role,al
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        mov     di,offset fname
@@:     stosb
        lodsb
        cmp     al,' '
        je      @F
        cmp     al,13
        jne     @B
@@:     mov     byte ptr [di],0
        cmp     role,'C'
        je      @F
        cmp     role,'L'
        je      @F
        cmp     role,'S'
        je      @F
        cmp     role,'H'
        je      @F
        cmp     role,'D'
        je      @F
        cmp     role,'V'
        jne     usage
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line
        cmp     role,'L'
        je      leak
        cmp     role,'S'
        je      stk
        cmp     role,'H'
        je      hold
        cmp     role,'V'
        je      live
        cmp     role,'D'
        jne     docount
        push    es              ; D:  3 s first
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,55
        jb      @B
        pop     es
docount:        ; count
        mov     si,offset t_sys
        call    puts
        mov     bp,0DE0Ch
        call    cntmem
        call    putnl
        mov     si,offset t_com
        call    puts
        mov     bp,0DE19h
        call    cntmem
        call    putnl
        mov     si,offset t_mbx
        call    puts
        mov     bp,0109h
        call    cntobj
        call    putnl
        mov     si,offset t_tmr
        call    puts
        mov     bp,010Bh
        call    cntobj
        call    putnl
        mov     si,offset t_cfree
        call    puts
        mov     ax,0DE04h       ; common memory:  BX free bytes
        int     15h
        mov     ax,bx
        call    putdec
        call    putnl
        jmp     short done

leak:   mov     si,offset t_leak
        call    puts
        call    putnl
        mov     si,offset t_sys
        call    puts
        mov     bp,0DE0Ch
        call    getblk
        call    putflag
        call    putnl
        mov     si,offset t_com
        call    puts
        mov     bp,0DE19h
        call    getblk
        call    putflag
        call    putnl
        mov     si,offset t_mbx
        call    puts
        mov     bp,0109h
        call    newobj
        call    putflag
        call    putnl
        mov     si,offset t_tmr
        call    puts
        mov     bp,010Bh
        call    newobj
        call    putflag
        call    putnl
done:   mov     ah,3Eh
        mov     bx,handle
        int     21h
        mov     ax,4C00h
        int     21h

live:   push    es              ; 3 s first (the task beside it ends)
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,55
        jb      @B
        pop     es
        mov     si,offset t_live
        call    puts
        mov     ax,1200h        ; own handle
        mov     bx,0001h
        int     15h
        pop     dx
        pop     bx
        mov     ax,0DE07h       ; APPNUM
        int     15h
        shl     ax,1
        sub     bx,ax           ; task 0's
        xor     cx,cx
@@:     push    cx
        push    bx
        push    di
        mov     ax,cx
        shl     ax,1
        add     ax,bx
        mov     es,ax
        xor     di,di
        mov     ax,1016h        ; ISOBJ:  BX = FFFFh
        int     15h
        mov     ax,bx
        pop     di
        push    ds
        pop     es
        pop     bx
        pop     cx
        cmp     ax,0FFFFh
        jne     live_next
        mov     al,' '
        stosb
        mov     ax,cx
        call    putdec
live_next:
        inc     cx
        cmp     cx,32
        jb      @B
        call    putnl
        jmp     done

hold:   mov     si,offset t_hold
        call    puts
        xor     cx,cx
@@:     push    cx
        mov     bp,0DE0Ch
        call    getblk
        pop     cx
        jz      @F
        inc     cx
        cmp     cx,NMAX
        jb      @B
@@:     mov     ax,cx
        call    putdec
        call    putnl
        mov     ah,3Eh
        mov     bx,handle
        int     21h
@@:     mov     ax,1000h        ; until it is ended
        int     15h
        jmp     @B

stk:    mov     si,offset t_new
        call    puts
        mov     savsp,sp
        mov     ax,1200h        ; NEW mailbox, nothing reserved
        mov     bx,0109h
        int     15h
        mov     ax,savsp
        sub     ax,sp           ; bytes pushed
        cmp     ax,4
        jne     @F
        pop     word ptr hnd    ; the handle (offset, segment)
        pop     word ptr hnd+2
@@:     mov     sp,savsp
        call    putsdec
        call    putnl
        mov     si,offset t_handle
        call    puts
        mov     savsp,sp
        mov     ax,1200h        ; HANDLE 01h:  own window
        mov     bx,0001h
        int     15h
        mov     ax,savsp
        sub     ax,sp
        cmp     ax,4
        jne     @F
        pop     word ptr whnd
        pop     word ptr whnd+2
@@:     mov     sp,savsp
        call    putsdec
        call    putnl
        mov     si,offset t_handle0
        call    puts
        push    word ptr whnd+2 ; HANDLE 00h of that window
        push    word ptr whnd
        mov     savsp,sp
        mov     ax,1200h
        mov     bx,0000h
        int     15h
        mov     ax,savsp
        sub     ax,sp
        mov     sp,savsp
        add     sp,4
        call    putsdec
        call    putnl
        mov     si,offset t_free
        call    puts
        push    word ptr hnd+2  ; FREE of that mailbox
        push    word ptr hnd
        mov     savsp,sp
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     ax,savsp
        sub     ax,sp
        mov     sp,savsp
        add     sp,4
        call    putsdec
        call    putnl
        jmp     done

usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; BP = DE0Ch (GETMEM) or DE19h (GETCOMMON):  256-byte blocks until none
; (NMAX at most), the count to DI, then all given back (BP + 1)
cntmem  proc near
        push    di
        xor     cx,cx
        mov     si,offset ptrs
@@:     push    cx
        push    si
        mov     bx,256
        mov     ax,bp
        int     15h
        mov     ax,es
        mov     dx,di
        pop     si
        pop     cx
        mov     bx,ax
        or      bx,dx
        jz      @F
        mov     [si],dx
        mov     [si+2],ax
        add     si,4
        inc     cx
        cmp     cx,NMAX
        jb      @B
@@:     mov     count,cx
        jcxz    cm_done
        mov     si,offset ptrs
@@:     push    cx
        push    si
        les     di,[si]
        mov     ax,bp
        inc     ax              ; PUTMEM / PUTCOMMON
        int     15h
        pop     si
        pop     cx
        add     si,4
        loop    @B
cm_done:
        push    ds
        pop     es
        pop     di
        mov     ax,count
        call    putdec
        ret
cntmem  endp

; BP = 0109h (mailbox) or 010Bh (timer):  NEW until null (NMAX at most),
; the count to DI, then all FREEd
cntobj  proc near
        xor     cx,cx
        mov     si,offset ptrs
@@:     push    cx
        push    si
        call    newobj
        pop     si
        pop     cx
        jz      @F
        mov     [si],dx
        mov     [si+2],ax
        add     si,4
        inc     cx
        cmp     cx,NMAX
        jb      @B
@@:     mov     count,cx
        jcxz    co_done
        mov     si,offset ptrs
@@:     push    cx
        push    si
        push    word ptr [si+2] ; the object DWORD (FREE pops it)
        push    word ptr [si]
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        pop     si
        pop     cx
        add     si,4
        loop    @B
co_done:
        mov     ax,count
        call    putdec
        ret
cntobj  endp

; a 256-byte block of function BP (DE0Ch, DE19h):  ZF = 1:  none (DI, ES
; kept)
getblk  proc near
        push    di
        mov     bx,256
        mov     ax,bp
        int     15h
        mov     ax,es
        or      ax,di
        push    ds
        pop     es
        pop     di
        ret
getblk  endp

; NEW of class BP:  AX:DX = the object (segment, offset), ZF = 1:  null
newobj  proc near
        mov     ax,1200h        ; (it pushes the handle)
        mov     bx,bp
        int     15h
        pop     dx
        pop     ax
        mov     bx,ax
        or      bx,dx
        ret
newobj  endp

; "1" (NZ) or "0" (ZF = 1) to DI
putflag proc near
        mov     al,'1'
        jnz     @F
        dec     al
@@:     stosb
        ret
putflag endp

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file
putnl   proc near
        mov     ax,0A0Dh
        stosw
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     di,offset line
        ret
putnl   endp

; AX signed to DI
putsdec proc near
        or      ax,ax
        jns     putdec
        neg     ax
        push    ax
        mov     al,'-'
        stosb
        pop     ax
putsdec endp                    ; (falls through)
putdec  proc near
        push    bx
        push    dx
        push    cx
        mov     bx,10
        xor     cx,cx
@@:     xor     dx,dx
        div     bx
        push    dx
        inc     cx
        or      ax,ax
        jnz     @B
@@:     pop     ax
        add     al,'0'
        stosb
        loop    @B
        pop     cx
        pop     dx
        pop     bx
        ret
putdec  endp

utext   db      'LEAKPRB C|L|S|H|D|V file',13,10,'$'
t_sys   db      'sys ',0
t_com   db      'com ',0
t_mbx   db      'mbx ',0
t_tmr   db      'tmr ',0
t_cfree db      'cfree ',0
t_leak  db      'leak',0
t_hold  db      'hold ',0
t_live  db      'live',0
t_new   db      'new ',0
t_handle db     'handle ',0
t_free  db      'free ',0
t_handle0 db    'handle0 ',0
whnd    dd      0
savsp   dw      0
hnd     dd      0
role    db      0
handle  dw      0
count   dw      0
fname   db      80 dup (0)
line    db      80 dup (0)
ptrs    dd      NMAX dup (0)

        end     start
