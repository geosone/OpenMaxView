; SPDX-License-Identifier: GPL-3.0-or-later
; DOSBox probe for bounded TopView SOUND queue behavior.

        .8086
        .model tiny
        .code
        org 100h

start:
        push    cs
        pop     ds

        ; INT 1Ch expires an active entry without a foreground API call.
        mov     ah,00h
        int     1Ah
        mov     word ptr start_tick,dx
        mov     ax,1019h
        mov     bx,1000
        mov     cx,1
        int     15h
wait_for_expiry:
        call    sound_info
        or      dx,dx
        jz      short expiry_passed
        mov     ah,00h
        int     1Ah
        mov     ax,dx
        sub     ax,word ptr start_tick
        cmp     ax,5
        jb      short wait_for_expiry
        jmp     failed
expiry_passed:

        ; Frequencies below DESQview 2.x's 20 Hz floor are clamped.
        mov     ax,1019h
        mov     bx,10
        mov     cx,20
        int     15h
        call    sound_info
        cmp     bx,20
        jne     failed
        or      cx,cx
        jz      failed
        cmp     dx,1
        jne     failed
        mov     ax,1019h
        xor     bx,bx
        xor     cx,cx
        int     15h

        ; A nonzero-frequency cancellation drops only the current entry.
        mov     ax,1019h
        mov     bx,1000
        mov     cx,100
        int     15h
        mov     bx,0                  ; queued silence
        mov     cx,100
        int     15h
        mov     bx,500
        mov     cx,100
        int     15h
        call    sound_info
        cmp     bx,1000
        jne     failed
        cmp     dx,3
        jne     failed
        mov     ax,1019h
        mov     bx,1
        xor     cx,cx
        int     15h
        call    sound_info
        or      bx,bx
        jnz     failed
        cmp     dx,2
        jne     failed

        ; BX=CX=0 cancels the current entry and the complete queue.
        mov     ax,1019h
        xor     bx,bx
        xor     cx,cx
        int     15h
        call    sound_info
        or      bx,bx
        jnz     failed
        or      cx,cx
        jnz     failed
        or      dx,dx
        jnz     failed
        in      al,61h
        test    al,03h
        jnz     failed

        ; Fill all 32 bounded slots. A 33rd request is a nonblocking no-op.
        mov     bp,32
fill_queue:
        mov     ax,1019h
        mov     bx,440
        mov     cx,0FFFFh
        int     15h
        dec     bp
        jnz     fill_queue
        call    sound_info
        cmp     dx,32
        jne     failed
        mov     ax,1019h
        mov     bx,880
        mov     cx,0FFFFh
        int     15h
        call    sound_info
        cmp     bx,440
        jne     failed
        cmp     dx,32
        jne     failed

        ; Task reset clears the queue and silences the speaker.
        mov     ax,0D702h
        int     2Fh
        call    sound_info
        or      bx,bx
        jnz     failed
        or      cx,cx
        jnz     failed
        or      dx,dx
        jnz     failed
        in      al,61h
        test    al,03h
        jnz     failed

        mov     dx,offset passed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

failed:
        mov     ax,1019h
        xor     bx,bx
        xor     cx,cx
        int     15h
        mov     dx,offset failed_msg
        mov     ah,09h
        int     21h
        mov     ax,4C01h
        int     21h

sound_info:
        mov     ax,0D706h
        int     2Fh
        ret

start_tick dw 0
passed_msg db 'MAXVTSR bounded SOUND queue passed.',13,10,'$'
failed_msg db 'MAXVTSR bounded SOUND queue failed.',13,10,'$'
        end start
