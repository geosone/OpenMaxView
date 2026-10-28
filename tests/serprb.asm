; SPDX-License-Identifier: GPL-3.0-or-later
; A BBS node's serial side (tests/qemu):  SERPRB port file
;   port 1-4:  COM1 3F8h IRQ4, COM2 2F8h IRQ3, COM3 3E8h IRQ4, COM4 2E8h
;   IRQ3.  Receives by interrupt (the IRQ's vector hooked, as BBS programs
;   and FOSSIL drivers do), echoes every byte (polled) and about once a
;   second appends "rx N" (bytes received) to the file and shows it.
;   Sends "R" when ready and again each second until the first byte came
;   (linux/test/serfeed.py of Open 386MAX is the other side).  Runs until
;   the machine is stopped.

        .model tiny
        .386
        .code
        org 100h

RBSIZE equ 1024                       ; the receive ring (a power of 2)

start:
        mov     si,81h
        call    skip
        sub     al,'1'
        cmp     al,3
        ja      usage
        movzx   bx,al
        shl     bx,1
        mov     ax,bases[bx]
        mov     base,ax
        mov     al,vecs[bx]
        mov     vec,al
        mov     al,irqmasks[bx]
        mov     irqmask,al
        inc     si
        call    skip
        mov     di,offset fname
name_copy:
        lodsb
        cmp     al,' '
        jbe     name_end
        stosb
        jmp     name_copy
name_end:
        cmp     di,offset fname
        je      usage
        mov     byte ptr [di],0
        mov     ah,3Ch                ; the file, empty
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     bx,ax
        mov     ah,3Eh
        int     21h

        mov     dx,base               ; 9600 8N1, no FIFO (a byte an IRQ)
        add     dx,3
        mov     al,83h
        out     dx,al
        mov     dx,base
        mov     al,12
        out     dx,al
        inc     dx
        xor     al,al
        out     dx,al
        add     dx,2
        mov     al,03h
        out     dx,al
        dec     dx                    ; (FCR)
        xor     al,al
        out     dx,al
        mov     al,vec                ; the IRQ's vector
        mov     ah,25h
        mov     dx,offset irq
        int     21h
        mov     dx,base               ; MCR:  DTR, RTS, OUT2
        add     dx,4
        mov     al,0Bh
        out     dx,al
        mov     dx,base               ; (old data away)
        in      al,dx
        inc     dx                    ; IER:  received data
        mov     al,01h
        out     dx,al
        in      al,21h
        mov     ah,irqmask
        not     ah
        and     al,ah
        out     21h,al
        mov     al,'R'
        call    tx

second:
        push    ds
        push    40h
        pop     ds
        mov     ax,ds:[6Ch]
        pop     ds
        mov     last,ax
echo_loop:
        mov     bx,tail
        cmp     bx,head
        je      echo_idle
        mov     al,rbuf[bx]
        inc     bx
        and     bx,RBSIZE - 1
        mov     tail,bx
        call    tx
        jmp     echo_loop
echo_idle:
        push    ds
        push    40h
        pop     ds
        mov     ax,ds:[6Ch]
        pop     ds
        sub     ax,last
        cmp     ax,18
        jb      echo_loop
        cli
        mov     ax,count
        sti
        or      ax,ax
        jnz     report
        push    ax
        mov     al,'R'                ; nothing yet:  ready again
        call    tx
        pop     ax
report:
        mov     di,offset num + 4
        mov     cx,5
        mov     bx,10
report_digit:
        xor     dx,dx
        div     bx
        add     dl,'0'
        mov     [di],dl
        dec     di
        loop    report_digit
        mov     ax,3D01h
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     bx,ax
        mov     ax,4202h
        xor     cx,cx
        xor     dx,dx
        int     21h
        mov     ah,40h
        mov     cx,LINE_LEN
        mov     dx,offset line
        int     21h
        mov     ah,3Eh
        int     21h
        mov     ah,40h                ; (on the screen too)
        mov     bx,1
        mov     cx,LINE_LEN
        mov     dx,offset line
        int     21h
        jmp     second

; The IRQ:  every received byte into the ring.
irq:
        push    ax
        push    bx
        push    dx
irq_byte:
        mov     dx,cs:base
        add     dx,5                  ; LSR:  data ready?
        in      al,dx
        test    al,1
        jz      irq_done
        mov     dx,cs:base
        in      al,dx
        mov     bx,cs:head
        mov     cs:rbuf[bx],al
        inc     bx
        and     bx,RBSIZE - 1
        mov     cs:head,bx
        inc     cs:count
        jmp     irq_byte
irq_done:
        mov     dx,cs:base            ; (IIR read:  a THRE cleared)
        add     dx,2
        in      al,dx
        mov     al,20h
        out     20h,al
        pop     dx
        pop     bx
        pop     ax
        iret

; AL to the port, once the transmitter is empty.
tx:
        push    ax
        mov     dx,base
        add     dx,5
tx_wait:
        in      al,dx
        test    al,20h
        jz      tx_wait
        pop     ax
        mov     dx,base
        out     dx,al
        ret

; SI past blanks; AL the character there.
skip:
        lodsb
        cmp     al,' '
        je      skip
        dec     si
        ret

usage:
        mov     dx,offset t_usage
        mov     ah,09h
        int     21h
fail:
        mov     ax,4C01h
        int     21h

bases   dw      3F8h,2F8h,3E8h,2E8h
vecs    db      0Ch,0,0Bh,0,0Ch,0,0Bh,0
irqmasks db    10h,0,08h,0,10h,0,08h,0
base    dw      0
vec     db      0
irqmask db     0
last    dw      0
count   dw      0
head    dw      0
tail    dw      0
line    db      'rx '
num     db      '00000',13,10
LINE_LEN equ    $ - line
t_usage db      'SERPRB port file',13,10,'$'
fname   db      80 dup(0)
rbuf    db      RBSIZE dup(0)

        end     start
