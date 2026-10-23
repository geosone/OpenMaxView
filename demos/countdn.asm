; SPDX-License-Identifier: GPL-3.0-or-later
; COUNTDN:  a countdown in a window of its own (clean-room demo of the
; DESQview API, written for Open MaxView).
;   A window object (NEW 08h:  5 rows, 24 columns, title "countdown") with
;   an input field for the seconds (filled from the right), a keyboard
;   object opened to it in field mode and a timer object.  The OBJECTQ
;   says which of them has input:  the keyboard's records give the seconds
;   (field 1), Enter (field 2) starts, Esc (field 3) ends; each expiry of
;   the timer counts one second down ("left" in the window) and starts it
;   again, at 0 "time is up" goes to the own window.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     ax,2B01h              ; DESQview (or MaxView) there?
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
        mov     ax,1200h              ; the own window's handle
        mov     bx,0001h
        int     15h
        pop     word ptr own
        pop     word ptr own+2

        push    ds                    ; NEW 08h:  title, its length,
        push    offset title_text     ; rows, columns, no input buffer,
        push    0                     ; default stack, no task, no entry
        push    title_len
        push    0
        push    5
        push    0
        push    24
        xor     ax,ax
        mov     cx,8
@@:     push    ax
        loop    @B
        mov     ax,1200h
        mov     bx,0108h
        int     15h
        pop     word ptr win
        pop     word ptr win+2
        mov     si,offset s_hide      ; hidden, logical colours, colour 1
        call    winwrite
        mov     si,offset s_logical
        call    winwrite

        mov     ax,1200h              ; NEW keyboard, OPEN to the window,
        mov     bx,010Ah              ; field mode with the cursor
        int     15h
        pop     word ptr kbd
        pop     word ptr kbd+2
        push    word ptr win+2
        push    word ptr win
        push    word ptr kbd+2
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0C00h
        int     15h
        push    0                     ; (and the hardware cursor:  else
        push    3                     ; DESQview leaves input fields alone)
        push    word ptr kbd+2
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        mov     ax,1200h              ; NEW timer
        mov     bx,010Bh
        int     15h
        pop     word ptr tim
        pop     word ptr tim+2

        push    ds                    ; the text (no stream:  as is)
        push    offset panel_text
        push    0
        push    panel_len
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        mov     si,offset s_fields
        call    winwrite
        call    show_left
        mov     si,offset s_place     ; moved, shown, on top
        call    winwrite
        mov     si,offset s_show
        call    winwrite
        mov     si,offset s_top
        call    winwrite
        mov     si,offset s_cursor    ; the cursor in the seconds' field
        call    winwrite

next:   mov     ax,1200h              ; OBJECTQ READ:  who has input?
        mov     bx,0407h
        int     15h
        pop     dx
        pop     ax
        cmp     dx,word ptr tim
        jne     keys
        cmp     ax,word ptr tim+2
        jne     keys
        cmp     left,0                ; the timer:  a second less
        je      next
        dec     left
        call    show_left
        cmp     left,0
        je      time_up
        call    one_second
        jmp     next
time_up:
        push    ds                    ; "time is up" in the own window
        push    offset t_up
        push    0
        push    t_up_len
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        jmp     next

keys:   push    word ptr kbd+2        ; READ the keyboard:  the records
        push    word ptr kbd          ; (field, word length, the data)
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     cx
        pop     ax
        pop     si
        pop     fs
        mov     di,si
        add     di,cx
nextrec:cmp     si,di
        jae     records_done
        mov     al,fs:[si]
        mov     cx,fs:[si+1]
        add     si,3
        cmp     al,1
        jne     not_seconds
        call    seconds_of            ; field 1:  the seconds
        jmp     record_next
not_seconds:
        cmp     al,2
        jne     not_start
        pusha                         ; (the record's length, where)
        mov     ax,seconds            ; field 2 (Enter):  start
        mov     left,ax
        call    show_left
        cmp     left,0
        je      @F
        call    one_second
@@:     popa
        jmp     record_next
not_start:
        cmp     al,3                  ; field 3 (Esc):  the end
        je      the_end
record_next:
        add     si,cx
        jmp     nextrec
records_done:
        mov     si,offset s_reset     ; the fields reset
        call    winwrite
        jmp     next

the_end:
        mov     bx,offset tim         ; FREE the timer, keyboard, window
        call    free
        mov     bx,offset kbd
        call    free
        mov     bx,offset win
        call    free
        mov     ax,4C00h
        int     21h

; FREE of the object whose handle is at BX.
free    proc near
        push    word ptr [bx+2]
        push    word ptr [bx]
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        ret
free    endp

; The timer to expire in one second (ADDTO:  100 hundredths).
one_second proc near
        push    0
        push    100
        push    word ptr tim+2
        push    word ptr tim
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        ret
one_second endp

; The digits FS:SI (CX of them, blanks ignored) as the seconds.
seconds_of proc near
        push    cx
        push    si
        xor     ax,ax
        jcxz    seconds_set
@@:     movzx   dx,byte ptr fs:[si]
        inc     si
        sub     dl,'0'
        cmp     dl,9
        ja      seconds_skip
        imul    ax,10
        add     ax,dx
seconds_skip:
        loop    @B
seconds_set:
        mov     seconds,ax
        pop     si
        pop     cx
        ret
seconds_of endp

; "left" (3 digits) at row 2, column 8 of the window.
show_left proc near
        mov     ax,left
        mov     bl,10
        mov     di,offset s_digits + 2
        mov     cx,3
@@:     div     bl
        add     ah,'0'
        mov     [di],ah
        dec     di
        xor     ah,ah
        loop    @B
        mov     si,offset s_left
        call    winwrite
        ret
show_left endp

; The stream at SI (1Bh, type, word length, ...) to the window.
winwrite proc near
        push    ds
        push    si
        push    0
        mov     ax,word ptr [si+2]
        add     ax,4
        push    ax
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        ret
winwrite endp

t_nodv  db      'COUNTDN needs DESQview or Open MaxView.',13,10,'$'
title_text db   'countdown'
title_len equ   $ - title_text
panel_text db   ' Seconds:  [  ]         '
        db      '                        '
        db      ' Left:                  '
        db      '                        '
        db      ' Enter=start   Esc=end  '
panel_len equ   $ - panel_text
s_hide  db      1Bh,0,2,0,0D5h,0E4h
s_logical db    1Bh,0,3,0,0DAh,0E2h,1
s_fields db     1Bh,0
        dw      fields_end - fields
fields  db      0E5h,18h              ; two-key tables:  8-byte entries
        db      0FFh,3,47h,0,0,9,2    ; 3 fields, keys, numbered records
        db      0,12,0,13,80h,28h,0,0 ; the seconds:  from the right
        db      1,0,0,0,0C0h,13,1,0   ; Enter:  keyboard only
        db      1,0,0,0,0C0h,27,1,0   ; Esc:  keyboard only
fields_end label byte
s_left  db      1Bh,0,7,0,0C0h,2,8,63h
s_digits db     '000'
s_place db      1Bh,0,3,0,0C2h,8,28
s_show  db      1Bh,0,1,0,0D4h
s_top   db      1Bh,10h,1,0,0C2h
s_cursor db     1Bh,0,2,0,0F4h,1
s_reset db      1Bh,0,1,0,0FEh
t_up    db      'time is up',13,10
t_up_len equ    $ - t_up
seconds dw      0
left    dw      0
own     dd      0
win     dd      0
kbd     dd      0
tim     dd      0

        end     start
