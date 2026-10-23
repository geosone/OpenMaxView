; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview subtasks (tests/qemu):  SUBPRB file
;   "new XXXX B"   NEW 08h with an entry point here (no window):  the
;                  handle's segment (0:  none) and the bytes NEW left on
;                  the stack
;   then the subtask (DS = ES = SS its own stack, DX:CX its task's handle)
;   goes to a stack here, writes "sub in the window" to its task's window (that handle) and
;   ADDTO its task's mailbox (BL=02h) "hi", status 7; then counts for ever
;   "mail LL SS text"  READ of the own mailbox (BL=03h):  length, status
;                  (STATUS), the text
;   "runs Y/N"     the count went on during 1 s (a timer's)
;   "free"         FREE of the subtask's handle; "stops Y/N":  the count
;                  stood still during 1 s afterwards
;   "subprb done" on row 12

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
        mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     ax,0DE0Bh
        mov     bx,0201h
        int     15h
        mov     ax,1200h              ; a timer for the waits
        mov     bx,010Bh
        int     15h
        pop     word ptr tim
        pop     word ptr tim+2
        mov     di,offset line

        mov     si,offset t_new       ; NEW 08h:  title, its length, rows,
        call    puts                  ; columns 0, no buffer, the default
        mov     savsp,sp              ; stack, a task, the entry point
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0
        push    0FFFFh
        push    0FFFFh
        push    0FFFFh
        push    0FFFFh
        push    cs
        push    offset subtask
        mov     ax,1200h
        mov     bx,0108h
        int     15h
        mov     bp,sp
        mov     ax,[bp+2]
        mov     word ptr sub_h,0
        mov     word ptr sub_h+2,ax
        call    puthex
        mov     al,' '
        stosb
        mov     ax,savsp
        sub     ax,sp
        call    putdec
        mov     sp,savsp
        call    putnl

        mov     si,offset t_mail      ; READ of the own mailbox
        call    puts
        mov     ax,1200h
        mov     bx,0403h
        int     15h
        pop     cx
        pop     ax
        pop     si
        pop     fs
        mov     ax,cx
        call    puthex8
        mov     al,' '
        stosb
        mov     ax,1200h              ; STATUS of it
        mov     bx,0F03h
        int     15h
        pop     ax
        pop     dx
        call    puthex8
        mov     al,' '
        stosb
        jcxz    @F
copy:   mov     al,fs:[si]
        inc     si
        stosb
        loop    copy
@@:     call    putnl

        mov     si,offset t_runs      ; the count runs?
        call    puts
        call    second_count
        call    putnl
        mov     si,offset t_free      ; FREE of it
        call    puts
        call    putnl
        push    word ptr sub_h+2
        push    word ptr sub_h
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        call    wait_second
        mov     si,offset t_stops
        call    puts
        call    second_count
        xor     al,'Y' xor 'N'        ; (stood still:  Y)
        mov     [di-1],al
        call    putnl

        mov     ah,2
        xor     bh,bh
        mov     dx,0C00h
        int     10h
        mov     dx,offset t_done
        mov     ah,9
        int     21h
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

; "Y" to DI if the subtask's count changed during 18 ticks, else "N"
second_count proc near
        mov     eax,count
        mov     count0,eax
        call    wait_second
        mov     eax,count
        cmp     eax,count0
        mov     al,'Y'
        jne     @F
        mov     al,'N'
@@:     stosb
        ret
second_count endp

; One second:  the timer (ADDTO 100 hundredths, READ:  until expired;
; under DESQview 40:6C stands still while a subtask runs)
wait_second proc near
        push    0
        push    100
        push    word ptr tim+2
        push    word ptr tim
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        push    word ptr tim+2
        push    word ptr tim
        mov     ax,1200h
        mov     bx,0400h
        int     15h
        add     sp,4
        ret
wait_second endp

; The subtask:  DS = ES = SS = its stack, DX:CX its task's handle.
subtask proc far
        push    cs
        pop     ds
        mov     ax,cs                 ; a stack of its own (DESQview's is
        cli                           ; small, as the DV C library does)
        mov     ss,ax
        mov     sp,offset sub_stack_top
        sti
        mov     word ptr parent,cx
        mov     word ptr parent+2,dx
        push    ds                    ; WRITE to its task's window
        push    offset t_sub
        push    0
        push    t_sub_len
        push    word ptr parent+2
        push    word ptr parent
        mov     ax,1200h
        mov     bx,0500h
        int     15h
        push    ds                    ; ADDTO its task's mailbox:  "hi",
        push    offset t_hi           ; status 7
        push    0
        push    2
        push    0
        push    7
        push    word ptr parent+2
        push    word ptr parent
        mov     ax,1200h
        mov     bx,0A02h
        int     15h
@@:     inc     count                 ; then counts
        mov     ax,1000h
        int     15h
        jmp     @B
subtask endp

puthex  proc near
        push    ax
        mov     al,ah
        call    puthex8
        pop     ax
puthex  endp
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

puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

putnl   proc near
        push    cx
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
        pop     cx
        ret
putnl   endp

utext   db      'SUBPRB file',13,10,'$'
t_done  db      'subprb done',13,10,'$'
t_new   db      'new ',0
t_mail  db      'mail ',0
t_runs  db      'runs ',0
t_free  db      'free',0
t_stops db      'stops ',0
t_sub   db      'sub in the window',13,10
t_sub_len equ   $ - t_sub
t_hi    db      'hi'
handle  dw      0
savsp   dw      0
count   dd      0
count0  dd      0
sub_h   dd      0
tim     dd      0
parent  dd      0
fname   db      80 dup (0)
line    db      120 dup (0)
        dw      256 dup (0)
sub_stack_top label word

        end     start
