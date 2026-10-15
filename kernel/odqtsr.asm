; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView resident compatibility API, 16-bit DOS .COM program.
;
; Assembled by the JWasm embedded in Open 386MAX and linked by JWlink.
;
; Implemented compatibility surface:
;   INT 21h AX=2B01h CX='DE' DX='SQ'  presence/version query
;   INT 15h AX=1000h                 cooperative PAUSE
;   INT 15h AX=101Bh/101Ch           critical-section markers (no-op in 0.1)
;   INT 2Fh AX=D700h                 Open MaxView-private status query

DV_VERSION     equ 0280h
MUX_STATUS     equ 0D700h
MUX_SIGNATURE  equ 04F44h            ; "OD" in register byte order

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds

        mov     ax,MUX_STATUS
        int     2Fh
        cmp     bx,MUX_SIGNATURE
        jne     install
        mov     dx,offset already_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

install:
        mov     ax,3515h
        int     21h
        mov     word ptr old15,bx
        mov     word ptr old15+2,es

        mov     ax,3521h
        int     21h
        mov     word ptr old21,bx
        mov     word ptr old21+2,es

        mov     ax,352Fh
        int     21h
        mov     word ptr old2f,bx
        mov     word ptr old2f+2,es

        mov     dx,offset int15_handler
        mov     ax,2515h
        int     21h
        mov     dx,offset int21_handler
        mov     ax,2521h
        int     21h
        mov     dx,offset int2f_handler
        mov     ax,252Fh
        int     21h

        mov     dx,offset installed_msg
        mov     ah,09h
        int     21h

        mov     dx,offset resident_end
        add     dx,15
        mov     cl,4
        shr     dx,cl
        mov     ax,3100h
        int     21h

int21_handler:
        cmp     ax,2B01h
        jne     int21_chain
        cmp     cx,4445h              ; 'DE'
        jne     int21_chain
        cmp     dx,5351h              ; 'SQ'
        jne     int21_chain
        mov     bx,DV_VERSION
        xor     al,al
        iret
int21_chain:
        jmp     dword ptr cs:old21

int15_handler:
        cmp     ax,1000h              ; PAUSE
        je      int15_handled
        cmp     ax,101Bh              ; BEGINC
        je      int15_handled
        cmp     ax,101Ch              ; ENDC
        je      int15_handled
        jmp     dword ptr cs:old15
int15_handled:
        clc
        iret

int2f_handler:
        cmp     ax,MUX_STATUS
        jne     int2f_chain
        mov     bx,MUX_SIGNATURE
        mov     cx,0001h              ; resident API version
        mov     dx,DV_VERSION
        clc
        iret
int2f_chain:
        jmp     dword ptr cs:old2f

old15          dd 0
old21          dd 0
old2f          dd 0

installed_msg  db 'Open MaxView resident API 0.1 installed.',13,10,'$'
already_msg    db 'Open MaxView resident API is already installed.',13,10,'$'

resident_end:

        end     start
