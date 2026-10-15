; SPDX-License-Identifier: GPL-3.0-or-later
; Read-only XMS free-memory query for Open Watcom 16-bit callers.

        .8086
        .model  small
        .code

        public  odq_xms_query_

odq_xms_query_ proc near
        push    si
        push    di
        push    es
        mov     si,ax                   ; total-free output pointer
        mov     di,dx                   ; largest-free output pointer

        mov     ax,4300h
        int     2Fh
        cmp     al,80h
        jne     short xms_absent
        mov     ax,4310h
        int     2Fh
        mov     word ptr cs:xms_entry,bx
        mov     ax,es
        mov     word ptr cs:xms_entry+2,ax

        mov     ah,08h
        call    dword ptr cs:xms_entry
        mov     word ptr [si],dx
        mov     word ptr [di],ax
        mov     ax,1
        jmp     short xms_done

xms_absent:
        xor     ax,ax
xms_done:
        pop     es
        pop     di
        pop     si
        ret

xms_entry       dd 0

odq_xms_query_ endp
        end
