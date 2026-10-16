; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for TopView OSTACK/USTACK foreground task-stack switching.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds

        mov     ax,0D705h
        int     2Fh
        test    bx,2000h
        jz      failed

        mov     ax,ss
        mov     word ptr user_ss,ax
        mov     word ptr user_sp,sp
        mov     ax,101Ah
        int     15h

        mov     ax,ss
        cmp     ax,word ptr user_ss
        je      stack_failed
        mov     word ptr internal_ss,ax

        ; The private stack must support ordinary data and nested API calls.
        mov     ax,055AAh
        push    ax
        xor     ax,ax
        pop     ax
        cmp     ax,055AAh
        jne     stack_failed
        mov     ax,0DE26h
        int     15h
        or      bx,bx
        jz      stack_failed

        mov     ax,1025h
        int     15h
        mov     ax,ss
        cmp     ax,word ptr user_ss
        jne     failed
        mov     ax,sp
        cmp     ax,word ptr user_sp
        jne     failed

        ; A second pair proves that the bounded resident stack is reusable.
        mov     ax,101Ah
        int     15h
        mov     ax,ss
        cmp     ax,word ptr internal_ss
        jne     stack_failed
        mov     ax,1025h
        int     15h
        mov     ax,ss
        cmp     ax,word ptr user_ss
        jne     failed
        mov     ax,sp
        cmp     ax,word ptr user_sp
        jne     failed

        mov     dx,offset passed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

stack_failed:
        mov     ax,1025h
        int     15h
failed:
        mov     dx,offset failed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

user_ss dw 0
user_sp dw 0
internal_ss dw 0
passed_msg db 'MAXVTSR task stack switching passed.',13,10,'$'
failed_msg db 'MAXVTSR task stack switching failed.',13,10,'$'
        end start
