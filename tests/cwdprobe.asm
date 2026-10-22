; SPDX-License-Identifier: GPL-3.0-or-later
; Current directory probe for the multitasking core (tests/qemu):
;   CWDPROBE dir out
; changes to dir, then for about 10 seconds asks DOS for the current
; directory again and again while other tasks change theirs; writes
; "cwd <dir> ok" (or "bad <what it got>") to out.

        .8086
        .model tiny
        .code
        org 100h

start:
        mov     si,81h
        mov     di,offset dir
        call    word1
        mov     di,offset outf
        call    word1
        cmp     outf,0
        je      usage
        mov     ah,3Bh
        mov     dx,offset dir
        int     21h
        jc      fail
        mov     ah,47h          ; the directory as DOS gives it
        xor     dl,dl
        mov     si,offset want
        int     21h
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     bx,ds:[6Ch]
        pop     ds
again:  mov     ah,47h
        xor     dl,dl
        mov     si,offset got
        int     21h
        mov     si,offset want
        mov     di,offset got
@@:     mov     al,[si]
        cmp     al,[di]
        jne     bad
        inc     si
        inc     di
        or      al,al
        jnz     @B
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     ax,ds:[6Ch]
        pop     ds
        sub     ax,bx
        cmp     ax,182
        jb      again
        mov     dx,offset t_ok
        mov     si,offset want
        mov     bp,5
        jmp     short report
bad:    mov     dx,offset t_bad
        mov     si,offset got
        mov     bp,6
report: push    dx
        push    si
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset outf
        int     21h
        jc      fail
        mov     bx,ax
        mov     dx,offset t_cwd
        mov     cx,4
        mov     ah,40h
        int     21h
        pop     dx              ; the directory
        mov     di,dx
        xor     cx,cx
@@:     cmp     byte ptr [di],0
        je      @F
        inc     di
        inc     cx
        jmp     @B
@@:     mov     ah,40h
        int     21h
        pop     dx              ; " ok" / " bad"
        mov     cx,bp
        mov     ah,40h
        int     21h
        mov     ah,3Eh
        int     21h
        mov     ax,4C00h
        int     21h
usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; next word of the command tail (SI) to DI, ASCIIZ
word1   proc near
@@:     lodsb
        cmp     al,' '
        je      @B
@@:     cmp     al,13
        je      @F
        cmp     al,' '
        je      @F
        stosb
        lodsb
        jmp     @B
@@:     mov     byte ptr [di],0
        dec     si
        ret
word1   endp

utext   db      'CWDPROBE dir out',13,10,'$'
t_cwd   db      'cwd '
t_ok    db      ' ok',13,10
t_bad   db      ' bad',13,10
dir     db      80 dup (0)
outf    db      80 dup (0)
want    db      64 dup (0)
got     db      64 dup (0)

        end     start
