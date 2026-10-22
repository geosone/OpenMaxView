; SPDX-License-Identifier: GPL-3.0-or-later
; Critical error probe for the multitasking core (tests/qemu):
;   CRITPRB path out
; waits 3 seconds, opens path (A:\X with no disk:  "Not ready", INT 24h),
; then writes "open CF AX" (e.g. "open 1 0015") to out.  Started in the
; background, the critical error must come to the foreground.

        .8086
        .model tiny
        .code
        org 100h

start:
        mov     si,81h
        mov     di,offset path
        call    word1
        mov     di,offset outf
        call    word1
        cmp     outf,0
        je      usage
        mov     dx,offset msg
        mov     ah,9
        int     21h
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     bx,ds:[6Ch]
@@:     mov     ax,ds:[6Ch]
        sub     ax,bx
        cmp     ax,55
        jb      @B
        pop     ds
        mov     ax,3D00h
        mov     dx,offset path
        int     21h
        mov     bl,'0'
        jnc     @F
        mov     bl,'1'
@@:     mov     res_cf,bl
        mov     di,offset res_ax
        mov     cx,4
@@:     rol     ax,1
        rol     ax,1
        rol     ax,1
        rol     ax,1
        push    ax
        and     al,0Fh
        add     al,'0'
        cmp     al,'9'
        jbe     hexok
        add     al,7
hexok:  stosb
        pop     ax
        loop    @B
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset outf
        int     21h
        jc      fail
        mov     bx,ax
        mov     ah,40h
        mov     cx,RESLEN
        mov     dx,offset res
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

utext   db      'CRITPRB path out',13,10,'$'
msg     db      'critprobe start',13,10,'$'
res     db      'open '
res_cf  db      '? '
res_ax  db      '0000',13,10
RESLEN  equ     $-res
path    db      80 dup (0)
outf    db      80 dup (0)

        end     start
