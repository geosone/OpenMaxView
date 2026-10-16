; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for foreground TopView PRINTC compatibility.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds
        mov     ax,0DE26h
        int     15h
        or      bx,bx
        jz      failed
        mov     word ptr window_segment,bx

        mov     ah,0Fh
        int     10h
        cmp     al,3
        ja      failed
        mov     byte ptr columns,ah
        mov     ax,0B800h
        mov     es,ax

        xor     bh,bh
        mov     ah,03h
        int     10h
        mov     word ptr saved_cursor,dx

        ; Selector 01h positions the current task's default window.
        xor     ax,ax
        push    ax                    ; column high word
        mov     ax,2
        push    ax                    ; column low word
        xor     ax,ax
        push    ax                    ; row high word
        mov     ax,2
        push    ax                    ; row low word
        mov     ax,1200h
        mov     bx,1101h
        int     15h
        xor     bh,bh
        mov     ah,03h
        int     10h
        cmp     dx,0202h
        jne     restore_cursor_failed

        ; Selector 00h accepts the explicit foreground-window handle.
        xor     ax,ax
        push    ax                    ; column high word
        mov     ax,3
        push    ax                    ; column low word
        xor     ax,ax
        push    ax                    ; row high word
        mov     ax,2
        push    ax                    ; row low word
        push    word ptr window_segment
        xor     ax,ax
        push    ax                    ; window offset
        mov     ax,1200h
        mov     bx,1100h
        int     15h
        xor     bh,bh
        mov     ah,03h
        int     10h
        cmp     dx,0203h
        jne     restore_cursor_failed

        xor     ax,ax
        mov     al,byte ptr columns
        mov     bx,2
        mul     bx
        add     ax,3
        shl     ax,1
        mov     di,ax
        mov     ax,word ptr es:[di]
        mov     word ptr saved_cell,ax

        mov     dx,word ptr window_segment
        mov     bx,1E5Ah              ; yellow-on-blue 'Z'
        mov     ax,1003h
        int     15h
        cmp     word ptr es:[di],1E5Ah
        jne     restore_failed
        xor     bh,bh
        mov     ah,03h
        int     10h
        cmp     dx,0204h
        jne     restore_failed

        mov     dx,word ptr window_segment
        xor     bx,bx                 ; synchronize cursor only
        mov     ax,1003h
        int     15h
        xor     bh,bh
        mov     ah,03h
        int     10h
        cmp     dx,0204h
        jne     restore_failed

        mov     ax,word ptr saved_cell
        mov     word ptr es:[di],ax
        mov     dx,word ptr saved_cursor
        xor     bh,bh
        mov     ah,02h
        int     10h
        mov     dx,offset passed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

restore_failed:
        mov     ax,word ptr saved_cell
        mov     word ptr es:[di],ax
restore_cursor_failed:
        mov     dx,word ptr saved_cursor
        xor     bh,bh
        mov     ah,02h
        int     10h
failed:
        mov     dx,offset failed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

window_segment dw 0
columns db 0
saved_cursor dw 0
saved_cell dw 0
passed_msg db 'MAXVTSR PRINTC foreground output passed.',13,10,'$'
failed_msg db 'MAXVTSR PRINTC foreground output failed.',13,10,'$'
        end start
