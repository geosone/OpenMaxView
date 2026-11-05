; SPDX-License-Identifier: GPL-3.0-or-later
; NETBIOS (measurement and tests/qemu):  NBPRB file S|R [n]
;   INT 5Ch there ("nb rc":  an invalid command's code, 03h), ADD NAME
;   NBPRB-S / NBPRB-R ("name rc num").
;   S:  n broadcast datagrams (default 20), one per half second, "s N rc"
;   each (SEND BROADCAST DATAGRAM, wait);
;   R:  a no-wait RECEIVE BROADCAST DATAGRAM with a POST routine (one:
;   every pending one gets each broadcast); each done "r N rc post P" (its
;   number, code, the POSTs run so far), posted again; the end after n
;   datagrams, 180 s or a key "x" (CANCEL).  Then "end N post P bad B" (B:
;   POST calls whose NCB was not ours) and DELETE NAME.  "nbprb ready" on
;   the screen.  Each line is committed to the file at once.

        .model tiny
        .386
        .code
        org     100h

NRECV   equ     1
NCBSZ   equ     64
DGSIZE  equ     16

start:
        mov     si,81h
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
        dec     si
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        and     al,0DFh
        mov     mode,al
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,'0'
        jb      args_done
        cmp     al,'9'
        ja      args_done
        mov     count,0
@@:     sub     al,'0'
        cbw
        xchg    ax,count
        mov     dx,10
        mul     dx
        add     count,ax
        lodsb
        cmp     al,'0'
        jb      args_done
        cmp     al,'9'
        jbe     @B
args_done:
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line

        mov     byte ptr ncb,7Fh      ; there?  (an invalid command)
        call    netbios
        mov     rc,al
        mov     si,offset t_nb
        call    puts
        mov     al,rc
        call    puthex8
        call    putnl
        call    flush
        cmp     rc,03h
        je      @F
        jmp     done
@@:     mov     al,'S'                ; ADD NAME
        cmp     mode,'S'
        je      @F
        mov     al,'R'
@@:     mov     byte ptr myname+6,al
        call    ncbclear
        mov     byte ptr ncb,30h
        mov     si,offset myname
        mov     di,offset ncb+26
        mov     cx,16
        rep     movsb
        call    netbios
        push    ax
        mov     di,offset line
        mov     si,offset t_name
        call    puts
        pop     ax
        call    puthex8
        mov     al,' '
        stosb
        mov     al,byte ptr ncb+3
        mov     num,al
        call    puthex8
        call    putnl
        call    flush
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
        cmp     mode,'S'
        je      sender
        jmp     receiver

; S:  n broadcast datagrams
sender: mov     seq,0
s_next: mov     ax,seq
        cmp     ax,count
        jae     s_end
        inc     seq
        mov     ax,seq
        mov     word ptr dgram+6,ax
        call    ncbclear
        mov     byte ptr ncb,22h      ; SEND BROADCAST DATAGRAM
        mov     al,num
        mov     byte ptr ncb+3,al
        mov     word ptr ncb+4,offset dgram
        mov     word ptr ncb+6,ds
        mov     word ptr ncb+8,DGSIZE
        call    netbios
        push    ax
        mov     di,offset line
        mov     si,offset t_s
        call    puts
        mov     ax,seq
        call    putdec
        mov     al,' '
        stosb
        pop     ax
        call    puthex8
        call    putnl
        call    flush
        call    halfsec
        jmp     s_next
s_end:  jmp     closeit

; R:  no-wait receives with the POST routine
receiver:
        xor     bx,bx
@@:     call    post
        inc     bx
        cmp     bx,NRECV
        jb      @B
        mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        add     eax,3276              ; 180 s
        mov     deadline,eax
        push    ds
        pop     es
r_loop: xor     bx,bx
r_ncb:  call    ncbof
        cmp     byte ptr [si+49],0FFh ; done?
        je      r_ncb_next
        push    bx
        mov     di,offset line
        push    si
        mov     si,offset t_r
        call    puts
        pop     si
        mov     bp,[si+4]             ; its datagram
        mov     ax,[bp+6]
        call    putdec
        mov     al,' '
        stosb
        mov     al,[si+1]
        call    puthex8
        mov     si,offset t_post
        call    puts
        mov     ax,posts
        call    putdec
        call    putnl
        call    flush
        pop     bx
        inc     got
        call    post
        mov     ax,got
        cmp     ax,count
        jae     r_end
r_ncb_next:
        inc     bx
        cmp     bx,NRECV
        jb      r_ncb
        mov     ah,1
        int     16h
        jz      @F
        xor     ah,ah
        int     16h
        cmp     al,'x'
        je      r_end
@@:     mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        push    ds
        pop     es
        cmp     eax,deadline
        jb      r_loop
r_end:  xor     bx,bx                 ; the receives cancelled
@@:     push    bx
        call    ncbof
        cmp     byte ptr [si+49],0FFh
        jne     r_cancel_next
        mov     word ptr cncb+4,si
        mov     word ptr cncb+6,ds
        mov     byte ptr cncb,35h
        push    si
        mov     bx,offset cncb
        int     5Ch
        pop     si
r_cancel_next:
        pop     bx
        inc     bx
        cmp     bx,NRECV
        jb      @B
        mov     di,offset line
        mov     si,offset t_end
        call    puts
        mov     ax,got
        call    putdec
        mov     si,offset t_post
        call    puts
        mov     ax,posts
        call    putdec
        mov     si,offset t_bad
        call    puts
        mov     ax,bad
        call    putdec
        call    putnl
        call    flush

closeit:
        call    ncbclear              ; DELETE NAME
        mov     byte ptr ncb,31h
        mov     si,offset myname
        mov     di,offset ncb+26
        mov     cx,16
        rep     movsb
        call    netbios
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

; INT 5Ch with ncb (wait):  AL its code
netbios proc near
        push    bx
        push    di
        push    si
        push    es
        push    ds
        pop     es
        mov     bx,offset ncb
        int     5Ch
        pop     es
        pop     si
        pop     di
        pop     bx
        cld
        ret
netbios endp

ncbclear proc near
        push    di
        push    cx
        mov     di,offset ncb
        mov     cx,NCBSZ
        xor     al,al
        rep     stosb
        pop     cx
        pop     di
        ret
ncbclear endp

; SI = receive NCB BX (0..NRECV-1)
ncbof   proc near
        mov     ax,NCBSZ
        mul     bx
        add     ax,offset rncb
        mov     si,ax
        ret
ncbof   endp

; receive BX posted (no-wait, the POST routine)
post    proc near
        push    bx
        call    ncbof
        push    si
        mov     di,si
        mov     cx,NCBSZ
        xor     al,al
        rep     stosb
        pop     si
        mov     byte ptr [si],0A3h    ; RECEIVE BROADCAST DATAGRAM, no-wait
        mov     al,num
        mov     [si+3],al
        mov     ax,DGSIZE
        mul     bx
        add     ax,offset rbuf
        mov     [si+4],ax
        mov     [si+6],ds
        mov     word ptr [si+8],DGSIZE
        mov     word ptr [si+44],offset postr
        mov     word ptr [si+46],cs
        mov     bx,si
        int     5Ch
        cld
        pop     bx
        ret
post    endp

; the POST routine (ES:BX the NCB, AL its code; returns with IRET)
postr   proc far
        push    ax
        push    bx
        mov     ax,es
        mov     bx,cs
        cmp     ax,bx
        mov     bx,sp                 ; (BX back from the stack)
        mov     bx,ss:[bx]
        jne     post_bad
        cmp     bx,offset rncb
        jb      post_bad
        cmp     bx,offset rncb + NRECV * NCBSZ
        jae     post_bad
        inc     word ptr cs:posts
        pop     bx
        pop     ax
        iret
post_bad:
        inc     word ptr cs:bad
        pop     bx
        pop     ax
        iret
postr   endp

; about half a second (9 ticks)
halfsec proc near
        push    es
        mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        add     eax,9
@@:     cmp     es:[6Ch],eax
        jb      @B
        pop     es
        ret
halfsec endp

; the line (up to DI) to the file, committed
flush   proc near
        push    ax
        push    bx
        push    cx
        push    dx
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     ah,68h
        mov     bx,handle
        int     21h
        mov     di,offset line
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
flush   endp

puthex8 proc near
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
puthex8 endp

; AX in decimal to DI
putdec  proc near
        push    cx
        push    dx
        mov     cx,10
        xor     dx,dx
        div     cx
        or      ax,ax
        jz      @F
        call    putdec
@@:     mov     al,dl
        add     al,'0'
        stosb
        pop     dx
        pop     cx
        ret
putdec  endp

; the text at SI (0 ends) to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

putnl   proc near
        mov     ax,0A0Dh
        stosw
        ret
putnl   endp

t_nb    db      'nb ',0
t_name  db      'name ',0
t_s     db      's ',0
t_r     db      'r ',0
t_post  db      ' post ',0
t_end   db      'end ',0
t_bad   db      ' bad ',0
t_ready db      'nbprb ready',13,10,'$'
utext   db      'NBPRB file S|R [n]',13,10,'$'
mode    db      0
rc      db      0
num     db      0
count   dw      20
seq     dw      0
got     dw      0
posts   dw      0
bad     dw      0
handle  dw      0
deadline dd     0
myname  db      'NBPRB-?         '
dgram   db      'NBPRB', 0, 0, 0, 8 dup (0)
ncb     db      NCBSZ dup (0)
cncb    db      NCBSZ dup (0)
rncb    db      NRECV * NCBSZ dup (0)
rbuf    db      NRECV * DGSIZE dup (0)
fname   db      80 dup (0)
line    db      200 dup (?)

        end     start
