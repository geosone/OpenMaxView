; SPDX-License-Identifier: GPL-3.0-or-later
; The task's keyboard object (tests/qemu):  KBDPRB file
;   "kbd SSSS:OOOO"           HANDLE 05h, the task's own keyboard
;   then "kbdprb ready" on the screen, and READ 05h (it waits for a
;   key) three times:  "key LLLLLLLL hh hh .." (the length on top, the bytes at the
;   address below it, 8 at most), " st SSSSSSSS" (STATUS 05h)

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
        mov     si,offset t_kbd
        call    puts
        mov     ax,1200h        ; HANDLE 05h
        mov     bx,0005h
        int     15h
        pop     dx
        pop     ax
        call    putptr
        call    putnl
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
        mov     cx,3
next:   push    cx
        mov     ax,1200h        ; READ 05h:  waits for a key
        mov     bx,0405h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        pop     word ptr d2
        pop     word ptr d2+2
        mov     si,offset t_key
        call    puts
        mov     eax,d1
        call    puthex32
        mov     cx,word ptr d1
        cmp     word ptr d1+2,0
        jne     shown
        cmp     cx,8
        jbe     @F
        mov     cx,8
@@:     jcxz    shown
        push    ds
        lds     si,d2
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        pop     ds
shown:  mov     si,offset t_st      ; STATUS 05h:  the scan code
        call    puts
        mov     ax,1200h
        mov     bx,0F05h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        mov     eax,d1
        call    puthex32
        call    putnl
        pop     cx
        loop    next
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

puthex32 proc near
        push    eax
        shr     eax,16
        call    puthex
        pop     eax
puthex32 endp                   ; (falls through:  the low word)
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

utext   db      'KBDPRB file',13,10,'$'
t_ready db      'kbdprb ready',13,10,'$'
t_kbd   db      'kbd ',0
t_key   db      'key ',0
t_st    db      ' st ',0
handle  dw      0
d1      dd      0
d2      dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
