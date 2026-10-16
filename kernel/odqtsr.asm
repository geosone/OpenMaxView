; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView resident compatibility API, 16-bit DOS .COM program.
;
; Assembled by the JWasm embedded in Open 386MAX and linked by JWlink.
;
; Implemented compatibility surface:
;   INT 21h AX=2B01h CX='DE' DX='SQ'  presence/version query
;   INT 15h AX=1000h                 cooperative PAUSE
;   INT 15h AX=1001h/1002h           system-memory allocate/release aliases
;   INT 15h AX=1016h                 object-handle validation
;   INT 15h AX=1018h                 foreground window location
;   INT 15h AX=101Bh/101Ch           nested critical-section markers
;   INT 15h AX=1022h, BX=0000h       TopView-compatible API identity
;   INT 15h AX=1024h                 foreground virtual-screen buffer
;   INT 15h AX=102Dh, BL=operation   keyboard-mouse mode state
;   INT 15h AH=12h, BH=00h           HANDLE object-message subset
;   INT 15h AX=DE04h                 common-memory availability
;   INT 15h AX=DE05h                 conventional-memory availability
;   INT 15h AX=DE06h                 expanded-memory availability
;   INT 15h AX=DE07h                 foreground program number
;   INT 15h AX=DE0Ah, BL=character   physical status-line debug output
;   INT 15h AX=DE0Bh, BX=level       minimum API level selection
;   INT 15h AX=DE0Ch/DE0Dh           system-memory allocate/release
;   INT 15h AX=DE10h, BX=scan/char   foreground keyboard PUSHKEY
;   INT 15h AX=DE11h, BL=mode        viewport justification mode
;   INT 15h AX=DE12h, BX=mode        C-style linefeed mode
;   INT 15h AX=DE13h                 critical nesting query
;   INT 15h AX=DE14h                 object type query
;   INT 15h AX=DE15h/DE16h           set/get error-return policy
;   INT 15h AX=DE1Ch                 interrupt-safe critical entry
;   INT 15h AX=DE1Dh                 targeted foreground PUTKEY
;   INT 15h AX=DE1Eh                 physical screen information
;   INT 15h AX=DE1Fh                 foreground DOS-owner handle
;   INT 15h AX=DE22h                 foreground process-memory status
;   INT 15h AX=DE19h/DE1Ah           common-memory allocate/release
;   INT 15h AX=DE25h                 resident installation directory
;   INT 15h AX=DE26h                 foreground task handle
;   INT 15h AX=DE2Bh                 foreground object-list traversal
;   INT 15h AX=DE2Ch                 foreground window/task information
;   INT 15h AX=DE2Fh                 direct-video activation query
;   INT 15h AX=DE30h                 DESQview/X version query
;   INT 10h AH=FEh                   alternate text-video buffer
;   INT 10h AH=FFh                   video-buffer change notification
;   INT 2Fh AX=D700h                 Open MaxView-private status query
;   INT 2Fh AX=D701h                 private capabilities/state query
;   INT 2Fh AX=D702h                 reset per-foreground-task state
;   INT 2Fh AX=D703h                 query per-foreground-task state
;   INT 2Fh AX=D704h                 extended capability query
;   INT 2Fh AX=D705h                 object-message capability query

DV_VERSION     equ 0280h
MUX_STATUS     equ 0D700h
MUX_INFO       equ 0D701h
MUX_RESET      equ 0D702h
MUX_TASK_INFO  equ 0D703h
MUX_CAPS2      equ 0D704h
MUX_CAPS3      equ 0D705h
MUX_SIGNATURE  equ 04F44h            ; "OD" in register byte order
MUX_VERSION    equ 0016h
CAPABILITIES   equ 0FFFFh
CAPABILITIES2  equ 0FFFFh
CAPABILITIES3  equ 000Fh             ; HANDLE, timer control, mailbox lifetime

MEM_SLOT_SIZE      equ 0100h
SYSTEM_SLOT_COUNT  equ 8
COMMON_SLOT_COUNT  equ 4
COMMON_TOTAL       equ COMMON_SLOT_COUNT * MEM_SLOT_SIZE
TIMER_SLOT_COUNT   equ 4
TIMER_OBJECT_SIZE  equ 32
MAILBOX_SLOT_COUNT equ 2
MAILBOX_OBJECT_SIZE equ 32

TASK_JUSTIFY   equ 0001h
TASK_CSTYLE    equ 0002h

        .8086
        .model  tiny
        .code
        org     100h

start:
        push    cs
        pop     ds

        call    capture_install_path

        mov     ax,MUX_STATUS
        int     2Fh
        cmp     bx,MUX_SIGNATURE
        jne     install
        mov     dx,offset already_msg
        mov     ah,09h
        int     21h
        mov     ax,4C00h
        int     21h

install:
        mov     ax,cs
        mov     bx,offset task_object
        mov     cl,4
        shr     bx,cl
        add     ax,bx
        mov     word ptr task_handle_segment,ax
        mov     word ptr task_object+0Ah,ax
        mov     word ptr task_object+0Eh,ax
        call    initialize_timer_objects
        call    initialize_mailbox_objects

        mov     ah,0Fh
        int     10h
        mov     word ptr video_segment,0B800h
        cmp     al,7
        jne     short video_known
        mov     word ptr video_segment,0B000h
video_known:
        mov     ax,3510h
        int     21h
        mov     word ptr old10,bx
        mov     word ptr old10+2,es

        mov     ax,3515h
        int     21h
        mov     word ptr old15,bx
        mov     word ptr old15+2,es

        mov     ax,3521h
        int     21h
        mov     word ptr old21,bx
        mov     word ptr old21+2,es

        mov     ax,352Fh
        int     21h
        mov     word ptr old2f,bx
        mov     word ptr old2f+2,es

        mov     dx,offset int10_handler
        mov     ax,2510h
        int     21h
        mov     dx,offset int15_handler
        mov     ax,2515h
        int     21h
        mov     dx,offset int21_handler
        mov     ax,2521h
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

int21_handler:
        pushf
        cmp     ax,2B01h
        jne     int21_chain
        cmp     cx,4445h              ; 'DE'
        jne     int21_chain
        cmp     dx,5351h              ; 'SQ'
        jne     int21_chain
        mov     bx,DV_VERSION
        xor     al,al
        popf
        iret
int21_chain:
        popf
        jmp     dword ptr cs:old21

int10_handler:
        pushf
        cmp     ah,0FEh
        je      short int10_buffer
        cmp     ah,0FFh
        je      short int10_handled
        jmp     short int10_chain
int10_buffer:
        mov     es,word ptr cs:video_segment
        xor     di,di
int10_handled:
        popf
        iret
int10_chain:
        popf
        jmp     dword ptr cs:old10

int15_handler:
        pushf
        cmp     ah,12h                ; TopView/DESQview SEND MESSAGE
        jne     short int15_not_message
        cmp     bh,0                  ; HANDLE
        je      short int15_dispatch_handle
        cmp     bh,1                  ; NEW
        je      short int15_dispatch_new
        cmp     bh,2                  ; FREE
        je      short int15_dispatch_free
        cmp     bh,5                  ; WRITE absolute timer deadline
        je      short int15_dispatch_timer_add
        cmp     bh,8                  ; SIZEOF
        je      short int15_dispatch_timer_query
        cmp     bh,9                  ; LEN
        je      short int15_dispatch_timer_query
        cmp     bh,0Ah                ; ADDTO
        je      short int15_dispatch_timer_add
        cmp     bh,0Ch                ; OPEN
        je      short int15_dispatch_timer_open_close
        cmp     bh,0Dh                ; CLOSE
        je      short int15_dispatch_timer_open_close
        cmp     bh,0Fh                ; STATUS
        je      short int15_dispatch_timer_query
        jmp     short int15_unknown_message
int15_dispatch_handle:
        jmp     int15_message_handle
int15_dispatch_new:
        jmp     int15_message_new
int15_dispatch_free:
        jmp     int15_message_free
int15_dispatch_timer_query:
        jmp     int15_message_timer_query
int15_dispatch_timer_add:
        jmp     int15_message_timer_add
int15_dispatch_timer_open_close:
        jmp     int15_message_timer_open_close
int15_unknown_message:
        jmp     int15_chain
int15_not_message:
        cmp     ax,1000h              ; PAUSE
        je      int15_handled
        cmp     ax,1001h              ; TopView-compatible GETMEM alias
        jne     short int15_not_getmem_alias
        jmp     int15_getmem
int15_not_getmem_alias:
        cmp     ax,1002h              ; TopView-compatible PUTMEM alias
        jne     short int15_not_putmem_alias
        jmp     int15_putmem
int15_not_putmem_alias:
        cmp     ax,1016h              ; ISOBJ
        jne     short int15_not_isobj
        jmp     int15_isobj
int15_not_isobj:
        cmp     ax,1018h              ; LOCATE
        jne     short int15_not_locate
        jmp     int15_locate
int15_not_locate:
        cmp     ax,101Bh              ; BEGINC
        je      int15_begin
        cmp     ax,101Ch              ; ENDC
        je      int15_end
        cmp     ax,1022h              ; GETVER
        jne     short int15_not_getver
        or      bx,bx
        jne     int15_chain
        mov     bx,0A01h              ; DESQview 2.x-compatible identity
        jmp     int15_handled
int15_not_getver:
        cmp     ax,1024h              ; GETBUF
        jne     short int15_not_getbuf
        jmp     int15_getbuf
int15_not_getbuf:
        cmp     ax,102Dh              ; keyboard mouse control
        jne     short int15_not_keyboard_mouse
        jmp     int15_keyboard_mouse
int15_not_keyboard_mouse:
        cmp     ax,0DE04h             ; GET AVAILABLE COMMON MEMORY
        jne     short int15_not_common_status
        jmp     int15_common_status
int15_not_common_status:
        cmp     ax,0DE05h             ; conventional-memory availability
        jne     short int15_not_conventional_status
        jmp     int15_conventional_status
int15_not_conventional_status:
        cmp     ax,0DE06h             ; expanded-memory availability
        jne     short int15_not_expanded_status
        jmp     int15_expanded_status
int15_not_expanded_status:
        cmp     ax,0DE07h             ; APPNUM
        je      int15_appnum
        cmp     ax,0DE0Ah             ; DBGPOKE
        jne     short int15_not_dbgpoke
        jmp     int15_dbgpoke
int15_not_dbgpoke:
        cmp     ax,0DE0Bh             ; APILEVEL
        je      int15_apilevel
        cmp     ax,0DE0Ch             ; GETMEM
        jne     short int15_not_getmem
        jmp     int15_getmem
int15_not_getmem:
        cmp     ax,0DE0Dh             ; PUTMEM
        jne     short int15_not_putmem
        jmp     int15_putmem
int15_not_putmem:
        cmp     ax,0DE10h             ; PUSHKEY
        je      int15_pushkey
        cmp     ax,0DE11h             ; JUSTIFY
        jne     short int15_not_justify
        jmp     int15_justify
int15_not_justify:
        cmp     ax,0DE12h             ; CSTYLE
        jne     short int15_not_cstyle
        jmp     int15_cstyle
int15_not_cstyle:
        cmp     ax,0DE13h             ; GETCRIT
        jne     short int15_not_getcrit
        jmp     int15_getcrit
int15_not_getcrit:
        cmp     ax,0DE14h             ; GET OBJECT TYPE
        jne     short int15_not_object_type
        jmp     int15_object_type
int15_not_object_type:
        cmp     ax,0DE15h             ; SET ERROR HANDLING
        jne     short int15_not_set_error
        jmp     int15_set_error
int15_not_set_error:
        cmp     ax,0DE16h             ; GET ERROR HANDLING
        jne     short int15_not_get_error
        jmp     int15_get_error
int15_not_get_error:
        cmp     ax,0DE1Ch             ; ENTERC
        jne     short int15_not_enterc
        jmp     int15_begin
int15_not_enterc:
        cmp     ax,0DE19h             ; GETCOMMON
        jne     short int15_not_getcommon
        jmp     int15_getcommon
int15_not_getcommon:
        cmp     ax,0DE1Ah             ; PUTCOMMON
        jne     short int15_not_putcommon
        jmp     int15_putcommon
int15_not_putcommon:
        cmp     ax,0DE1Dh             ; PUTKEY
        jne     short int15_not_putkey
        jmp     int15_putkey
int15_not_putkey:
        cmp     ax,0DE1Eh             ; SCRNINFO
        jne     short int15_not_scrninfo
        jmp     int15_scrninfo
int15_not_scrninfo:
        cmp     ax,0DE1Fh             ; DOSUSER
        jne     short int15_not_dosuser
        jmp     int15_dosuser
int15_not_dosuser:
        cmp     ax,0DE22h             ; PROCESSMEM
        jne     short int15_not_processmem
        jmp     int15_processmem
int15_not_processmem:
        cmp     ax,0DE25h             ; GETDVPATH
        jne     short int15_not_getpath
        jmp     int15_getpath
int15_not_getpath:
        cmp     ax,0DE26h             ; GETFOREGROUND
        jne     short int15_not_foreground
        jmp     int15_foreground
int15_not_foreground:
        cmp     ax,0DE2Bh             ; OBJNEXT
        jne     short int15_not_objnext
        jmp     int15_objnext
int15_not_objnext:
        cmp     ax,0DE2Ch             ; WININFO
        jne     short int15_not_wininfo
        jmp     int15_wininfo
int15_not_wininfo:
        cmp     ax,0DE2Fh             ; VIDEONOTIFY
        jne     short int15_not_videonotify
        jmp     int15_videonotify
int15_not_videonotify:
        cmp     ax,0DE30h             ; GETDVXVERSION
        jne     short int15_chain_jump
        jmp     int15_getdvxversion
int15_chain_jump:
        jmp     int15_chain
int15_begin:
        cmp     word ptr cs:critical_depth,0FFFFh
        je      short int15_begin_done
        inc     word ptr cs:critical_depth
int15_begin_done:
        jmp     int15_handled
int15_end:
        cmp     word ptr cs:critical_depth,0
        je      short int15_end_done
        dec     word ptr cs:critical_depth
int15_end_done:
        jmp     int15_handled
int15_appnum:
        mov     ax,1                   ; sole foreground program
        jmp     int15_handled

; Write one character on the bottom row of the active physical text page.
; Attributes are deliberately preserved.  Graphics and unknown modes are a
; no-op, and the independent debug cursor wraps at the BIOS column count.
int15_dbgpoke:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es
        mov     ax,40h                ; BIOS data area
        mov     es,ax
        mov     al,byte ptr es:[49h]  ; current video mode
        cmp     al,3
        jbe     short dbgpoke_colour
        cmp     al,7
        jne     short dbgpoke_done
        mov     bp,0B000h
        jmp     short dbgpoke_geometry
dbgpoke_colour:
        mov     bp,0B800h
dbgpoke_geometry:
        mov     si,word ptr es:[4Ah]  ; text columns
        or      si,si
        jz      short dbgpoke_done
        xor     cx,cx
        mov     cl,byte ptr es:[84h]  ; zero-based bottom row
        or      cl,cl
        jnz     short dbgpoke_rows
        mov     cl,24                 ; conservative 25-row fallback
dbgpoke_rows:
        mov     ax,si
        mul     cx
        shl     ax,1
        mov     di,ax
        add     di,word ptr es:[4Eh]  ; active display-page offset
        xor     ax,ax
        mov     al,byte ptr cs:debug_column
        cmp     ax,si
        jb      short dbgpoke_column
        xor     ax,ax                 ; geometry changed since previous call
dbgpoke_column:
        mov     dx,ax
        shl     ax,1
        add     di,ax
        inc     dx
        cmp     dx,si
        jb      short dbgpoke_save_column
        xor     dx,dx
dbgpoke_save_column:
        mov     byte ptr cs:debug_column,dl
        mov     es,bp
        mov     byte ptr es:[di],bl
dbgpoke_done:
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     int15_handled
int15_apilevel:
        mov     word ptr cs:api_level,bx
        mov     ax,DV_VERSION          ; maximum supported API level
        jmp     int15_handled
int15_pushkey:
        push    ax
        call    enqueue_bios_key
        pop     ax
        jmp     int15_handled
int15_justify:
        and     word ptr cs:task_flags,not TASK_JUSTIFY
        or      bl,bl
        jz      int15_handled
        or      word ptr cs:task_flags,TASK_JUSTIFY
        jmp     int15_handled
int15_cstyle:
        and     word ptr cs:task_flags,not TASK_CSTYLE
        or      bx,bx
        jz      int15_handled
        or      word ptr cs:task_flags,TASK_CSTYLE
        jmp     int15_handled
int15_getcrit:
        mov     bx,word ptr cs:critical_depth
        jmp     int15_handled
int15_set_error:
        mov     byte ptr cs:error_mode,bl
        jmp     int15_handled
int15_get_error:
        mov     bl,byte ptr cs:error_mode
        jmp     int15_handled
int15_scrninfo:
        push    ax
        push    es
        mov     ah,0Fh
        int     10h
        mov     bl,al                 ; physical video mode
        mov     ch,ah                 ; physical columns
        mov     ax,40h
        mov     es,ax
        mov     cl,byte ptr es:[84h]  ; rows minus one on EGA/VGA BIOSes
        or      cl,cl
        jnz     short scrninfo_rows
        mov     cl,24                 ; conservative 25-row fallback
scrninfo_rows:
        inc     cl
        pop     es
        pop     ax
        jmp     int15_handled
int15_videonotify:
        xor     bx,bx                 ; no direct-window switch has occurred
        jmp     int15_handled
int15_getdvxversion:
        xor     bx,bx                 ; Open MaxView is not DESQview/X
        jmp     int15_handled

; Foreground keyboard-mouse compatibility state.  Subfunction zero queries,
; one enables and two disables.  Event synthesis belongs to the later
; task-private input backend; unknown subfunctions leave the state unchanged.
int15_keyboard_mouse:
        cmp     bl,1
        je      short keyboard_mouse_enable
        cmp     bl,2
        je      short keyboard_mouse_disable
        cmp     bl,0
        jne     int15_handled
        mov     bl,byte ptr cs:keyboard_mouse
        jmp     int15_handled
keyboard_mouse_enable:
        mov     byte ptr cs:keyboard_mouse,1
        jmp     int15_handled
keyboard_mouse_disable:
        mov     byte ptr cs:keyboard_mouse,0
        jmp     int15_handled

int15_isobj:
        push    ax
        push    si
        xor     bx,bx
        or      di,di
        jnz     short int15_isobj_invalid
        mov     ax,es
        cmp     ax,word ptr cs:task_handle_segment
        je      short int15_isobj_valid
        call    timer_validate
        jnc     short int15_isobj_valid
        call    mailbox_validate
        jc      short int15_isobj_invalid
int15_isobj_valid:
        mov     bx,0FFFFh
        jmp     short int15_isobj_done
int15_isobj_invalid:
        xor     bx,bx
int15_isobj_done:
        pop     si
        pop     ax
        jmp     int15_handled

int15_object_type:
        push    ax
        push    si
        xor     bx,bx
        or      di,di
        jnz     short int15_object_type_invalid
        mov     ax,es
        cmp     ax,word ptr cs:task_handle_segment
        jne     short int15_object_type_timer
        mov     bl,08h                ; window/task object
        jmp     short int15_object_type_done
int15_object_type_timer:
        call    timer_validate
        jc      short int15_object_type_mailbox
        mov     bl,0Bh                ; timer object
        jmp     short int15_object_type_done
int15_object_type_mailbox:
        call    mailbox_validate
        jc      short int15_object_type_invalid
        mov     bl,09h                ; mailbox object
        jmp     short int15_object_type_done
int15_object_type_invalid:
        xor     bx,bx
int15_object_type_done:
        pop     si
        pop     ax
        jmp     int15_handled

; HANDLE uses the TopView message ABI: the caller reserves a DWORD on its
; stack before INT 15h, and the service replaces it with an object pointer.
; At this entry the handler's PUSHF plus the interrupt frame place that DWORD
; ten bytes above BP after saving BP. Selector zero validates either the
; resident task/window or a currently allocated timer. Other unavailable
; mailbox, keyboard and OBJECTQ selectors return a null handle.
int15_message_handle:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0                  ; validate/return stacked handle
        je      short message_handle_stacked
        cmp     bl,1                  ; current task's window
        je      short message_handle_current
        jmp     short message_handle_null
message_handle_stacked:
        cmp     word ptr ss:[bp+10],0
        jne     short message_handle_null
        mov     ax,word ptr ss:[bp+12]
        cmp     ax,word ptr cs:task_handle_segment
        je      short message_handle_done
        call    timer_validate
        jnc     short message_handle_done
        call    mailbox_validate
        jc      short message_handle_null
        jmp     short message_handle_done
message_handle_current:
        mov     word ptr ss:[bp+10],0
        mov     ax,word ptr cs:task_handle_segment
        mov     word ptr ss:[bp+12],ax
        jmp     short message_handle_done
message_handle_null:
        mov     word ptr ss:[bp+10],0
        mov     word ptr ss:[bp+12],0
message_handle_done:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_handled

; NEW allocates a resident timer or mailbox object. The caller reserves the
; same DWORD used by HANDLE; unsupported classes and pool exhaustion return a
; null pointer.
int15_message_new:
        push    bp
        mov     bp,sp
        push    ax
        push    cx
        push    si
        mov     word ptr ss:[bp+10],0
        mov     word ptr ss:[bp+12],0
        cmp     bl,0Bh                ; TIMER object class
        je      short message_new_timer
        cmp     bl,09h                ; MAILBOX object class
        je      short message_new_mailbox
        jmp     short message_new_done
message_new_timer:
        xor     si,si
        mov     cx,TIMER_SLOT_COUNT
message_new_scan:
        cmp     word ptr cs:timer_used[si],0
        je      short message_new_found
        add     si,2
        loop    message_new_scan
        jmp     short message_new_done
message_new_found:
        mov     word ptr cs:timer_used[si],1
        mov     word ptr cs:timer_open[si],0
        mov     word ptr cs:timer_state[si],0
        mov     ax,word ptr cs:timer_handle_segments[si]
        mov     word ptr ss:[bp+12],ax
        jmp     short message_new_done
message_new_mailbox:
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
message_new_mailbox_scan:
        cmp     word ptr cs:mailbox_used[si],0
        je      short message_new_mailbox_found
        add     si,2
        loop    message_new_mailbox_scan
        jmp     short message_new_done
message_new_mailbox_found:
        mov     word ptr cs:mailbox_used[si],1
        mov     word ptr cs:mailbox_open[si],0
        mov     word ptr cs:mailbox_status[si],0
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        mov     word ptr ss:[bp+12],ax
message_new_done:
        pop     si
        pop     cx
        pop     ax
        pop     bp
        jmp     int15_handled

; FREE message class 00h consumes and pops a timer pointer from the caller's
; stack. Invalid, stale and non-timer handles are harmless no-ops, but the
; documented stack pop still occurs.
int15_message_free:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0
        jne     short message_free_done
        cmp     word ptr ss:[bp+10],0
        jne     short message_free_done
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short message_free_mailbox
        mov     word ptr cs:timer_used[si],0
        mov     word ptr cs:timer_open[si],0
        mov     word ptr cs:timer_state[si],0
        jmp     short message_free_done
message_free_mailbox:
        call    mailbox_validate
        jc      short message_free_done
        mov     word ptr cs:mailbox_used[si],0
        mov     word ptr cs:mailbox_open[si],0
        mov     word ptr cs:mailbox_status[si],0
message_free_done:
        pop     si
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled

; SIZEOF returns elapsed hundredths, LEN returns remaining hundredths and
; STATUS returns the documented closed/running state bits. The handle DWORD
; is replaced in place by the query result.
int15_message_timer_query:
        push    bp
        mov     bp,sp
        push    ax
        push    cx
        push    dx
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     short timer_query_invalid
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short timer_query_mailbox
        call    timer_elapsed
        cmp     bh,08h
        je      short timer_query_store
        cmp     bh,09h
        je      short timer_query_length
        xor     ax,ax                 ; STATUS
        xor     dx,dx
        cmp     word ptr cs:timer_open[si],0
        jne     short timer_query_status_open
        mov     dx,8000h              ; closed
        jmp     short timer_query_store
timer_query_status_open:
        cmp     word ptr cs:timer_state[si],1
        jne     short timer_query_store
        mov     dx,4000h              ; open and running
        jmp     short timer_query_store
timer_query_mailbox:
        cmp     bh,0Fh
        jne     short timer_query_invalid
        call    mailbox_validate
        jc      short timer_query_invalid
        mov     ax,word ptr cs:mailbox_status[si]
        xor     dx,dx
        jmp     short timer_query_store
timer_query_length:
        cmp     word ptr cs:timer_state[si],1
        jne     short timer_query_invalid
        mov     cx,word ptr cs:timer_duration_lo[si]
        sub     cx,ax
        mov     ax,cx
        mov     cx,word ptr cs:timer_duration_hi[si]
        sbb     cx,dx
        mov     dx,cx
        jmp     short timer_query_store
timer_query_invalid:
        xor     ax,ax
        xor     dx,dx
timer_query_store:
        mov     word ptr ss:[bp+10],ax
        mov     word ptr ss:[bp+12],dx
timer_query_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        pop     bp
        jmp     int15_handled

; OPEN and CLOSE consume one timer handle DWORD. ADDTO and WRITE consume a
; timer handle followed by relative/absolute DWORD time in hundredths.
int15_message_timer_open_close:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     short timer_open_close_done
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short timer_open_close_mailbox
        mov     word ptr cs:timer_state[si],0
        cmp     bh,0Ch
        jne     short timer_close
        mov     word ptr cs:timer_open[si],1
        jmp     short timer_open_close_done
timer_close:
        mov     word ptr cs:timer_open[si],0
        jmp     short timer_open_close_done
timer_open_close_mailbox:
        call    mailbox_validate
        jc      short timer_open_close_done
        mov     word ptr cs:mailbox_status[si],0
        cmp     bh,0Ch
        jne     short mailbox_close
        mov     word ptr cs:mailbox_open[si],1
        jmp     short timer_open_close_done
mailbox_close:
        mov     word ptr cs:mailbox_open[si],0
timer_open_close_done:
        pop     si
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled

int15_message_timer_add:
        push    bp
        mov     bp,sp
        push    ax
        push    cx
        push    dx
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     short timer_add_done
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short timer_add_done
        call    timer_now
        mov     word ptr cs:timer_start_lo[si],ax
        mov     word ptr cs:timer_start_hi[si],dx
        cmp     bh,05h
        je      short timer_write_absolute
        mov     ax,word ptr ss:[bp+14]
        mov     dx,word ptr ss:[bp+16]
        jmp     short timer_start_store
timer_write_absolute:
        mov     cx,word ptr ss:[bp+14]
        sub     cx,ax
        mov     ax,cx
        mov     cx,word ptr ss:[bp+16]
        sbb     cx,dx
        mov     dx,cx
        jnc     short timer_start_store
        add     ax,0D600h              ; schedule after midnight if needed
        adc     dx,0083h
timer_start_store:
        mov     word ptr cs:timer_duration_lo[si],ax
        mov     word ptr cs:timer_duration_hi[si],dx
        mov     word ptr cs:timer_open[si],1
        mov     word ptr cs:timer_state[si],1
timer_add_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; Locate the sole full-screen foreground window.  A search below that window
; or a coordinate outside the physical text screen returns a null handle.
int15_locate:
        push    ax
        push    bx
        mov     ax,es
        or      ax,ax
        jnz     short locate_none
        mov     ax,40h
        mov     es,ax
        cmp     bh,byte ptr es:[4Ah]  ; zero-based column versus BIOS width
        jae     short locate_none
        mov     al,byte ptr es:[84h]  ; zero-based last row on EGA/VGA
        or      al,al
        jnz     short locate_rows
        mov     al,24                 ; conservative 25-row fallback
locate_rows:
        cmp     bl,al
        ja      short locate_none
        mov     ax,word ptr cs:task_handle_segment
        mov     es,ax
        jmp     short locate_done
locate_none:
        xor     ax,ax
        mov     es,ax
locate_done:
        pop     bx
        pop     ax
        jmp     int15_handled

; Return the foreground physical text buffer as the current task's virtual
; screen.  Zero selects the default window; a nonzero BX must be the exact
; resident task handle.  Invalid handles return a null, empty buffer.
int15_getbuf:
        push    ax
        or      bx,bx
        jz      short getbuf_valid
        cmp     bx,word ptr cs:task_handle_segment
        jne     short getbuf_invalid
getbuf_valid:
        mov     ax,40h
        mov     es,ax
        mov     cx,word ptr es:[4Ah]  ; text columns
        or      cx,cx
        jnz     short getbuf_columns
        mov     cx,80
getbuf_columns:
        xor     ax,ax
        mov     al,byte ptr es:[84h]  ; rows minus one
        or      al,al
        jnz     short getbuf_rows
        mov     al,24
getbuf_rows:
        inc     ax
        mul     cx
        shl     ax,1                  ; character plus attribute per cell
        mov     cx,ax
        mov     ax,word ptr cs:video_segment
        mov     es,ax
        xor     di,di
        xor     dl,dl                 ; text screen
        pop     ax
        jmp     int15_handled
getbuf_invalid:
        xor     ax,ax
        mov     es,ax
        xor     di,di
        xor     cx,cx
        xor     dl,dl
        pop     ax
        jmp     int15_handled

int15_foreground:
        mov     bx,word ptr cs:task_handle_segment
        jmp     int15_handled

int15_dosuser:
        mov     bx,word ptr cs:task_handle_segment
        jmp     int15_handled

; Report the current foreground DOS allocation and bounded task-system pool.
; The call is process-context only because querying the current PSP chains to
; DOS.  DX must identify the resident foreground task handle.
int15_processmem:
        cmp     dx,word ptr cs:task_handle_segment
        jne     short processmem_invalid
        push    es
        push    si
        push    di
        xor     bx,bx                 ; allocated system-memory paragraphs
        xor     cx,cx                 ; largest available system block
        mov     si,offset system_used
        mov     di,SYSTEM_SLOT_COUNT
processmem_slots:
        cmp     byte ptr cs:[si],0
        je      short processmem_free
        add     bx,MEM_SLOT_SIZE / 16
        jmp     short processmem_next
processmem_free:
        mov     cx,MEM_SLOT_SIZE / 16
processmem_next:
        inc     si
        dec     di
        jnz     short processmem_slots

        push    bx
        push    cx
        mov     ah,51h                ; DOS 2+ current PSP
        int     21h
        mov     si,bx
        pop     cx
        pop     bx
        xor     dx,dx
        or      si,si
        jz      short processmem_done
        mov     ax,si
        dec     ax
        mov     es,ax                 ; owning MCB immediately before PSP
        mov     al,byte ptr es:[0]
        cmp     al,'M'
        je      short processmem_mcb_type
        cmp     al,'Z'
        jne     short processmem_done
processmem_mcb_type:
        cmp     word ptr es:[1],si
        jne     short processmem_done
        mov     dx,word ptr es:[3]    ; allocation size excluding MCB
processmem_done:
        pop     di
        pop     si
        pop     es
        xor     ax,ax                 ; no swapped/shared flags
        jmp     int15_handled
processmem_invalid:
        mov     ax,0FFFFh             ; Open MaxView invalid-handle status
        xor     bx,bx
        xor     cx,cx
        xor     dx,dx
        jmp     int15_handled

int15_getpath:
        push    ax
        push    cx
        push    si
        push    di
        mov     si,offset install_path
        mov     cx,67
        cld
getpath_copy:
        mov     al,byte ptr cs:[si]
        inc     si
        stosb
        or      al,al
        jz      short getpath_clear
        loop    getpath_copy
        jmp     short getpath_done
getpath_clear:
        dec     cx
        xor     al,al
        rep     stosb
getpath_done:
        pop     di
        pop     si
        pop     cx
        pop     ax
        jmp     int15_handled

int15_putkey:
        cmp     dx,word ptr cs:task_handle_segment
        jne     short putkey_invalid
        call    enqueue_bios_key
        jmp     int15_handled
putkey_invalid:
        mov     ax,1
        jmp     int15_handled

; Queue BX (BH scan code, BL character) in the BIOS foreground buffer.
; AX=0 succeeds and AX=1 reports the standard full-buffer condition.
enqueue_bios_key:
        push    dx
        push    di
        push    es
        mov     ax,40h                ; BIOS data area
        mov     es,ax
        mov     di,word ptr es:[1Ch]  ; keyboard-buffer tail
        mov     dx,di
        add     dx,2
        cmp     dx,3Eh
        jb      short enqueue_nowrap
        mov     dx,1Eh
enqueue_nowrap:
        cmp     dx,word ptr es:[1Ah]  ; full when next tail is head
        je      short enqueue_full
        mov     word ptr es:[di],bx
        mov     word ptr es:[1Ch],dx
        xor     ax,ax
        jmp     short enqueue_done
enqueue_full:
        mov     ax,1
enqueue_done:
        pop     es
        pop     di
        pop     dx
        ret

; Traverse the resident foreground task followed by allocated timer objects.
; Timer slots appear in stable allocation-pool order; a stale handle is
; rejected instead of silently restarting enumeration.
int15_objnext:
        push    bx
        push    cx
        push    si
        mov     ax,es
        or      ax,ax
        jnz     short objnext_existing
        or      di,di
        jnz     short objnext_invalid
        mov     ax,word ptr cs:task_handle_segment
        mov     es,ax
        xor     di,di
        xor     ax,ax
        jmp     short objnext_done
objnext_existing:
        or      di,di
        jnz     short objnext_invalid
        cmp     ax,word ptr cs:task_handle_segment
        jne     short objnext_timer
        xor     si,si
        jmp     short objnext_scan
objnext_timer:
        call    timer_validate
        jc      short objnext_mailbox
        add     si,2
objnext_scan:
        cmp     si,TIMER_SLOT_COUNT * 2
        jae     short objnext_mailbox_first
        cmp     word ptr cs:timer_used[si],0
        jne     short objnext_found
        add     si,2
        jmp     short objnext_scan
objnext_found:
        mov     ax,word ptr cs:timer_handle_segments[si]
        mov     es,ax
        xor     di,di
        xor     ax,ax
        jmp     short objnext_done
objnext_mailbox:
        call    mailbox_validate
        jc      short objnext_invalid
        add     si,2
        jmp     short objnext_mailbox_scan
objnext_mailbox_first:
        xor     si,si
objnext_mailbox_scan:
        cmp     si,MAILBOX_SLOT_COUNT * 2
        jae     short objnext_end
        cmp     word ptr cs:mailbox_used[si],0
        jne     short objnext_mailbox_found
        add     si,2
        jmp     short objnext_mailbox_scan
objnext_mailbox_found:
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        mov     es,ax
        xor     di,di
        xor     ax,ax
        jmp     short objnext_done
objnext_end:
        xor     ax,ax
        mov     es,ax
        xor     di,di
        jmp     short objnext_done
objnext_invalid:
        mov     ax,1
objnext_done:
        pop     si
        pop     cx
        pop     bx
        jmp     int15_handled

; DESQview 2.5-format information for the sole foreground task.  BX may be
; zero for the default task or the exact resident task-handle segment.
int15_wininfo:
        cmp     dx,0100h
        jne     short wininfo_invalid
        or      bx,bx
        jz      short wininfo_valid
        cmp     bx,word ptr cs:task_handle_segment
        jne     short wininfo_invalid
wininfo_valid:
        push    bx
        mov     byte ptr es:[di+0],1  ; task rather than child window
        mov     byte ptr es:[di+1],1  ; owner process number
        mov     bx,word ptr cs:task_handle_segment
        mov     word ptr es:[di+2],bx ; owner task handle
        mov     word ptr es:[di+4],0  ; no separate mapping context yet
        mov     byte ptr es:[di+6],0  ; waiting/runnable foreground state
        mov     byte ptr es:[di+7],0
        mov     word ptr es:[di+8],1  ; belongs to a DESQview process
        mov     byte ptr es:[di+10],1 ; foreground-only window
        pop     bx
        xor     ax,ax
        jmp     int15_handled
wininfo_invalid:
        mov     ax,1
        jmp     int15_handled

int15_getmem:
        push    bx
        push    cx
        push    si
        push    dx
        mov     si,offset system_used
        mov     di,offset system_pool
        mov     cx,SYSTEM_SLOT_COUNT
        call    allocate_slot
        pop     dx
        pop     si
        pop     cx
        pop     bx
        jmp     int15_handled

int15_putmem:
        push    bx
        push    cx
        push    si
        push    dx
        mov     si,offset system_used
        mov     bx,offset system_pool
        mov     cx,SYSTEM_SLOT_COUNT
        call    release_slot
        pop     dx
        pop     si
        pop     cx
        pop     bx
        jmp     int15_handled

int15_getcommon:
        push    bx
        push    cx
        push    si
        push    dx
        mov     si,offset common_used
        mov     di,offset common_pool
        mov     cx,COMMON_SLOT_COUNT
        call    allocate_slot
        pop     dx
        pop     si
        pop     cx
        pop     bx
        jmp     int15_handled

int15_putcommon:
        push    bx
        push    cx
        push    si
        push    dx
        mov     si,offset common_used
        mov     bx,offset common_pool
        mov     cx,COMMON_SLOT_COUNT
        call    release_slot
        pop     dx
        pop     si
        pop     cx
        pop     bx
        jmp     int15_handled

int15_common_status:
        push    ax
        push    si
        xor     bx,bx
        mov     si,offset common_used
        mov     cx,COMMON_SLOT_COUNT
common_status_loop:
        cmp     byte ptr cs:[si],0
        jne     short common_status_used
        add     bx,MEM_SLOT_SIZE
common_status_used:
        inc     si
        loop    common_status_loop
        xor     cx,cx
        or      bx,bx
        jz      short common_status_done
        mov     cx,MEM_SLOT_SIZE
common_status_done:
        mov     dx,COMMON_TOTAL
        pop     si
        pop     ax
        jmp     int15_handled

; Walk the DOS MCB chain and report free conventional memory in KiB.  This is
; a process-context service because AH=52h chains into DOS.  Invalid chains
; fail closed with zero available/largest values while retaining BIOS total.
int15_conventional_status:
        push    ax
        push    si
        push    di
        push    bp
        push    es
        xor     si,si                 ; free paragraphs
        xor     di,di                 ; largest free block in paragraphs
        mov     ah,52h                ; DOS list of lists
        int     21h
        cmp     bx,2
        jb      short conventional_invalid
        mov     ax,word ptr es:[bx-2] ; first MCB segment
        mov     bp,4096               ; malformed-chain guard
conventional_loop:
        or      ax,ax
        jz      short conventional_invalid
        cmp     ax,0A000h
        jae     short conventional_invalid
        mov     es,ax
        mov     bl,byte ptr es:[0]
        cmp     bl,'M'
        je      short conventional_type_ok
        cmp     bl,'Z'
        jne     short conventional_invalid
conventional_type_ok:
        mov     cx,word ptr es:[3]
        or      cx,cx
        jz      short conventional_invalid
        cmp     word ptr es:[1],0
        jne     short conventional_used
        add     si,cx
        jc      short conventional_invalid
        cmp     cx,di
        jbe     short conventional_used
        mov     di,cx
conventional_used:
        cmp     bl,'Z'
        je      short conventional_done
        mov     ax,es
        add     ax,cx
        inc     ax
        dec     bp
        jnz     short conventional_loop
conventional_invalid:
        xor     si,si
        xor     di,di
conventional_done:
        mov     bx,si
        shr     bx,1
        shr     bx,1
        shr     bx,1
        shr     bx,1
        shr     bx,1
        shr     bx,1                  ; paragraphs to KiB
        mov     cx,di
        shr     cx,1
        shr     cx,1
        shr     cx,1
        shr     cx,1
        shr     cx,1
        shr     cx,1
        int     12h
        mov     dx,ax                 ; BIOS conventional total in KiB
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     ax
        jmp     int15_handled

; Translate the standard EMS page counts to the KiB units required by DE06h.
; With a conventional EMS provider, all unallocated pages form the largest
; allocatable block.  Values beyond the 16-bit KiB result are saturated.
int15_expanded_status:
        push    ax
        mov     ah,40h
        int     67h
        or      ah,ah
        jnz     short expanded_unavailable
        mov     ah,42h
        int     67h
        or      ah,ah
        jnz     short expanded_unavailable
        cmp     bx,0FFFh
        jbe     short expanded_free_scale
        mov     bx,0FFFFh
        jmp     short expanded_free_done
expanded_free_scale:
        shl     bx,1
        shl     bx,1
        shl     bx,1
        shl     bx,1
expanded_free_done:
        mov     cx,bx
        cmp     dx,0FFFh
        jbe     short expanded_total_scale
        mov     dx,0FFFFh
        jmp     short expanded_done
expanded_total_scale:
        shl     dx,1
        shl     dx,1
        shl     dx,1
        shl     dx,1
expanded_done:
        pop     ax
        jmp     int15_handled
expanded_unavailable:
        xor     bx,bx
        xor     cx,cx
        xor     dx,dx
        pop     ax
        jmp     int15_handled

; Allocate one bounded resident slot.  BX is the requested byte count,
; SI is the allocation bitmap, DI is the pool base and CX is the slot count.
; AX=0 and ES:DI identify a zero-filled slot; AX=1 and 0000:0000 mean failure.
allocate_slot:
        mov     ax,1
        or      bx,bx
        jz      short allocate_fail
        cmp     bx,MEM_SLOT_SIZE
        ja      short allocate_fail
allocate_scan:
        cmp     byte ptr cs:[si],0
        je      short allocate_found
        inc     si
        add     di,MEM_SLOT_SIZE
        loop    allocate_scan
allocate_fail:
        xor     di,di
        mov     es,di
        mov     ax,1
        ret
allocate_found:
        mov     byte ptr cs:[si],1
        push    cs
        pop     es
        push    di
        push    cx
        push    ax
        pushf
        cld
        xor     ax,ax
        mov     cx,MEM_SLOT_SIZE / 2
        rep     stosw
        popf
        pop     ax
        pop     cx
        pop     di
        xor     ax,ax
        ret

; Release an exact slot pointer.  ES:DI is the pointer, SI the bitmap,
; BX the pool base and CX the slot count.  AX=0 succeeds; AX=1 rejects it.
release_slot:
        mov     ax,es
        push    cs
        pop     dx
        cmp     ax,dx
        jne     short release_fail
release_scan:
        cmp     di,bx
        je      short release_found
        inc     si
        add     bx,MEM_SLOT_SIZE
        loop    release_scan
release_fail:
        mov     ax,1
        ret
release_found:
        cmp     byte ptr cs:[si],0
        je      short release_fail
        mov     byte ptr cs:[si],0
        xor     ax,ax
        ret

int15_handled:
        popf
        iret
int15_chain:
        popf
        jmp     dword ptr cs:old15

; Validate an allocated timer segment. AX is the candidate segment. On
; success CF is clear and SI is the word index in the timer tables. BX and CX
; are preserved; callers preserve SI when the public ABI requires it.
timer_validate:
        push    bx
        push    cx
        xor     si,si
        mov     cx,TIMER_SLOT_COUNT
timer_validate_scan:
        cmp     ax,word ptr cs:timer_handle_segments[si]
        jne     short timer_validate_next
        cmp     word ptr cs:timer_used[si],1
        jne     short timer_validate_invalid
        clc
        jmp     short timer_validate_done
timer_validate_next:
        add     si,2
        loop    timer_validate_scan
timer_validate_invalid:
        stc
timer_validate_done:
        pop     cx
        pop     bx
        ret

mailbox_validate:
        push    bx
        push    cx
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
mailbox_validate_scan:
        cmp     ax,word ptr cs:mailbox_handle_segments[si]
        jne     short mailbox_validate_next
        cmp     word ptr cs:mailbox_used[si],1
        jne     short mailbox_validate_invalid
        clc
        jmp     short mailbox_validate_done
mailbox_validate_next:
        add     si,2
        loop    mailbox_validate_scan
mailbox_validate_invalid:
        stc
mailbox_validate_done:
        pop     cx
        pop     bx
        ret

; Return hundredths since midnight in DX:AX using the BIOS tick counter.
; Multiplication by 500/91 tracks the 18.2 Hz clock to within about one tick
; while avoiding DOS calls from the resident INT 15h handler.
timer_now:
        push    bx
        push    cx
        push    si
        push    di
        xor     ax,ax
        int     1Ah                    ; CX:DX ticks since midnight
        mov     ax,dx
        mov     bx,500
        mul     bx
        mov     si,ax                  ; low product word
        mov     di,dx                  ; carry into high word
        mov     ax,cx
        mul     bx
        add     ax,di                  ; product fits below 2^32 per day
        mov     cx,ax                  ; high product word
        mov     bx,91
        xor     dx,dx
        mov     ax,cx
        div     bx
        mov     cx,ax                  ; high quotient word
        mov     ax,si
        div     bx
        mov     dx,cx
        pop     di
        pop     si
        pop     cx
        pop     bx
        ret

; Return elapsed hundredths for timer slot SI in DX:AX. A running timer is
; advanced against the BIOS clock, including one midnight wrap, and becomes
; state 2 when its bounded duration expires.
timer_elapsed:
        push    bx
        push    cx
        cmp     word ptr cs:timer_state[si],1
        je      short timer_elapsed_running
        cmp     word ptr cs:timer_state[si],2
        je      short timer_elapsed_expired
        xor     ax,ax
        xor     dx,dx
        jmp     short timer_elapsed_done
timer_elapsed_expired:
        mov     ax,word ptr cs:timer_duration_lo[si]
        mov     dx,word ptr cs:timer_duration_hi[si]
        jmp     short timer_elapsed_done
timer_elapsed_running:
        call    timer_now
        sub     ax,word ptr cs:timer_start_lo[si]
        sbb     dx,word ptr cs:timer_start_hi[si]
        jnc     short timer_elapsed_compare
        add     ax,0D600h              ; 8,640,000 hundredths per day
        adc     dx,0083h
timer_elapsed_compare:
        mov     bx,word ptr cs:timer_duration_hi[si]
        cmp     dx,bx
        jb      short timer_elapsed_done
        ja      short timer_elapsed_finish
        mov     cx,word ptr cs:timer_duration_lo[si]
        cmp     ax,cx
        jb      short timer_elapsed_done
timer_elapsed_finish:
        mov     word ptr cs:timer_state[si],2
        mov     ax,word ptr cs:timer_duration_lo[si]
        mov     dx,word ptr cs:timer_duration_hi[si]
timer_elapsed_done:
        pop     cx
        pop     bx
        ret

; Relocate the saved flags/IRET frame over one consumed handle DWORD.
; BP is the message handler frame pointer.
message_shift4:
        push    ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+12],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+10],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp+8],ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp+6],ax
        pop     ax
        ret

; Relocate the frame over a handle plus one DWORD argument.
message_shift8:
        push    ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+16],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+14],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp+12],ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp+10],ax
        pop     ax
        ret

; Build four paragraph-addressable public timer headers. Every slot is 32
; bytes, so its segment:0000 handle remains stable for the resident lifetime.
initialize_timer_objects:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     bx,offset timer_objects
        xor     si,si
        mov     cx,TIMER_SLOT_COUNT
initialize_timer_loop:
        push    cx
        mov     ax,bx
        mov     cl,4
        shr     ax,cl
        pop     cx
        mov     dx,cs
        add     ax,dx
        mov     word ptr timer_handle_segments[si],ax
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],0Bh
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        add     bx,TIMER_OBJECT_SIZE
        add     si,2
        loop    initialize_timer_loop
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

initialize_mailbox_objects:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     bx,offset mailbox_objects
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
initialize_mailbox_loop:
        push    cx
        mov     ax,bx
        mov     cl,4
        shr     ax,cl
        pop     cx
        mov     dx,cs
        add     ax,dx
        mov     word ptr mailbox_handle_segments[si],ax
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],09h
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        add     bx,MAILBOX_OBJECT_SIZE
        add     si,2
        loop    initialize_mailbox_loop
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; Capture the COM program's fully-qualified environment tail before becoming
; resident, then strip MAXVTSR.COM. DOS 3+ places the executable pathname
; after the environment's double NUL and following count word.
capture_install_path:
        pushf
        push    ax
        push    bx
        push    cx
        push    si
        push    di
        push    es
        mov     ax,word ptr cs:[2Ch]  ; environment segment in the PSP
        or      ax,ax
        jz      short capture_fallback
        mov     es,ax
        xor     di,di
        mov     cx,0FFFEh             ; reject a malformed unterminated block
capture_find_end:
        cmp     byte ptr es:[di],0
        je      short capture_zero
        inc     di
        loop    capture_find_end
        jmp     short capture_fallback
capture_zero:
        inc     di
        dec     cx
        jz      short capture_fallback
        cmp     byte ptr es:[di],0
        jne     short capture_find_end
        inc     di                    ; skip the second NUL
        add     di,2                  ; skip additional-string count
        mov     si,offset install_path
        mov     bx,0FFFFh             ; destination of last backslash
        mov     cx,66
        cld
capture_copy:
        mov     al,byte ptr es:[di]
        inc     di
        or      al,al
        jz      short capture_copied
        mov     byte ptr cs:[si],al
        cmp     al,'\\'
        jne     short capture_not_slash
        mov     bx,si
capture_not_slash:
        inc     si
        loop    capture_copy
capture_copied:
        mov     byte ptr cs:[si],0
        cmp     bx,0FFFFh
        je      short capture_fallback
        mov     byte ptr cs:[bx],0    ; remove separator and executable name
        cmp     bx,offset install_path+2
        jne     short capture_done
        cmp     byte ptr cs:install_path+1,':'
        jne     short capture_done
        mov     byte ptr cs:[bx],'\\' ; retain root form such as C:\
        mov     byte ptr cs:[bx+1],0
        jmp     short capture_done
capture_fallback:
        mov     byte ptr cs:install_path,'.'
        mov     byte ptr cs:install_path+1,0
capture_done:
        pop     es
        pop     di
        pop     si
        pop     cx
        pop     bx
        pop     ax
        popf
        ret

int2f_handler:
        pushf
        cmp     ax,MUX_STATUS
        je      short int2f_status
        cmp     ax,MUX_INFO
        je      short int2f_info
        cmp     ax,MUX_RESET
        je      short int2f_reset
        cmp     ax,MUX_TASK_INFO
        je      short int2f_task_info
        cmp     ax,MUX_CAPS2
        jne     short int2f_not_caps2
        jmp     int2f_caps2
int2f_not_caps2:
        cmp     ax,MUX_CAPS3
        jne     short int2f_not_caps3
        jmp     int2f_caps3
int2f_not_caps3:
        jmp     int2f_chain
int2f_status:
        mov     bx,MUX_SIGNATURE
        mov     cx,MUX_VERSION        ; resident API version
        mov     dx,DV_VERSION
        popf
        iret
int2f_info:
        mov     bx,CAPABILITIES
        mov     cx,word ptr cs:critical_depth
        mov     dx,word ptr cs:video_segment
        popf
        iret
int2f_reset:
        mov     word ptr cs:critical_depth,0
        mov     word ptr cs:api_level,0100h
        mov     word ptr cs:task_flags,TASK_JUSTIFY
        mov     byte ptr cs:error_mode,0
        mov     byte ptr cs:debug_column,0
        mov     byte ptr cs:keyboard_mouse,0
        push    ax
        push    cx
        push    di
        push    es
        push    cs
        pop     es
        xor     ax,ax
        mov     di,offset system_used
        mov     cx,SYSTEM_SLOT_COUNT
        cld
        rep     stosb
        mov     di,offset timer_used
        mov     cx,TIMER_SLOT_COUNT
        rep     stosw
        mov     di,offset mailbox_used
        mov     cx,MAILBOX_SLOT_COUNT
        rep     stosw
        pop     es
        pop     di
        pop     cx
        pop     ax
        popf
        iret
int2f_task_info:
        mov     bx,word ptr cs:api_level
        mov     cx,1                   ; sole foreground program
        mov     dx,word ptr cs:task_flags
        popf
        iret
int2f_caps2:
        mov     bx,CAPABILITIES2
        xor     cx,cx
        xor     dx,dx
        popf
        iret
int2f_caps3:
        mov     bx,CAPABILITIES3
        xor     cx,cx
        xor     dx,dx
        popf
        iret
int2f_chain:
        popf
        jmp     dword ptr cs:old2f

old10          dd 0
old15          dd 0
old21          dd 0
old2f          dd 0
critical_depth dw 0
api_level      dw 0100h
task_flags     dw TASK_JUSTIFY
error_mode     db 0
debug_column   db 0
keyboard_mouse db 0
video_segment  dw 0B800h
task_handle_segment dw 0
install_path   db 67 dup(0)
system_used    db SYSTEM_SLOT_COUNT dup(0)
common_used    db COMMON_SLOT_COUNT dup(0)
timer_used     dw TIMER_SLOT_COUNT dup(0)
timer_handle_segments dw TIMER_SLOT_COUNT dup(0)
timer_open     dw TIMER_SLOT_COUNT dup(0)
timer_state    dw TIMER_SLOT_COUNT dup(0)
timer_start_lo dw TIMER_SLOT_COUNT dup(0)
timer_start_hi dw TIMER_SLOT_COUNT dup(0)
timer_duration_lo dw TIMER_SLOT_COUNT dup(0)
timer_duration_hi dw TIMER_SLOT_COUNT dup(0)
mailbox_used   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_handle_segments dw MAILBOX_SLOT_COUNT dup(0)
mailbox_open   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_status dw MAILBOX_SLOT_COUNT dup(0)
system_pool    db (SYSTEM_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)
common_pool    db (COMMON_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)

; Keep this label paragraph-aligned: GETFOREGROUND returns segment:0000.
; Dynamic alignment remains correct as the resident code grows.
TASK_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      TASK_OBJECT_PAD dup (0)
task_object    label byte
        dw      0,0                   ; previous and next task objects
        dw      0FEDCh                ; DESQview-compatible object signature
        dw      0                     ; window/task object type
        dw      0,0                   ; public handle, patched at install
        dw      0,0                   ; canonical address, patched at install
        db      1,0                   ; task flag and internal window number
        dw      0,0,0,0,0,0,0        ; bounded public header storage

; NEW/FREE timers use separate paragraph-aligned 32-byte headers. They expose
; pointer-compatible identities now; countdown messages are not implemented.
TIMER_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      TIMER_OBJECT_PAD dup (0)
timer_objects  db (TIMER_SLOT_COUNT * TIMER_OBJECT_SIZE) dup(0)

MAILBOX_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      MAILBOX_OBJECT_PAD dup (0)
mailbox_objects db (MAILBOX_SLOT_COUNT * MAILBOX_OBJECT_SIZE) dup(0)

installed_msg  db 'Open MaxView resident API 0.22 installed.',13,10,'$'
already_msg    db 'Open MaxView resident API is already installed.',13,10,'$'

resident_end:

        end     start
