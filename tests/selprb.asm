; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview input fields (tests/qemu):  SELPRB file
;   "selprb ready" on row 10 (DOS), then a WRITE 01h of a window stream
;   FFh:  header 3 fields, 41h (keyboard selection, packed characters),
;   current 0, select attributes 70h (pointed at) 1Fh (selected); fields
;   rows 3/4/5 columns 10-14, select (C0h), keys "A" "B" "C", normal
;   colour 07h; then the
;   keyboard to field mode with the cursor (ADDTO 05h bits 03h) and
;   READ 05h:
;   "r LLLLLLLL hh hh .."  the length on top, the bytes (16 at most)
;   "st SSSSSSSS"          STATUS 05h (why the field manager returned)
;   "at a1 a2 a3"          the attributes at column 10 of rows 3-5 (AH=08h)
;   "hdr hh hh hh hh hh hh t1 t2 t3"  the header and the three type
;                          bytes in the stream after it
; Typed for it (tests):  "b", then Enter if the READ has not returned.

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
        mov     di,offset line

        mov     ah,2            ; "selprb ready" on row 10
        xor     bh,bh
        mov     dx,0A00h
        int     10h
        mov     dx,offset t_ready
        mov     ah,9
        int     21h

        push    ds              ; WRITE 01h:  the fields
        push    offset stream
        push    0
        push    streamlen
        mov     ax,1200h
        mov     bx,0501h
        int     15h
        push    0               ; ADDTO 05h:  field mode, cursor
        push    3
        mov     ax,1200h
        mov     bx,0A05h
        int     15h

        mov     ax,1200h        ; READ 05h
        mov     bx,0405h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        pop     word ptr d2
        pop     word ptr d2+2
        mov     si,offset t_r
        call    puts
        mov     eax,d1
        call    puthex32
        mov     cx,word ptr d1
        cmp     word ptr d1+2,0
        jne     shown
        cmp     cx,16
        jbe     @F
        mov     cx,16
@@:     jcxz    shown
        push    ds
        lds     si,d2
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        pop     ds
shown:  call    putnl
        mov     si,offset t_st
        call    puts
        mov     ax,1200h
        mov     bx,0F05h
        int     15h
        pop     word ptr d1
        pop     word ptr d1+2
        mov     eax,d1
        call    puthex32
        call    putnl
        mov     si,offset t_at
        call    puts
        mov     ah,3            ; the cursor kept
        xor     bh,bh
        int     10h
        mov     savcur,dx
        mov     row,3
@@:     mov     dh,row
        mov     dl,10
        mov     ah,2
        xor     bh,bh
        int     10h
        mov     ah,8
        int     10h
        mov     al,' '
        stosb
        mov     al,ah
        call    puthex8
        inc     row
        cmp     row,6
        jb      @B
        mov     dx,savcur
        mov     ah,2
        int     10h
        call    putnl
        mov     si,offset t_hdr
        call    puts
        mov     si,offset fhdr
        mov     cx,6
@@:     mov     al,' '
        stosb
        lodsb
        call    puthex8
        loop    @B
        mov     al,' '
        stosb
        mov     al,f1type
        call    puthex8
        mov     al,' '
        stosb
        mov     al,f2type
        call    puthex8
        mov     al,' '
        stosb
        mov     al,f3type
        call    puthex8
        call    putnl

        push    0               ; SUBFROM 05h:  keystroke mode again
        push    3
        mov     ax,1200h
        mov     bx,0B05h
        int     15h
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

puthex32 proc near
        push    eax
        shr     eax,16
        call    puthex
        pop     eax
puthex32 endp                   ; (falls through:  the low word)
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

; text SI to DI
puts    proc near
@@:     lodsb
        or      al,al
        jz      @F
        stosb
        jmp     @B
@@:     ret
puts    endp

; the line (offset line .. DI) + CR LF to the file, committed
putnl   proc near
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
        ret
putnl   endp

utext   db      'SELPRB file',13,10,'$'
t_ready db      'selprb ready',13,10,'$'
t_r     db      'r ',0
t_st    db      'st ',0
t_at    db      'at',0
t_hdr   db      'hdr',0
stream  db      1Bh,00h
        dw      sbody_end - sbody
sbody   db      0FFh
fhdr    db      3,41h,0,0,70h,1Fh
        db      3,10,3,14
f1type  db      0C0h
        db      'A',07h
        db      4,10,4,14
f2type  db      0C0h
        db      'B',07h
        db      5,10,5,14
f3type  db      0C0h
        db      'C',07h
sbody_end label byte
streamlen equ   $ - stream
handle  dw      0
savcur  dw      0
row     db      0
d1      dd      0
d2      dd      0
fname   db      80 dup (0)
line    db      80 dup (0)

        end     start
