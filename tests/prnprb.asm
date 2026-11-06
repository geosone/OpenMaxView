; SPDX-License-Identifier: GPL-3.0-or-later
; Printer contention (measurement and tests/qemu):  PRNPRB tag [n [gap
; [hold]]] prints n lines (default 10) "<tag> i t=<ticks>" to LPT1 by
; INT 17h (a lower-case tag:  by DOS, PRN opened before the first and closed
; after the last), gap ticks (default 9) after each, then "<tag> end
; t=<ticks>";
; it stays hold ticks more (default 0) before it ends.  "prnprb <tag>
; ready", "... printed", "... ended" on the screen ("... open error N":
; PRN not opened).

        .8086
        .model tiny
        .code
        org     100h

start:  mov     si,81h
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        mov     tag,al
        mov     t_tag1,al
        mov     t_tag2,al
        mov     t_tag3,al
@@:     lodsb                         ; the rest of the tag
        cmp     al,' '
        je      @F
        cmp     al,13
        jne     @B
@@:     dec     si
        mov     di,offset lines
        call    number
        mov     di,offset gap
        call    number
        mov     di,offset hold
        call    number

        cmp     tag,'a'
        jb      @F
        mov     dx,offset t_prn
        mov     ax,3D01h
        int     21h
        jc      open_err
        mov     prn,ax
@@:     mov     dx,offset t_ready
        mov     ah,9
        int     21h
        mov     cx,lines
        mov     bx,1
@@:     push    cx
        mov     ax,bx
        call    report
        mov     cx,gap
        call    pause
        inc     bx
        pop     cx
        loop    @B
        xor     ax,ax                 ; "end"
        call    report
        cmp     tag,'a'
        jb      @F
        mov     bx,prn
        mov     ah,3Eh
        int     21h
@@:
        mov     dx,offset t_print
        mov     ah,9
        int     21h
        mov     cx,hold
        call    pause
        mov     dx,offset t_ended
        mov     ah,9
        int     21h
        mov     ax,4C00h
        int     21h
open_err:                             ; "prnprb <tag> open error <AX>"
        mov     di,offset t_errn
        call    decimal
        mov     ax,0A0Dh
        stosw
        mov     byte ptr [di],'$'
        mov     al,tag
        mov     t_tag4,al
        mov     dx,offset t_err
        mov     ah,9
        int     21h
        mov     ax,4C02h
        int     21h
usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
        mov     ax,4C01h
        int     21h

; [DI] = the next decimal number from [SI] (left as it is without one)
number  proc near
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,'0'
        jb      nb_none
        cmp     al,'9'
        ja      nb_none
        mov     word ptr [di],0
@@:     sub     al,'0'
        cbw
        xchg    ax,[di]
        mov     dx,10
        mul     dx
        add     [di],ax
        lodsb
        cmp     al,'0'
        jb      nb_none
        cmp     al,'9'
        jbe     @B
nb_none:
        dec     si
        ret
number  endp

; CX ticks (busy:  DV 2.80 hung a window's INT 28h loop while another
; window waited in the background)
pause   proc near
        jcxz    wt_ret
        push    ds
        xor     ax,ax
        mov     ds,ax
        mov     dx,ds:[46Ch]
@@:     mov     ax,ds:[46Ch]
        sub     ax,dx
        cmp     ax,cx
        jb      @B
        pop     ds
wt_ret: ret
pause   endp

; the line "<tag> <AX> t=<ticks>" (AX 0:  "end") to the printer
report  proc near
        push    bx
        mov     bx,ax
        mov     di,offset line
        mov     al,tag
        stosb
        mov     al,' '
        stosb
        mov     ax,bx
        or      ax,ax
        jz      rp_end
        call    decimal
        jmp     short @F
rp_end: mov     ax,'ne'
        stosw
        mov     al,'d'
        stosb
@@:     mov     ax,'t '
        stosw
        mov     al,'='
        stosb
        push    ds
        xor     ax,ax
        mov     ds,ax
        mov     ax,ds:[46Ch]
        pop     ds
        call    decimal
        mov     ax,0A0Dh
        stosw
        cmp     tag,'a'               ; a lower-case tag:  by DOS
        jb      rp_bios
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     bx,prn
        mov     ah,40h
        int     21h
        jmp     short rp_ret
rp_bios:
        mov     si,offset line
@@:     lodsb
        xor     ah,ah
        xor     dx,dx                 ; LPT1
        int     17h
        cmp     si,di
        jb      @B
rp_ret:
        pop     bx
        ret
report  endp

; AX in decimal at [DI]
decimal proc near
        mov     cx,10
        xor     dx,dx
        push    dx                    ; (the end)
@@:     xor     dx,dx
        div     cx
        add     dl,'0'
        push    dx
        or      ax,ax
        jnz     @B
@@:     pop     ax
        or      ax,ax
        jz      @F
        stosb
        jmp     @B
@@:     ret
decimal endp

tag     db      'A'
lines   dw      10
gap     dw      9
hold    dw      0
prn     dw      4
t_prn   db      'PRN',0
t_ready db      'prnprb '
t_tag1  db      'A ready',13,10,'$'
t_print db      'prnprb '
t_tag2  db      'A printed',13,10,'$'
t_ended db      'prnprb '
t_tag3  db      'A ended',13,10,'$'
t_err   db      'prnprb '
t_tag4  db      'A open error '
t_errn  db      8 dup (0)
utext   db      'PRNPRB tag [n [gap [hold]]]',13,10,'$'
line    db      40 dup (0)

        end     start
