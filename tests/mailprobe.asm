; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for the bounded mailbox object lifecycle.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds
        call    new_mailbox
        or      dx,dx
        jnz     failed
        or      ax,ax
        jz      failed
        mov     word ptr mailbox_one,ax
        call    new_mailbox
        or      dx,dx
        jnz     failed
        or      ax,ax
        jz      failed
        cmp     ax,word ptr mailbox_one
        je      failed
        mov     word ptr mailbox_two,ax
        call    new_mailbox
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        mov     ax,word ptr mailbox_one
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        cmp     bx,0FFFFh
        jne     failed
        mov     ax,0DE14h
        int     15h
        cmp     bl,09h
        jne     failed

        mov     ax,word ptr mailbox_one
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
        cmp     ax,word ptr mailbox_one
        jne     failed

        mov     ax,word ptr mailbox_one
        mov     bx,0C00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0F00h
        call    mailbox_query
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0D00h
        call    mailbox_command

        xor     ax,ax
        mov     es,ax
        xor     di,di
        mov     ax,0DE2Bh
        int     15h                   ; foreground task
        or      ax,ax
        jnz     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        cmp     ax,word ptr mailbox_one
        jne     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        cmp     ax,word ptr mailbox_two
        jne     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        or      ax,ax
        jnz     failed

        mov     ax,word ptr mailbox_one
        call    free_mailbox
        mov     ax,word ptr mailbox_one
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
        jnz     failed
        call    new_mailbox
        cmp     ax,word ptr mailbox_one
        jne     failed

        mov     ax,0D702h
        int     2Fh
        mov     ax,word ptr mailbox_two
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
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

new_mailbox:
        push    bx
        xor     ax,ax
        push    ax
        push    ax
        mov     ax,1200h
        mov     bx,0109h
        int     15h
        pop     dx
        pop     ax
        pop     bx
        ret

free_mailbox:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        pop     bx
        ret

mailbox_command:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        int     15h
        pop     bx
        ret

mailbox_query:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        int     15h
        pop     ax
        pop     dx
        pop     bx
        ret

mailbox_one dw 0
mailbox_two dw 0
passed_msg db 'MAXVTSR mailbox object lifecycle passed.',13,10,'$'
failed_msg db 'MAXVTSR mailbox object lifecycle failed.',13,10,'$'
        end start
