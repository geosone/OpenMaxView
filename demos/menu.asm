; SPDX-License-Identifier: GPL-3.0-or-later
; MENU:  a pop-up menu in a window of its own (clean-room demo of the
; DESQview API, written for Open MaxView).
;   A window object (NEW 08h:  4 rows, 12 columns, title "colours"), a
;   keyboard object opened to it in field mode, the menu text and a field
;   table of four select fields (keys R, G, B, Q) plus Esc as an invisible
;   one; moved to 9,33, shown, put on top.  Each READ of the keyboard gives
;   the chosen field's number:  "item N chosen" in the own window; Q or
;   Esc ends.  MENU file also writes "N L XX.." (field, record length, the
;   record) to the file.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     si,81h                ; an optional log file
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      nolog
        mov     di,offset fname
@@:     stosb
        lodsb
        cmp     al,' '
        je      @F
        cmp     al,13
        jne     @B
@@:     mov     byte ptr [di],0
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      nolog
        mov     handle,ax
nolog:
        mov     bx,1                  ; DESQview (or MaxView) there?
        mov     ax,2B01h
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
        mov     ax,0DE0Bh             ; API level 2.01:  menus with the
        mov     bx,0201h              ; arrow keys
        int     15h
        push    ds                    ; alternate field mode (BDh):  the
        push    offset s_cursor       ; cursor keys in menus
        push    0
        push    5
        mov     ax,1200h
        mov     bx,0501h
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
        push    4
        push    0
        push    12
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
        mov     bx,010Ah              ; field mode
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
        push    0
        push    1
        push    word ptr kbd+2
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0A00h
        int     15h

        push    ds                    ; the text (no stream:  as is)
        push    offset menu_text
        push    0
        push    menu_len
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        mov     si,offset s_fields
        call    winwrite
        mov     si,offset s_place     ; moved, shown, on top
        call    winwrite
        mov     si,offset s_show
        call    winwrite
        mov     si,offset s_top
        call    winwrite

next:   push    word ptr kbd+2        ; READ:  the chosen field
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     cx                    ; the length
        pop     ax
        pop     si                    ; the record
        pop     fs
        xor     al,al
        jcxz    @F
        mov     al,fs:[si]
@@:     mov     field,al
        call    logrec
        mov     si,offset s_reset     ; the fields reset
        call    winwrite
        mov     al,field
        add     al,'0'
        mov     t_digit,al
        push    ds                    ; "item N chosen" in the own window
        push    offset t_item
        push    0
        push    t_item_len
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        cmp     field,4
        jb      next

        push    word ptr kbd+2        ; FREE both
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     bx,handle
        or      bx,bx
        jz      @F
        mov     ah,3Eh
        int     21h
@@:     mov     ax,4C00h
        int     21h

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

; "N L XX.." (FS:SI - CX bytes) to the log file, if any.
logrec  proc near
        cmp     handle,0
        je      logrec_ret
        mov     di,offset line
        mov     al,field
        call    hex8
        mov     al,' '
        stosb
        mov     ax,cx
        call    hex8
        mov     al,' '
        stosb
        jcxz    logrec_end
        push    cx
@@:     mov     al,fs:[si]
        inc     si
        call    hex8
        loop    @B
        pop     cx
logrec_end:
        mov     ax,0A0Dh
        stosw
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     ah,68h
        int     21h
logrec_ret:
        ret
logrec  endp

hex8    proc near
        push    ax
        shr     al,4
        call    nibble
        pop     ax
        and     al,0Fh
nibble: add     al,'0'
        cmp     al,'9'
        jbe     @F
        add     al,7
@@:     stosb
        ret
hex8    endp

t_nodv  db      'MENU needs DESQview or Open MaxView.',13,10,'$'
title_text db   'colours'
title_len equ   $ - title_text
menu_text db    ' red      R '
        db      ' green    G '
        db      ' blue     B '
        db      ' quit     Q '
menu_len equ    $ - menu_text
s_cursor db     1Bh,10h,1,0,0BDh
s_hide  db      1Bh,0,2,0,0D5h,0E4h
s_logical db    1Bh,0,3,0,0DAh,0E2h,1
s_fields db     1Bh,0
        dw      fields_end - fields
fields  db      0E5h,18h              ; two-key menus:  8-byte entries
        db      0FFh,5,43h,0,0,9,1    ; 5 fields, keys, numbered records
        db      0,0,0,11,0C0h,'R',1,0
        db      1,0,1,11,0C0h,'G',1,0
        db      2,0,2,11,0C0h,'B',1,0
        db      3,0,3,11,0C0h,'Q',1,0
        db      1,0,0,0,0C0h,27,1,0   ; Esc:  keyboard only
fields_end label byte
s_place db      1Bh,0,3,0,0C2h,9,33
s_show  db      1Bh,0,1,0,0D4h
s_top   db      1Bh,10h,1,0,0C2h
s_reset db      1Bh,0,1,0,0FEh
t_item  db      'item '
t_digit db      '0'
        db      ' chosen',13,10
t_item_len equ  $ - t_item
handle  dw      0
field   db      0
own     dd      0
win     dd      0
kbd     dd      0
fname   db      80 dup (0)
line    db      140 dup (0)

        end     start
