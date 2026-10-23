; SPDX-License-Identifier: GPL-3.0-or-later
; The DESQview pointer object (tests/qemu):  PTRPRB file
;   "ptr SSSS:OOOO"  NEW 0Fh;  "win SSSS:OOOO"  HANDLE 01h (the own
;                    window); OPEN of the pointer to the window, ADDTO of
;                    bits 0001h (messages on button activity only)
;   "pptrprb ready" on row 10, then for two pointer events:
;   "qN SSSS:OOOO"   READ 07h (the object with input)
;   "pN L row col st [fld]"  READ of the pointer:  the length, the
;                    message (word row, word column, byte status, the byte
;                    field only with 6 bytes:  API level 2.00 on)
; Clicked for it (tests):  the left button at some cell, then the right
; one at another.

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

        mov     si,offset t_ptr ; NEW pointer
        call    puts
        mov     ax,1200h
        mov     bx,010Fh
        int     15h
        pop     dx
        pop     ax
        mov     word ptr pobj,dx
        mov     word ptr pobj+2,ax
        call    putptr
        call    putnl
        mov     si,offset t_win ; the own window
        call    puts
        mov     ax,1200h
        mov     bx,0001h
        int     15h
        pop     dx
        pop     ax
        mov     word ptr win,dx
        mov     word ptr win+2,ax
        call    putptr
        call    putnl
        push    word ptr win+2  ; OPEN:  the pointer to the window
        push    word ptr win
        push    word ptr pobj+2
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0C00h
        int     15h
        push    0               ; ADDTO:  button activity only
        push    1
        push    word ptr pobj+2
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0A00h
        int     15h

        mov     ah,2            ; "pptrprb ready" on row 10
        xor     bh,bh
        mov     dx,0A00h
        int     10h
        mov     dx,offset t_ready
        mov     ah,9
        int     21h

        mov     cx,2
event:  push    cx
        mov     si,offset t_q
        call    puts
        mov     al,'3'
        sub     al,cl
        stosb
        mov     al,' '
        stosb
        mov     ax,1200h
        mov     bx,0407h
        int     15h
        pop     dx
        pop     ax
        call    putptr
        call    putnl
        mov     si,offset t_p
        call    puts
        pop     cx
        push    cx
        mov     al,'3'
        sub     al,cl
        stosb
        push    word ptr pobj+2
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     cx              ; the length (low word)
        pop     ax
        pop     si              ; the address
        pop     fs
        mov     al,' '
        stosb
        mov     ax,cx
        call    putdec
        cmp     cx,5
        jb      @F
        mov     al,' '
        stosb
        mov     ax,fs:[si]
        call    putdec
        mov     al,' '
        stosb
        mov     ax,fs:[si+2]
        call    putdec
        mov     al,' '
        stosb
        mov     al,fs:[si+4]
        call    puthex8
        cmp     cx,6
        jb      @F
        mov     al,' '
        stosb
        mov     al,fs:[si+5]
        call    puthex8
@@:
        call    putnl
        pop     cx
        dec     cx
        jnz     event

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

utext   db      'PTRPRB file',13,10,'$'
t_ready db      'pptrprb ready',13,10,'$'
t_ptr   db      'ptr ',0
t_win   db      'win ',0
t_q     db      'q',0
t_p     db      'p',0
handle  dw      0
pobj    dd      0
win     dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
