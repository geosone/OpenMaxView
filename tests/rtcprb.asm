; SPDX-License-Identifier: GPL-3.0-or-later
; A slave PIC IRQ (measurement and tests/qemu):  RTCPRB file [s]
;   hooks INT 70h (IRQ8, the real-time clock) and turns its periodic
;   interrupt on (64 a second); each second "rtc N" (the IRQ8s so far), for
;   s seconds (default 30); then "end N", the clock and the vector as
;   before.  "rtcprb ready" on the screen.  Each line is committed to the
;   file at once.

        .8086
        .model tiny
        .code
        org     100h

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
@@:     lodsb                         ; s
        cmp     al,' '
        je      @B
        cmp     al,'0'
        jb      args_done
        cmp     al,'9'
        ja      args_done
        mov     secs,0
@@:     sub     al,'0'
        cbw
        xchg    ax,secs
        mov     dx,10
        mul     dx
        add     secs,ax
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

        mov     ax,3570h
        int     21h
        mov     word ptr old70,bx
        mov     word ptr old70+2,es
        mov     dx,offset irq8
        mov     ax,2570h
        int     21h
        cli
        mov     al,0Ah                ; rate 64 a second
        out     70h,al
        in      al,71h
        mov     olda,al
        and     al,0F0h
        or      al,0Ah
        mov     ah,al
        mov     al,0Ah
        out     70h,al
        mov     al,ah
        out     71h,al
        mov     al,0Bh                ; the periodic interrupt on
        out     70h,al
        in      al,71h
        mov     oldb,al
        or      al,40h
        mov     ah,al
        mov     al,0Bh
        out     70h,al
        mov     al,ah
        out     71h,al
        mov     al,0Ch                ; (one pending:  gone)
        out     70h,al
        in      al,71h
        in      al,0A1h               ; IRQ8 unmasked
        and     al,0FEh
        out     0A1h,al
        in      al,21h                ; (the cascade)
        and     al,0FBh
        out     21h,al
        sti
        mov     dx,offset t_ready
        mov     ah,9
        int     21h

        call    ticks
        mov     last,ax
second: call    ticks
        sub     ax,last
        cmp     ax,18
        jb      second
        add     last,18
        mov     si,offset t_rtc
        call    report
        dec     secs
        jnz     second

        cli
        mov     al,0Bh
        out     70h,al
        mov     al,oldb
        out     71h,al
        mov     al,0Ah
        out     70h,al
        mov     al,olda
        out     71h,al
        mov     al,0Ch
        out     70h,al
        in      al,71h
        sti
        push    ds
        lds     dx,old70
        mov     ax,2570h
        int     21h
        pop     ds
        mov     si,offset t_end
        call    report
        mov     ah,3Eh
        mov     bx,handle
        int     21h
        mov     ax,4C00h
        int     21h
usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; AX = the BIOS tick count (low word)
ticks   proc near
        push    ds
        xor     ax,ax
        mov     ds,ax
        mov     ax,ds:[46Ch]
        pop     ds
        ret
ticks   endp

; the line "<SI> <count>", committed
report  proc near
        mov     di,offset line
@@:     lodsb
        or      al,al
        jz      @F
        mov     [di],al
        inc     di
        jmp     @B
@@:     cli
        mov     ax,word ptr count
        mov     dx,word ptr count+2
        sti
        mov     cx,10                 ; DX:AX in decimal
        xor     bx,bx
@@:     push    ax
        mov     ax,dx
        xor     dx,dx
        div     cx
        mov     si,ax
        pop     ax
        div     cx
        push    dx
        inc     bx
        mov     dx,si
        or      si,ax
        jnz     @B
@@:     pop     ax
        add     al,'0'
        mov     [di],al
        inc     di
        dec     bx
        jnz     @B
        mov     word ptr [di],0A0Dh
        add     di,2
        mov     cx,di
        sub     cx,offset line
        mov     dx,offset line
        mov     bx,handle
        mov     ah,40h
        int     21h
        mov     ah,68h                ; committed
        mov     bx,handle
        int     21h
        ret
report  endp

; IRQ8:  counted, the clock's flags read (else no next one), EOI
irq8    proc far
        push    ax
        add     word ptr cs:count,1
        adc     word ptr cs:count+2,0
        mov     al,0Ch
        out     70h,al
        in      al,71h
        mov     al,20h
        out     0A0h,al
        out     20h,al
        pop     ax
        iret
irq8    endp

secs    dw      30
handle  dw      0
last    dw      0
count   dd      0
old70   dd      0
olda    db      0
oldb    db      0
t_rtc   db      'rtc ',0
t_end   db      'end ',0
t_ready db      'rtcprb ready',13,10,'$'
utext   db      'RTCPRB file [s]',13,10,'$'
fname   db      80 dup (0)
line    db      40 dup (0)

        end     start
