; SPDX-License-Identifier: GPL-3.0-or-later
; EMS per task probe for the multitasking core (tests/qemu):
;   EMSPROBE file c
; allocates 4 EMS pages, maps them to the page frame, fills the 64KB with
; c, checks them for about 10 seconds (saving and restoring the mapping,
; 47h/48h, each time) while other tasks do the same with their own pages, then writes "ems c ok" (bad:  another task's pattern
; seen; err:  an EMS call failed) to file.

        .8086
        .model tiny
        .code
        org 100h

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
        je      usage
        jmp     @B
@@:     mov     byte ptr [di],0
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      usage
        mov     pat,al
        mov     msg_pat,al
        mov     ah,41h          ; page frame
        int     67h
        or      ah,ah
        jnz     err
        mov     frame,bx
        mov     ah,43h          ; 4 pages
        mov     bx,4
        int     67h
        or      ah,ah
        jnz     err
        mov     handle,dx
        xor     bx,bx
@@:     mov     ax,4400h        ; logical BX -> physical AL
        add     al,bl
        mov     dx,handle
        int     67h
        or      ah,ah
        jnz     err
        inc     bx
        cmp     bx,4
        jb      @B
        mov     es,frame
        xor     di,di
        mov     al,pat
        mov     ah,al
        mov     cx,8000h
        cld
        rep     stosw
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     bx,ds:[6Ch]
        pop     ds
again:  mov     ah,47h          ; save and restore the mapping (TSR style)
        mov     dx,handle
        int     67h
        or      ah,ah
        jnz     err
        mov     ah,48h
        mov     dx,handle
        int     67h
        or      ah,ah
        jnz     err
        xor     di,di
        mov     al,pat
        mov     cx,0FFFFh
        repe    scasb
        jne     bad
        push    ds
        mov     ax,40h
        mov     ds,ax
        mov     ax,ds:[6Ch]
        pop     ds
        sub     ax,bx
        cmp     ax,182
        jb      again
        jmp     short report
bad:    mov     word ptr msg_res,'ab'
        mov     byte ptr msg_res+2,'d'
        jmp     short report
err:    mov     word ptr msg_res,'re'
        mov     byte ptr msg_res+2,'r'
report: cmp     handle,0
        je      @F
        mov     ah,45h          ; free
        mov     dx,handle
        int     67h
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     bx,ax
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

utext   db      'EMSPROBE file c',13,10,'$'
msg     db      'ems '
msg_pat db      '? '
msg_res db      'ok ',13,10
MSGLEN  equ     $-msg
pat     db      ?
frame   dw      ?
handle  dw      0
fname   db      80 dup (?)

        end     start
