; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox smoke probe for MAXVANSI.COM.

MUX_QUERY      equ 0D710h
MUX_SIGNATURE  equ 04E41h

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds
        mov     ax,MUX_QUERY
        int     2Fh
        cmp     bx,MUX_SIGNATURE
        jne     failed
        cmp     cx,0100h
        jne     failed

        mov     si,offset sequence
emit_loop:
        lodsb
        or      al,al
        jz      verify_cursor
        int     29h
        jmp     emit_loop

verify_cursor:
        mov     ah,03h
        xor     bh,bh
        int     10h
        cmp     dh,4
        jne     failed
        cmp     dl,11
        jne     failed
        mov     dl,10
        mov     ah,02h
        int     10h
        mov     ah,08h
        int     10h
        cmp     al,'Y'
        jne     failed
        and     ah,0Fh
        cmp     ah,04h
        jne     failed
        mov     dx,offset passed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

failed:
        mov     dx,offset failed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

sequence   db 1Bh,'[2J',1Bh,'[5;10H','X',1Bh,'[31m','Y',0
passed_msg db 'MAXVANSI probe passed',13,10,'$'
failed_msg db 'MAXVANSI probe failed',13,10,'$'

        end     start
