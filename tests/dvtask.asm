; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview scheduling API probe for the multitasking core (tests/qemu):
;   DVTASK A out      the measuring task
;   DVTASK B out      the counting task:  counts a dword in CMOS RAM
;                     (78h-7Bh, unused):  shared by all tasks (40:F0h is
;                     not, DESQview keeps it per window)
; Both write "app N dv VVVV" (APPNUM, the 2B01h version) to out first.  A
; then appends
;   "crit C0 C1 C2"   counter at BEGINC, 2 s later (ENDC), 2 s after that:
;                     C0 = C1 (no switch inside), C2 > C1
;   "pause D1 D2"     what B counted in 2 s of busy waiting and in 2 s of
;                     PAUSE calls:  D2 well above D1
;   "ica own|shared"  40:F0h (B writes there all the time):  own under
;                     DESQview (per window)
;   "err own|shared"  the error-return policy (DE15h/DE16h):  A sets 1,
;                     B sets 2 now and then
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
        push    es              ; 40:F0h:  ours (B writes there all the time)
        push    40h
        pop     es
        mov     al,role
        mov     es:[0F0h],al
        pop     es
        cmp     role,'B'
        je      count
        ; until B counts (10 s at most)
        push    es
        push    40h
        pop     es
        mov     bx,es:[6Ch]
@@:     mov     ax,1000h
        int     15h
        call    getcnt
        or      eax,eax
        jnz     @F
        mov     ax,es:[6Ch]
        sub     ax,bx
        cmp     ax,182
        jb      @B
@@:     pop     es
        mov     ax,0DE15h       ; error-return policy 1 (B sets 2)
        mov     bl,1
        int     15h
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
        mov     si,offset t_icaown
        push    es
        push    40h
        pop     es
        cmp     byte ptr es:[0F0h],'A'
        pop     es
        je      @F
        mov     si,offset t_icashr
@@:     call    puts
        call    putnl
        mov     ax,0DE16h
        int     15h
        mov     si,offset t_errown
        cmp     bl,1
        je      @F
        mov     si,offset t_errshr
@@:     call    puts
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
@@:     mov     byte ptr es:[0F0h],'B'
        cli
        call    getcnt
        inc     eax
        call    putcnt
        sti
        or      ax,ax           ; now and then:  policy 2
        jnz     @B
        mov     ax,0DE15h
        mov     bl,2
        int     15h
        jmp     @B

usage:  mov     dx,offset utext
        mov     ah,9
        int     21h
fail:   mov     ax,4C01h
        int     21h

CMOSCNT equ     78h

; EAX = the counter (CMOS 78h-7Bh), putcnt:  EAX to it
getcnt  proc near
        push    cx
        push    edx
        pushf
        cli
        xor     edx,edx
        mov     cx,4
@@:     mov     al,CMOSCNT-1
        add     al,cl
        out     70h,al
        in      al,71h
        shl     edx,8
        mov     dl,al
        loop    @B
        mov     eax,edx
        popf
        pop     edx
        pop     cx
        ret
getcnt  endp

putcnt  proc near
        push    cx
        push    edx
        push    eax
        mov     edx,eax
        mov     cl,CMOSCNT
@@:     mov     al,cl
        out     70h,al
        mov     al,dl
        out     71h,al
        shr     edx,8
        inc     cl
        cmp     cl,CMOSCNT+4
        jb      @B
        pop     eax
        pop     edx
        pop     cx
        ret
putcnt  endp

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
t_icaown db     'ica own',0
t_icashr db     'ica shared',0
t_errown db     'err own',0
t_errshr db     'err shared',0
role    db      ?
handle  dw      ?
c0      dd      ?
c1      dd      ?
c2      dd      ?
fname   db      80 dup (?)
line    db      128 dup (?)

        end     start
