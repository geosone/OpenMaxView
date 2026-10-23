; SPDX-License-Identifier: GPL-3.0-or-later
; MOUSE:  a pointer object (clean-room demo of the DESQview API, written
; for Open MaxView).  It clears its window, writes how it works, opens a
; pointer object to the window, puts the mouse pointer on row 5, column 30
; and then marks each pointer message where it happened:  "." for a move,
; "L" for the left button, "R" for the right one, which ends it.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     ax,2B01h              ; DESQview (or Open MaxView) there?
        mov     cx,'DE'
        mov     dx,'SQ'
        int     21h
        cmp     al,0FFh
        jne     have_dv
        mov     dx,offset t_nodv
        mov     ah,9
        int     21h
        mov     ax,4C01h
        int     21h
have_dv:
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        mov     ax,1200h              ; the own window
        mov     bx,0001h
        int     15h
        pop     word ptr win
        pop     word ptr win+2
        mov     ax,1200h              ; NEW pointer
        mov     bx,010Fh
        int     15h
        pop     word ptr pobj
        pop     word ptr pobj+2

        push    word ptr win+2        ; ERASE the window, the text
        push    word ptr win
        mov     ax,1200h
        mov     bx,0E00h
        int     15h
        push    ds
        push    offset t_info
        push    0
        push    t_info_len
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h

        push    word ptr win+2        ; OPEN the pointer to the window
        push    word ptr win
        push    word ptr pobj+2
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0C00h
        int     15h
        push    0                     ; WRITE:  the pointer to row 5,
        push    5                     ; column 30 (the column on top)
        push    0
        push    30
        push    word ptr pobj+2
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0500h
        int     15h

next:   push    word ptr pobj+2       ; READ a pointer message:  word row,
        push    word ptr pobj         ; word column, byte status
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     cx                    ; the length
        pop     ax
        pop     si                    ; the message
        pop     fs
        cmp     cx,5
        jb      next
        mov     al,'.'
        mov     ah,fs:[si+4]
        test    ah,01h
        jz      @F
        mov     al,'L'
@@:     test    ah,02h
        jz      @F
        mov     al,'R'
@@:     mov     mark,al
        push    0                     ; AT:  the cursor there (the column
        push    word ptr fs:[si]      ; on top), the mark
        push    0
        push    word ptr fs:[si+2]
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,1100h
        int     15h
        push    ds
        push    offset mark
        push    0
        push    1
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        cmp     mark,'R'
        jne     next

        push    word ptr pobj+2       ; FREE the pointer
        push    word ptr pobj
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     ax,4C00h
        int     21h

t_nodv  db      'MOUSE needs DESQview or Open MaxView.',13,10,'$'
t_info  db      'Move the mouse:  "." where the pointer went, "L" where',13,10
        db      'the left button was pressed.  The right button ends.',13,10
t_info_len equ  $ - t_info
mark    db      0
win     dd      0
pobj    dd      0

        end     start
