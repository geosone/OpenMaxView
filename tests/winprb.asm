; SPDX-License-Identifier: GPL-3.0-or-later
; Text to the task's window with WRITE (tests/qemu):  WINPRB file
;   AT 01h row 5 column 0, then
;   "w1 N R C"   WRITE 01h of "Hello" (address, then length pushed):  N =
;                bytes the call left on the stack beyond the 8 pushed (-8:
;                all popped), R C the BIOS cursor after it
;   "w2 N R C"   WRITE 00h of "AB" to the own window (HANDLE 01h)
;   "w3 N R C"   WRITE 01h of "X", CR, LF, "Y"
;   "w4 N R C"   WRITE 01h of "1", BS, "2", BEL, TAB, "3"
; then "winprb done" on row 10 (DOS), 3 s.

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
        mov     ax,1200h        ; own window
        mov     bx,0001h
        int     15h
        pop     word ptr win
        pop     word ptr win+2
        push    0               ; AT 01h:  row 5, column 0 (on top)
        push    5
        push    0
        push    0
        mov     ax,1200h
        mov     bx,1101h
        int     15h

        mov     si,offset t_w1
        mov     bx,offset s1
        mov     cx,s1len
        xor     bp,bp
        call    wr
        mov     si,offset t_w2
        mov     bx,offset s2
        mov     cx,s2len
        mov     bp,1
        call    wr
        mov     si,offset t_w3
        mov     bx,offset s3
        mov     cx,s3len
        xor     bp,bp
        call    wr
        mov     si,offset t_w4
        mov     bx,offset s4
        mov     cx,s4len
        xor     bp,bp
        call    wr

        mov     ah,2            ; "winprb done" on row 10
        xor     bh,bh
        mov     dx,0A00h
        int     10h
        mov     dx,offset t_done
        mov     ah,9
        int     21h
        push    40h             ; 3 s to see it
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,55
        jb      @B
        push    ds
        pop     es
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

; WRITE of CX bytes at BX:  BP = 0:  01h (own window), 1:  00h with the
; window handle on top; the line SI "N R C"
wr      proc near
        push    si
        mov     savsp,sp
        push    ds              ; address
        push    bx
        push    0               ; length (on it)
        push    cx
        or      bp,bp
        jz      @F
        push    word ptr win+2
        push    word ptr win
@@:     mov     ax,1200h
        mov     bx,0501h
        or      bp,bp
        jz      @F
        mov     bx,0500h
@@:     int     15h
        mov     ax,savsp
        sub     ax,sp
        mov     sp,savsp
        sub     ax,8            ; beyond the 8 (12) pushed
        or      bp,bp
        jz      @F
        sub     ax,4
@@:     pop     si
        push    ax
        call    puts
        pop     ax
        call    putsdec
        mov     ah,3
        xor     bh,bh
        int     10h
        push    dx
        mov     al,' '
        stosb
        mov     al,dh
        xor     ah,ah
        call    putdec
        mov     al,' '
        stosb
        pop     dx
        mov     al,dl
        xor     ah,ah
        call    putdec
        call    putnl
        ret
wr      endp

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

utext   db      'WINPRB file',13,10,'$'
t_done  db      'winprb done',13,10,'$'
t_w1    db      'w1 ',0
t_w2    db      'w2 ',0
t_w3    db      'w3 ',0
t_w4    db      'w4 ',0
s1      db      'Hello'
s1len   equ     $ - s1
s2      db      'AB'
s2len   equ     $ - s2
s3      db      'X',13,10,'Y'
s3len   equ     $ - s3
s4      db      '1',8,'2',7,9,'3'
s4len   equ     $ - s4
handle  dw      0
savsp   dw      0
win     dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
