; SPDX-License-Identifier: GPL-3.0-or-later
; A background task on the CRTC and DAC ports (tests/qemu):
;   CRTPRB F file   (the foreground) the BIOS cursor to row 20 column 40,
;                   DAC entry 1 read, 6 s, then "cur AAAA" (the CRTC cursor
;                   address, 3D4h 0Eh/0Fh) and "dac same|changed"
;   CRTPRB B file   (a background task) 5 s of direct OUTs:  the CRTC
;                   cursor to address 0005h, DAC entry 1 to 3Fh 0 0; then
;                   "rb AAAA" (the cursor address IN 3D5h gives it) and
;                   "bios R C" (its BIOS cursor, INT 10h AH=03h)
; Under MaxView F gets "cur 0668" and "dac same":  the background task's
; CRTC and DAC writes do not reach the hardware (QPI 0Dh/0Eh), and B
; reads back what it wrote ("rb 0005", "bios 0 5").

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
        cmp     role,'F'
        je      @F
        cmp     role,'B'
        jne     usage
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     di,offset line
        cmp     role,'B'
        je      back

        mov     ah,2            ; F:  BIOS cursor 20,40
        xor     bh,bh
        mov     dx,1428h
        int     10h
        mov     si,offset dac0
        call    dacrd
        mov     cx,6 * 18 + 4
        call    wait_ticks
        mov     si,offset t_cur
        call    puts
        mov     dx,3D4h
        mov     al,0Eh
        out     dx,al
        inc     dx
        in      al,dx
        mov     ah,al
        dec     dx
        mov     al,0Fh
        out     dx,al
        inc     dx
        in      al,dx
        call    puthex
        call    putnl
        mov     si,offset dac1
        call    dacrd
        mov     si,offset t_dac
        call    puts
        mov     si,offset t_same
        mov     ax,word ptr dac0
        cmp     ax,word ptr dac1
        jne     @F
        mov     al,dac0+2
        cmp     al,dac1+2
        je      dacout
@@:     mov     si,offset t_changed
dacout: call    puts
        call    putnl
        jmp     done

back:   push    es              ; B:  5 s of OUTs
        push    40h
        pop     es
        mov     bx,es:[6Ch]
bloop:  mov     dx,3D4h
        mov     ax,000Eh        ; 0Eh := 00h
        out     dx,ax
        mov     ax,050Fh        ; 0Fh := 05h
        out     dx,ax
        mov     dx,3C8h
        mov     al,1
        out     dx,al
        inc     dx
        mov     al,3Fh
        out     dx,al
        xor     al,al
        out     dx,al
        out     dx,al
        mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,5 * 18 + 1
        jb      bloop
        pop     es
        mov     si,offset t_rb
        call    puts
        mov     dx,3D4h
        mov     al,0Eh
        out     dx,al
        inc     dx
        in      al,dx
        mov     ah,al
        dec     dx
        mov     al,0Fh
        out     dx,al
        inc     dx
        in      al,dx
        call    puthex
        call    putnl
        mov     si,offset t_bios
        call    puts
        mov     ah,3
        xor     bh,bh
        int     10h
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

; DAC entry 1 into the 3 bytes at SI
dacrd   proc near
        mov     dx,3C7h
        mov     al,1
        out     dx,al
        mov     dx,3C9h
        in      al,dx
        mov     [si],al
        in      al,dx
        mov     [si+1],al
        in      al,dx
        mov     [si+2],al
        ret
dacrd   endp

; CX ticks, with PAUSE
wait_ticks proc near
        push    es
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,cx
        jb      @B
        pop     es
        ret
wait_ticks endp

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

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file, committed
putnl   proc near
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
        mov     di,offset line
        ret
putnl   endp

utext   db      'CRTPRB F|B file',13,10,'$'
t_cur   db      'cur ',0
t_dac   db      'dac ',0
t_same  db      'same',0
t_changed db    'changed',0
t_rb    db      'rb ',0
t_bios  db      'bios ',0
role    db      0
handle  dw      0
dac0    db      3 dup (0)
dac1    db      3 dup (0)
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
