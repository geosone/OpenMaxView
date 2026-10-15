; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView resident compatibility API, 16-bit DOS .COM program.
;
; Assembled by the JWasm embedded in Open 386MAX and linked by JWlink.
;
; Implemented compatibility surface:
;   INT 21h AX=2B01h CX='DE' DX='SQ'  presence/version query
;   INT 15h AX=1000h                 cooperative PAUSE
;   INT 15h AX=101Bh/101Ch           nested critical-section markers
;   INT 15h AX=DE10h, BX=scan/char   foreground keyboard PUSHKEY
;   INT 10h AH=FEh                   alternate text-video buffer
;   INT 10h AH=FFh                   video-buffer change notification
;   INT 2Fh AX=D700h                 Open MaxView-private status query
;   INT 2Fh AX=D701h                 private capabilities/state query
;   INT 2Fh AX=D702h                 reset per-foreground-task state

DV_VERSION     equ 0280h
MUX_STATUS     equ 0D700h
MUX_INFO       equ 0D701h
MUX_RESET      equ 0D702h
MUX_SIGNATURE  equ 04F44h            ; "OD" in register byte order
MUX_VERSION    equ 0003h
CAPABILITIES   equ 001Fh

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
        mov     ah,0Fh
        int     10h
        mov     word ptr video_segment,0B800h
        cmp     al,7
        jne     short video_known
        mov     word ptr video_segment,0B000h
video_known:
        mov     ax,3510h
        int     21h
        mov     word ptr old10,bx
        mov     word ptr old10+2,es

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

        mov     dx,offset int10_handler
        mov     ax,2510h
        int     21h
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
        pushf
        cmp     ax,2B01h
        jne     int21_chain
        cmp     cx,4445h              ; 'DE'
        jne     int21_chain
        cmp     dx,5351h              ; 'SQ'
        jne     int21_chain
        mov     bx,DV_VERSION
        xor     al,al
        popf
        iret
int21_chain:
        popf
        jmp     dword ptr cs:old21

int10_handler:
        pushf
        cmp     ah,0FEh
        je      short int10_buffer
        cmp     ah,0FFh
        je      short int10_handled
        jmp     short int10_chain
int10_buffer:
        mov     es,word ptr cs:video_segment
        xor     di,di
int10_handled:
        popf
        iret
int10_chain:
        popf
        jmp     dword ptr cs:old10

int15_handler:
        pushf
        cmp     ax,1000h              ; PAUSE
        je      int15_handled
        cmp     ax,101Bh              ; BEGINC
        je      short int15_begin
        cmp     ax,101Ch              ; ENDC
        je      short int15_end
        cmp     ax,0DE10h             ; PUSHKEY
        je      short int15_pushkey
        jmp     short int15_chain
int15_begin:
        cmp     word ptr cs:critical_depth,0FFFFh
        je      short int15_handled
        inc     word ptr cs:critical_depth
        jmp     short int15_handled
int15_end:
        cmp     word ptr cs:critical_depth,0
        je      short int15_handled
        dec     word ptr cs:critical_depth
        jmp     short int15_handled
int15_pushkey:
        push    ax
        push    dx
        push    di
        push    es
        mov     ax,40h                ; BIOS data area
        mov     es,ax
        mov     di,word ptr es:[1Ch]  ; keyboard-buffer tail
        mov     ax,di
        add     ax,2
        cmp     ax,3Eh
        jb      short pushkey_nowrap
        mov     ax,1Eh
pushkey_nowrap:
        cmp     ax,word ptr es:[1Ah]  ; full when next tail is head
        je      short pushkey_done
        mov     word ptr es:[di],bx   ; BH scan code, BL character
        mov     word ptr es:[1Ch],ax
pushkey_done:
        pop     es
        pop     di
        pop     dx
        pop     ax
int15_handled:
        popf
        iret
int15_chain:
        popf
        jmp     dword ptr cs:old15

int2f_handler:
        pushf
        cmp     ax,MUX_STATUS
        je      short int2f_status
        cmp     ax,MUX_INFO
        je      short int2f_info
        cmp     ax,MUX_RESET
        je      short int2f_reset
        jmp     short int2f_chain
int2f_status:
        mov     bx,MUX_SIGNATURE
        mov     cx,MUX_VERSION        ; resident API version
        mov     dx,DV_VERSION
        popf
        iret
int2f_info:
        mov     bx,CAPABILITIES
        mov     cx,word ptr cs:critical_depth
        mov     dx,word ptr cs:video_segment
        popf
        iret
int2f_reset:
        mov     word ptr cs:critical_depth,0
        popf
        iret
int2f_chain:
        popf
        jmp     dword ptr cs:old2f

old10          dd 0
old15          dd 0
old21          dd 0
old2f          dd 0
critical_depth dw 0
video_segment  dw 0B800h

installed_msg  db 'Open MaxView resident API 0.3 installed.',13,10,'$'
already_msg    db 'Open MaxView resident API is already installed.',13,10,'$'

resident_end:

        end     start
