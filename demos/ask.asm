; SPDX-License-Identifier: GPL-3.0-or-later
; ASK:  the client of SERVE (clean-room demo of the DESQview API, written
; for Open MaxView).
;   It looks for the mailbox named "MaxView demo server" (FINDMAIL, AX=
;   DE0Eh), waiting (PAUSE) until SERVE runs; then each line typed is sent
;   to it (ADDTO of the mailbox) and the answer read from the own mailbox
;   is shown.  An empty line ends.

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
        mov     waited,0
find:   push    ds                    ; FINDMAIL:  DS:SI the mailbox
        push    ds
        pop     es
        mov     di,offset mbname
        mov     cx,mbname_len
        mov     ax,0DE0Eh
        int     15h
        mov     ax,ds
        pop     ds
        or      bx,bx
        jnz     found
        cmp     waited,0
        jne     @F
        mov     waited,1
        mov     dx,offset t_wait
        mov     ah,9
        int     21h
@@:     mov     ax,1000h              ; PAUSE, then again
        int     15h
        jmp     find
found:  mov     word ptr server,si
        mov     word ptr server+2,ax
        mov     dx,offset t_ready
        mov     ah,9
        int     21h

ask:    mov     dx,offset t_prompt
        mov     ah,9
        int     21h
        mov     inbuf,LINE_SIZE       ; a line (DOS buffered input)
        mov     dx,offset inbuf
        mov     ah,0Ah
        int     21h
        mov     dx,offset t_crlf
        mov     ah,9
        int     21h
        movzx   cx,inbuf+1
        jcxz    done
        push    ds                    ; ADDTO the server:  the address,
        push    offset inbuf + 2      ; the length, status 1, the mailbox
        push    0                     ; on top
        push    cx
        push    0
        push    1
        push    word ptr server+2
        push    word ptr server
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        mov     ax,1200h              ; READ of the own mailbox (BL=03h):
        mov     bx,0403h              ; the length (on top), the address
        int     15h
        pop     cx
        pop     ax
        pop     si
        pop     fs
        jcxz    ask
@@:     mov     dl,fs:[si]            ; the answer
        inc     si
        mov     ah,2
        int     21h
        loop    @B
        mov     dx,offset t_crlf
        mov     ah,9
        int     21h
        jmp     ask
done:   mov     ax,4C00h
        int     21h

LINE_SIZE equ   78
t_nodv  db      'ASK needs DESQview or Open MaxView.',13,10,'$'
t_wait  db      'Waiting for SERVE...',13,10,'$'
t_ready db      'SERVE found.  Type a line (an empty one ends).',13,10,'$'
t_prompt db     '> $'
t_crlf  db      13,10,'$'
mbname  db      'MaxView demo server'
mbname_len equ  $ - mbname
waited  db      0
server  dd      0
inbuf   db      LINE_SIZE, 0, LINE_SIZE dup (0)

        end     start
