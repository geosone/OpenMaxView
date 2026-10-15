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
        je      short qpi_clone
        cmp     ax,0800h
        je      short qpi_is_switch
        cmp     ax,0900h
        je      short qpi_is_map_query
        cmp     ax,0A00h
        je      short qpi_is_map_set
        jmp     short qpi_not_switch
qpi_is_switch:
        jmp     qpi_switch
qpi_is_free:
        jmp     qpi_free
qpi_is_map_query:
        jmp     qpi_map_query
qpi_is_map_set:
        jmp     qpi_map_set
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
        stc
        retf
qpi_alloc_available:
        mov     byte ptr cs:qpi_allocated,1
        mov     word ptr cs:qpi_mapping_page,0FFFFh
        mov     edx,00005678h
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
        je      short qpi_error
        mov     byte ptr cs:qpi_allocated,0
        mov     word ptr cs:qpi_mapping_page,0FFFFh
        clc
        retf
qpi_switch:
        cmp     edx,00001234h
        je      short qpi_switch_valid
        cmp     byte ptr cs:qpi_allocated,1
        jne     short qpi_error
        cmp     edx,00005678h
        jne     short qpi_error
qpi_switch_valid:
        mov     dword ptr cs:qpi_active_context,edx
        clc
        retf
qpi_map_query:
        cmp     dword ptr cs:qpi_active_context,00005678h
        jne     short qpi_error
        cmp     cx,03FFh
        ja      short qpi_error
        cmp     cx,word ptr cs:qpi_mapping_page
        jne     short qpi_map_identity
        mov     dx,word ptr cs:qpi_mapping_frame
        clc
        retf
qpi_map_identity:
        mov     dx,cx
        clc
        retf
qpi_map_set:
        cmp     dword ptr cs:qpi_active_context,00005678h
        jne     short qpi_error
        cmp     cx,03FFh
        ja      short qpi_error
        mov     word ptr cs:qpi_mapping_page,cx
        mov     word ptr cs:qpi_mapping_frame,dx
        clc
        retf
qpi_error:
        stc
        retf

old2f           dd 0
qpi_allocated   db 0
qpi_active_context dd 00001234h
qpi_mapping_page dw 0FFFFh
qpi_mapping_frame dw 0
resident_end:
        end     start
