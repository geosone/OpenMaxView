; SPDX-License-Identifier: GPL-3.0-or-later
; A subtask sizes and moves its own window (tests/qemu):  SOWPRB
;   The task writes "main" to its window and makes a subtask (NEW 08h
;   with an entry point).  The subtask sends its own window (WRITE
;   BL=01h) C3h 4 rows 20 columns, C5h the same logical size and C2h to
;   row 15, column 40, then the text "sub own" and REDRAW (BH=13h
;   BL=01h), and waits (PAUSE) for ever.  The task writes "made", waits
;   for a key, FREEs the subtask and ends.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        mov     si,offset t_main
        mov     cx,t_main_len
        call    wr
        mov     savsp,sp              ; NEW 08h:  no title, no size, the
        push    0                     ; default stack, a task, the entry
        push    0                     ; point
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0FFFFh
        push    0FFFFh
        push    0FFFFh
        push    0FFFFh
        push    cs
        push    offset subtask
        mov     ax,1200h
        mov     bx,0108h
        int     15h
        mov     bp,sp
        mov     ax,[bp+2]
        mov     sub_h,ax
        mov     sp,savsp
        mov     ax,1000h              ; (the subtask on)
        int     15h
        mov     si,offset t_made
        mov     cx,t_made_len
        call    wr
        xor     ah,ah
        int     16h
        push    sub_h                 ; FREE of it
        push    0
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     ax,4C00h
        int     21h

; WRITE of CX bytes at DS:SI to the own window.
wr:     push    ds
        push    si
        push    0
        push    cx
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        ret

subtask:
        push    cs
        pop     ds
        push    cs
        pop     ss
        mov     sp,offset stk_end
        mov     si,offset s_geom
        mov     cx,s_geom_len
        call    wr
        mov     si,offset t_sub
        mov     cx,t_sub_len
        call    wr
        mov     ax,1200h              ; REDRAW
        mov     bx,1301h
        int     15h
subtask_wait:
        mov     ax,1000h              ; PAUSE
        int     15h
        jmp     subtask_wait

savsp   dw      0
sub_h   dw      0
t_main  db      'main '
t_main_len equ  $ - t_main
t_made  db      'made '
t_made_len equ  $ - t_made
s_geom  db      1Bh,0
        dw      s_geom_end - s_geom - 4
        db      0C3h,4,20
        db      0C5h,4,20
        db      0C2h,15,40
s_geom_end label byte
s_geom_len equ  $ - s_geom
t_sub   db      'sub own'
t_sub_len equ   $ - t_sub
        db      512 dup(0)
stk_end label byte

        end     start
