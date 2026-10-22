; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview scheduling API probe for the multitasking core (tests/qemu):
;   DVTASK A out      the measuring task
;   DVTASK B out      the counting task:  counts the dword at 40:F0h (the
;                     BIOS intra-application area, shared by all tasks)
; Both write "app N dv VVVV" (APPNUM, the 2B01h version) to out first.  A
; then appends
;   "crit C0 C1 C2"   counter at BEGINC, 2 s later (ENDC), 2 s after that:
;                     C0 = C1 (no switch inside), C2 > C1
;   "pause D1 D2"     what B counted in 2 s of busy waiting and in 2 s of
;                     PAUSE calls:  D2 well above D1
; and ends; B counts until it is stopped.

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
        cmp     role,'A'
        je      @F
        cmp     role,'B'
        jne     usage
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        ; identity
        mov     ax,0DE07h       ; APPNUM
        int     15h
        push    ax
        mov     di,offset line
        mov     si,offset t_app
        call    puts
        pop     ax
        call    putdec
        mov     ax,2B01h        ; DESQview installation check
        mov     cx,'DE'
        mov     dx,'SQ'
        int     21h
        push    ax
        push    bx
        mov     si,offset t_dv
        call    puts
        pop     bx
        pop     ax
        cmp     al,0FFh
        mov     ax,0FFFFh
        je      @F
        mov     ax,bx
@@:     call    puthex
        call    putnl
        cmp     role,'B'
        je      count
        ; until B counts (10 s at most)
        push    es
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        cmp     dword ptr es:[0F0h],0
        jne     @F
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,182
        jb      @B
@@:     pop     es
        ; critical section
        mov     ax,101Bh        ; BEGINC
        int     15h
        call    getcnt
        mov     c0,eax
        mov     cx,36
        call    busy
        call    getcnt
        mov     c1,eax
        mov     ax,101Ch        ; ENDC
        int     15h
        mov     cx,36
        call    busy
        call    getcnt
        mov     c2,eax
        mov     si,offset t_crit
        call    puts
        mov     eax,c0
        call    putdec32
        mov     al,' '
        stosb
        mov     eax,c1
        call    putdec32
        mov     al,' '
        stosb
        mov     eax,c2
        call    putdec32
        call    putnl
        ; PAUSE
        call    getcnt
        mov     c0,eax
        mov     cx,36
        call    busy
        call    getcnt
        sub     eax,c0
        mov     c1,eax
        call    getcnt
        mov     c0,eax
        mov     cx,36
        call    pausing
        call    getcnt
        sub     eax,c0
        mov     c2,eax
        mov     si,offset t_pause
        call    puts
        mov     eax,c1
        call    putdec32
        mov     al,' '
        stosb
        mov     eax,c2
        call    putdec32
        call    putnl
        mov     ah,3Eh
        mov     bx,handle
        int     21h
        mov     ax,4C00h
        int     21h

count:  mov     ah,3Eh
        mov     bx,handle
        int     21h
        push    40h
        pop     es
@@:     add     dword ptr es:[0F0h],1
        jmp     @B

usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

; EAX = the counter
getcnt  proc near
        push    es
        push    40h
        pop     es
        mov     eax,es:[0F0h]
        pop     es
        ret
getcnt  endp

; CX ticks:  busy (no DOS, no BIOS but the tick count)
busy    proc near
        push    es
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,cx
        jb      @B
        pop     es
        ret
busy    endp

; CX ticks of DESQview PAUSE calls
pausing proc near
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
pausing endp

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file
putnl   proc near
        mov     ax,0A0Dh
        stosw
        mov     cx,di
        mov     dx,offset line
        sub     cx,dx
        mov     ah,40h
        mov     bx,handle
        int     21h
        mov     di,offset line
        ret
putnl   endp

putdec  proc near
        movzx   eax,ax
putdec  endp                    ; (falls through)
putdec32 proc near
        push    ebx
        push    edx
        push    cx
        mov     ebx,10
        xor     cx,cx
@@:     xor     edx,edx
        div     ebx
        push    dx
        inc     cx
        or      eax,eax
        jnz     @B
@@:     pop     ax
        add     al,'0'
        stosb
        loop    @B
        pop     cx
        pop     edx
        pop     ebx
        ret
putdec32 endp

puthex  proc near
        push    cx
        mov     cx,4
@@:     rol     ax,4
        push    ax
        and     al,0Fh
        add     al,'0'
        cmp     al,'9'
        jbe     hexok
        add     al,7
hexok:  stosb
        pop     ax
        loop    @B
        pop     cx
        ret
puthex  endp

utext   db      'DVTASK A|B file',13,10,'$'
t_app   db      'app ',0
t_dv    db      ' dv ',0
t_crit  db      'crit ',0
t_pause db      'pause ',0
role    db      ?
handle  dw      ?
c0      dd      ?
c1      dd      ?
c2      dd      ?
fname   db      80 dup (?)
line    db      128 dup (?)

        end     start
