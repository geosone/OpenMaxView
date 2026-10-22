; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview task mailboxes between two tasks (tests/qemu):
;   IPCPRB S file     the server:  "mine SSSS:OOOO" (HANDLE 03h, its own
;                     mailbox), names it IPCSRV (SETNAME 03h), "named",
;                     waits for a message (READ 03h:  blocks under
;                     DESQview) and writes "got LLLLLLLL PPPPPPPP text"
;                     (the two DWORDs READ leaves, top first, and the
;                     message if the first is its length)
;   IPCPRB C file     the client, 3 s later:  "mine SSSS:OOOO", "find B
;                     SSSS:OOOO" (FINDMAIL IPCSRV), then WRITE of "hello"
;                     to it and "sent", then "me SSSS:OOOO" (HANDLE 01h)
;                     and waits for the answer:  "reply LLLLLLLL text"
;   (the server, after "got":  "from SSSS:OOOO" (ADDR of its mailbox:  the
;   sender) and WRITE 02h of "ok" to that task's mailbox, "replied")
; The two "mine" differ:  a mailbox per task.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     si,81h
@@:     lodsb
        cmp     al,' '
        je      @B
        and     al,0DFh
        mov     role,al
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        mov     di,offset fname
@@:     stosb
        lodsb
        cmp     al,' '
        je      @F
        cmp     al,13
        jne     @B
@@:     mov     byte ptr [di],0
        cmp     role,'S'
        je      @F
        cmp     role,'C'
        jne     usage
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line
        ; own mailbox (HANDLE 03h pushes it)
        mov     si,offset t_mine
        call    puts
        mov     ax,1200h
        mov     bx,0003h
        int     15h
        pop     dx              ; offset
        pop     ax              ; segment
        mov     word ptr own,dx
        mov     word ptr own+2,ax
        call    putptr
        call    putnl
        cmp     role,'C'
        je      client

        ; AT 01h:  10 pushed first, 5 on top, then the cursor:  "at R C"
        push    0
        push    10
        push    0
        push    5
        mov     ax,1200h
        mov     bx,1101h
        int     15h
        mov     ah,3
        xor     bh,bh
        int     10h
        mov     si,offset t_at
        call    puts
        push    dx
        mov     al,dh
        xor     ah,ah
        call    putdec
        mov     al,' '
        stosb
        pop     dx
        mov     al,dl
        xor     ah,ah
        call    putdec
        call    putnl

        ; server:  SETNAME 03h, length pushed first (1) or address first
        ; (2), each checked with FINDMAIL:  "named N" (0:  neither)
        mov     si,offset t_named
        call    puts
        mov     savsp,sp
        push    0
        push    srvlen
        push    ds
        push    offset srvname
        mov     ax,1200h
        mov     bx,1103h
        int     15h
        call    stkdiff
        call    find
        mov     al,'1'
        jnz     @F
        mov     savsp,sp
        push    ds
        push    offset srvname
        push    0
        push    srvlen
        mov     ax,1200h
        mov     bx,1103h
        int     15h
        call    stkdiff
        call    find
        mov     al,'2'
        jnz     @F
        mov     al,'0'
@@:     stosb
        call    putnl
        mov     ax,1200h        ; READ 03h:  wait for a message
        mov     bx,0403h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        pop     word ptr d2
        pop     word ptr d2+2
        mov     si,offset t_got
        call    puts
        mov     eax,d1
        call    puthex32
        mov     al,' '
        stosb
        mov     eax,d2
        call    puthex32
        mov     al,' '
        stosb
        mov     cx,word ptr d1  ; length first:  the text at D2
        cmp     word ptr d1+2,0
        jne     @F
        cmp     cx,40
        ja      @F
        push    ds
        lds     si,d2
        rep     movsb
        pop     ds
@@:     call    putnl
        mov     si,offset t_from        ; ADDR:  who sent it
        call    puts
        push    word ptr own+2
        push    word ptr own
        mov     ax,1200h
        mov     bx,0300h
        int     15h
        pop     dx
        pop     ax
        mov     word ptr sender,dx
        mov     word ptr sender+2,ax
        call    putptr
        call    putnl
        push    ds              ; WRITE 02h:  to the mailbox of that task
        push    offset okmsg
        push    0
        push    okmsg_len
        push    word ptr sender+2
        push    word ptr sender
        mov     ax,1200h
        mov     bx,0502h
        int     15h
        mov     si,offset t_replied
        call    puts
        call    putnl
        jmp     done

client: push    es              ; 3 s first
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,55
        jb      @B
        pop     es
        call    find
        push    ax
        mov     si,offset t_find
        call    puts
        mov     al,'0'
        add     al,bl
        stosb
        mov     al,' '
        stosb
        pop     ax
        call    putptr
        call    putnl
        or      bl,bl
        jz      done
        push    ds              ; WRITE:  address, length, mailbox pushed
        push    offset msg      ; (the mailbox on top)
        push    0
        push    msglen
        push    word ptr mbox+2
        push    word ptr mbox
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        mov     si,offset t_sent
        call    puts
        call    putnl
        mov     si,offset t_me          ; HANDLE 01h
        call    puts
        mov     ax,1200h
        mov     bx,0001h
        int     15h
        pop     dx
        pop     ax
        call    putptr
        call    putnl
        mov     ax,1200h        ; READ 03h:  the answer
        mov     bx,0403h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        pop     word ptr d2
        pop     word ptr d2+2
        mov     si,offset t_reply
        call    puts
        mov     eax,d1
        call    puthex32
        mov     al,' '
        stosb
        mov     cx,word ptr d1
        cmp     word ptr d1+2,0
        jne     @F
        cmp     cx,40
        ja      @F
        push    ds
        lds     si,d2
        rep     movsb
        pop     ds
@@:     call    putnl

done:   mov     ah,3Eh
        mov     bx,handle
        int     21h
        mov     ax,4C00h
        int     21h

usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; FINDMAIL IPCSRV:  BX = 1 (NZ):  found, AX:DX = mbox = the mailbox
find    proc near
        push    di
        mov     di,offset srvname
        mov     cx,srvlen
        push    ds
        push    es
        push    ds
        pop     es
        mov     ax,0DE0Eh
        int     15h
        mov     dx,si
        mov     ax,ds
        pop     es
        pop     ds
        pop     di
        mov     word ptr mbox,dx
        mov     word ptr mbox+2,ax
        or      bx,bx
        ret
find    endp

; "sDDD " (what the call left on the stack beyond savsp, in bytes, - :
; popped) to DI, SP back to savsp
stkdiff proc near
        pop     bp              ; (the return)
        mov     ax,savsp
        sub     ax,sp
        sub     ax,8            ; the 8 bytes pushed
        mov     sp,savsp
        push    bp
        push    ax
        mov     al,'s'
        stosb
        pop     ax
        add     ax,'0'+8
        stosb
        mov     al,' '
        stosb
        ret
stkdiff endp

putdec  proc near
        push    bx
        push    dx
        push    cx
        mov     bx,10
        xor     cx,cx
@@:     xor     dx,dx
        div     bx
        push    dx
        inc     cx
        or      ax,ax
        jnz     @B
@@:     pop     ax
        add     al,'0'
        stosb
        loop    @B
        pop     cx
        pop     dx
        pop     bx
        ret
putdec  endp

; AX:DX (segment, offset) as SSSS:OOOO to DI
putptr  proc near
        call    puthex
        mov     al,':'
        stosb
        mov     ax,dx
        call    puthex
        ret
putptr  endp

puthex32 proc near
        push    eax
        shr     eax,16
        call    puthex
        pop     eax
puthex32 endp                   ; (falls through:  the low word)
puthex  proc near
        push    cx
        mov     cx,4
@@:     rol     ax,4
        push    ax
        and     al,0Fh
        add     al,'0'
        cmp     al,'9'
        jbe     hexok
        add     al,7
hexok:  stosb
        pop     ax
        loop    @B
        pop     cx
        ret
puthex  endp

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file
putnl   proc near
        mov     ax,0A0Dh
        stosw
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     ah,68h          ; commit:  the line is in the file even if
        int     21h             ; DESQview ends the program
        mov     di,offset line
        ret
putnl   endp

utext   db      'IPCPRB S|C file',13,10,'$'
srvname db      'IPCSRV'
srvlen  equ     $ - srvname
msg     db      'hello'
msglen  equ     $ - msg
t_mine  db      'mine ',0
t_at    db      'at ',0
t_named db      'named',0
t_got   db      'got ',0
t_find  db      'find ',0
t_sent  db      'sent',0
t_me    db      'me ',0
t_reply db      'reply ',0
t_from  db      'from ',0
t_replied db    'replied',0
okmsg   db      'ok'
okmsg_len equ   $ - okmsg
own     dd      0
sender  dd      0
role    db      0
handle  dw      0
d1      dd      0
d2      dd      0
mbox    dd      0
savsp   dw      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
