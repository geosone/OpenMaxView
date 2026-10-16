; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for TopView second-level callback bit services.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds
        mov     ax,0DE26h
        int     15h
        or      bx,bx
        jz      failed
        mov     word ptr expected_task,bx

        push    cs
        pop     es
        mov     di,offset callback_one
        mov     ax,1013h
        int     15h
        cmp     bx,0001h
        jne     failed
        mov     word ptr allocated_mask,bx

        mov     di,offset callback_two
        mov     ax,1013h
        int     15h
        cmp     bx,0002h
        jne     failed
        or      word ptr allocated_mask,bx

        mov     si,0004h
        mov     bp,14
allocate_rest:
        mov     di,offset callback_filler
        mov     ax,1013h
        int     15h
        cmp     bx,si
        jne     failed
        or      word ptr allocated_mask,bx
        shl     si,1
        dec     bp
        jnz     allocate_rest
        cmp     word ptr allocated_mask,0FFFFh
        jne     failed

        ; The seventeenth allocation reports exhaustion.
        mov     di,offset callback_filler
        mov     ax,1013h
        int     15h
        or      bx,bx
        jnz     failed

        ; A callback may enqueue another bit without recursive dispatch.
        mov     byte ptr nested_enable,1
        mov     bx,0001h
        mov     ax,1015h
        int     15h
        cmp     byte ptr callback_one_count,1
        jne     failed
        cmp     byte ptr callback_two_count,1
        jne     failed
        cmp     byte ptr callback_filler_count,0
        jne     failed

        ; Multiple bits dispatch in one SETBIT and receive the task in ES.
        mov     bx,8003h
        mov     ax,1015h
        int     15h
        cmp     byte ptr callback_one_count,2
        jne     failed
        cmp     byte ptr callback_two_count,2
        jne     failed
        cmp     byte ptr callback_filler_count,1
        jne     failed
        cmp     byte ptr bad_task_count,0
        jne     failed

        ; FREEBIT cancels the released bit, which is then reused first.
        mov     bx,0001h
        mov     ax,1014h
        int     15h
        mov     ax,1015h
        int     15h
        cmp     byte ptr callback_one_count,2
        jne     failed
        mov     di,offset callback_two
        mov     ax,1013h
        int     15h
        cmp     bx,0001h
        jne     failed
        mov     bx,0003h
        mov     ax,1015h
        int     15h
        cmp     byte ptr callback_two_count,4
        jne     failed

        ; Releasing a mask removes all callbacks and SETBIT becomes harmless.
        mov     bx,0FFFFh
        mov     ax,1014h
        int     15h
        mov     ax,1015h
        int     15h
        cmp     byte ptr callback_two_count,4
        jne     failed
        cmp     byte ptr callback_filler_count,1
        jne     failed

        ; The task-reset service also releases every callback allocation.
        mov     di,offset callback_filler
        mov     ax,1013h
        int     15h
        cmp     bx,0001h
        jne     failed
        mov     ax,0D702h
        int     2Fh
        mov     di,offset callback_one
        mov     ax,1013h
        int     15h
        cmp     bx,0001h
        jne     failed
        mov     ax,1014h
        int     15h

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

callback_one proc far
        push    ax
        push    bx
        call    check_task
        inc     byte ptr cs:callback_one_count
        cmp     byte ptr cs:nested_enable,0
        je      short callback_one_done
        mov     byte ptr cs:nested_enable,0
        mov     bx,0002h
        mov     ax,1015h
        int     15h
callback_one_done:
        pop     bx
        pop     ax
        retf
callback_one endp

callback_two proc far
        push    ax
        call    check_task
        inc     byte ptr cs:callback_two_count
        pop     ax
        retf
callback_two endp

callback_filler proc far
        push    ax
        call    check_task
        inc     byte ptr cs:callback_filler_count
        pop     ax
        retf
callback_filler endp

check_task:
        mov     ax,es
        cmp     ax,word ptr cs:expected_task
        je      short check_task_done
        inc     byte ptr cs:bad_task_count
check_task_done:
        ret

expected_task dw 0
allocated_mask dw 0
callback_one_count db 0
callback_two_count db 0
callback_filler_count db 0
bad_task_count db 0
nested_enable db 0
passed_msg db 'MAXVTSR second-level callback services passed.',13,10,'$'
failed_msg db 'MAXVTSR second-level callback services failed.',13,10,'$'
        end start
