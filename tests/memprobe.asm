; SPDX-License-Identifier: GPL-3.0-or-later
; Task memory isolation probe for the multitasking core (tests/qemu):
;   MEMPROBE file c [V]
; fills 32KB behind itself (V:  the text pages 1-7, B9000h-BFFFFh) with
; the character c, checks it for about 10 seconds while other tasks run,
; then writes "psp SSSS c ok" (or "bad") to file.  Tasks in contexts of
; their own get the same PSP segment and never see each other's pattern.

        .8086
        .model tiny
        .code
        org 100h

BUFLEN  equ     8000h

start:
        mov     si,81h
@@:     lodsb                   ; file name
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
        je      usage
        jmp     @B
@@:     mov     byte ptr [di],0
@@:     lodsb                   ; pattern
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        mov     pat,al
        mov     msg_pat,al
        mov     ax,ds           ; where:  behind us or the text pages
        mov     bx,offset buf
        mov     cl,4
        shr     bx,cl
        add     ax,bx
        inc     ax
        mov     bufseg,ax
        mov     blen,BUFLEN
@@:     lodsb
        cmp     al,' '
        je      @B
        and     al,0DFh
        cmp     al,'V'
        jne     where_ok
        mov     bufseg,0B900h
        mov     blen,7000h
where_ok:
        ; PSP -> hex
        mov     ax,cs
        mov     di,offset msg_psp
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
        ; fill
        mov     es,bufseg
        xor     di,di
        mov     cx,blen
        mov     al,pat
        cld
        rep     stosb
        ; check for 182 ticks
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     bx,ds:[6Ch]
        pop     ds
again:  xor     di,di
        mov     cx,blen
        mov     al,pat
        repe    scasb
        jne     bad
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     ax,ds:[6Ch]
        pop     ds
        sub     ax,bx
        cmp     ax,182
        jb      again
        jmp     short report
bad:    mov     word ptr msg_res,'ab'
        mov     byte ptr msg_res+2,'d'
report: mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     bx,ax
        mov     ah,40h
        mov     cx,MSGLEN
        mov     dx,offset msg
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

utext   db      'MEMPROBE file c',13,10,'$'
msg     db      'psp '
msg_psp db      '0000 '
msg_pat db      '? '
msg_res db      'ok ',13,10
MSGLEN  equ     $-msg
pat     db      ?
bufseg  dw      ?
blen  dw      ?
fname   db      80 dup (?)
buf     label   byte

        end     start
