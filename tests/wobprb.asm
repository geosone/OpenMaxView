; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview window objects (tests/qemu):  WOBPRB file
;   "own SSSS:OOOO"  HANDLE 01h (the task's window)
;   "new SSSS:OOOO B"  a WRITE to the own window of stream E6h 4,12 (a new
;                    window, 4 rows, 12 columns); B = the bytes left on the
;                    stack (its handle on top)
;   then a window stream to it:  EFh "probe" (the name), C2h 14,30 (position), E2h 1Fh, "hello"
;   (65h:  5 characters), C0h 2,3, "world", C0h 3,0, "A" "B" "C" "D" in
;   E2h 00h, 1Fh, 70h, 7Fh (logical colours), D4h (visible), E4h (redraw); "wobprb ready" in the own window
;   (row 3), 4 s, then a second stream:  C2h 17,50, E4h; 4 s; then FREE
;   of it and "wobprb done" (row 4)

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

        mov     si,offset t_own
        call    puts
        mov     ax,1200h
        mov     bx,0001h
        int     15h
        pop     dx
        pop     ax
        call    putptr
        call    putnl

        mov     si,offset t_new ; NEW 08h, RBIL's DWORDs top first
        call    puts
        mov     savsp,sp
        push    ds              ; WRITE 01h of stream E6h 4,12
        push    offset strm0
        push    0
        push    strm0len
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     bp,sp
        mov     dx,[bp]
        mov     ax,[bp+2]
        mov     word ptr win,dx
        mov     word ptr win+2,ax
        call    putptr
        mov     al,' '
        stosb
        mov     ax,savsp
        sub     ax,sp
        call    putdec
        mov     sp,savsp
        call    putnl

        push    ds              ; WRITE the stream to it
        push    offset strm1
        push    0
        push    strm1len
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h

        mov     ah,2            ; "wobprb ready" on row 20
        xor     bh,bh
        mov     dx,0300h
        int     10h
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
        mov     cx,4 * 18
        call    wait_ticks

        push    ds              ; moved
        push    offset strm2
        push    0
        push    strm2len
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        mov     cx,4 * 18
        call    wait_ticks

        push    word ptr win+2  ; FREE
        push    word ptr win
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     ah,2
        xor     bh,bh
        mov     dx,0400h
        int     10h
        mov     dx,offset t_done
        mov     ah,9
        int     21h
        mov     cx,2 * 18
        call    wait_ticks

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

; CX ticks, with PAUSE
wait_ticks proc near
        push    es
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,cx
        jb      @B
        pop     es
        ret
wait_ticks endp

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

utext   db      'WOBPRB file',13,10,'$'
t_ready db      'wobprb ready',13,10,'$'
t_done  db      'wobprb done',13,10,'$'
t_own   db      'own ',0
t_new   db      'new ',0
titlelen equ    5
strm0   db      1Bh,0
        dw      3
        db      0E6h,4,12
strm0len equ    $ - strm0
strm1   db      1Bh,0
        dw      s1end - s1
s1      db      0EFh,titlelen,'probe',0C2h,14,30,0E2h,1Fh,65h,'hello'
        db      0C0h,2,3,65h,'world'
        db      0C0h,3,0,0E2h,0,61h,'A',0E2h,1Fh,61h,'B',0E2h,70h,61h,'C'
        db      0E2h,7Fh,61h,'D',0D4h,0E4h
s1end   label byte
strm1len equ    $ - strm1
strm2   db      1Bh,0
        dw      s2end - s2
s2      db      0C2h,17,50,0E4h
s2end   label byte
strm2len equ    $ - strm2
handle  dw      0
savsp   dw      0
win     dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
