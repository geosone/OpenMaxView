; SPDX-License-Identifier: GPL-3.0-or-later
; SERVE:  a server task (clean-room demo of the DESQview API, written for
; Open MaxView); ASK is its client.
;   It names its mailbox "MaxView demo server" (SETNAME), so that clients
;   find it (FINDMAIL), and waits on its OBJECTQ for the mailbox or a timer:
;   each second the clock on its first line is set from the timer (READ of
;   a timer:  the time it expired at); each message is answered to the
;   sender's own mailbox (ADDR, then BL=02h) in capitals, and counted.
;   Ctrl+C or the end of the task ends it.

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
        mov     ax,0DE0Eh             ; a server already there?
        push    ds
        push    ds
        pop     es
        mov     di,offset mbname
        mov     cx,mbname_len
        int     15h
        pop     ds
        or      bx,bx
        jz      alone
        mov     dx,offset t_twice
        mov     ah,9
        int     21h
        mov     ax,4C01h
        int     21h
alone:
        mov     ax,1200h              ; the own window and mailbox
        mov     bx,0001h
        int     15h
        pop     word ptr win
        pop     word ptr win+2
        mov     ax,1200h
        mov     bx,0003h
        int     15h
        pop     word ptr mbox
        pop     word ptr mbox+2
        push    ds                    ; SETNAME:  the address, the length,
        push    offset mbname         ; the mailbox on top
        push    0
        push    mbname_len
        push    word ptr mbox+2
        push    word ptr mbox
        mov     ax,1200h
        mov     bx,1100h
        int     15h
        mov     ax,1200h              ; NEW timer
        mov     bx,010Bh
        int     15h
        pop     word ptr tim
        pop     word ptr tim+2

        push    word ptr win+2        ; ERASE, the text
        push    word ptr win
        mov     ax,1200h
        mov     bx,0E00h
        int     15h
        mov     si,offset t_head
        mov     cx,t_head_len
        call    winput
        call    show_count
        call    one_second

next:   mov     ax,1200h              ; OBJECTQ READ:  who has input?
        mov     bx,0407h
        int     15h
        pop     dx
        pop     ax
        cmp     dx,word ptr tim
        jne     mail
        cmp     ax,word ptr tim+2
        jne     mail
        push    word ptr tim+2        ; READ of the timer:  the time
        push    word ptr tim
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     ax
        pop     dx
        call    show_time
        call    one_second
        jmp     next

mail:   push    word ptr mbox+2       ; READ of the mailbox:  the length
        push    word ptr mbox         ; (on top), the message's address
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        pop     cx
        pop     ax
        pop     si
        pop     fs
        cmp     cx,REPLY_SIZE
        jbe     @F
        mov     cx,REPLY_SIZE
@@:     mov     reply_len,cx
        mov     di,offset reply       ; in capitals
        jcxz    upper_done
@@:     mov     al,fs:[si]
        inc     si
        cmp     al,'a'
        jb      upper_store
        cmp     al,'z'
        ja      upper_store
        sub     al,20h
upper_store:
        mov     [di],al
        inc     di
        loop    @B
upper_done:
        push    word ptr mbox+2       ; ADDR:  the sender (a task)
        push    word ptr mbox
        mov     ax,1200h
        mov     bx,0300h
        int     15h
        pop     word ptr sender
        pop     word ptr sender+2
        push    ds                    ; ADDTO its own mailbox (BL=02h:  the
        push    offset reply          ; task's in place of the task):  the
        push    0                     ; address, the length, status 1
        push    reply_len
        push    0
        push    1
        push    word ptr sender+2
        push    word ptr sender
        mov     ax,1200h
        mov     bx,0A02h
        int     15h
        inc     count
        call    show_count
        jmp     next

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

; DX:AX hundredths since midnight as hh:mm:ss at row 0, column 13.
show_time proc near
        mov     bx,6000               ; the minutes (below 1440), the
        div     bx                    ; hundredths in the minute
        push    ax
        mov     ax,dx
        xor     dx,dx
        mov     bx,100
        div     bx
        mov     cl,al                 ; the seconds
        pop     ax
        xor     dx,dx
        mov     bx,60
        div     bx                    ; DX the minutes, AX the hours
        mov     di,offset s_clock_digits
        call    two
        inc     di
        mov     ax,dx
        call    two
        inc     di
        mov     al,cl
        xor     ah,ah
        call    two
        mov     si,offset s_clock
        call    winwrite
        ret
two:    push    dx
        mov     dl,10
        div     dl
        add     ax,'00'
        mov     [di],ax
        add     di,2
        pop     dx
        ret
show_time endp

; The count at row 0, column 33.
show_count proc near
        mov     ax,count
        mov     di,offset s_count_digits + 4
        mov     cx,5
        mov     bx,10
@@:     xor     dx,dx
        div     bx
        add     dl,'0'
        mov     [di],dl
        dec     di
        loop    @B
        mov     si,offset s_count
        call    winwrite
        ret
show_count endp

; CX characters at SI to the own window.
winput  proc near
        push    ds
        push    si
        push    0
        push    cx
        push    word ptr win+2
        push    word ptr win
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        ret
winput  endp

; The stream at SI (1Bh, type, word length, ...) to the own window.
winwrite proc near
        mov     cx,word ptr [si+2]
        add     cx,4
        jmp     winput
winwrite endp

REPLY_SIZE equ  80
t_nodv  db      'SERVE needs DESQview or Open MaxView.',13,10,'$'
t_twice db      'SERVE is already running.',13,10,'$'
mbname  db      'MaxView demo server'
mbname_len equ  $ - mbname
t_head  db      'SERVE  time  --:--:--  requests  00000',13,10
        db      'Start ASK in another window:  it sends lines here and',13,10
        db      'shows them back in capitals.',13,10
t_head_len equ  $ - t_head
s_clock db      1Bh,0,12,0,0C0h,0,13,68h
s_clock_digits db '00:00:00'
s_count db      1Bh,0,9,0,0C0h,0,33,65h
s_count_digits db '00000'
count   dw      0
reply_len dw    0
win     dd      0
mbox    dd      0
tim     dd      0
sender  dd      0
reply   db      REPLY_SIZE dup (0)

        end     start
