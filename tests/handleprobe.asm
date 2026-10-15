; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for the DESQview/TopView HANDLE message stack ABI.

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds

        mov     ax,0DE26h             ; resident foreground task handle
        int     15h
        or      bx,bx
        jz      failed
        mov     word ptr expected_segment,bx

        ; Selector 01h replaces a reserved DWORD with the current window.
        xor     ax,ax
        push    ax                    ; segment
        push    ax                    ; offset
        mov     ax,1200h
        mov     bx,0001h
        int     15h
        pop     di
        pop     es
        or      di,di
        jnz     failed
        mov     ax,es
        cmp     ax,word ptr expected_segment
        jne     failed

        ; Selector 00h accepts the same valid pointer from the caller stack.
        mov     ax,word ptr expected_segment
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        xor     bx,bx
        int     15h
        pop     di
        pop     es
        or      di,di
        jnz     failed
        mov     ax,es
        cmp     ax,word ptr expected_segment
        jne     failed

        ; A foreign stacked pointer is rejected with a null object handle.
        mov     ax,1234h
        push    ax
        mov     ax,1
        push    ax
        mov     ax,1200h
        xor     bx,bx
        int     15h
        pop     di
        pop     es
        or      di,di
        jnz     failed
        mov     ax,es
        or      ax,ax
        jnz     failed

        ; Mailbox selector 03h remains null until that object is implemented.
        xor     ax,ax
        push    ax
        push    ax
        mov     ax,1200h
        mov     bx,0003h
        int     15h
        pop     di
        pop     es
        or      di,di
        jnz     failed
        mov     ax,es
        or      ax,ax
        jnz     failed

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

expected_segment dw 0
passed_msg db 'MAXVTSR HANDLE message passed.',13,10,'$'
failed_msg db 'MAXVTSR HANDLE message failed.',13,10,'$'

        end     start
