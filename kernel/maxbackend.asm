; SPDX-License-Identifier: GPL-3.0-or-later
; Open 386MAX Open-MaxView backend discovery wrapper for 16-bit C callers.

        .model  small
        .386
        .code

        public  odq_max_backend_query_
        public  odq_max_context_clone_
        public  odq_max_context_release_
        public  odq_max_context_activate_
        public  odq_max_context_restore_

MV_QUERY        equ 04D00h
MV_STATUS       equ 04D01h
MV_ABI_1_0      equ 00100h
MV_SIGNATURE_1  equ 04D56h
MV_SIGNATURE_2  equ 04D58h
MV_CAP_STATUS   equ 00001h
MV_ROOT_CONTEXT equ 00001h
QPI_VERSION     equ 00300h
QPI_ALLOC_PAGE  equ 00400h
QPI_FREE_PAGE   equ 00500h
QPI_CLONE_TABLE equ 00600h
QPI_GET_CONTEXT equ 00700h
QPI_SET_CONTEXT equ 00800h

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
        mov     word ptr cs:qpi_context_ready,0

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
        jz      short int67_signature_ok
        jmp     backend_absent
int67_signature_ok:
        mov     ax,es
        or      ax,di
        jnz     short backend_found
        jmp     backend_absent
backend_found:
        mov     word ptr cs:qpi_entry,di
        mov     ax,es
        mov     word ptr cs:qpi_entry+2,ax

        mov     ax,MV_QUERY
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short query_returned
        add     sp,2
        jmp     backend_absent
query_returned:
        ; The legacy QPI entry is a FAR procedure.  PUSHF is required by the
        ; interface but its word is not consumed by the callee.
        add     sp,2
        cmp     ax,MV_ABI_1_0
        jae     short abi_version_ok
        jmp     backend_absent
abi_version_ok:
        cmp     bx,MV_SIGNATURE_1
        je      short signature_1_ok
        jmp     backend_absent
signature_1_ok:
        cmp     cx,MV_SIGNATURE_2
        je      short signature_2_ok
        jmp     backend_absent
signature_2_ok:
        test    dx,MV_CAP_STATUS
        jnz     short status_capability_ok
        jmp     backend_absent
status_capability_ok:

        mov     word ptr [si],ax
        mov     word ptr [si+2],dx

        mov     ax,MV_STATUS
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short status_returned
        add     sp,2
        jmp     backend_absent
status_returned:
        add     sp,2
        or      ax,ax
        jnz     short backend_absent
        mov     word ptr [si+4],bx
        mov     word ptr [si+6],cx
        mov     word ptr [si+8],dx

        ; The private 4Dxxh ABI identifies Open 386MAX and reports its
        ; administrative status.  Standard QPI calls expose the page-table
        ; context used by the future scheduler.  They are optional here so
        ; older ABI 1.0 builds remain detectable.
        mov     word ptr [si+10],0
        mov     dword ptr [si+12],0
        mov     ax,QPI_VERSION
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short qpi_version_returned
        add     sp,2
        jmp     short backend_present
qpi_version_returned:
        add     sp,2
        or      ax,ax
        jz      short backend_present
        cmp     ax,bx
        jne     short backend_present
        mov     word ptr [si+10],ax

        mov     ax,QPI_GET_CONTEXT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short qpi_context_returned
        add     sp,2
        jmp     short backend_present
qpi_context_returned:
        add     sp,2
        mov     dword ptr [si+12],edx
        test    edx,edx
        jz      short backend_present
        cmp     word ptr [si+4],MV_ROOT_CONTEXT
        jne     short backend_present
        cmp     dword ptr cs:qpi_root_context,0
        jne     short qpi_root_known
        mov     dword ptr cs:qpi_root_context,edx
qpi_root_known:
        mov     word ptr cs:qpi_context_ready,1
backend_present:
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

odq_max_backend_query_ endp

; Allocate one physical page and clone the active 0-4 MB page table into it.
; The clone is not activated. If cloning fails, release the allocated page.
odq_max_context_clone_ proc near
        push    si
        mov     si,ax
        or      si,si
        jz      short context_clone_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short context_clone_failed
        cmp     dword ptr cs:qpi_owned_context,0
        jne     short context_clone_failed

        mov     ax,QPI_ALLOC_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_page_allocated
        add     sp,2
        jmp     short context_clone_failed
context_page_allocated:
        add     sp,2
        push    edx
        mov     ax,QPI_CLONE_TABLE
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_table_cloned
        add     sp,2
        pop     edx
        mov     ax,QPI_FREE_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        add     sp,2
        jmp     short context_clone_failed
context_table_cloned:
        add     sp,2
        pop     edx
        mov     dword ptr [si],edx
        mov     dword ptr cs:qpi_owned_context,edx
        mov     ax,1
        pop     si
        ret
context_clone_failed:
        xor     ax,ax
        pop     si
        ret
odq_max_context_clone_ endp

; Release a non-active clone and clear the caller's token on success.
odq_max_context_release_ proc near
        push    si
        mov     si,ax
        or      si,si
        jz      short context_release_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short context_release_failed
        mov     edx,dword ptr [si]
        test    edx,edx
        jz      short context_release_failed
        cmp     edx,dword ptr cs:qpi_owned_context
        jne     short context_release_failed
        cmp     word ptr cs:qpi_owned_active,0
        jne     short context_release_failed
        mov     ax,QPI_FREE_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_released
        add     sp,2
        jmp     short context_release_failed
context_released:
        add     sp,2
        mov     dword ptr [si],0
        mov     dword ptr cs:qpi_owned_context,0
        mov     ax,1
        pop     si
        ret
context_release_failed:
        xor     ax,ax
        pop     si
        ret
odq_max_context_release_ endp

; Activate only the clone owned by this layer and verify QPI 07h afterwards.
odq_max_context_activate_ proc near
        push    si
        mov     si,ax
        or      si,si
        jz      short context_activate_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short context_activate_failed
        cmp     word ptr cs:qpi_owned_active,0
        jne     short context_activate_failed
        mov     edx,dword ptr [si]
        cmp     edx,dword ptr cs:qpi_owned_context
        jne     short context_activate_failed

        mov     ax,QPI_SET_CONTEXT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_switch_returned
        add     sp,2
        jmp     short context_activate_failed
context_switch_returned:
        add     sp,2
        mov     word ptr cs:qpi_owned_active,1
        mov     ax,QPI_GET_CONTEXT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_switch_observed
        add     sp,2
        jmp     short context_activate_recover
context_switch_observed:
        add     sp,2
        cmp     edx,dword ptr cs:qpi_owned_context
        jne     short context_activate_recover
        mov     ax,1
        pop     si
        ret
context_activate_recover:
        call    odq_max_context_restore_
context_activate_failed:
        xor     ax,ax
        pop     si
        ret
odq_max_context_activate_ endp

; Return to the baseline captured by the first successful QPI 07h query.
; The active flag is cleared only after a second 07h verifies the transition.
odq_max_context_restore_ proc near
        cmp     word ptr cs:qpi_context_ready,1
        jne     short context_restore_failed
        mov     edx,dword ptr cs:qpi_root_context
        test    edx,edx
        jz      short context_restore_failed
        mov     ax,QPI_SET_CONTEXT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_restore_returned
        add     sp,2
        jmp     short context_restore_failed
context_restore_returned:
        add     sp,2
        mov     ax,QPI_GET_CONTEXT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short context_restore_observed
        add     sp,2
        jmp     short context_restore_failed
context_restore_observed:
        add     sp,2
        cmp     edx,dword ptr cs:qpi_root_context
        jne     short context_restore_failed
        mov     word ptr cs:qpi_owned_active,0
        mov     ax,1
        ret
context_restore_failed:
        xor     ax,ax
        ret
odq_max_context_restore_ endp

qpi_entry         dd 0
qpi_context_ready dw 0
qpi_owned_context dd 0
qpi_root_context  dd 0
qpi_owned_active  dw 0

        end
