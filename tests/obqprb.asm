; SPDX-License-Identifier: GPL-3.0-or-later
; The task's OBJECTQ (tests/qemu):  OBQPRB file
;   "obq SSSS:OOOO"  HANDLE 07h;  "kbd" / "mbx" the own keyboard and
;                    mailbox (HANDLE 05h/03h), "tmr" a NEW timer
;   then READ 07h (waits for an object with input) three times, each
;   "rN B d1 d2 d3":  B = bytes the call left on the stack, the first
;   DWORDs of them (top first, 3 at most):
;     r1 after ADDTO of 1 s to the timer
;     r2 after WRITE of "m" to the own mailbox
;     r3 after "obqprb ready" on the screen and a key (READ 05h then
;        takes it)
;   "r4 .." the same READ 07h once more after a READ of the mailbox and
;   the timer's ERASE, with a 2 s timer started as an end

        .model tiny
        .386
        .code
        org 100h

start:
        mov     si,81h
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
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line
        mov     si,offset t_obq
        mov     bx,0007h
        call    hnd
        mov     si,offset t_kbd
        mov     bx,0005h
        call    hnd
        mov     si,offset t_mbx
        mov     bx,0003h
        call    hnd
        mov     si,offset t_tmr  ; NEW timer
        call    puts
        mov     ax,1200h
        mov     bx,010Bh
        int     15h
        pop     dx
        pop     ax
        mov     word ptr tmr,dx
        mov     word ptr tmr+2,ax
        call    putptr
        call    putnl

        mov     cx,100          ; r1:  the timer, 1 s
        call    tstart
        mov     si,offset t_r1
        call    rdq

        push    ds              ; r2:  WRITE "m" to the own mailbox
        push    offset mmsg
        push    0
        push    1
        mov     ax,1200h
        mov     bx,0503h
        int     15h
        mov     si,offset t_r2
        call    rdq

        mov     dx,offset t_ready ; r3:  a key
        mov     ah,9
        int     21h
        mov     si,offset t_r3
        call    rdq
        mov     ax,1200h        ; READ 05h takes it
        mov     bx,0405h
        int     15h
        add     sp,8

        mov     ax,1200h        ; r4:  the mailbox read, the timer erased,
        mov     bx,0403h        ; a 2 s one as an end
        int     15h
        add     sp,8
        push    word ptr tmr+2
        push    word ptr tmr
        mov     ax,1200h
        mov     bx,0E00h
        int     15h
        mov     cx,200
        call    tstart
        mov     si,offset t_r4
        call    rdq

        mov     ah,3Eh
        mov     bx,handle
        int     21h
        mov     ax,4C00h
        int     21h

usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; "text SI SSSS:OOOO":  HANDLE BX
hnd     proc near
        call    puts
        mov     ax,1200h
        int     15h
        pop     dx
        pop     ax
        call    putptr
        call    putnl
        ret
hnd     endp

; ADDTO of CX hundredths to the timer
tstart  proc near
        push    0
        push    cx
        push    word ptr tmr+2
        push    word ptr tmr
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        ret
tstart  endp

; READ 07h:  "SI B d1 d2 d3"
rdq     proc near
        call    puts
        mov     savsp,sp
        mov     ax,1200h
        mov     bx,0407h
        int     15h
        mov     bp,sp
        mov     cx,savsp
        sub     cx,sp
        mov     ax,cx
        mov     al,' '
        stosb
        mov     ax,cx
        call    putdec
        shr     cx,2
        cmp     cx,3
        jbe     @F
        mov     cx,3
@@:     jcxz    rdq_done
@@:     mov     al,' '
        stosb
        mov     dx,[bp]
        mov     ax,[bp+2]
        call    putptr
        add     bp,4
        loop    @B
rdq_done:
        mov     sp,savsp
        call    putnl
        ret
rdq     endp

; AX:DX (segment, offset) as SSSS:OOOO to DI
putptr  proc near
        call    puthex
        mov     al,':'
        stosb
        mov     ax,dx
        call    puthex
        ret
putptr  endp

puthex  proc near
        push    ax
        mov     al,ah
        call    puthex8
        pop     ax
puthex  endp                    ; (falls through:  AL)
puthex8 proc near
        push    ax
        shr     al,4
        call    nibble
        pop     ax
        and     al,0Fh
nibble: add     al,'0'
        cmp     al,'9'
        jbe     @F
        add     al,7
@@:     stosb
        ret
puthex8 endp

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

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file, committed
putnl   proc near
        push    cx
        mov     ax,0A0Dh
        stosw
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     ah,68h
        int     21h
        mov     di,offset line
        pop     cx
        ret
putnl   endp

utext   db      'OBQPRB file',13,10,'$'
t_ready db      'obqprb ready',13,10,'$'
t_obq   db      'obq ',0
t_kbd   db      'kbd ',0
t_mbx   db      'mbx ',0
t_tmr   db      'tmr ',0
t_r1    db      'r1',0
t_r2    db      'r2',0
t_r3    db      'r3',0
t_r4    db      'r4',0
mmsg    db      'm'
handle  dw      0
savsp   dw      0
tmr     dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
