; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox conformance probe for bounded timer NEW/FREE object lifecycles.

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds

        ; Allocate the complete four-object timer pool.
        xor     si,si
        mov     cx,4
allocate_loop:
        call    new_timer
        or      dx,dx                 ; public handles are segment:0000
        jnz     failed
        or      ax,ax
        jz      failed
        cmp     si,0
        je      short allocate_unique
        cmp     ax,word ptr timer_segments
        je      failed
        cmp     si,2
        je      short allocate_unique
        cmp     ax,word ptr timer_segments+2
        je      failed
        cmp     si,4
        je      short allocate_unique
        cmp     ax,word ptr timer_segments+4
        je      failed
allocate_unique:
        mov     word ptr timer_segments[si],ax
        add     si,2
        loop    allocate_loop

        ; A fifth timer fails cleanly with a null pointer.
        call    new_timer
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        ; ISOBJ and object type recognize a live timer.
        mov     ax,word ptr timer_segments
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        cmp     bx,0FFFFh
        jne     failed
        mov     ax,0DE14h
        int     15h
        cmp     bl,0Bh
        jne     failed

        ; HANDLE selector 00h validates the same timer identity.
        mov     ax,word ptr timer_segments
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        xor     bx,bx
        int     15h
        pop     di
        pop     es
        or      di,di
        jnz     failed
        mov     ax,es
        cmp     ax,word ptr timer_segments
        jne     failed

        ; OBJNEXT enumerates the task first and then all live timers.
        xor     ax,ax
        mov     es,ax
        xor     di,di
        mov     ax,0DE2Bh
        int     15h
        or      ax,ax
        jnz     failed
        mov     ax,es
        or      ax,ax
        jz      failed
        xor     si,si
        mov     cx,4
enumerate_loop:
        mov     ax,0DE2Bh
        int     15h
        or      ax,ax
        jnz     failed
        or      di,di
        jnz     failed
        mov     ax,es
        cmp     ax,word ptr timer_segments[si]
        jne     failed
        add     si,2
        loop    enumerate_loop
        mov     ax,0DE2Bh
        int     15h
        or      ax,ax
        jnz     failed
        or      di,di
        jnz     failed
        mov     ax,es
        or      ax,ax
        jnz     failed

        ; FREE invalidates one handle and NEW deterministically reuses it.
        mov     ax,word ptr timer_segments+2
        call    free_timer
        mov     ax,word ptr timer_segments+2
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
        jnz     failed
        mov     ax,0DE14h
        int     15h
        or      bl,bl
        jnz     failed
        call    new_timer
        or      dx,dx
        jnz     failed
        cmp     ax,word ptr timer_segments+2
        jne     failed

        ; A foreground-task reset reclaims the complete timer pool.
        mov     ax,0D702h
        int     2Fh
        xor     si,si
        mov     cx,4
reset_validate_loop:
        mov     ax,word ptr timer_segments[si]
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
        jnz     failed
        add     si,2
        loop    reset_validate_loop

        ; The reset pool can allocate again and explicit FREE cleans it up.
        call    new_timer
        or      dx,dx
        jnz     failed
        cmp     ax,word ptr timer_segments
        jne     failed
        call    free_timer

        mov     dx,offset passed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

failed:
        mov     dx,offset failed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

; Return the NEW result in AX:DX as segment:offset.
new_timer:
        push    bx
        xor     ax,ax
        push    ax                    ; reserved segment
        push    ax                    ; reserved offset
        mov     ax,1200h
        mov     bx,010Bh              ; NEW TIMER
        int     15h
        pop     dx
        pop     ax
        pop     bx
        ret

; Free the timer whose segment arrives in AX.
free_timer:
        push    bx
        push    ax                    ; handle segment
        xor     ax,ax
        push    ax                    ; handle offset
        mov     ax,1200h
        mov     bx,0200h              ; FREE object
        int     15h
        add     sp,4
        pop     bx
        ret

timer_segments dw 4 dup(0)
passed_msg db 'MAXVTSR timer object lifecycle passed.',13,10,'$'
failed_msg db 'MAXVTSR timer object lifecycle failed.',13,10,'$'

        end     start
