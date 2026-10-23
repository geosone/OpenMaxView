; SPDX-License-Identifier: GPL-3.0-or-later
; WORMS:  worms crawling through the own window, each one a subtask
; (clean-room demo of the DESQview API, written for Open MaxView).
;   The main task reads keys:  N a new worm (NEW 08h with an entry point
;   here:  a subtask of this task, on a stack of its own), K kills the
;   newest one (FREE of its handle), S stops and starts them all, C clears
;   the window, Q ends (FREE of all of them).
;   A worm has a timer of its own (NEW 0Bh, ADDTO of hundredths, READ:
;   waits for it); each step is one WRITE of a stream to its task's window
;   (C0h row, column; E2h colour; 61h one character):  one call, so worms
;   moving at the same time never mix their streams.

        .model tiny
        .386
        .code
        org 100h

WORMS   equ     4                     ; at most
WLEN    equ     8                     ; cells of a worm
TOP     equ     2                     ; the field:  rows TOP..BOTTOM,
BOTTOM  equ     21                    ; columns 0..RIGHT
RIGHT   equ     77
STACKW  equ     192                   ; a worm's stack (words)

WSTATE    struc
W_HAND  dw      ?                     ; its handle's segment (0:  free)
W_TIMER dd      ?
W_ROW   db      ?                     ; the head
W_COL   db      ?
W_DROW  db      ?                     ; its direction (-1, 0, 1)
W_DCOL  db      ?
W_ATTR  db      ?
W_SEED  dw      ?
W_TAIL  dw      ?                     ; the oldest of W_CELLS
W_CELLS dw      WLEN dup (?)          ; row, column of each cell (0:  none)
WSTATE    ends

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
        mov     si,offset s_phys      ; physical colours
        call    ownwrite
        call    clear

keys:   mov     ah,0                  ; a key (under DESQview the other
        int     16h                   ; tasks run meanwhile)
        and     al,0DFh               ; (upper case)
        cmp     al,'N'
        je      key_new
        cmp     al,'K'
        je      key_kill
        cmp     al,'S'
        je      key_stop
        cmp     al,'C'
        je      key_clear
        cmp     al,'Q'
        je      key_quit
        cmp     al,1Bh and 0DFh       ; (Esc)
        je      key_quit
        jmp     keys

key_new:
        call    new_worm
        jmp     keys
key_kill:
        mov     bx,offset wtab + (WORMS - 1) * (size WSTATE)
        mov     cx,WORMS
@@:     cmp     [bx].W_HAND,0         ; the newest one alive
        jne     @F
        sub     bx,size WSTATE
        loop    @B
        jmp     keys
@@:     call    kill_worm
        jmp     keys
key_stop:
        xor     stopped,1
        jmp     keys
key_clear:
        call    clear
        jmp     keys

key_quit:
        mov     bx,offset wtab
        mov     cx,WORMS
@@:     cmp     [bx].W_HAND,0
        je      quit_next
        push    cx
        call    kill_worm
        pop     cx
quit_next:
        add     bx,size WSTATE
        loop    @B
        mov     si,offset s_erase
        call    ownwrite
        mov     ax,4C00h
        int     21h

; Blanks in colour 07h on rows 1-24 (as the worms clear their tails:  an
; ERASE takes the window's colour), the help line on row 0
clear   proc near
        mov     si,offset s_field
        call    ownwrite
        mov     si,offset s_help
        call    ownwrite
        ret
clear   endp

; A new worm in a free slot (none:  nothing)
new_worm proc near
        mov     bx,offset wtab
        mov     cx,WORMS
@@:     cmp     [bx].W_HAND,0
        je      @F
        add     bx,size WSTATE
        loop    @B
        ret
@@:     mov     ax,WORMS              ; its number 0..WORMS-1
        sub     ax,cx
        mov     si,ax
        mov     al,colours[si]
        mov     [bx].W_ATTR,al
        mov     ax,si                 ; a start in its own quarter
        imul    ax,ax,(BOTTOM - TOP) / WORMS
        add     al,TOP + 1
        mov     [bx].W_ROW,al
        mov     ax,si
        imul    ax,ax,RIGHT / WORMS
        add     al,8
        mov     [bx].W_COL,al
        mov     [bx].W_DROW,0
        mov     [bx].W_DCOL,1
        in      al,40h                ; some randomness
        mov     ah,al
        add     ax,si
        or      ax,1
        mov     [bx].W_SEED,ax
        mov     [bx].W_TAIL,0
        push    cx
        push    bx
        lea     di,[bx].W_CELLS
        push    ds
        pop     es
        xor     ax,ax
        mov     cx,WLEN
        cld
        rep     stosw
        pop     bx
        pop     cx
        mov     ax,si                 ; its stack:  the top of its part
        inc     ax
        imul    ax,ax,STACKW * 2
        add     ax,offset stacks
        mov     newstack,ax
        mov     newworm,bx
        mov     started,0
        xor     ax,ax                 ; NEW 08h:  no title, no rows and
        mov     cx,10                 ; columns (no window), no buffer,
@@:     push    ax                    ; the default stack, the own task,
        loop    @B                    ; the entry point
        mov     ax,0FFFFh
        mov     cx,4
@@:     push    ax
        loop    @B
        push    cs
        push    offset crawler
        mov     ax,1200h
        mov     bx,0108h
        int     15h
        pop     ax                    ; its handle (offset 0)
        pop     ax
        mov     bx,newworm
        mov     [bx].W_HAND,ax
        or      ax,ax
        jz      new_ret
@@:     cmp     started,0             ; until it has its stack
        jne     new_ret
        mov     ax,1000h              ; PAUSE
        int     15h
        jmp     @B
new_ret:
        ret
new_worm endp

; FREE of worm BX (its timer, the subtask)
kill_worm proc near
        mov     si,bx
        push    word ptr [bx].W_TIMER+2
        push    word ptr [bx].W_TIMER
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     bx,si
        push    [bx].W_HAND
        push    0
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        mov     bx,si
        mov     [bx].W_HAND,0
        ret
kill_worm endp

; A worm (the subtask's entry point:  DX:CX its task's handle).
crawler proc far
        push    cs
        pop     ds
        push    cs
        pop     es
        mov     bx,newworm
        mov     ax,cs                 ; its own stack (the default one is
        cli                           ; small)
        mov     ss,ax
        mov     sp,newstack
        sti
        mov     di,bx
        mov     ax,1200h              ; NEW timer (its handle on the stack)
        mov     bx,010Bh
        int     15h
        mov     bx,di
        pop     word ptr [bx].W_TIMER
        pop     word ptr [bx].W_TIMER+2
        mov     started,1
crawl:  push    bx
        push    0                     ; ADDTO the timer:  1/10 s, READ
        push    10                    ; (waits for it)
        push    word ptr [bx].W_TIMER+2
        push    word ptr [bx].W_TIMER
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        pop     bx
        push    bx
        push    word ptr [bx].W_TIMER+2
        push    word ptr [bx].W_TIMER
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        add     sp,4                  ; (the time)
        pop     bx
        cmp     stopped,0
        jne     crawl
        call    step
        jmp     crawl
crawler endp

; One step of worm BX:  a new direction now and then, off the edges, the
; tail cell cleared, the new head drawn
step    proc near
        mov     ax,[bx].W_SEED        ; (a linear congruential generator)
        imul    ax,ax,25173
        add     ax,13849
        mov     [bx].W_SEED,ax
        test    ah,0E0h               ; 1 in 8:  a turn
        jnz     step_go
        mov     al,ah
        and     al,3
        mov     [bx].W_DROW,0
        mov     [bx].W_DCOL,0
        cmp     al,0
        jne     @F
        mov     [bx].W_DROW,-1
@@:     cmp     al,1
        jne     @F
        mov     [bx].W_DROW,1
@@:     cmp     al,2
        jne     @F
        mov     [bx].W_DCOL,-1
@@:     cmp     al,3
        jne     step_go
        mov     [bx].W_DCOL,1
step_go:
        mov     al,[bx].W_ROW
        add     al,[bx].W_DROW
        cmp     al,TOP
        jl      step_vrev
        cmp     al,BOTTOM
        jle     @F
step_vrev:
        neg     [bx].W_DROW
        mov     al,[bx].W_ROW
        add     al,[bx].W_DROW
@@:     mov     [bx].W_ROW,al
        mov     al,[bx].W_COL
        add     al,[bx].W_DCOL
        cmp     al,0
        jl      step_hrev
        cmp     al,RIGHT
        jle     @F
step_hrev:
        neg     [bx].W_DCOL
        mov     al,[bx].W_COL
        add     al,[bx].W_DCOL
@@:     mov     [bx].W_COL,al
        mov     si,[bx].W_TAIL        ; the tail cell:  cleared
        shl     si,1
        mov     ax,[bx+si].W_CELLS
        or      ax,ax
        jz      @F
        mov     cell_rc,ax
        mov     cell_attr,07h
        mov     cell_char,' '
        call    cellwrite
@@:     mov     al,[bx].W_ROW         ; the head:  there now
        mov     ah,[bx].W_COL
        mov     [bx+si].W_CELLS,ax
        mov     cell_rc,ax
        mov     al,[bx].W_ATTR
        mov     cell_attr,al
        mov     cell_char,0DBh
        call    cellwrite
        mov     ax,[bx].W_TAIL
        inc     ax
        cmp     ax,WLEN
        jb      @F
        xor     ax,ax
@@:     mov     [bx].W_TAIL,ax
        ret
step    endp

; WRITE of the cell stream (cell_rc, cell_attr, cell_char) to the window;
; BX kept
cellwrite proc near
        push    bx
        push    si
        push    ds
        push    offset s_cell
        push    0
        push    s_cell_len
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        pop     si
        pop     bx
        ret
cellwrite endp

; WRITE of the stream SI (word length, then the stream) to the own window
ownwrite proc near
        push    ds
        lea     ax,[si+2]
        push    ax
        push    0
        push    word ptr [si]
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        ret
ownwrite endp

t_nodv  db      'WORMS needs DESQview or Open MaxView.',13,10,'$'
s_phys  dw      s_phys_e - $ - 2      ; physical colours
        db      1Bh,0
        dw      1
        db      0DBh
s_phys_e label byte
s_erase dw      s_erase_e - $ - 2     ; ERASE
        db      1Bh,0
        dw      1
        db      0E3h
s_erase_e label byte
s_field dw      s_field_e - $ - 2     ; rows 1-24:  80 blanks each
        db      1Bh,0
        dw      s_field_e - $ - 2
        db      0E2h,07h
row     = 1
        rept    24
        db      0C0h,row,0,00h,00h,10h ; (00h-1Fh:  1-32 blanks, 0:  32)
row     = row + 1
        endm
s_field_e label byte
s_help  dw      s_help_e - $ - 2      ; row 0:  the keys
        db      1Bh,0
        dw      s_help_e - $ - 2
        db      0C0h,0,0,0E2h,70h,60h + help1_len ; (60h-7Fh:  1-32
help1   db      ' WORMS  N new   K kill   S stop' ; characters)
help1_len equ   $ - help1
        db      60h + help2_len
help2   db      '/go   C clear   Q quit '
help2_len equ   $ - help2
s_help_e label byte
s_cell  db      1Bh,0                 ; one cell
        dw      s_cell_e - $ - 2
        db      0C0h
cell_rc dw      0
        db      0E2h
cell_attr db    07h
        db      61h
cell_char db    ' '
s_cell_e label byte
s_cell_len equ  $ - s_cell
colours db      0Ah,0Ch,0Eh,0Bh       ; the worms'
own     dd      0
stopped db      0
started db      0
newworm dw      0
newstack dw     0
wtab    WSTATE    WORMS dup (<>)
stacks  dw      WORMS * STACKW dup (0)

        end     start
