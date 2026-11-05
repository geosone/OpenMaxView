; SPDX-License-Identifier: GPL-3.0-or-later
; IPX (measurement and tests/qemu):  IPXPRB file S|R [n]
;   the IPX entry (INT 2Fh AX=7A00h), "ipx SSSS:OOOO" and the own address
;   ("addr" net, node); socket 4545h opened (short-lived), "open cc".
;   S:  n packets (default 20) broadcast to the socket, one per half
;   second, "s N cc" each (its completion code);
;   R:  four listens with an ESR; each packet received "r N cc esr E" (its
;   number, completion code, the ESRs run so far), its listen posted
;   again; the end after n packets, 180 s or a key "x".
;   Then "end N esr E bad B" (B:  ESR calls whose ECB was not one of ours,
;   or whose DS:  not ours) and the socket closed.  "ipxprb ready" on the
;   screen.  Each line is committed to the file at once.

        .model tiny
        .386
        .code
        org     100h

SOCKET  equ     4545h                 ; (as IPX wants it:  high byte first)
NLISTEN equ     4
ECBSIZE equ     36                    ; ECB with one fragment
PKTSIZE equ     30 + 16               ; IPX header and the data

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
        mov     di,offset line
        mov     si,offset t_ipx
        call    puts
        mov     dx,word ptr ipx
        mov     ax,word ptr ipx+2
        call    putptr
        call    putnl
        mov     si,offset myaddr        ; GET INTERNETWORK ADDRESS
        mov     bx,09h
        call    ipxcall
        mov     si,offset t_addr
        call    puts
        mov     si,offset myaddr
        mov     cx,10
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        call    putnl
        mov     al,0                  ; OPEN SOCKET
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
        cmp     mode,'S'
        je      sender
        jmp     receiver

; S:  n broadcasts
sender: mov     word ptr hdr+2,PKTSIZE shl 8 + PKTSIZE shr 8 ; (high first)
        mov     byte ptr hdr+5,4      ; packet type IPX
        mov     di,offset hdr+10      ; to the local net's every node
        mov     ax,0FFFFh
        stosw
        stosw
        stosw
        mov     word ptr hdr+16,SOCKET
        push    ds
        pop     es
        mov     di,offset sendecb+1Ch ; immediate address:  broadcast
        stosw
        stosw
        stosw
        mov     word ptr sendecb+0Ah,SOCKET
        mov     word ptr sendecb+22h,1
        mov     word ptr sendecb+24h,offset hdr
        mov     word ptr sendecb+26h,ds
        mov     word ptr sendecb+28h,PKTSIZE
        mov     seq,0
s_next: mov     ax,seq
        cmp     ax,count
        jae     s_end
        inc     seq
        mov     ax,seq
        mov     word ptr hdr+30+6,ax  ; "IPXPRB" and the number
        mov     si,offset sendecb
        mov     bx,03h                ; SEND PACKET
        call    ipxcall
@@:     cmp     byte ptr sendecb+8,0  ; (in use)
        je      @F
        mov     bx,0Ah
        call    ipxcall
        jmp     @B
@@:     mov     di,offset line
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
s_end:  jmp     closeit

; R:  listens with the ESR until n packets
receiver:
        xor     bx,bx
@@:     call    post
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
r_loop: xor     bx,bx
r_ecb:  call    ecbof
        cmp     byte ptr [si+8],0     ; done?
        jne     r_ecb_next
        push    bx
        mov     di,offset line
        mov     si,offset t_r
        call    puts
        pop     bx
        push    bx
        call    ecbof
        mov     bp,[si+24h]           ; its packet
        mov     ax,[bp+30+6]
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
        mov     ax,got
        cmp     ax,count
        jae     r_end
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
r_end:  xor     bx,bx                 ; the listens cancelled
@@:     push    bx
        call    ecbof
        mov     bx,06h                ; CANCEL EVENT
        call    ipxcall
        pop     bx
        inc     bx
        cmp     bx,NLISTEN
        jb      @B
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
        push    si
        mov     di,si
        mov     cx,ECBSIZE
        xor     al,al
        rep     stosb
        pop     si
        mov     word ptr [si+4],offset esr
        mov     word ptr [si+6],cs
        mov     word ptr [si+0Ah],SOCKET
        mov     word ptr [si+22h],1
        mov     ax,PKTSIZE
        mul     bx
        add     ax,offset lpkt
        mov     [si+24h],ax
        mov     [si+26h],ds
        mov     word ptr [si+28h],PKTSIZE
        mov     bx,04h                ; LISTEN FOR PACKET
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

; AX:DX (segment, offset) as SSSS:OOOO to DI
putptr  proc near
        call    puthex
        mov     al,':'
        stosb
        mov     ax,dx
        call    puthex
        ret
putptr  endp

puthex  proc near
        push    ax
        mov     al,ah
        call    puthex8
        pop     ax
puthex  endp                    ; (falls through:  AL)
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
t_ipx   db      'ipx ',0
t_addr  db      'addr',0
t_open  db      'open ',0
t_s     db      's ',0
t_r     db      'r ',0
t_esr   db      ' esr ',0
t_end   db      'end ',0
t_bad   db      ' bad ',0
t_ready db      'ipxprb ready',13,10,'$'
utext   db      'IPXPRB file S|R [n]',13,10,'$'
mode    db      0
count   dw      20
seq     dw      0
got     dw      0
esrs    dw      0
bad     dw      0
handle  dw      0
deadline dd     0
ipx     dd      0
myaddr  db      10 dup (0)
hdr     dw      0FFFFh, 0             ; checksum, length
        db      0, 4                  ; transport control, packet type
        db      12 dup (0)            ; destination net, node, socket
        db      12 dup (0)            ; source
        db      'IPXPRB', 0, 0        ; the data:  "IPXPRB", the number
        db      8 dup (0)
sendecb db      ECBSIZE dup (0)
lecb    db      NLISTEN * ECBSIZE dup (0)
lpkt    db      NLISTEN * PKTSIZE dup (0)
fname   db      80 dup (0)
line    db      200 dup (?)

        end     start
