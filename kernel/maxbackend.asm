; SPDX-License-Identifier: GPL-3.0-or-later
; Open 386MAX Open-MaxView backend discovery wrapper for 16-bit C callers.

        .8086
        .model  small
        .code

        public  odq_max_backend_query_

MV_QUERY        equ 04D00h
MV_STATUS       equ 04D01h
MV_ABI_1_0      equ 00100h
MV_SIGNATURE_1  equ 04D56h
MV_SIGNATURE_2  equ 04D58h
MV_CAP_STATUS   equ 00001h

odq_max_backend_query_ proc near
        push    bp
        mov     bp,sp
        push    si
        push    di
        push    es

        ; Open Watcom's default 16-bit register convention passes the first
        ; near pointer in AX.  Keep it in a preserved register while AX is
        ; used for QPI discovery and calls.
        mov     si,ax

        xor     di,di
        mov     es,di
        mov     ax,1684h
        mov     bx,4354h
        int     2Fh
        mov     ax,es
        or      ax,di
        jnz     short backend_found

        ; Older QPI clients discover the same entry through INT 67h.
        ; Open 386MAX keeps this path for QEMM-compatible environments.
        xor     di,di
        mov     es,di
        mov     ax,3F00h
        mov     cx,5145h              ; 'QE'
        mov     dx,4D4Dh              ; 'MM'
        int     67h
        or      ah,ah
        jnz     short backend_absent
        mov     ax,es
        or      ax,di
        jz      short backend_absent
backend_found:
        mov     word ptr cs:qpi_entry,di
        mov     ax,es
        mov     word ptr cs:qpi_entry+2,ax

        mov     ax,MV_QUERY
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short query_returned
        add     sp,2
        jmp     short backend_absent
query_returned:
        ; The legacy QPI entry is a FAR procedure.  PUSHF is required by the
        ; interface but its word is not consumed by the callee.
        add     sp,2
        cmp     ax,MV_ABI_1_0
        jb      short backend_absent
        cmp     bx,MV_SIGNATURE_1
        jne     short backend_absent
        cmp     cx,MV_SIGNATURE_2
        jne     short backend_absent
        test    dx,MV_CAP_STATUS
        jz      short backend_absent

        mov     word ptr [si],ax
        mov     word ptr [si+2],dx

        mov     ax,MV_STATUS
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short status_returned
        add     sp,2
        jmp     short backend_absent
status_returned:
        add     sp,2
        or      ax,ax
        jnz     short backend_absent
        mov     word ptr [si+4],bx
        mov     word ptr [si+6],cx
        mov     word ptr [si+8],dx
        mov     ax,1
        jmp     short backend_done

backend_absent:
        xor     ax,ax
backend_done:
        pop     es
        pop     di
        pop     si
        pop     bp
        ret

qpi_entry       dd 0

odq_max_backend_query_ endp
        end
