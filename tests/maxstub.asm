; SPDX-License-Identifier: GPL-3.0-or-later
; Test-only Open 386MAX MaxView backend stub.  Not part of the package.

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds
        mov     ax,352Fh
        int     21h
        mov     word ptr old2f,bx
        mov     word ptr old2f+2,es
        mov     dx,offset int2f_handler
        mov     ax,252Fh
        int     21h
        mov     dx,offset resident_end
        add     dx,15
        mov     cl,4
        shr     dx,cl
        mov     ax,3100h
        int     21h

int2f_handler:
        cmp     ax,1684h
        jne     short int2f_chain
        cmp     bx,4354h
        jne     short int2f_chain
        push    cs
        pop     es
        mov     di,offset qpi_entry
        iret
int2f_chain:
        jmp     dword ptr cs:old2f

qpi_entry:
        cmp     ax,4D00h
        je      short qpi_query
        cmp     ax,4D01h
        je      short qpi_status
        mov     ax,1
        stc
        retf
qpi_query:
        mov     ax,0100h
        mov     bx,4D56h
        mov     cx,4D58h
        mov     dx,0001h
        clc
        retf
qpi_status:
        xor     ax,ax
        mov     bx,0001h
        mov     cx,0002h
        mov     dx,0004h
        clc
        retf

old2f           dd 0
resident_end:
        end     start
