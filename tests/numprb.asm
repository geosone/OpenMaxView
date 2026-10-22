; SPDX-License-Identifier: GPL-3.0-or-later
; DESQview numbered field records (tests/qemu):  NUMPRB m file
;   "numprb ready" on row 10 (DOS), then a WRITE 01h of a window stream
;   FFh:  header 3 fields, 40h + mode m (2:  all fields, 3:  modified ones,
;   numbered records), current 1, select attributes 70h 1Fh; field 1 row
;   3 columns 10-14 fill-in, field 2 row 4 columns 10-14 select (key "B",
;   07h), field 3 row 5 columns 10-12 fill-in, and F4h 1; then the
;   keyboard to field mode with the cursor (ADDTO 05h bits 03h) and
;   READ 05h:
;   "r LLLLLLLL hh hh .."  the length on top, the bytes (32 at most)
;   "st SSSSSSSS"          STATUS 05h (why the field manager returned)
;   "hdr hh hh hh hh hh hh t1 t2"  the header and the two type bytes in
;                          the stream after it
; Typed for it (tests):  "ab", Enter.

        .model tiny
        .386
        .code
        org 100h

start:
        mov     si,81h
@@:     lodsb
        cmp     al,' '
        je      @B
        sub     al,'0'
        and     al,3
        or      fhdr+1,al
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

        mov     ah,2            ; "numprb ready" on row 10
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
        cmp     cx,32
        jbe     @F
        mov     cx,32
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

utext   db      'NUMPRB m file',13,10,'$'
t_ready db      'numprb ready',13,10,'$'
t_r     db      'r ',0
t_st    db      'st ',0
t_hdr   db      'hdr',0
stream  db      1Bh,00h
        dw      sbody_end - sbody
sbody   db      0FFh
fhdr    db      3,40h,1,0,70h,1Fh
        db      3,10,3,14
f1type  db      80h
        db      0,70h
        db      4,10,4,14
f2type  db      0C0h
        db      'B',07h
        db      5,10,5,12
f3type  db      80h
        db      0,70h
        db      0F4h,1          ; the cursor to field 1
sbody_end label byte
streamlen equ   $ - stream
handle  dw      0
d1      dd      0
d2      dd      0
fname   db      80 dup (0)
line    db      160 dup (0)

        end     start
