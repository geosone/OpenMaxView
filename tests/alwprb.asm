; SPDX-License-Identifier: GPL-3.0-or-later
; Allow / disallow (measurement and tests/qemu):  ALWPRB hh hh ...
;   API level 2.01; the hex bytes as a manager stream (1Bh, 10h) to the own
;   window ("alwprb ready" on the screen), then keys until "x":  each shown
;   as "key cc".

        .model tiny
        .386
        .code
        org     100h

start:  mov     si,81h
        mov     di,offset sbody
next:   lodsb
        cmp     al,' '
        je      next
        cmp     al,13
        je      args_done
        mov     ah,al
        lodsb
        xchg    al,ah
        call    hexdig
        shl     al,4
        mov     dl,al
        mov     al,ah
        call    hexdig
        or      al,dl
        stosb
        jmp     next
args_done:
        mov     cx,di
        sub     cx,offset sbody
        mov     slen,cx
        mov     word ptr stream+2,cx
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        push    ds                    ; WRITE to the own window
        push    offset stream
        push    0
        mov     ax,slen
        add     ax,4
        push    ax
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
keys:   xor     ah,ah
        int     16h
        push    ax
        mov     dx,offset t_key
        mov     ah,9
        int     21h
        pop     ax
        push    ax
        mov     dl,al
        mov     ah,2
        int     21h
        mov     dx,offset t_nl
        mov     ah,9
        int     21h
        pop     ax
        cmp     al,'x'
        jne     keys
        mov     ax,4C00h
        int     21h

hexdig: or      al,20h
        sub     al,'0'
        cmp     al,9
        jbe     @F
        sub     al,'a'-'0'-10
@@:     ret

t_ready db      'alwprb ready',13,10,'$'
t_key   db      'key $'
t_nl    db      13,10,'$'
slen    dw      0
stream  db      1Bh,10h
        dw      0               ; (the length:  slen)
sbody   db      64 dup (0)

        end     start
