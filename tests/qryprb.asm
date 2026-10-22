; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview query streams in WRITE (tests/qemu):  QRYPRB file
;   a WRITE 01h of a window stream (C0h 4 7, E2h 1Eh), then one of a query
;   stream (type 01h):  A0h A1h C0h C3h C5h A6h A7h ABh AFh E2h D4h D6h
;   DCh DEh, the result bytes EEh before;
;   "q hh hh .."         the query stream's body after the WRITE
;   "cur R C"            the BIOS cursor after it
; then "qryprb done" on row 10 (DOS), 3 s.

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

        push    ds              ; WRITE 01h:  address, length (on top)
        push    offset stream
        push    0
        push    streamlen
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        push    ds              ; the query
        push    offset query
        push    0
        push    querylen
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     si,offset t_q
        call    puts
        mov     si,offset qbody
        mov     cx,qbody_end - qbody
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        call    putnl

        mov     si,offset t_cur
        call    puts
        mov     ah,3
        xor     bh,bh
        int     10h
        push    dx
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

        mov     ah,2            ; "qryprb done" on row 10
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

utext   db      'QRYPRB file',13,10,'$'
t_done  db      'qryprb done',13,10,'$'
t_cur   db      'cur ',0
t_q     db      'q',0
stream  db      1Bh,00h
        dw      sbody_end - sbody
sbody   db      0C0h,4,7
        db      0E2h,1Eh
sbody_end label byte
streamlen equ   $ - stream
query   db      1Bh,01h
        dw      qbody_end - qbody
qbody   db      0A0h,0EEh,0A1h,0EEh,0C0h,0EEh,0EEh,0C3h,0EEh,0EEh
        db      0C5h,0EEh,0EEh,0A6h,0EEh,0A7h,0EEh,0ABh,0EEh,0AFh,0EEh
        db      0E2h,0EEh,0D4h,0D6h,0DCh,0DEh
qbody_end label byte
querylen equ    $ - query
handle  dw      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
