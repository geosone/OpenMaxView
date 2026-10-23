; SPDX-License-Identifier: GPL-3.0-or-later
; The task's own window sized and moved (tests/qemu):  OWNPRB
;   A stream to the own window (WRITE BL=01h):  C3h 5 rows 20 columns,
;   C5h the same logical size, C4h origin 0,0, C2h to row 6, column 30,
;   E2h colour 1Eh; then the text "own window" (plain WRITE) and REDRAW
;   (BH=13h BL=01h).  Then it waits for a key and ends.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        push    ds
        push    offset s_geom
        push    0
        push    s_geom_len
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        push    ds
        push    offset t_text
        push    0
        push    t_text_len
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     ax,1200h              ; REDRAW
        mov     bx,1301h
        int     15h
        xor     ah,ah
        int     16h
        mov     ax,4C00h
        int     21h

s_geom  db      1Bh,0
        dw      s_geom_end - s_geom - 4
        db      0C3h,5,20
        db      0C5h,5,20
        db      0C4h,0,0
        db      0C2h,6,30
        db      0E2h,1Eh
s_geom_end label byte
s_geom_len equ  $ - s_geom
t_text  db      'own window'
t_text_len equ  $ - t_text

        end     start
