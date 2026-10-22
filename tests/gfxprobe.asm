; SPDX-License-Identifier: GPL-3.0-or-later
; Graphics probe for the multitasking core (tests/qemu):
;   GFXPROBE file
; sets VGA mode 13h, fills the screen with colour 2 and checks it again and
; again; a cleared screen (back in the foreground) is drawn again.  "." (or
; a minute) ends it:  text mode, then "gfx redraw R gap G" to file:  R
; redraws, G the longest time without running (timer ticks; held in the
; background).

        .8086
        .model tiny
        .code
        org 100h

COLOUR  equ     2

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
        je      @F
        jmp     @B
@@:     mov     byte ptr [di],0
        mov     ax,0013h
        int     10h
        call    draw
        call    ticks
        mov     t0,ax
        mov     tlast,ax
again:  call    ticks
        mov     bx,ax
        sub     ax,tlast
        mov     tlast,bx
        cmp     ax,gap
        jbe     @F
        mov     gap,ax
@@:     mov     ax,bx
        sub     ax,t0
        cmp     ax,1092         ; a minute
        jae     done
        mov     ax,0A000h
        mov     es,ax
        cmp     byte ptr es:[0],COLOUR
        jne     redraw
        cmp     byte ptr es:[63999],COLOUR
        je      @F
redraw: inc     nredraw
        call    draw
@@:     mov     ah,1
        int     16h
        jz      again
        xor     ah,ah
        int     16h
        cmp     al,'.'
        jne     again
done:   mov     ax,0003h
        int     10h
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     bx,ax
        mov     di,offset t_red
        mov     ax,nredraw
        call    dec5
        mov     di,offset t_gap
        mov     ax,gap
        call    dec5
        mov     ah,40h
        mov     cx,MSGLEN
        mov     dx,offset msg
        int     21h
        mov     ah,3Eh
        int     21h
        mov     ax,4C00h
        int     21h
usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

draw    proc near
        push    es
        mov     ax,0A000h
        mov     es,ax
        xor     di,di
        mov     ax,COLOUR*101h
        mov     cx,32000
        cld
        rep     stosw
        pop     es
        ret
draw    endp

; AX = BIOS timer ticks (low word)
ticks   proc near
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     ax,ds:[6Ch]
        pop     ds
        ret
ticks   endp

; AX to 5 decimal digits at DI
dec5    proc near
        push    bx
        add     di,4
        mov     bx,10
        mov     cx,5
@@:     xor     dx,dx
        div     bx
        add     dl,'0'
        mov     [di],dl
        dec     di
        loop    @B
        pop     bx
        ret
dec5    endp

utext   db      'GFXPROBE file',13,10,'$'
msg     db      'gfx redraw '
t_red   db      '00000 gap '
t_gap   db      '00000',13,10
MSGLEN  equ     $-msg
nredraw dw      0
gap     dw      0
t0      dw      ?
tlast   dw      ?
fname   db      80 dup (?)

        end     start
