; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView resident ANSI console service, built with JWasm/JWlink.

MUX_QUERY      equ 0D710h
MUX_SIGNATURE  equ 04E41h            ; "AN"
ANSI_VERSION   equ 0100h

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds
        mov     ax,MUX_QUERY
        int     2Fh
        cmp     bx,MUX_SIGNATURE
        jne     install
        mov     dx,offset already_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

install:
        mov     ax,3529h
        int     21h
        mov     word ptr old29,bx
        mov     word ptr old29+2,es
        mov     ax,352Fh
        int     21h
        mov     word ptr old2f,bx
        mov     word ptr old2f+2,es

        mov     dx,offset int29_handler
        mov     ax,2529h
        int     21h
        mov     dx,offset int2f_handler
        mov     ax,252Fh
        int     21h

        mov     dx,offset installed_msg
        mov     ah,09h
        int     21h
        mov     dx,offset resident_end
        add     dx,15
        mov     cl,4
        shr     dx,cl
        mov     ax,3100h
        int     21h

int2f_handler:
        cmp     ax,MUX_QUERY
        jne     int2f_chain
        mov     bx,MUX_SIGNATURE
        mov     cx,ANSI_VERSION
        iret
int2f_chain:
        jmp     dword ptr cs:old2f

int29_handler:
        cmp     byte ptr cs:escape_state,0
        jne     ansi_parse
        cmp     al,1Bh
        je      ansi_escape
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        push    cs
        pop     ds
        call    output_char
        jmp     handler_done
ansi_escape:
        mov     byte ptr cs:escape_state,1
        iret

ansi_parse:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        push    cs
        pop     ds
        cmp     byte ptr escape_state,1
        jne     parse_parameters
        cmp     al,'['
        jne     parse_literal
        mov     byte ptr escape_state,2
        mov     byte ptr parameter_index,0
        mov     word ptr parameters,0
        mov     word ptr parameters+2,0
        mov     word ptr parameters+4,0
        mov     word ptr parameters+6,0
        jmp     handler_done
parse_literal:
        mov     byte ptr escape_state,0
        call    output_char
        jmp     handler_done

parse_parameters:
        cmp     al,'0'
        jb      parameter_separator
        cmp     al,'9'
        ja      parameter_separator
        sub     al,'0'
        xor     ah,ah
        mov     si,ax
        xor     bx,bx
        mov     bl,byte ptr parameter_index
        shl     bx,1
        mov     ax,word ptr parameters[bx]
        mov     cx,10
        mul     cx
        add     ax,si
        cmp     ax,999
        jbe     store_digit
        mov     ax,999
store_digit:
        mov     word ptr parameters[bx],ax
        jmp     handler_done

parameter_separator:
        cmp     al,';'
        jne     dispatch_command
        cmp     byte ptr parameter_index,3
        jae     handler_done
        inc     byte ptr parameter_index
        jmp     handler_done

dispatch_command:
        mov     byte ptr escape_state,0
        cmp     al,'A'
        je      cursor_up
        cmp     al,'B'
        je      cursor_down
        cmp     al,'C'
        je      cursor_right
        cmp     al,'D'
        je      cursor_left
        cmp     al,'H'
        je      cursor_position
        cmp     al,'f'
        je      cursor_position
        cmp     al,'J'
        je      erase_screen
        cmp     al,'K'
        je      erase_line
        cmp     al,'m'
        je      set_attributes
        cmp     al,'s'
        je      save_cursor
        cmp     al,'u'
        je      restore_cursor
        jmp     handler_done

cursor_up:
        call    get_cursor
        mov     cx,word ptr parameters
        or      cx,cx
        jnz     cursor_up_count
        inc     cx
cursor_up_count:
        cmp     cx,24
        jbe     cursor_up_limited
        mov     cx,24
cursor_up_limited:
        cmp     dh,cl
        jae     cursor_up_subtract
        xor     dh,dh
        jmp     set_cursor
cursor_up_subtract:
        sub     dh,cl
        jmp     set_cursor

cursor_down:
        call    get_cursor
        mov     cx,word ptr parameters
        or      cx,cx
        jnz     cursor_down_count
        inc     cx
cursor_down_count:
        xor     ax,ax
        mov     al,dh
        add     ax,cx
        cmp     ax,24
        jbe     cursor_down_store
        mov     ax,24
cursor_down_store:
        mov     dh,al
        jmp     set_cursor

cursor_right:
        call    get_cursor
        mov     cx,word ptr parameters
        or      cx,cx
        jnz     cursor_right_count
        inc     cx
cursor_right_count:
        xor     ax,ax
        mov     al,dl
        add     ax,cx
        cmp     ax,79
        jbe     cursor_right_store
        mov     ax,79
cursor_right_store:
        mov     dl,al
        jmp     set_cursor

cursor_left:
        call    get_cursor
        mov     cx,word ptr parameters
        or      cx,cx
        jnz     cursor_left_count
        inc     cx
cursor_left_count:
        cmp     cx,79
        jbe     cursor_left_limited
        mov     cx,79
cursor_left_limited:
        cmp     dl,cl
        jae     cursor_left_subtract
        xor     dl,dl
        jmp     set_cursor
cursor_left_subtract:
        sub     dl,cl
        jmp     set_cursor

cursor_position:
        mov     ax,word ptr parameters
        or      ax,ax
        jnz     position_row
        inc     ax
position_row:
        dec     ax
        cmp     ax,24
        jbe     position_row_ok
        mov     ax,24
position_row_ok:
        mov     dh,al
        mov     ax,word ptr parameters+2
        or      ax,ax
        jnz     position_column
        inc     ax
position_column:
        dec     ax
        cmp     ax,79
        jbe     position_column_ok
        mov     ax,79
position_column_ok:
        mov     dl,al
        jmp     set_cursor

erase_screen:
        mov     ax,0600h
        mov     bh,byte ptr current_attribute
        xor     cx,cx
        mov     dx,184Fh
        int     10h
        xor     dx,dx
        jmp     set_cursor

erase_line:
        call    get_cursor
        mov     si,dx
        xor     cx,cx
        mov     cl,80
        sub     cl,dl
        mov     ax,0920h
        xor     bh,bh
        mov     bl,byte ptr current_attribute
        int     10h
        mov     dx,si
        jmp     set_cursor

save_cursor:
        call    get_cursor
        mov     word ptr saved_cursor,dx
        jmp     handler_done

restore_cursor:
        mov     dx,word ptr saved_cursor
        jmp     set_cursor

set_attributes:
        xor     si,si
attribute_loop:
        mov     bx,si
        shl     bx,1
        mov     ax,word ptr parameters[bx]
        cmp     ax,0
        je      attribute_reset
        cmp     ax,1
        je      attribute_bold
        cmp     ax,5
        je      attribute_blink
        cmp     ax,7
        je      attribute_reverse
        cmp     ax,22
        je      attribute_normal
        cmp     ax,25
        je      attribute_no_blink
        cmp     ax,30
        jb      attribute_next
        cmp     ax,37
        jbe     attribute_foreground
        cmp     ax,40
        jb      attribute_next
        cmp     ax,47
        jbe     attribute_background
        jmp     attribute_next
attribute_reset:
        mov     byte ptr current_attribute,07h
        jmp     attribute_next
attribute_bold:
        or      byte ptr current_attribute,08h
        jmp     attribute_next
attribute_blink:
        or      byte ptr current_attribute,80h
        jmp     attribute_next
attribute_normal:
        and     byte ptr current_attribute,0F7h
        jmp     attribute_next
attribute_no_blink:
        and     byte ptr current_attribute,07Fh
        jmp     attribute_next
attribute_reverse:
        mov     al,byte ptr current_attribute
        mov     ah,al
        and     al,07h
        shl     al,1
        shl     al,1
        shl     al,1
        shl     al,1
        and     ah,70h
        mov     cl,4
        shr     ah,cl
        or      al,ah
        mov     byte ptr current_attribute,al
        jmp     attribute_next
attribute_foreground:
        sub     ax,30
        mov     bx,offset color_map
        add     bx,ax
        mov     al,byte ptr [bx]
        mov     ah,byte ptr current_attribute
        and     ah,0F8h
        or      al,ah
        mov     byte ptr current_attribute,al
        jmp     attribute_next
attribute_background:
        sub     ax,40
        mov     bx,offset color_map
        add     bx,ax
        mov     al,byte ptr [bx]
        mov     cl,4
        shl     al,cl
        mov     ah,byte ptr current_attribute
        and     ah,08Fh
        or      al,ah
        mov     byte ptr current_attribute,al
attribute_next:
        inc     si
        xor     ax,ax
        mov     al,byte ptr parameter_index
        cmp     si,ax
        jbe     attribute_loop
        jmp     handler_done

set_cursor:
        mov     ah,02h
        xor     bh,bh
        int     10h
        jmp     handler_done

handler_done:
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        iret

get_cursor proc near
        mov     ah,03h
        xor     bh,bh
        int     10h
        ret
get_cursor endp

output_char proc near
        cmp     al,13
        je      output_carriage
        cmp     al,10
        je      output_linefeed
        cmp     al,8
        je      output_backspace
        cmp     al,9
        je      output_tab
        cmp     al,32
        jb      output_return
        mov     byte ptr pending_character,al
        call    get_cursor
        mov     ax,0900h
        mov     al,byte ptr pending_character
        xor     bh,bh
        mov     bl,byte ptr current_attribute
        mov     cx,1
        int     10h
        call    get_cursor
        inc     dl
        cmp     dl,80
        jb      output_set_cursor
        xor     dl,dl
        inc     dh
        cmp     dh,25
        jb      output_set_cursor
        call    scroll_screen
        mov     dh,24
        jmp     output_set_cursor
output_carriage:
        call    get_cursor
        xor     dl,dl
        jmp     output_set_cursor
output_linefeed:
        call    get_cursor
        inc     dh
        cmp     dh,25
        jb      output_set_cursor
        call    scroll_screen
        mov     dh,24
        jmp     output_set_cursor
output_backspace:
        call    get_cursor
        or      dl,dl
        jz      output_return
        dec     dl
        jmp     output_set_cursor
output_tab:
        call    get_cursor
        mov     al,dl
        and     al,7
        mov     cl,8
        sub     cl,al
output_tab_loop:
        mov     al,' '
        push    cx
        call    output_char
        pop     cx
        dec     cl
        jnz     output_tab_loop
        jmp     output_return
output_set_cursor:
        mov     ah,02h
        xor     bh,bh
        int     10h
output_return:
        ret
output_char endp

scroll_screen proc near
        mov     ax,0601h
        mov     bh,byte ptr current_attribute
        xor     cx,cx
        mov     dx,184Fh
        int     10h
        ret
scroll_screen endp

old29               dd 0
old2f               dd 0
escape_state        db 0
parameter_index     db 0
current_attribute   db 07h
pending_character   db 0
parameters          dw 4 dup (0)
saved_cursor        dw 0
color_map           db 0,4,2,6,1,5,3,7

installed_msg db 'Open MaxView ANSI console 1.0 installed.',13,10,'$'
already_msg   db 'Open MaxView ANSI console is already installed.',13,10,'$'

resident_end:
        end     start
