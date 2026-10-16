; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for the bounded mailbox queue lifecycle.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds
        call    new_mailbox
        or      dx,dx
        jnz     failed
        or      ax,ax
        jz      failed
        mov     word ptr mailbox_one,ax
        call    new_mailbox
        or      dx,dx
        jnz     failed
        or      ax,ax
        jz      failed
        cmp     ax,word ptr mailbox_one
        je      failed
        mov     word ptr mailbox_two,ax
        call    new_mailbox
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        ; Names are copied by SETNAME, returned without a terminator by
        ; GETNAME, and discoverable through DESQview FINDMAIL.
        mov     ax,word ptr mailbox_one
        mov     cx,8
        mov     si,offset mailbox_name
        call    mailbox_setname
        mov     ax,word ptr mailbox_two
        mov     cx,4
        mov     si,offset second_name
        call    mailbox_setname
        push    ds
        push    ds
        pop     es
        mov     di,offset mailbox_name
        mov     cx,8
        mov     ax,0DE0Eh
        int     15h
        mov     ax,ds
        mov     dx,si
        pop     ds
        cmp     bx,1
        jne     failed
        cmp     ax,word ptr mailbox_one
        jne     failed
        or      dx,dx
        jnz     failed
        push    ds
        pop     es
        mov     di,offset name_buffer
        mov     ax,word ptr mailbox_one
        mov     cx,4
        call    mailbox_getname
        cmp     ax,4
        jne     failed
        or      dx,dx
        jnz     failed
        cmp     word ptr name_buffer,'VM'
        jne     failed
        cmp     word ptr name_buffer+2,'ET'
        jne     failed
        mov     ax,word ptr mailbox_two
        xor     cx,cx
        xor     si,si
        call    mailbox_setname
        push    ds
        push    ds
        pop     es
        mov     di,offset second_name
        mov     cx,4
        mov     ax,0DE0Eh
        int     15h
        pop     ds
        or      bx,bx
        jnz     failed

        mov     ax,word ptr mailbox_one
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        cmp     bx,0FFFFh
        jne     failed
        mov     ax,0DE14h
        int     15h
        cmp     bl,09h
        jne     failed

        mov     ax,word ptr mailbox_one
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
        cmp     ax,word ptr mailbox_one
        jne     failed

        mov     ax,word ptr mailbox_one
        mov     bx,0C00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0F00h
        call    mailbox_query
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        mov     ax,word ptr mailbox_one
        mov     bx,0800h              ; SIZEOF: queued message count
        call    mailbox_query
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0900h              ; LEN: total queued bytes
        call    mailbox_query
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Ah
        mov     si,offset sample_message
        call    mailbox_add_value
        jc      failed
        mov     di,3
mailbox_fill_loop:
        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Bh
        mov     si,offset later_message
        call    mailbox_add_value
        jc      failed
        dec     di
        jnz     short mailbox_fill_loop

        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        cmp     ax,4
        jne     failed
        or      dx,dx
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0900h
        call    mailbox_query
        cmp     ax,20
        jne     failed
        or      dx,dx
        jnz     failed

        ; A fifth message exceeds the bounded queue and must fail without
        ; changing its count or byte length.
        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Bh
        mov     si,offset sample_message
        call    mailbox_add_value
        jnc     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        cmp     ax,4
        jne     failed

        push    ds
        pop     es
        mov     di,offset read_buffer
        mov     ax,word ptr mailbox_one
        mov     cx,128
        call    mailbox_readinto
        jc      failed
        cmp     ax,5
        jne     failed
        or      dx,dx
        jnz     failed
        cmp     byte ptr read_buffer,'H'
        jne     failed
        cmp     byte ptr read_buffer+1,'E'
        jne     failed
        cmp     byte ptr read_buffer+2,'L'
        jne     failed
        cmp     byte ptr read_buffer+3,'L'
        jne     failed
        cmp     byte ptr read_buffer+4,'O'
        jne     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0F00h              ; status of the message just read
        call    mailbox_query
        cmp     ax,007Ah
        jne     failed
        or      dx,dx
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        cmp     ax,3
        jne     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0900h
        call    mailbox_query
        cmp     ax,15
        jne     failed

        ; The dequeue frees the oldest ring slot for another write.
        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Bh
        mov     si,offset sample_message
        call    mailbox_add_value
        jc      failed
        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        cmp     ax,4
        jne     failed

        mov     ax,word ptr mailbox_one
        mov     bx,0E00h              ; ERASE discards every queued message
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        or      ax,ax
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0900h
        call    mailbox_query
        or      ax,ax
        jnz     failed

        ; Until the scheduler exists, an empty READINTO is a nonblocking
        ; failure returning a zero byte count.
        push    ds
        pop     es
        mov     di,offset read_buffer
        mov     ax,word ptr mailbox_one
        mov     cx,128
        call    mailbox_readinto
        jnc     failed
        or      ax,ax
        jnz     failed
        or      dx,dx
        jnz     failed

        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Ch
        mov     si,offset sample_message
        call    mailbox_add_value
        jc      failed
        mov     ax,word ptr mailbox_one
        mov     bx,0D00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0800h              ; CLOSE also discards pending mail
        call    mailbox_query
        or      ax,ax
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Dh
        mov     si,offset sample_message
        call    mailbox_add_value
        jnc     failed

        ; Flags 1 and 2 allow closed writes and preserve the queue on CLOSE.
        mov     ax,word ptr mailbox_one
        mov     dx,0006h
        call    mailbox_setflags
        mov     ax,word ptr mailbox_one
        mov     bx,1600h
        call    mailbox_query
        cmp     ax,0006h
        jne     failed
        or      dx,dx
        jnz     failed
        mov     ax,word ptr mailbox_one
        mov     cx,5
        mov     dx,007Eh
        mov     si,offset sample_message
        call    mailbox_add_value
        jc      failed
        mov     ax,word ptr mailbox_one
        mov     bx,0C00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0D00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        mov     bx,0800h
        call    mailbox_query
        cmp     ax,1
        jne     failed
        mov     ax,word ptr mailbox_one
        mov     bx,0E00h
        call    mailbox_command
        mov     ax,word ptr mailbox_one
        xor     dx,dx
        call    mailbox_setflags
        mov     ax,word ptr mailbox_one
        mov     bx,1600h
        call    mailbox_query
        or      ax,ax
        jnz     failed

        xor     ax,ax
        mov     es,ax
        xor     di,di
        mov     ax,0DE2Bh
        int     15h                   ; foreground task
        or      ax,ax
        jnz     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        cmp     ax,word ptr mailbox_one
        jne     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        cmp     ax,word ptr mailbox_two
        jne     failed
        mov     ax,0DE2Bh
        int     15h
        mov     ax,es
        or      ax,ax
        jnz     failed

        mov     ax,word ptr mailbox_one
        call    free_mailbox
        mov     ax,word ptr mailbox_one
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
        jnz     failed
        call    new_mailbox
        cmp     ax,word ptr mailbox_one
        jne     failed

        mov     ax,0D702h
        int     2Fh
        mov     ax,word ptr mailbox_two
        mov     es,ax
        xor     di,di
        mov     ax,1016h
        int     15h
        or      bx,bx
        jnz     failed

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

new_mailbox:
        push    bx
        xor     ax,ax
        push    ax
        push    ax
        mov     ax,1200h
        mov     bx,0109h
        int     15h
        pop     dx
        pop     ax
        pop     bx
        ret

free_mailbox:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        mov     bx,0200h
        int     15h
        pop     bx
        ret

mailbox_command:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        int     15h
        pop     bx
        ret

mailbox_query:
        push    bx
        push    ax
        xor     ax,ax
        push    ax
        mov     ax,1200h
        int     15h
        pop     ax
        pop     dx
        pop     bx
        ret

; AX is the mailbox segment, DX the status, CX the byte length and DS:SI the
; message address. ADDTO consumes status, length, address and handle DWORDs.
mailbox_add_value:
        push    bp
        mov     bp,sp
        push    bx
        push    di
        mov     di,ax
        xor     ax,ax
        push    ax                    ; status high word
        push    dx                    ; status low word
        push    ax                    ; length high word
        push    cx                    ; length low word
        push    ds                    ; message segment
        push    si                    ; message offset
        push    di                    ; mailbox segment
        push    ax                    ; mailbox offset
        mov     ax,1200h
        mov     bx,0A00h
        int     15h
        pop     di
        pop     bx
        pop     bp
        ret

; AX is the mailbox segment, CX the destination capacity and ES:DI the
; destination. READINTO consumes the handle and pointer but leaves one DWORD
; byte count, returned here as DX:AX.
mailbox_readinto:
        push    bp
        mov     bp,sp
        push    bx
        push    si
        mov     si,ax
        xor     ax,ax
        push    ax                    ; capacity high word
        push    cx                    ; capacity low word / result storage
        push    es                    ; destination segment
        push    di                    ; destination offset
        push    si                    ; mailbox segment
        push    ax                    ; mailbox offset
        mov     ax,1200h
        mov     bx,1300h
        int     15h
        pop     ax                    ; returned byte count low
        pop     dx                    ; returned byte count high
        pop     si
        pop     bx
        pop     bp
        ret

; AX is the mailbox segment and DX the low flags word. SETFLAGS consumes the
; flags and handle DWORDs.
mailbox_setflags:
        push    bx
        push    di
        mov     di,ax
        xor     ax,ax
        push    ax                    ; flags high word
        push    dx                    ; flags low word
        push    di                    ; mailbox segment
        push    ax                    ; mailbox offset
        mov     ax,1200h
        mov     bx,1500h
        int     15h
        pop     di
        pop     bx
        ret

; AX is the mailbox segment, CX the name length and DS:SI the name. SETNAME
; consumes the length, pointer and mailbox DWORDs.
mailbox_setname:
        push    bx
        push    di
        mov     di,ax
        xor     ax,ax
        push    ax                    ; length high word
        push    cx                    ; length low word
        push    ds                    ; name segment
        push    si                    ; name offset
        push    di                    ; mailbox segment
        push    ax                    ; mailbox offset
        mov     ax,1200h
        mov     bx,1100h
        int     15h
        pop     di
        pop     bx
        ret

; AX is the mailbox segment, CX the capacity and ES:DI the destination.
; GETNAME consumes pointer and handle, leaving the returned length DWORD.
mailbox_getname:
        push    bx
        push    si
        mov     si,ax
        xor     ax,ax
        push    ax                    ; capacity high word
        push    cx                    ; capacity low word / result storage
        push    es                    ; destination segment
        push    di                    ; destination offset
        push    si                    ; mailbox segment
        push    ax                    ; mailbox offset
        mov     ax,1200h
        mov     bx,1200h
        int     15h
        pop     ax
        pop     dx
        pop     si
        pop     bx
        ret

mailbox_one dw 0
mailbox_two dw 0
sample_message db 'HELLO'
later_message db 'LATER'
mailbox_name db 'MVTEST01'
second_name db 'NODE'
name_buffer db 32 dup(0)
read_buffer db 128 dup(0)
passed_msg db 'MAXVTSR mailbox queue lifecycle passed.',13,10,'$'
failed_msg db 'MAXVTSR mailbox queue lifecycle failed.',13,10,'$'
        end start
