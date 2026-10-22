; SPDX-License-Identifier: GPL-3.0-or-later
; Keyboard and screen probe for the multitasking core (tests/qemu):
;   KEYPROBE file B|D
; shows "keyprobe X ready", then reads keys (B:  INT 16h AH=00h, D:  DOS
; INT 21h AH=08h), echoes each one and writes it to file; "." ends.  A
; background task must neither get keys nor show on the screen, and a
; waiting one must leave the CPU to the others.

        .8086
        .model tiny
        .code
        org 100h

start:
        mov     si,81h
@@:     lodsb                   ; file name
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
        je      usage
        jmp     @B
@@:     mov     byte ptr [di],0
@@:     lodsb                   ; mode
        cmp     al,' '
        je      @B
        and     al,0DFh
        cmp     al,'B'
        je      @F
        cmp     al,'D'
        jne     usage
@@:     mov     mode,al
        mov     msg_mode,al
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     dx,offset msg
        mov     ah,9
        int     21h
next:   cmp     mode,'B'
        jne     @F
        xor     ah,ah
        int     16h
        jmp     short got
@@:     mov     ah,08h
        int     21h
got:    cmp     al,'.'
        je      done
        mov     key,al
        mov     dl,al           ; echo
        mov     ah,2
        int     21h
        mov     ah,40h
        mov     bx,handle
        mov     cx,1
        mov     dx,offset key
        int     21h
        jmp     next
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

utext   db      'KEYPROBE file B|D',13,10,'$'
msg     db      'keyprobe '
msg_mode db     '? ready',13,10,'$'
mode    db      ?
key     db      ?
handle  dw      ?
fname   db      80 dup (?)

        end     start
