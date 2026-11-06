; SPDX-License-Identifier: GPL-3.0-or-later
; SPX (measurement and tests/qemu):  SPXPRB file S|R [n] [node]
;   SPX there (IPX function 10h, "spx cc"), socket 4646h opened, "open cc".
;   R:  four LISTEN FOR SEQUENCED PACKET with an ESR, then LISTEN FOR
;   CONNECTION; "conn cc" when one is there.  Each packet "r N cc esr E"
;   (its number, completion code, the ESRs run so far), its listen posted
;   again; the end after n packets and the sender's termination ("term"),
;   180 s or a key "x".  Then "end N esr E bad B term T" (B:  ESR calls
;   whose ECB was not ours) and the socket closed.
;   S:  to node (12 hex digits, the receiver's on the local net):
;   ESTABLISH CONNECTION ("est cc" when called, "c cc" when done), n
;   packets (default 20) one per half second ("s N cc" each), TERMINATE
;   CONNECTION ("t cc").
;   "spxprb ready" on the screen.  Each line is committed to the file at
;   once.

        .model tiny
        .386
        .code
        org     100h

SOCKET  equ     4646h                 ; (as IPX wants it:  high byte first)
NLISTEN equ     4
ECBSIZE equ     42                    ; ECB with one fragment (24h + 6)
SPXHDR  equ     42
PKTSIZE equ     SPXHDR + 16           ; SPX header and the data

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
@@:     lodsb                         ; n
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
        jb      args_n
        cmp     al,'9'
        jbe     @B
args_n: cmp     al,' '                ; node
        jne     args_done
@@:     lodsb
        cmp     al,' '
        je      @B
        dec     si
        mov     di,offset node
        mov     cx,6
@@:     call    hexdig
        shl     al,4
        mov     ah,al
        call    hexdig
        or      al,ah
        stosb
        loop    @B
args_done:
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line

        mov     ax,7A00h              ; IPX there?
        int     2Fh
        cmp     al,0FFh
        je      @F
        mov     si,offset t_noipx
        call    puts
        call    putnl
        call    flush
        jmp     done
@@:     mov     word ptr ipx,di
        mov     word ptr ipx+2,es
        push    ds
        pop     es
        mov     al,0                  ; SPX INSTALLED?
        mov     bx,10h
        call    ipxcall
        mov     di,offset line
        mov     rc,al
        mov     si,offset t_spx
        call    puts
        mov     al,rc
        call    puthex8
        call    putnl
        cmp     rc,0FFh
        je      @F
        call    flush
        jmp     done
@@:     mov     al,0                  ; OPEN SOCKET
        mov     dx,SOCKET
        mov     bx,00h
        call    ipxcall
        push    ax
        mov     si,offset t_open
        call    puts
        pop     ax
        call    puthex8
        call    putnl
        call    flush
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
        xor     bx,bx                 ; the listens (both sides:  SPX
@@:     call    post                  ; wants some before a connection)
        inc     bx
        cmp     bx,NLISTEN
        jb      @B
        mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        add     eax,3276              ; 180 s
        mov     deadline,eax
        push    ds
        pop     es
        cmp     mode,'S'
        je      sender
        jmp     receiver

; S:  connect, n packets, terminate
sender: mov     si,offset node        ; the receiver's address
        mov     di,offset esthdr+10
        movsw
        movsw
        movsw
        mov     word ptr esthdr+16,SOCKET
        mov     si,offset estecb
        mov     ax,offset esthdr
        call    ecbset
        mov     si,offset node        ; immediate address:  the same net
        mov     di,offset estecb+1Ch
        movsw
        movsw
        movsw
        mov     si,offset estecb
        mov     ax,0                  ; ESTABLISH CONNECTION (default
        mov     bx,11h                ; retries, no watchdog)
        call    ipxcall
        mov     conn,dx
        mov     rc,al
        mov     di,offset line
        mov     si,offset t_est
        call    puts
        mov     al,rc
        call    puthex8
        call    putnl
        call    flush
        cmp     rc,0
        jnz     s_end
        mov     si,offset estecb
        call    waitecb
        mov     di,offset line
        mov     si,offset t_c
        call    puts
        mov     al,byte ptr estecb+9
        call    puthex8
        call    putnl
        call    flush
        cmp     byte ptr estecb+9,0
        jne     s_end
        mov     seq,0
s_next: mov     ax,seq
        cmp     ax,count
        jae     s_term
        inc     seq
        mov     ax,seq
        mov     word ptr pkt+SPXHDR+6,ax ; "SPXPRB" and the number
        mov     byte ptr pkt+31,0     ; datastream type
        mov     si,offset sendecb
        mov     ax,offset pkt
        call    ecbset
        mov     word ptr sendecb+28h,PKTSIZE
        mov     dx,conn
        mov     bx,16h                ; SEND SEQUENCED PACKET
        call    ipxcall
        mov     si,offset sendecb
        call    waitecb
        mov     di,offset line
        mov     si,offset t_s
        call    puts
        mov     ax,seq
        call    putdec
        mov     al,' '
        stosb
        mov     al,byte ptr sendecb+9
        call    puthex8
        call    putnl
        call    flush
        call    halfsec
        jmp     s_next
s_term: mov     si,offset termecb
        mov     ax,offset termhdr
        call    ecbset
        mov     dx,conn
        mov     bx,13h                ; TERMINATE CONNECTION
        call    ipxcall
        mov     si,offset termecb
        call    waitecb
        mov     di,offset line
        mov     si,offset t_t
        call    puts
        mov     al,byte ptr termecb+9
        call    puthex8
        call    putnl
        call    flush
s_end:  call    cancels
        jmp     closeit

; R:  the connection, then the packets
receiver:
        mov     si,offset connecb
        mov     ax,offset connhdr
        call    ecbset
        mov     ax,0                  ; LISTEN FOR CONNECTION
        mov     bx,12h
        call    ipxcall
        mov     si,offset connecb
        call    waitecb
        mov     di,offset line
        mov     si,offset t_conn
        call    puts
        mov     al,byte ptr connecb+9
        call    puthex8
        call    putnl
        call    flush
r_loop: xor     bx,bx
r_ecb:  call    ecbof
        cmp     byte ptr [si+8],0     ; done?
        jne     r_ecb_next
        push    bx
        mov     bp,[si+24h]           ; its packet
        cmp     byte ptr [bp+31],0FEh ; the end of the connection?
        je      r_term
        cmp     byte ptr [si+9],0ECh  ; (terminated by the other side)
        jne     @F
r_term:
        inc     term
        pop     bx
        jmp     r_end
@@:     mov     di,offset line
        mov     si,offset t_r
        call    puts
        pop     bx
        push    bx
        call    ecbof
        mov     bp,[si+24h]
        mov     ax,[bp+SPXHDR+6]
        call    putdec
        mov     al,' '
        stosb
        mov     al,[si+9]
        call    puthex8
        mov     si,offset t_esr
        call    puts
        mov     ax,esrs
        call    putdec
        call    putnl
        call    flush
        pop     bx
        inc     got
        call    post
r_ecb_next:
        inc     bx
        cmp     bx,NLISTEN
        jb      r_ecb
        mov     bx,0Ah                ; RELINQUISH CONTROL
        call    ipxcall
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
r_end:  call    cancels
        mov     di,offset line
        mov     si,offset t_end
        call    puts
        mov     ax,got
        call    putdec
        mov     si,offset t_esr
        call    puts
        mov     ax,esrs
        call    putdec
        mov     si,offset t_bad
        call    puts
        mov     ax,bad
        call    putdec
        mov     si,offset t_term
        call    puts
        mov     ax,term
        call    putdec
        call    putnl
        call    flush

closeit:
        mov     dx,SOCKET             ; CLOSE SOCKET
        mov     bx,01h
        call    ipxcall
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

; a hex digit at SI into AL
hexdig  proc near
        lodsb
        cmp     al,'9'
        jbe     @F
        and     al,0DFh
        sub     al,'A' - 10
        ret
@@:     sub     al,'0'
        ret
hexdig  endp

; IPX's function BX (it keeps no register):  AX, DX back, the others kept
ipxcall proc near
        push    bx
        push    cx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        call    dword ptr cs:ipx
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     cx
        pop     bx
        cld
        ret
ipxcall endp

; ECB at SI cleared:  a no-op ESR, the socket, one fragment AX (a header)
ecbset  proc near
        push    di
        push    cx
        push    ax
        mov     di,si
        mov     cx,ECBSIZE
        xor     al,al
        rep     stosb
        pop     ax
        mov     word ptr [si+4],offset noesr
        mov     word ptr [si+6],cs
        mov     word ptr [si+0Ah],SOCKET
        mov     word ptr [si+22h],1
        mov     [si+24h],ax
        mov     [si+26h],ds
        mov     word ptr [si+28h],SPXHDR
        pop     cx
        pop     di
        ret
ecbset  endp

; until the ECB at SI is done (or the deadline)
waitecb proc near
@@:     cmp     byte ptr [si+8],0
        je      @F
        push    si
        mov     bx,0Ah
        call    ipxcall
        pop     si
        push    es
        mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        pop     es
        cmp     eax,deadline
        jb      @B
@@:     ret
waitecb endp

; the listens cancelled
cancels proc near
        xor     bx,bx
@@:     push    bx
        call    ecbof
        mov     bx,06h                ; CANCEL EVENT
        call    ipxcall
        pop     bx
        inc     bx
        cmp     bx,NLISTEN
        jb      @B
        ret
cancels endp

; SI = listen ECB BX (0..NLISTEN-1)
ecbof   proc near
        mov     ax,ECBSIZE
        mul     bx
        add     ax,offset lecb
        mov     si,ax
        ret
ecbof   endp

; listen BX posted:  its ECB with the ESR, one fragment (its packet)
post    proc near
        push    bx
        call    ecbof
        mov     ax,PKTSIZE
        mul     bx
        add     ax,offset lpkt
        call    ecbset
        mov     word ptr [si+28h],PKTSIZE
        mov     word ptr [si+4],offset esr
        mov     word ptr [si+6],cs
        mov     bx,17h                ; LISTEN FOR SEQUENCED PACKET
        call    ipxcall
        pop     bx
        ret
post    endp

; the ESR (IPX:  far, ES:SI the ECB, interrupts off, DS not ours)
esr     proc far
        push    ax
        push    bx
        mov     ax,es
        mov     bx,cs
        cmp     ax,bx
        jne     esr_bad
        cmp     si,offset lecb
        jb      esr_bad
        cmp     si,offset lecb + NLISTEN * ECBSIZE
        jae     esr_bad
        inc     word ptr cs:esrs
        pop     bx
        pop     ax
        ret
esr_bad:
        inc     word ptr cs:bad
        pop     bx
        pop     ax
        ret
esr     endp

noesr   proc far
        ret
noesr   endp

; about half a second (9 ticks)
halfsec proc near
        push    es
        mov     ax,40h
        mov     es,ax
        mov     eax,es:[6Ch]
        add     eax,9
@@:     push    eax
        mov     bx,0Ah
        call    ipxcall
        pop     eax
        cmp     es:[6Ch],eax
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

t_noipx db      'no ipx',0
t_spx   db      'spx ',0
t_open  db      'open ',0
t_est   db      'est ',0
t_c     db      'c ',0
t_conn  db      'conn ',0
t_s     db      's ',0
t_t     db      't ',0
t_r     db      'r ',0
t_esr   db      ' esr ',0
t_end   db      'end ',0
t_bad   db      ' bad ',0
t_term  db      ' term ',0
t_ready db      'spxprb ready',13,10,'$'
utext   db      'SPXPRB file S|R [n] [node]',13,10,'$'
mode    db      0
rc      db      0
count   dw      20
seq     dw      0
got     dw      0
esrs    dw      0
bad     dw      0
term    dw      0
conn    dw      0
handle  dw      0
deadline dd     0
ipx     dd      0
node    db      6 dup (0FFh)
esthdr  db      5 dup (0), 5, SPXHDR - 6 dup (0) ; (packet type SPX)
termhdr db      5 dup (0), 5, SPXHDR - 6 dup (0)
connhdr db      5 dup (0), 5, SPXHDR - 6 dup (0)
pkt     db      5 dup (0), 5, SPXHDR - 6 dup (0)
        db      'SPXPRB', 0, 0        ; the data:  "SPXPRB", the number
        db      8 dup (0)
estecb  db      ECBSIZE dup (0)
termecb db      ECBSIZE dup (0)
connecb db      ECBSIZE dup (0)
sendecb db      ECBSIZE dup (0)
lecb    db      NLISTEN * ECBSIZE dup (0)
lpkt    db      NLISTEN * PKTSIZE dup (0)
fname   db      80 dup (0)
line    db      200 dup (?)

        end     start
