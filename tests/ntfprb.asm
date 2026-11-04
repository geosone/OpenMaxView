; SPDX-License-Identifier: GPL-3.0-or-later
; Window notifications (measurement and tests/qemu):  NTFPRB file [V]
;   (V:  INT 10h modes 1 and 3 once the notifications are asked for)
;   API level 2.01; a manager stream (type 10h) to the own window asks for
;   the notifications 40h-51h; "win", "kbd", "obq", "mbx" the handles (HANDLE
;   01h, 05h, 07h, 03h); "ntfprb ready" on the screen.  Then, up to 48 times:  READ
;   07h (an object with input), "q SSSS:OOOO" its handle; READ 00h of it
;   (handle on the stack), "  B d1 d2 d3" the bytes the call left and their
;   DWORDs (top first); the 16 bytes at the second DWORD and at the first
;   ("a" and "b").  A key "x" read from the keyboard ends it.  Each line is
;   committed to the file at once.

        .model tiny
        .386
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
        jne     @B
@@:     mov     byte ptr [di],0
        dec     si                    ; flag V:  set the video modes 1, 3
@@:     lodsb
        cmp     al,' '
        je      @B
        or      al,20h
        mov     vflag,al
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        push    ds                    ; the notifications, to the own window
        push    offset s_ntf
        push    0
        push    s_ntf_len
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        mov     di,offset line
        mov     si,offset t_win
        mov     bx,0001h
        call    hnd
        mov     si,offset t_kbd
        mov     bx,0005h
        call    hnd
        mov     si,offset t_obq
        mov     bx,0007h
        call    hnd
        mov     si,offset t_mbx
        mov     bx,0003h
        call    hnd
        call    flush
        cmp     vflag,'v'
        jne     @F
        mov     ax,0001h
        int     10h
        mov     ax,0003h
        int     10h
@@:     mov     dx,offset t_ready
        mov     ah,9
        int     21h

        mov     count,48
again:  mov     di,offset line
        mov     si,offset t_q         ; READ 07h:  the object
        call    puts
        mov     savsp,sp
        mov     ax,1200h
        mov     bx,0407h
        int     15h
        mov     bp,sp
        mov     dx,[bp]
        mov     ax,[bp+2]
        mov     sp,savsp
        mov     word ptr obj,dx
        mov     word ptr obj+2,ax
        call    putptr
        call    putnl
        mov     si,offset t_rd        ; READ 00h of it
        call    puts
        mov     savsp,sp
        push    word ptr obj+2
        push    word ptr obj
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        mov     bp,sp
        mov     cx,savsp
        sub     cx,sp
        mov     ax,cx
        call    putdec
        shr     cx,2
        cmp     cx,3
        jbe     @F
        mov     cx,3
@@:     push    cx
        push    bp
        jcxz    rd_dw_done
@@:     mov     al,' '
        stosb
        mov     dx,[bp]
        mov     ax,[bp+2]
        call    putptr
        add     bp,4
        loop    @B
rd_dw_done:
        pop     bp
        pop     cx
        call    putnl
        cmp     cx,2
        jb      rd_end
        mov     si,offset t_a         ; the bytes at the second DWORD
        call    puts
        push    ds
        lds     si,[bp+4]
        call    dump
        pop     ds
        call    putnl
        mov     si,offset t_b         ; and at the first
        call    puts
        push    ds
        lds     si,[bp]
        call    dump
        pop     ds
        call    putnl
        mov     ax,word ptr obj       ; the keyboard's "x":  the end
        cmp     ax,word ptr kbd
        jne     rd_end
        mov     ax,word ptr obj+2
        cmp     ax,word ptr kbd+2
        jne     rd_end
        push    ds
        lds     si,[bp+4]
        mov     al,[si]
        pop     ds
        mov     sp,savsp
        call    flush
        cmp     al,'x'
        je      done
        jmp     short rd_next
rd_end: mov     sp,savsp
        call    flush
rd_next:
        dec     count
        jz      done
        jmp     again
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

; "text SI SSSS:OOOO":  HANDLE BX (kept:  win, kbd)
hnd     proc near
        call    puts
        mov     ax,1200h
        int     15h
        pop     dx
        pop     ax
        cmp     si,offset t_kbd + 5   ; (puts left SI after the text)
        jne     @F
        mov     word ptr kbd,dx
        mov     word ptr kbd+2,ax
@@:     call    putptr
        call    putnl
        ret
hnd     endp

; 16 bytes at DS:SI as hex, " " between them, to ES:DI
dump    proc near
        mov     cx,16
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        ret
dump    endp

; the line (up to DI) to the file, committed
flush   proc near
        push    ax
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

s_ntf   db      1Bh,10h,18,0
        db      40h,41h,42h,43h,44h,45h,46h,47h,48h,49h,4Ah,4Bh,4Ch,4Dh
        db      4Eh,4Fh,50h,51h
s_ntf_len equ $ - s_ntf
t_win   db      'win ',0
t_kbd   db      'kbd ',0
t_obq   db      'obq ',0
t_mbx   db      'mbx ',0
t_q     db      'q ',0
t_rd    db      '  ',0
t_a     db      '  a',0
t_b     db      '  b',0
t_ready db      'ntfprb ready',13,10,'$'
utext   db      'NTFPRB file',13,10,'$'
vflag   db      0
handle  dw      0
count   dw      0
savsp   dw      0
obj     dd      0
kbd     dd      0
fname   db      80 dup (0)
line    db      600 dup (?)

        end     start
