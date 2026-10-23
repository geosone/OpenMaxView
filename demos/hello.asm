; SPDX-License-Identifier: GPL-3.0-or-later
; HELLO:  the smallest DESQview API program (clean-room demo for Open
; MaxView).  It asks for DESQview (INT 21h AX=2B01h, CX:DX 'DESQ'), ends
; with a message without it, sets the API level 2.01 and writes a line to
; its own window through the API (WRITE of the window).

        .model tiny
        .code
        org 100h

start:
        mov     ax,2B01h              ; DESQview (or Open MaxView) there?
        mov     cx,'DE'
        mov     dx,'SQ'
        int     21h
        cmp     al,0FFh
        je      no_dv
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        push    ds                    ; WRITE to the own window (BL=01h):
        mov     ax,offset greeting    ; the address and the length
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,greeting_len
        push    ax
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     ax,4C00h
        int     21h
no_dv:
        mov     dx,offset t_nodv
        mov     ah,9
        int     21h
        mov     ax,4C01h
        int     21h

greeting db     'Hello from a DESQview API program.',13,10
greeting_len equ $ - greeting
t_nodv  db      'HELLO needs DESQview or Open MaxView.',13,10,'$'

        end     start
