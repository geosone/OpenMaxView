; SPDX-License-Identifier: GPL-3.0-or-later
; Panels (measurement and tests/qemu):  PANPRB file library flags name...
;   API level 2.01; "own" and "kbd" the handles HANDLE 01h and 05h give;
;   NEW 10h (a panel), OPEN of the library (its length with the 0), STATUS,
;   SIZEOF; per name (up to 6) READ (apply it:  the panel, the window, the
;   name's length and address on the stack; flag O:  the own window, else
;   0) and STATUS, then a key; CLOSE, STATUS, FREE.  Flag L:  LEN after
;   SIZEOF (DESQview 2.80:  a programming error).  Each call one line:  its
;   name, the bytes it left on the stack and their first four DWORDs (top
;   first).  "panprb ready" on the screen before each key wait.  Each line
;   is committed to the file at once.

        .model tiny
        .386
        .code
        org 100h

call_api macro bxval, text
        mov     si,offset text
        call    say
        mov     si,offset text
        call    puts
        mov     ax,1200h
        mov     bx,bxval
        int     15h
        call    recres
        endm

push_pan macro
        push    word ptr pan+2
        push    word ptr pan
        endm

start:  mov     si,81h
        mov     di,offset fname
        call    word_arg
        jc      usage
        mov     di,offset lib
        call    word_arg
        jc      usage
        mov     lib_len,cx
        mov     di,offset flags
        call    word_arg
        jc      usage
        mov     di,offset names       ; the names, 16 bytes each
        mov     bx,offset name_lens
@@:     call    word_arg
        jc      @F
        mov     [bx],cx
        add     bx,2
        add     di,16
        sub     di,cx
        inc     count
        cmp     count,6
        jb      @B
@@:     mov     ah,3Ch
        xor     cx,cx
        mov     dx,offset fname
        int     21h
        jc      fail
        mov     handle,ax
        mov     ax,0DE0Bh             ; API level 2.01
        mov     bx,0201h
        int     15h
        mov     di,offset line

        mov     savsp,sp              ; the own window and keyboard
        call_api 0001h, t_own
        mov     ax,word ptr first
        mov     word ptr own,ax
        mov     ax,word ptr first+2
        mov     word ptr own+2,ax
        mov     savsp,sp
        call_api 0005h, t_kbd

        mov     savsp,sp              ; NEW 10h
        call_api 0110h, t_new
        mov     ax,word ptr first
        mov     word ptr pan,ax
        mov     ax,word ptr first+2
        mov     word ptr pan+2,ax

        mov     savsp,sp              ; OPEN library (length with the 0)
        push    ds
        push    offset lib
        push    0
        mov     ax,lib_len
        inc     ax
        push    ax
        push_pan
        call_api 0C00h, t_open
        call    status
        mov     savsp,sp
        push_pan
        call_api 0800h, t_sizeof
        cmp     flags,'L'             ; L:  LEN too
        jne     @F
        mov     savsp,sp
        push_pan
        call_api 0900h, t_len
@@:     cmp     flags,'A'             ; A:  ADDR, G:  GETNAME (the 32 bytes
        jne     @F                    ; at their first DWORD)
        mov     savsp,sp
        push_pan
        call_api 0300h, t_addr
        call    dumpfirst
@@:     cmp     flags,'G'
        jne     @F
        mov     savsp,sp
        push_pan
        call_api 1200h, t_getname
        call    dumpfirst
@@:
        xor     bx,bx                 ; READ:  apply each name
apply:  cmp     bx,count
        jae     applied
        push    bx
        mov     savsp,sp
        push    ds
        mov     ax,bx
        shl     ax,4
        add     ax,offset names
        push    ax
        push    0
        shl     bx,1
        push    name_lens[bx]
        xor     ax,ax
        xor     dx,dx
        cmp     flags,'O'
        jne     @F
        mov     ax,word ptr own
        mov     dx,word ptr own+2
@@:     push    dx
        push    ax
        push_pan
        call_api 0400h, t_read
        call    status
        call    waitkey
        pop     bx
        inc     bx
        jmp     apply
applied:
        mov     savsp,sp
        push_pan
        call_api 0D00h, t_close
        call    status
        mov     savsp,sp
        push_pan
        call_api 0200h, t_free

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

dumpfirst proc near
        mov     si,offset t_at
        call    puts
        push    ds
        lds     si,first
        mov     cx,32
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        pop     ds
        call    putnl
        call    flush
        ret
dumpfirst endp

status  proc near
        mov     savsp,sp
        push_pan
        call_api 0F00h, t_status
        ret
status  endp

; the next blank-separated word at SI to DI (0 ended), CX its length;
; CF when there is none
word_arg proc near
@@:     lodsb
        cmp     al,' '
        je      @B
        cmp     al,13
        je      wa_none
        xor     cx,cx
@@:     stosb
        inc     cx
        lodsb
        cmp     al,' '
        je      @F
        cmp     al,13
        jne     @B
@@:     dec     si
        mov     byte ptr [di],0
        clc
        ret
wa_none: dec    si
        stc
        ret
word_arg endp

; after a call:  the bytes it left (savsp - SP) and up to four DWORDs, the
; first kept (first); the stack back to savsp; the line out
recres  proc near
        pop     dx                    ; (return address)
        mov     bp,sp
        mov     cx,savsp
        sub     cx,sp
        mov     al,' '
        stosb
        mov     ax,cx
        call    putdec
        mov     word ptr first,0
        mov     word ptr first+2,0
        cmp     cx,4
        jb      rec_dw
        mov     ax,[bp]
        mov     word ptr first,ax
        mov     ax,[bp+2]
        mov     word ptr first+2,ax
rec_dw: shr     cx,2
        cmp     cx,4
        jbe     @F
        mov     cx,4
@@:     jcxz    rec_end
@@:     mov     al,' '
        stosb
        push    dx
        mov     dx,[bp]
        mov     ax,[bp+2]
        call    putptr
        pop     dx
        add     bp,4
        loop    @B
rec_end: mov    sp,savsp
        push    dx
        call    putnl
        call    flush
        ret
recres  endp

waitkey proc near
        mov     dx,offset t_ready
        mov     ah,9
        int     21h
        xor     ah,ah
        int     16h
        ret
waitkey endp

; the line (up to DI) to the file, committed
flush   proc near
        push    ax
        push    bx
        push    cx
        push    dx
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
        pop     dx
        pop     cx
        pop     bx
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

; the text at SI (0 ends) and a blank to the screen
say     proc near
        push    ax
        push    dx
@@:     lodsb
        or      al,al
        jz      @F
        mov     dl,al
        mov     ah,2
        int     21h
        jmp     @B
@@:     mov     dl,' '
        mov     ah,2
        int     21h
        pop     dx
        pop     ax
        ret
say     endp

putnl   proc near
        mov     ax,0A0Dh
        stosw
        ret
putnl   endp

t_own   db      'own',0
t_kbd   db      'kbd',0
t_new   db      'new',0
t_open  db      'open',0
t_status db     'status',0
t_sizeof db     'sizeof',0
t_len   db      'len',0
t_addr  db      'addr',0
t_getname db    'getname',0
t_at    db      '  at',0
t_read  db      'read',0
t_close db      'close',0
t_free  db      'free',0
t_ready db      'panprb ready',13,10,'$'
utext   db      'PANPRB file library flags name...',13,10,'$'
handle  dw      0
savsp   dw      0
count   dw      0
pan     dd      0
own     dd      0
first   dd      0
lib_len dw      0
name_lens dw    6 dup (0)
fname   db      80 dup (0)
lib     db      80 dup (0)
flags   db      16 dup (0)
names   db      6*16 dup (0)
line    db      600 dup (?)

        end     start
