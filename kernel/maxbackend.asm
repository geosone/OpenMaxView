; SPDX-License-Identifier: GPL-3.0-or-later
; Open 386MAX Open-MaxView backend discovery wrapper for 16-bit C callers.
; Public entry points preserve Open Watcom register parameters not consumed by
; their signatures; QPI scratch values must not escape into optimized C code.

        .model  small
        .386
        .code

        public  odq_max_backend_query_
        public  odq_max_context_clone_
        public  odq_max_context_release_
        public  odq_max_context_activate_
        public  odq_max_context_restore_
        public  odq_max_page_allocate_
        public  odq_max_page_release_
        public  odq_max_mapping_query_
        public  odq_max_mapping_install_
        public  odq_max_mapping_commit_
        public  odq_max_mapping_restore_
        public  odq_max_irq_master_install_
        public  odq_max_irq_master_inject_
        public  odq_max_irq_master_remove_

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
QPI_GET_MAPPING equ 00900h
QPI_SET_MAPPING equ 00A00h
QPI_IRQ_MASTER_OFF equ 01C00h
QPI_IRQ_MASTER_ON  equ 01C01h
QPI_IRQ_INJECT     equ 01C04h
QPI_LAST_PAGE   equ 003FFh
QPI_PAGE_SLOTS  equ 4
QPI_PAGE_BYTES  equ QPI_PAGE_SLOTS * 4
QPI_MAP_SLOTS   equ 4
QPI_MAP_BYTES   equ QPI_MAP_SLOTS * 2

odq_max_backend_query_ proc near
        push    bp
        mov     bp,sp
        push    bx
        push    cx
        push    edx
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
        pop     edx
        pop     cx
        pop     bx
        pop     bp
        ret

odq_max_backend_query_ endp

; Allocate one physical page and clone the active 0-4 MB page table into it.
; The clone is not activated. If cloning fails, release the allocated page.
odq_max_context_clone_ proc near
        push    si
        push    bx
        push    cx
        push    edx
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
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
context_clone_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_context_clone_ endp

; Release a non-active clone and clear the caller's token on success.
odq_max_context_release_ proc near
        push    si
        push    bx
        push    cx
        push    edx
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
        cmp     word ptr cs:qpi_mapping_count,0
        jne     short context_release_failed
        cmp     word ptr cs:qpi_owned_page_count,0
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
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
context_release_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_context_release_ endp

; Activate only the clone owned by this layer and verify QPI 07h afterwards.
odq_max_context_activate_ proc near
        push    si
        push    bx
        push    cx
        push    edx
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
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
context_activate_recover:
        call    odq_max_context_restore_
context_activate_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_context_activate_ endp

; Return to the baseline captured by the first successful QPI 07h query.
; The active flag is cleared only after a second 07h verifies the transition.
odq_max_context_restore_ proc near
        push    bx
        push    cx
        push    edx
        cmp     word ptr cs:qpi_context_ready,1
        jne     short context_restore_failed
        cmp     word ptr cs:qpi_mapping_count,0
        je      short context_restore_mapping_ok
        mov     ax,word ptr cs:qpi_mapping_count
        cmp     ax,word ptr cs:qpi_mapping_committed_count
        jne     short context_restore_failed
context_restore_mapping_ok:
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
        pop     edx
        pop     cx
        pop     bx
        ret
context_restore_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        ret
odq_max_context_restore_ endp

; Allocate one private physical data page while the root context is active.
; Keep the complete QPI 04h frame; the mapping layer separately rejects frames
; that cannot be represented by QPI 0Ah. Ownership uses a fixed-size pool.
odq_max_page_allocate_ proc near
        push    si
        push    bx
        push    cx
        push    edx
        mov     si,ax
        or      si,si
        jz      short page_allocate_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short page_allocate_failed
        cmp     dword ptr cs:qpi_owned_context,0
        je      short page_allocate_failed
        cmp     word ptr cs:qpi_owned_active,0
        jne     short page_allocate_failed
        cmp     word ptr cs:qpi_mapping_count,0
        jne     short page_allocate_failed

        xor     bx,bx
page_allocate_find_slot:
        cmp     dword ptr cs:qpi_owned_pages[bx],0
        je      short page_allocate_slot_found
        add     bx,4
        cmp     bx,QPI_PAGE_BYTES
        jb      short page_allocate_find_slot
        jmp     short page_allocate_failed

page_allocate_slot_found:
        push    bx
        mov     ax,QPI_ALLOC_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short page_allocate_returned
        add     sp,2
        pop     bx
        jmp     short page_allocate_failed
page_allocate_returned:
        add     sp,2
        pop     bx
        test    edx,edx
        jz      short page_allocate_rollback
        mov     dword ptr [si],edx
        mov     dword ptr cs:qpi_owned_pages[bx],edx
        inc     word ptr cs:qpi_owned_page_count
        mov     ax,1
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
page_allocate_rollback:
        mov     ax,QPI_FREE_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        add     sp,2
page_allocate_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_page_allocate_ endp

; Release only the page owned here, after the clone mapping has been restored
; and the verified root context is active again.
odq_max_page_release_ proc near
        push    si
        push    bx
        push    cx
        push    edx
        mov     si,ax
        or      si,si
        jz      short page_release_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short page_release_failed
        cmp     word ptr cs:qpi_owned_active,0
        jne     short page_release_failed
        cmp     word ptr cs:qpi_mapping_count,0
        jne     short page_release_failed
        mov     edx,dword ptr [si]
        test    edx,edx
        jz      short page_release_failed

        xor     bx,bx
page_release_find_slot:
        cmp     edx,dword ptr cs:qpi_owned_pages[bx]
        je      short page_release_slot_found
        add     bx,4
        cmp     bx,QPI_PAGE_BYTES
        jb      short page_release_find_slot
        jmp     short page_release_failed

page_release_slot_found:
        push    bx
        mov     ax,QPI_FREE_PAGE
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short page_released
        add     sp,2
        pop     bx
        jmp     short page_release_failed
page_released:
        add     sp,2
        pop     bx
        mov     dword ptr [si],0
        mov     dword ptr cs:qpi_owned_pages[bx],0
        dec     word ptr cs:qpi_owned_page_count
        mov     ax,1
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
page_release_failed:
        xor     ax,ax
        pop     edx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_page_release_ endp

; Read the physical frame currently mapped at one 4 KB linear page. Mapping
; access is deliberately limited to the clone owned and activated here.
odq_max_mapping_query_ proc near
        push    si
        push    bx
        push    cx
        push    dx
        mov     si,ax
        or      si,si
        jz      short mapping_query_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short mapping_query_failed
        cmp     word ptr cs:qpi_owned_active,1
        jne     short mapping_query_failed
        mov     cx,word ptr [si]
        cmp     cx,QPI_LAST_PAGE
        ja      short mapping_query_failed

        mov     ax,QPI_GET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_query_returned
        add     sp,2
        jmp     short mapping_query_failed
mapping_query_returned:
        add     sp,2
        mov     word ptr [si+4],dx
        mov     ax,1
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret
mapping_query_failed:
        xor     ax,ax
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_mapping_query_ endp

; Save the old frame, install one replacement with QPI 0Ah and verify it
; through QPI 09h. Linear pages are unique within the bounded mapping table.
odq_max_mapping_install_ proc near
        push    si
        push    bx
        push    cx
        push    dx
        mov     si,ax
        or      si,si
        jz      mapping_install_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     mapping_install_failed
        cmp     word ptr cs:qpi_owned_active,1
        jne     mapping_install_failed
        cmp     word ptr cs:qpi_mapping_count,QPI_MAP_SLOTS
        jae     mapping_install_failed
        cmp     word ptr [si+6],0
        jne     mapping_install_failed
        cmp     word ptr [si+8],0
        jne     mapping_install_failed
        mov     cx,word ptr [si]
        cmp     cx,QPI_LAST_PAGE
        ja      mapping_install_failed
        mov     dx,word ptr [si+4]
        call    qpi_page_is_owned
        or      ax,ax
        jz      mapping_install_failed

        mov     cx,word ptr [si]
        xor     bx,bx
mapping_install_duplicate_next:
        cmp     word ptr cs:qpi_mapping_active[bx],0
        je      short mapping_install_duplicate_continue
        cmp     cx,word ptr cs:qpi_mapping_page[bx]
        je      mapping_install_failed
mapping_install_duplicate_continue:
        add     bx,2
        cmp     bx,QPI_MAP_BYTES
        jb      short mapping_install_duplicate_next

        xor     bx,bx
mapping_install_slot_next:
        cmp     word ptr cs:qpi_mapping_active[bx],0
        je      short mapping_install_slot_found
        add     bx,2
        cmp     bx,QPI_MAP_BYTES
        jb      short mapping_install_slot_next
        jmp     mapping_install_failed
mapping_install_slot_found:
        mov     word ptr cs:qpi_mapping_page[bx],cx

        push    bx
        mov     ax,QPI_GET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_original_returned
        add     sp,2
        pop     bx
        jmp     mapping_install_failed
mapping_original_returned:
        add     sp,2
        pop     bx
        mov     word ptr [si+2],dx
        mov     word ptr cs:qpi_mapping_original[bx],dx
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        mov     dx,word ptr [si+4]
        mov     word ptr cs:qpi_mapping_target[bx],dx
        mov     word ptr cs:qpi_mapping_active[bx],1
        mov     word ptr cs:qpi_mapping_committed[bx],0
        inc     word ptr cs:qpi_mapping_count
        mov     word ptr [si+6],1
        mov     word ptr [si+8],0

        push    bx
        mov     ax,QPI_SET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_set_returned
        add     sp,2
        pop     bx
        mov     word ptr cs:qpi_mapping_active[bx],0
        mov     word ptr cs:qpi_mapping_page[bx],0
        mov     word ptr cs:qpi_mapping_original[bx],0
        mov     word ptr cs:qpi_mapping_target[bx],0
        dec     word ptr cs:qpi_mapping_count
        mov     word ptr [si+6],0
        mov     word ptr [si+8],0
        jmp     mapping_install_failed
mapping_set_returned:
        add     sp,2
        pop     bx
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        push    bx
        mov     ax,QPI_GET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_verify_returned
        add     sp,2
        pop     bx
        jmp     short mapping_install_recover
mapping_verify_returned:
        add     sp,2
        pop     bx
        cmp     dx,word ptr cs:qpi_mapping_target[bx]
        jne     short mapping_install_recover
        mov     ax,1
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret

mapping_install_recover:
        ; Keep the mapping marked active if restoration fails. That fail-closed
        ; state prevents both a root switch and clone release.
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        mov     dx,word ptr cs:qpi_mapping_original[bx]
        push    bx
        mov     ax,QPI_SET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_recovery_set
        add     sp,2
        pop     bx
        jmp     short mapping_install_failed
mapping_recovery_set:
        add     sp,2
        pop     bx
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        push    bx
        mov     ax,QPI_GET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_recovery_read
        add     sp,2
        pop     bx
        jmp     short mapping_install_failed
mapping_recovery_read:
        add     sp,2
        pop     bx
        cmp     dx,word ptr cs:qpi_mapping_original[bx]
        jne     short mapping_install_failed
        mov     word ptr cs:qpi_mapping_active[bx],0
        mov     word ptr cs:qpi_mapping_committed[bx],0
        mov     word ptr cs:qpi_mapping_page[bx],0
        mov     word ptr cs:qpi_mapping_original[bx],0
        mov     word ptr cs:qpi_mapping_target[bx],0
        dec     word ptr cs:qpi_mapping_count
        mov     word ptr [si+6],0
        mov     word ptr [si+8],0
mapping_install_failed:
        xor     ax,ax
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_mapping_install_ endp

; Mark a verified replacement as persistent in the owned clone. A committed
; mapping may remain in that inactive clone while the verified root is active.
odq_max_mapping_commit_ proc near
        push    si
        push    bx
        mov     si,ax
        or      si,si
        jz      mapping_commit_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     mapping_commit_failed
        cmp     word ptr cs:qpi_owned_active,1
        jne     mapping_commit_failed
        cmp     word ptr [si+6],1
        jne     mapping_commit_failed
        cmp     word ptr [si+8],0
        jne     mapping_commit_failed

        xor     bx,bx
mapping_commit_find:
        cmp     word ptr cs:qpi_mapping_active[bx],1
        jne     short mapping_commit_next
        mov     ax,word ptr [si]
        cmp     ax,word ptr cs:qpi_mapping_page[bx]
        jne     short mapping_commit_next
        mov     ax,word ptr [si+2]
        cmp     ax,word ptr cs:qpi_mapping_original[bx]
        jne     short mapping_commit_next
        mov     ax,word ptr [si+4]
        cmp     ax,word ptr cs:qpi_mapping_target[bx]
        je      short mapping_commit_found
mapping_commit_next:
        add     bx,2
        cmp     bx,QPI_MAP_BYTES
        jb      short mapping_commit_find
        jmp     short mapping_commit_failed
mapping_commit_found:
        cmp     word ptr cs:qpi_mapping_committed[bx],0
        jne     short mapping_commit_failed
        mov     word ptr cs:qpi_mapping_committed[bx],1
        inc     word ptr cs:qpi_mapping_committed_count
        mov     word ptr [si+8],1
        mov     ax,1
        pop     bx
        pop     si
        ret
mapping_commit_failed:
        xor     ax,ax
        pop     bx
        pop     si
        ret
odq_max_mapping_commit_ endp

; Put back the saved frame and clear ownership only after QPI 09h observes it.
odq_max_mapping_restore_ proc near
        push    si
        push    bx
        push    cx
        push    dx
        mov     si,ax
        or      si,si
        jnz     short mapping_restore_pointer_ok
        jmp     mapping_restore_failed
mapping_restore_pointer_ok:
        cmp     word ptr cs:qpi_context_ready,1
        je      short mapping_restore_backend_ok
        jmp     mapping_restore_failed
mapping_restore_backend_ok:
        cmp     word ptr cs:qpi_owned_active,1
        jne     mapping_restore_failed
        cmp     word ptr [si+6],1
        jne     mapping_restore_failed

        xor     bx,bx
mapping_restore_find:
        cmp     word ptr cs:qpi_mapping_active[bx],1
        jne     short mapping_restore_next
        mov     ax,word ptr [si]
        cmp     ax,word ptr cs:qpi_mapping_page[bx]
        jne     short mapping_restore_next
        mov     ax,word ptr [si+2]
        cmp     ax,word ptr cs:qpi_mapping_original[bx]
        jne     short mapping_restore_next
        mov     ax,word ptr [si+4]
        cmp     ax,word ptr cs:qpi_mapping_target[bx]
        je      short mapping_restore_found
mapping_restore_next:
        add     bx,2
        cmp     bx,QPI_MAP_BYTES
        jb      short mapping_restore_find
        jmp     mapping_restore_failed
mapping_restore_found:
        mov     ax,word ptr [si+8]
        cmp     ax,word ptr cs:qpi_mapping_committed[bx]
        jne     mapping_restore_failed
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        mov     dx,word ptr cs:qpi_mapping_original[bx]

        push    bx
        mov     ax,QPI_SET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_restore_set
        add     sp,2
        pop     bx
        jmp     short mapping_restore_failed
mapping_restore_set:
        add     sp,2
        pop     bx
        mov     cx,word ptr cs:qpi_mapping_page[bx]
        push    bx
        mov     ax,QPI_GET_MAPPING
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short mapping_restore_read
        add     sp,2
        pop     bx
        jmp     short mapping_restore_failed
mapping_restore_read:
        add     sp,2
        pop     bx
        cmp     dx,word ptr cs:qpi_mapping_original[bx]
        jne     short mapping_restore_failed
        cmp     word ptr cs:qpi_mapping_committed[bx],0
        je      short mapping_restore_not_committed
        dec     word ptr cs:qpi_mapping_committed_count
mapping_restore_not_committed:
        dec     word ptr cs:qpi_mapping_count
        mov     word ptr cs:qpi_mapping_active[bx],0
        mov     word ptr cs:qpi_mapping_committed[bx],0
        mov     word ptr cs:qpi_mapping_page[bx],0
        mov     word ptr cs:qpi_mapping_original[bx],0
        mov     word ptr cs:qpi_mapping_target[bx],0
        mov     word ptr [si+6],0
        mov     word ptr [si+8],0
        mov     ax,1
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret
mapping_restore_failed:
        xor     ax,ax
        pop     dx
        pop     cx
        pop     bx
        pop     si
        ret
odq_max_mapping_restore_ endp

; Install a complete non-null IRQ0-7 V86 calldown table. QPI copies the
; caller's DS:DI table, so stack or automatic C storage is valid afterwards.
odq_max_irq_master_install_ proc near
        push    si
        push    di
        push    bx
        push    cx
        push    dx
        push    es
        mov     si,ax
        or      si,si
        jz      short irq_master_install_failed
        cmp     word ptr cs:qpi_context_ready,1
        jne     short irq_master_install_failed
        cmp     word ptr cs:qpi_irq_master_active,0
        jne     short irq_master_install_failed
        cmp     word ptr cs:qpi_owned_active,0
        jne     short irq_master_install_failed
        mov     di,si
        mov     cx,8
irq_master_validate_next:
        mov     eax,dword ptr [di]
        test    eax,eax
        jz      short irq_master_install_failed
        add     di,4
        loop    irq_master_validate_next
        mov     di,si
        mov     ax,QPI_IRQ_MASTER_ON
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short irq_master_install_returned
        add     sp,2
        jmp     short irq_master_install_failed
irq_master_install_returned:
        add     sp,2
        mov     word ptr cs:qpi_irq_master_active,1
        mov     ax,1
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
irq_master_install_failed:
        xor     ax,ax
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
odq_max_irq_master_install_ endp

; Inject only a master-PIC hardware vector while this wrapper owns the table.
odq_max_irq_master_inject_ proc near
        push    si
        push    di
        push    bx
        push    cx
        push    dx
        push    es
        mov     si,ax
        cmp     word ptr cs:qpi_context_ready,1
        jne     short irq_master_inject_failed
        cmp     word ptr cs:qpi_irq_master_active,1
        jne     short irq_master_inject_failed
        cmp     si,08h
        jb      short irq_master_inject_failed
        cmp     si,0Fh
        ja      short irq_master_inject_failed
        mov     bx,si
        mov     ax,QPI_IRQ_INJECT
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short irq_master_inject_returned
        add     sp,2
        jmp     short irq_master_inject_failed
irq_master_inject_returned:
        add     sp,2
        mov     ax,1
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
irq_master_inject_failed:
        xor     ax,ax
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
odq_max_irq_master_inject_ endp

; Disable the master calldown. Ownership is cleared only on QPI success.
odq_max_irq_master_remove_ proc near
        push    si
        push    di
        push    bx
        push    cx
        push    dx
        push    es
        cmp     word ptr cs:qpi_context_ready,1
        jne     short irq_master_remove_failed
        cmp     word ptr cs:qpi_irq_master_active,1
        jne     short irq_master_remove_failed
        mov     ax,QPI_IRQ_MASTER_OFF
        pushf
        call    dword ptr cs:qpi_entry
        jnc     short irq_master_remove_returned
        add     sp,2
        jmp     short irq_master_remove_failed
irq_master_remove_returned:
        add     sp,2
        mov     word ptr cs:qpi_irq_master_active,0
        mov     ax,1
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
irq_master_remove_failed:
        xor     ax,ax
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     di
        pop     si
        ret
odq_max_irq_master_remove_ endp

; Return nonzero when DX names a representable page in the owned pool.
qpi_page_is_owned proc near
        push    bx
        or      dx,dx
        jz      short qpi_page_owned_missing
        xor     bx,bx
qpi_page_owned_next:
        cmp     word ptr cs:qpi_owned_pages[bx]+2,0
        jne     short qpi_page_owned_continue
        cmp     dx,word ptr cs:qpi_owned_pages[bx]
        je      short qpi_page_owned_found
qpi_page_owned_continue:
        add     bx,4
        cmp     bx,QPI_PAGE_BYTES
        jb      short qpi_page_owned_next
qpi_page_owned_missing:
        xor     ax,ax
        pop     bx
        ret
qpi_page_owned_found:
        mov     ax,1
        pop     bx
        ret
qpi_page_is_owned endp

qpi_entry         dd 0
qpi_context_ready dw 0
qpi_owned_context dd 0
qpi_root_context  dd 0
qpi_owned_active  dw 0
qpi_owned_page_count dw 0
qpi_owned_pages      dd QPI_PAGE_SLOTS dup (0)
qpi_mapping_count           dw 0
qpi_mapping_committed_count dw 0
qpi_mapping_active          dw QPI_MAP_SLOTS dup (0)
qpi_mapping_committed       dw QPI_MAP_SLOTS dup (0)
qpi_mapping_page            dw QPI_MAP_SLOTS dup (0)
qpi_mapping_original        dw QPI_MAP_SLOTS dup (0)
qpi_mapping_target          dw QPI_MAP_SLOTS dup (0)
qpi_irq_master_active       dw 0

        end
