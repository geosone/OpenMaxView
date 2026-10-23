; SPDX-License-Identifier: GPL-3.0-or-later
; LAUNCH:  starts the other demos, each in a window and process of its own
; (clean-room demo of the DESQview API, written for Open MaxView).
;   A menu in a window object (NEW 08h), a keyboard object in field mode
;   on it (as MENU).  For the chosen demo it makes a DESQview program
;   information (DVP) in memory:  title, program name, memory, the current
;   drive and directory (where the demos are), a 25x80 screen, 8KB of
;   DESQview's own memory (for its windows and subtasks), layout
;   version 1, window shown and closed at the end; APP_START
;   (INT 15h AX=102Ch, ES:DI the DVP, BX its size) starts it, BX is the new
;   task's handle (0:  it could not start).  The result goes to the own
;   window; Q or Esc ends (the started ones keep running).

        .model tiny
        .386
        .code
        org 100h

DVPSIZE equ     1A0h                  ; a DESQview 2.x DVP
D_SUM   equ     01h                   ; its checksum:  bytes 02h..170h
D_TITLE equ     02h                   ; 30 bytes, blank padded
D_MAXKB equ     20h
D_MINKB equ     22h
D_PROG  equ     24h                   ; 64 bytes, 0 terminated
D_DRIVE equ     64h
D_DIR   equ     65h                   ; 64 bytes, 0 terminated
D_PARMS equ     0A5h                  ; 64 bytes, 0 terminated
D_PAGES equ     0E6h                  ; text pages
D_ROWS  equ     0E9h
D_COLS  equ     0EAh
D_SYSKB equ     0EDh                  ; KB of DESQview's memory for the
                                      ; program's windows, subtasks, objects
D_KEYS  equ     171h                  ; the two Open Window keys
D_VER   equ     17Eh                  ; 1:  the DESQview 2.x layout (DV
                                      ; starts nothing without it)
D_CLOSE equ     17Ch                  ; 1:  the window closes when the
                                      ; program ends (0:  a DOS prompt stays)
D_SHOW  equ     184h                  ; bit 7:  the window shown (DV:  else
                                      ; hidden, the program runs unseen)
NDEMO   equ     7                     ; menu entries before "quit"

start:
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
        push    ds                    ; alternate field mode (BDh)
        push    offset s_cursor
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
        push    NDEMO+1
        push    0
        push    16
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

        push    ds                    ; what it is for, in the own window
        push    offset t_hello
        push    0
        push    t_hello_len
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h

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
        mov     si,offset s_reset     ; the fields reset
        call    winwrite
        movzx   bx,field
        dec     bx
        cmp     bx,NDEMO
        jae     quit
        call    launch
        jmp     next

quit:   push    word ptr kbd+2        ; FREE both
        push    word ptr kbd
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     ax,4C00h
        int     21h

; Demo BX (0 ..):  its DVP made, APP_START, the result in the own window.
launch  proc near
        shl     bx,1
        mov     si,word ptr demos[bx] ; title, 0, program, 0, keys, memory
        cld
        mov     di,offset dvp         ; all zero, then the fields
        xor     al,al
        mov     cx,DVPSIZE
        rep     stosb
        mov     di,offset dvp+D_TITLE
        mov     cx,30
        mov     al,' '
        rep     stosb
        mov     di,offset dvp+D_TITLE
        mov     bx,si                 ; (the title for the result line)
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     mov     di,offset dvp+D_PROG
@@:     lodsb
        stosb
        or      al,al
        jnz     @B
        lodsw
        mov     word ptr dvp+D_KEYS,ax
        lodsw
        mov     word ptr dvp+D_MAXKB,ax
        mov     word ptr dvp+D_MINKB,ax
        mov     ah,19h                ; the current drive and directory:
        int     21h                   ; the demos are there
        add     al,'A'
        mov     byte ptr dvp+D_DRIVE,al
        mov     byte ptr dvp+D_DIR,'\'
        mov     ah,47h
        xor     dl,dl
        push    si
        mov     si,offset dvp+D_DIR+1
        int     21h
        pop     si
        mov     byte ptr dvp+D_PAGES,1
        mov     byte ptr dvp+D_ROWS,25
        mov     byte ptr dvp+D_COLS,80
        mov     word ptr dvp+D_SYSKB,8 ; (WORMS:  4 subtasks)
        mov     byte ptr dvp+D_VER,1
        mov     byte ptr dvp+D_SHOW,80h
        mov     byte ptr dvp+D_CLOSE,1
        mov     si,offset dvp+2       ; the checksum
        mov     cx,170h-1
        xor     ah,ah
@@:     lodsb
        add     ah,al
        loop    @B
        mov     byte ptr dvp+D_SUM,ah

        push    bx
        push    ds
        pop     es
        mov     di,offset dvp
        mov     bx,DVPSIZE
        mov     ax,102Ch              ; APP_START
        int     15h
        mov     dx,bx
        pop     si

        mov     di,offset line        ; "title:  task XXXX" or "title:
@@:     lodsb                         ; could not start"
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     mov     si,offset t_task
        or      dx,dx
        jnz     @F
        mov     si,offset t_fail
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     or      dx,dx
        jz      @F
        mov     al,dh
        call    hex8
        mov     al,dl
        call    hex8
@@:     mov     ax,0A0Dh
        stosw
        mov     cx,di
        sub     cx,offset line
        push    ds
        push    offset line
        push    0
        push    cx
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        ret
launch  endp

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

t_nodv  db      'LAUNCH needs DESQview or Open MaxView.',13,10,'$'
t_hello db      'LAUNCH:  choose a demo, it starts in a window of its own.',13,10
t_hello_len equ $ - t_hello
t_task  db      ':  task ',0
t_fail  db      ':  could not start',0
title_text db   'demos'
title_len equ   $ - title_text
menu_text db    ' hello        H '
        db      ' menu         M '
        db      ' mouse        P '
        db      ' countdown    C '
        db      ' worms        W '
        db      ' serve        S '
        db      ' ask          A '
        db      ' quit         Q '
menu_len equ    $ - menu_text
; per demo:  title, 0, program, 0, Open Window keys, KB of memory (a
; .COM program gets 64KB from DOS)
d_hello db      'Hello',0,'HELLO.COM',0,'HE'
        dw      64
d_menu  db      'Menu',0,'MENU.COM',0,'ME'
        dw      64
d_mouse db      'Mouse',0,'MOUSE.COM',0,'MO'
        dw      64
d_count db      'Countdown',0,'COUNTDN.COM',0,'CD'
        dw      64
d_worms db      'Worms',0,'WORMS.COM',0,'WO'
        dw      64
d_serve db      'Serve',0,'SERVE.COM',0,'SV'
        dw      64
d_ask   db      'Ask',0,'ASK.COM',0,'AS'
        dw      64
demos   dw      d_hello, d_menu, d_mouse, d_count, d_worms, d_serve, d_ask
s_cursor db     1Bh,10h,1,0,0BDh
s_hide  db      1Bh,0,2,0,0D5h,0E4h
s_logical db    1Bh,0,3,0,0DAh,0E2h,1
s_fields db     1Bh,0
        dw      fields_end - fields
fields  db      0E5h,18h              ; two-key menus:  8-byte entries
        db      0FFh,9,43h,0,0,9,1    ; 9 fields, keys, numbered records
        db      0,0,0,15,0C0h,'H',1,0
        db      1,0,1,15,0C0h,'M',1,0
        db      2,0,2,15,0C0h,'P',1,0
        db      3,0,3,15,0C0h,'C',1,0
        db      4,0,4,15,0C0h,'W',1,0
        db      5,0,5,15,0C0h,'S',1,0
        db      6,0,6,15,0C0h,'A',1,0
        db      7,0,7,15,0C0h,'Q',1,0
        db      1,0,0,0,0C0h,27,1,0   ; Esc:  keyboard only
fields_end label byte
s_place db      1Bh,0,3,0,0C2h,1,62
s_show  db      1Bh,0,1,0,0D4h
s_top   db      1Bh,10h,1,0,0C2h
s_reset db      1Bh,0,1,0,0FEh
field   db      0
own     dd      0
win     dd      0
kbd     dd      0
line    db      80 dup (0)
dvp     db      DVPSIZE dup (0)

        end     start
