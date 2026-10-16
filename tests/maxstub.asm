; SPDX-License-Identifier: GPL-3.0-or-later
; Test-only Open 386MAX MaxView backend stub.  Not part of the package.

        .model  tiny
        .386
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
        cmp     ax,0300h
        je      short qpi_version
        cmp     ax,0700h
        je      short qpi_context
        cmp     ax,0400h
        je      short qpi_alloc
        cmp     ax,0500h
        je      short qpi_is_free
        cmp     ax,0600h
        je      short qpi_is_clone
        cmp     ax,0800h
        je      short qpi_is_switch
        cmp     ax,0900h
        je      short qpi_is_map_query
        cmp     ax,0A00h
        je      short qpi_is_map_set
        cmp     ax,1C00h
        je      short qpi_is_irq_master_off
        cmp     ax,1C01h
        je      short qpi_is_irq_master_on
        cmp     ax,1C04h
        je      short qpi_is_irq_inject
        jmp     short qpi_not_switch
qpi_is_switch:
        jmp     qpi_switch
qpi_is_free:
        jmp     qpi_free
qpi_is_clone:
        jmp     qpi_clone
qpi_is_map_query:
        jmp     qpi_map_query
qpi_is_map_set:
        jmp     qpi_map_set
qpi_is_irq_master_off:
        jmp     qpi_irq_master_off
qpi_is_irq_master_on:
        jmp     qpi_irq_master_on
qpi_is_irq_inject:
        jmp     qpi_irq_inject
qpi_not_switch:
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
qpi_version:
        mov     ax,0703h
        mov     bx,ax
        clc
        retf
qpi_context:
        mov     edx,dword ptr cs:qpi_active_context
        clc
        retf
qpi_alloc:
        cmp     byte ptr cs:qpi_allocated,0
        je      short qpi_alloc_available
        test    byte ptr cs:qpi_page_mask,01h
        jz      short qpi_page_0_available
        test    byte ptr cs:qpi_page_mask,02h
        jz      short qpi_page_1_available
        test    byte ptr cs:qpi_page_mask,04h
        jz      short qpi_page_2_available
        test    byte ptr cs:qpi_page_mask,08h
        jz      short qpi_page_3_available
        stc
        retf
qpi_alloc_available:
        mov     byte ptr cs:qpi_allocated,1
        mov     edx,00005678h
        clc
        retf
qpi_page_0_available:
        or      byte ptr cs:qpi_page_mask,01h
        mov     edx,00006789h
        clc
        retf
qpi_page_1_available:
        or      byte ptr cs:qpi_page_mask,02h
        mov     edx,0000678Ah
        clc
        retf
qpi_page_2_available:
        or      byte ptr cs:qpi_page_mask,04h
        mov     edx,0000678Bh
        clc
        retf
qpi_page_3_available:
        or      byte ptr cs:qpi_page_mask,08h
        mov     edx,0000678Ch
        clc
        retf
qpi_clone:
        cmp     byte ptr cs:qpi_allocated,1
        je      short qpi_clone_allocated
        stc
        retf
qpi_clone_allocated:
        cmp     edx,00005678h
        je      short qpi_clone_valid
        stc
        retf
qpi_clone_valid:
        clc
        retf
qpi_free:
        cmp     edx,00006789h
        je      short qpi_free_page_0
        cmp     edx,0000678Ah
        je      short qpi_free_page_1
        cmp     edx,0000678Bh
        je      short qpi_free_page_2
        cmp     edx,0000678Ch
        je      short qpi_free_page_3
        cmp     byte ptr cs:qpi_allocated,1
        je      short qpi_free_allocated
        stc
        retf
qpi_free_allocated:
        cmp     edx,00005678h
        je      short qpi_free_owned
        stc
        retf
qpi_free_owned:
        cmp     dword ptr cs:qpi_active_context,00005678h
        jne     short qpi_free_context_inactive
        stc
        retf
qpi_free_context_inactive:
        cmp     byte ptr cs:qpi_page_mask,0
        jne     short qpi_free_rejected
        mov     byte ptr cs:qpi_allocated,0
        clc
        retf
qpi_free_rejected:
        stc
        retf
qpi_free_page_0:
        test    byte ptr cs:qpi_page_mask,01h
        jz      short qpi_free_rejected
        mov     al,0FEh
        jmp     short qpi_free_page
qpi_free_page_1:
        test    byte ptr cs:qpi_page_mask,02h
        jz      short qpi_free_rejected
        mov     al,0FDh
        jmp     short qpi_free_page
qpi_free_page_2:
        test    byte ptr cs:qpi_page_mask,04h
        jz      short qpi_free_rejected
        mov     al,0FBh
        jmp     short qpi_free_page
qpi_free_page_3:
        test    byte ptr cs:qpi_page_mask,08h
        jz      short qpi_free_rejected
        mov     al,0F7h
qpi_free_page:
        cmp     dword ptr cs:qpi_active_context,00001234h
        je      short qpi_free_page_in_root
        stc
        retf
qpi_free_page_in_root:
        and     byte ptr cs:qpi_page_mask,al
        clc
        retf
qpi_switch:
        cmp     edx,00001234h
        je      short qpi_switch_valid
        cmp     byte ptr cs:qpi_allocated,1
        jne     qpi_error
        cmp     edx,00005678h
        jne     qpi_error
qpi_switch_valid:
        mov     dword ptr cs:qpi_active_context,edx
        clc
        retf
qpi_map_query:
        cmp     dword ptr cs:qpi_active_context,00005678h
        jne     qpi_error
        cmp     cx,03FFh
        ja      qpi_error
        xor     bx,bx
qpi_map_query_next:
        cmp     word ptr cs:qpi_mapping_active[bx],0
        je      short qpi_map_query_continue
        cmp     cx,word ptr cs:qpi_mapping_page[bx]
        je      short qpi_map_query_found
qpi_map_query_continue:
        add     bx,2
        cmp     bx,8
        jb      short qpi_map_query_next
qpi_map_identity:
        mov     dx,cx
        clc
        retf
qpi_map_query_found:
        mov     dx,word ptr cs:qpi_mapping_frame[bx]
        clc
        retf
qpi_map_set:
        cmp     dword ptr cs:qpi_active_context,00005678h
        jne     short qpi_error
        cmp     cx,03FFh
        ja      short qpi_error
        xor     bx,bx
qpi_map_set_find:
        cmp     word ptr cs:qpi_mapping_active[bx],0
        je      short qpi_map_set_next
        cmp     cx,word ptr cs:qpi_mapping_page[bx]
        je      short qpi_map_set_existing
qpi_map_set_next:
        add     bx,2
        cmp     bx,8
        jb      short qpi_map_set_find

        ; The stub's unmodified mapping is identity. Restoring an identity
        ; page that is not in the table is already complete.
        cmp     dx,cx
        je      short qpi_map_set_done
        xor     bx,bx
qpi_map_set_free:
        cmp     word ptr cs:qpi_mapping_active[bx],0
        je      short qpi_map_set_store
        add     bx,2
        cmp     bx,8
        jb      short qpi_map_set_free
        jmp     short qpi_error

qpi_map_set_existing:
        cmp     dx,cx
        jne     short qpi_map_set_store
        mov     word ptr cs:qpi_mapping_active[bx],0
        mov     word ptr cs:qpi_mapping_page[bx],0
        mov     word ptr cs:qpi_mapping_frame[bx],0
        jmp     short qpi_map_set_done
qpi_map_set_store:
        mov     word ptr cs:qpi_mapping_active[bx],1
        mov     word ptr cs:qpi_mapping_page[bx],cx
        mov     word ptr cs:qpi_mapping_frame[bx],dx
qpi_map_set_done:
        clc
        retf
qpi_error:
        stc
        retf

qpi_irq_master_on:
        cmp     byte ptr cs:qpi_irq_enabled,0
        jne     short qpi_error
        mov     word ptr cs:qpi_irq_table,di
        mov     word ptr cs:qpi_irq_table+2,ds
        mov     byte ptr cs:qpi_irq_enabled,1
        clc
        retf
qpi_irq_master_off:
        cmp     byte ptr cs:qpi_irq_enabled,1
        jne     short qpi_error
        mov     byte ptr cs:qpi_irq_enabled,0
        mov     dword ptr cs:qpi_irq_table,0
        clc
        retf
qpi_irq_inject:
        cmp     byte ptr cs:qpi_irq_enabled,1
        jne     short qpi_error
        cmp     bx,08h
        jb      short qpi_error
        cmp     bx,0Fh
        ja      short qpi_error
        sub     bx,08h
        shl     bx,1
        shl     bx,1
        push    ds
        lds     si,dword ptr cs:qpi_irq_table
        pushf
        call    dword ptr [si+bx]
        pop     ds
        clc
        retf

old2f           dd 0
qpi_allocated   db 0
qpi_page_mask   db 0
qpi_active_context dd 00001234h
qpi_mapping_active dw 4 dup (0)
qpi_mapping_page dw 4 dup (0)
qpi_mapping_frame dw 4 dup (0)
qpi_irq_enabled db 0
qpi_irq_table   dd 0
resident_end:
        end     start
