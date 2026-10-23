; SPDX-License-Identifier: GPL-3.0-or-later
; Open MaxView resident compatibility API, 16-bit DOS .COM program.
;
; Assembled by the JWasm embedded in Open 386MAX and linked by JWlink.
;
; Implemented compatibility surface:
;   INT 21h AX=2B01h CX='DE' DX='SQ'  presence/version query
;   INT 15h AX=1000h                 cooperative PAUSE
;   INT 15h AX=1001h/1002h           system-memory allocate/release aliases
;   INT 15h AX=1003h                 foreground PRINTC text output
;   INT 15h AX=1013h/1014h/1015h     second-level callback services
;   INT 15h AX=1016h                 object-handle validation
;   INT 15h AX=1018h                 foreground window location
;   INT 15h AX=1019h                 queued PC-speaker SOUND
;   INT 15h AX=101Ah/1025h           OSTACK/USTACK task-stack switching
;   INT 15h AX=101Bh/101Ch           nested critical-section markers
;   INT 15h AX=1022h, BX=0000h       TopView-compatible API identity
;   INT 15h AX=1024h                 foreground virtual-screen buffer
;   INT 15h AX=102Ch, ES:DI=DVP      APP_START:  BX=its size; BX=the new
;                                    task's handle (0:  none); the host starts
;                                    it (D70Bh)
;   INT 15h AX=102Dh, BL=operation   keyboard-mouse mode state
;   INT 15h AX=102Eh                 DESQview 2.40 system-memory allocation
;   INT 15h AH=12h, BH=00h           HANDLE object-message subset
;   INT 15h AH=12h, BH=03h           mailbox ADDR sender query
;   INT 15h AH=12h, BH=04h           ready mailbox pointer READ
;   INT 15h AH=12h, BH=0Bh           mailbox SUBFROM by reference
;   INT 15h AH=12h, BH=11h           foreground window AT / mailbox SETNAME
;   INT 15h AH=12h, BH=12h           mailbox GETNAME
;   INT 15h AX=DE04h                 common-memory availability
;   INT 15h AX=DE05h                 conventional-memory availability
;   INT 15h AX=DE06h                 expanded-memory availability
;   INT 15h AX=DE07h                 foreground program number
;   INT 15h AX=DE0Ah, BL=character   physical status-line debug output
;   INT 15h AX=DE0Bh, BX=level       minimum API level selection
;   INT 15h AX=DE0Ch/DE0Dh           system-memory allocate/release
;   INT 15h AX=DE0Eh                 FINDMAIL named-mailbox lookup
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
;   INT 2Fh AX=D705h                 extended compatibility capabilities
;   INT 2Fh AX=D706h                 sound-queue diagnostic query
;   INT 2Fh AX=D707h                 per-task state block (for the core)
;                                    with the GETMEM pool
;   INT 2Fh AX=D708h, BX=task        a task ended:  free its objects
;   INT 2Fh AX=D70Ah, BX=task        the foreground task (FFFFh:  none known)
;   INT 2Fh AX=D709h, BX=1/0         the multitasking core switches / no
;                                    longer:  READ of an empty mailbox waits
;   INT 2Fh AX=D70Bh                 for the host (task 0):  AX=0, ES:BX =
;                                    an APP_START asked (appreq), else AX=1

DV_VERSION     equ 0250h        ; 2.80:  BH major, BL minor in binary (as DV)
MUX_STATUS     equ 0D700h
MUX_INFO       equ 0D701h
MUX_RESET      equ 0D702h
MUX_TASK_INFO  equ 0D703h
MUX_CAPS2      equ 0D704h
MUX_CAPS3      equ 0D705h
MUX_SOUND_INFO equ 0D706h
MUX_TASK_STATE equ 0D707h
MUX_TASK_END   equ 0D708h
MUX_CORE       equ 0D709h
MUX_SIGNATURE  equ 04F44h            ; "OD" in register byte order
MUX_VERSION    equ 0024h
CAPABILITIES   equ 0FFFFh
CAPABILITIES2  equ 0FFFFh
CAPABILITIES3  equ 3FFFh             ; object/window and task-stack services

MEM_SLOT_SIZE      equ 0100h
SYSTEM_SLOT_COUNT  equ 8
COMMON_SLOT_COUNT  equ 8
COMMON_TOTAL       equ COMMON_SLOT_COUNT * MEM_SLOT_SIZE
TIMER_SLOT_COUNT   equ 16
TIMER_OBJECT_SIZE  equ 32
MAILBOX_SLOT_COUNT equ 8
MAILBOX_OBJECT_SIZE equ 32
MAILBOX_QUEUE_DEPTH equ 4
MAILBOX_MESSAGE_SIZE equ 128
MAILBOX_ENTRY_COUNT equ MAILBOX_SLOT_COUNT * MAILBOX_QUEUE_DEPTH
MAILBOX_NAME_SIZE  equ 32
SECOND_LEVEL_COUNT equ 16
SOUND_QUEUE_COUNT equ 32
TASK_STACK_SIZE equ 512
READN_SIZE equ 80
API_STACK_SIZE equ 512                ; a call's stack (api_enter), per task
API_COPY equ 64                       ; the caller's frame and arguments                     ; READN:  characters at most
FIELD_BUFFER_SIZE equ 128
WF_VISIBLE equ 1
WF_FRAME equ 2
WF_DRAWN equ 4
WF_LOGICAL equ 8                      ; DAh:  colours 1-16 (wobj_logical)
WF_TOP equ 16                         ; on top (C0h-C2h):  a double frame
SUB_COUNT equ 8                       ; subtasks (their stacks)
SUB_SIZE equ 512
WOBJ_COUNT equ 8                      ; window objects (stream E6h)
WOBJ_POOL_SIZE equ 8192                     ; their contents and saved screens
WOBJ_TITLE_SIZE equ 32
KOBJ_COUNT equ 8                      ; keyboard objects (NEW 0Ah)
POINTER_SLOT_COUNT equ 8
POINTER_OBJECT_SIZE equ 32            ; its message at 10h (6 bytes)
MUX_FOREGROUND equ 0D70Ah
MUX_APP_START  equ 0D70Bh
APPREQ_MAX     equ 1A0h                ; DVP bytes (DESQview 2.x's 416)
TASK_OBJECT_COUNT equ 32              ; task 0 .. 31 of the multitasking core
TASK_OBJECT_SIZE equ 32

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
        call    initialize_task_objects
        call    initialize_keyboard_objects
        mov     ax,word ptr task_objects_base
        mov     word ptr task_handle_segment,ax ; task 0's, the caller's
        mov     word ptr task_live,1
        call    initialize_timer_objects
        call    initialize_pointer_objects
        call    initialize_window_objects
        call    initialize_keyboard_objects2
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

        mov     ax,351Ch
        int     21h
        mov     word ptr old1c,bx
        mov     word ptr old1c+2,es

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
        mov     dx,offset int1c_handler
        mov     ax,251Ch
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

; BIOS invokes INT 1Ch once per clock tick. Preserve the complete interrupted
; register state, advance the bounded foreground sound queue, then chain.
int1c_handler:
        pushf
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        call    sound_tick
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        popf
        jmp     dword ptr cs:old1c

int15_handler:
        pushf
        cmp     byte ptr cs:api_crit,0 ; in a call:  this INT 15h is nested
        je      short int15_not_nested ; (an IRQ's:  INT 9 AH=4Fh, the disk
        inc     word ptr cs:api_nest  ; BIOS' AH=90h/91h), api_leave not
int15_not_nested:                     ; for it
        cmp     word ptr cs:task_handle_segment,0
        jne     short int15_have_task
        call    task_handle_init
int15_have_task:
        cmp     ah,11h                ; AH=11h (but 1117h):  as AH=DEh in
        jne     short int15_not_11    ; DESQview 2.x (RBIL); the DV C
        cmp     al,17h                ; library calls FINDMAIL as 110Eh
        je      short int15_not_11
        mov     ah,0DEh
int15_not_11:
        cmp     ah,12h                ; TopView/DESQview SEND MESSAGE
        je      short int15_message_dispatch
        jmp     int15_not_message
int15_message_dispatch:
        cmp     byte ptr cs:api_crit,0 ; a call is one critical section, as
        jne     short message_dispatch_crit ; DESQview's (its waits:
        call    api_enter             ; api_pause), on a stack of its own
message_dispatch_crit:
        cmp     bl,3                  ; the current task's mailbox
        jne     short message_dispatch_not3
        jmp     message_default_mailbox
message_dispatch_not3:
        cmp     bl,2                  ; that of the task on the stack
        jne     short message_dispatch_not2
        jmp     message_task_mailbox
message_dispatch_not2:
        cmp     bl,5                  ; the current task's keyboard
        jne     short message_dispatch_not5
        jmp     message_default_keyboard
message_dispatch_not5:
        cmp     bl,4                  ; that of the task on the stack
        jne     short message_dispatch_go
        jmp     message_task_keyboard
message_dispatch_go:
        cmp     bh,0                  ; HANDLE
        je      short int15_dispatch_handle
        cmp     bh,1                  ; NEW
        je      short int15_dispatch_new
        cmp     bh,2                  ; FREE
        je      short int15_dispatch_free
        cmp     bh,3                  ; ADDR mailbox sender / window CONNECT
        je      short int15_dispatch_addr
        cmp     bh,4                  ; READ mailbox record
        je      short int15_dispatch_read
        cmp     bh,5                  ; WRITE absolute timer deadline
        je      short int15_dispatch_timer_add
        cmp     bh,8                  ; SIZEOF
        je      short int15_dispatch_timer_query
        cmp     bh,9                  ; LEN
        je      short int15_dispatch_timer_query
        cmp     bh,0Ah                ; ADDTO
        je      short int15_dispatch_timer_add
        cmp     bh,0Bh                ; SUBFROM mailbox by reference
        je      short int15_dispatch_mailbox_ref
        cmp     bh,0Ch                ; OPEN
        je      short int15_dispatch_timer_open_close
        cmp     bh,0Dh                ; CLOSE
        je      short int15_dispatch_timer_open_close
        cmp     bh,0Eh                ; ERASE
        je      short int15_dispatch_erase
        cmp     bh,0Fh                ; STATUS
        je      short int15_dispatch_timer_query
        cmp     bh,11h                ; SETNAME
        je      short int15_dispatch_mailbox_setname
        cmp     bh,12h                ; GETNAME
        je      short int15_dispatch_mailbox_getname
        cmp     bh,13h                ; READINTO
        je      short int15_dispatch_mailbox_readinto
        cmp     bh,15h                ; SETFLAGS
        je      short int15_dispatch_mailbox_setflags
        cmp     bh,16h                ; GETFLAGS
        je      short int15_dispatch_timer_query
        cmp     bh,14h                ; LOCK
        je      short int15_dispatch_lock
        jmp     short int15_unknown_message
int15_dispatch_lock:
        jmp     int15_message_lock
int15_dispatch_handle:
        jmp     int15_message_handle
int15_dispatch_new:
        jmp     int15_message_new
int15_dispatch_free:
        jmp     int15_message_free
int15_dispatch_addr:
        jmp     int15_message_addr_gateway
int15_dispatch_read:
        jmp     int15_message_read_gateway
int15_dispatch_timer_query:
        jmp     int15_message_timer_query
int15_dispatch_timer_add:
        jmp     int15_message_timer_add
int15_dispatch_mailbox_ref:
        jmp     int15_message_ref_gateway
int15_dispatch_timer_open_close:
        jmp     int15_message_timer_open_close
int15_dispatch_erase:
        jmp     int15_message_erase
int15_dispatch_mailbox_setname:
        jmp     int15_message_at_gateway
int15_dispatch_mailbox_getname:
        jmp     int15_message_readn_gateway
int15_dispatch_mailbox_readinto:
        jmp     int15_message_redraw_gateway
int15_dispatch_mailbox_setflags:
        jmp     int15_message_mailbox_setflags
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
        cmp     ax,1003h              ; PRINTC
        jne     short int15_not_printc
        cmp     dx,word ptr cs:task_handle_segment
        je      short int15_printc_ours
        jmp     int15_chain
int15_printc_ours:
        jmp     int15_printc
int15_not_printc:
        cmp     ax,1013h              ; GETBIT
        jne     short int15_not_getbit
        jmp     int15_getbit
int15_not_getbit:
        cmp     ax,1014h              ; FREEBIT
        jne     short int15_not_freebit
        jmp     int15_freebit
int15_not_freebit:
        cmp     ax,1015h              ; SETBIT
        jne     short int15_not_setbit
        jmp     int15_setbit
int15_not_setbit:
        cmp     ax,1016h              ; ISOBJ
        jne     short int15_not_isobj
        jmp     int15_isobj
int15_not_isobj:
        cmp     ax,1018h              ; LOCATE
        jne     short int15_not_locate
        jmp     int15_locate
int15_not_locate:
        cmp     ax,1019h              ; SOUND
        jne     short int15_not_sound
        jmp     int15_sound
int15_not_sound:
        cmp     ax,101Ah              ; OSTACK
        jne     short int15_not_ostack
        jmp     int15_ostack
int15_not_ostack:
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
        cmp     ax,1025h              ; USTACK
        jne     short int15_not_ustack
        jmp     int15_ustack
int15_not_ustack:
        cmp     ax,102Ch              ; APP_START
        jne     short int15_not_app_start
        jmp     int15_app_start
int15_not_app_start:
        cmp     ax,102Dh              ; keyboard mouse control
        jne     short int15_not_keyboard_mouse
        jmp     int15_keyboard_mouse
int15_not_keyboard_mouse:
        cmp     ax,102Eh              ; DESQview 2.40 extended GETMEM alias
        jne     short int15_not_extended_getmem
        jmp     int15_getmem
int15_not_extended_getmem:
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
        cmp     ax,0DE0Eh             ; FINDMAIL
        jne     short int15_not_findmail
        jmp     int15_findmail
int15_not_findmail:
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

; Display one exact character/attribute at the foreground logical cursor.
; The current foreground implementation aliases the BIOS hardware cursor.
; BX=0 therefore needs no synchronization work. Text output advances, wraps,
; and scrolls the full-screen window using BIOS services.
int15_printc:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        or      bx,bx
        jz      printc_done
        mov     si,bx
        mov     ah,0Fh
        int     10h
        cmp     al,3
        jbe     short printc_text_mode
        cmp     al,7
        jne     short printc_done
printc_text_mode:
        mov     byte ptr cs:printc_page,bh
        mov     byte ptr cs:printc_columns,ah
        mov     bh,byte ptr cs:printc_page
        mov     ah,03h
        int     10h
        mov     di,dx
        mov     ax,si
        mov     ah,09h
        mov     bx,si
        mov     bl,bh
        mov     bh,byte ptr cs:printc_page
        mov     cx,1
        int     10h
        mov     dx,di
        inc     dl
        cmp     dl,byte ptr cs:printc_columns
        jb      short printc_set_cursor
        xor     dl,dl
        inc     dh
        mov     ax,40h
        mov     es,ax
        mov     al,byte ptr es:[84h]
        or      al,al
        jnz     short printc_rows_ready
        mov     al,24
printc_rows_ready:
        cmp     dh,al
        jbe     short printc_set_cursor
        mov     byte ptr cs:printc_last_row,al
        mov     ax,0601h
        mov     bx,si
        xor     cx,cx
        mov     dh,byte ptr cs:printc_last_row
        mov     dl,byte ptr cs:printc_columns
        dec     dl
        int     10h
        mov     dh,byte ptr cs:printc_last_row
        xor     dl,dl
printc_set_cursor:
        mov     ah,02h
        mov     bh,byte ptr cs:printc_page
        int     10h
printc_done:
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     int15_handled

; Allocate one of the sixteen documented second-level interrupt bits and bind
; it to ES:DI. A null callback is rejected rather than leaving a callable null
; vector. The lowest free bit is returned in BX; zero reports exhaustion.
int15_getbit:
        push    ax
        push    cx
        push    dx
        push    si
        mov     ax,es
        or      ax,di
        jz      short getbit_exhausted
        mov     dx,1
        xor     si,si
        mov     cx,SECOND_LEVEL_COUNT
getbit_scan:
        test    word ptr cs:second_level_used,dx
        jz      short getbit_found
        shl     dx,1
        add     si,4
        loop    getbit_scan
getbit_exhausted:
        xor     bx,bx
        jmp     short getbit_done
getbit_found:
        or      word ptr cs:second_level_used,dx
        mov     word ptr cs:second_level_handlers[si],di
        mov     ax,es
        mov     word ptr cs:second_level_handlers[si+2],ax
        mov     bx,dx
getbit_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        jmp     int15_handled

; Remove every callback selected by BX. Pending callbacks are cancelled as
; part of the release, which also makes FREEBIT safe from inside a callback.
int15_freebit:
        push    ax
        push    cx
        push    dx
        push    si
        mov     ax,bx
        not     ax
        and     word ptr cs:second_level_pending,ax
        and     word ptr cs:second_level_used,ax
        mov     dx,1
        xor     si,si
        mov     cx,SECOND_LEVEL_COUNT
freebit_scan:
        test    bx,dx
        jz      short freebit_next
        mov     word ptr cs:second_level_handlers[si],0
        mov     word ptr cs:second_level_handlers[si+2],0
freebit_next:
        shl     dx,1
        add     si,4
        loop    freebit_scan
        pop     si
        pop     dx
        pop     cx
        pop     ax
        jmp     int15_handled

; Queue all allocated bits in BX and drain them in low-to-high order. Open
; MaxView's current foreground service has no scheduler/IRQ epilogue yet, so
; callbacks run synchronously before SETBIT returns. Nested SETBIT calls only
; extend the pending mask and are drained by the outer dispatcher.
int15_setbit:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        mov     ax,bx
        and     ax,word ptr cs:second_level_used
        or      word ptr cs:second_level_pending,ax
        cmp     byte ptr cs:second_level_active,0
        jne     setbit_done
        mov     byte ptr cs:second_level_active,1
setbit_dispatch:
        mov     ax,word ptr cs:second_level_pending
        and     ax,word ptr cs:second_level_used
        mov     word ptr cs:second_level_pending,ax
        or      ax,ax
        jz      short setbit_dispatch_done
        mov     dx,1
        xor     si,si
        mov     cx,SECOND_LEVEL_COUNT
setbit_scan:
        test    ax,dx
        jnz     short setbit_found
        shl     dx,1
        add     si,4
        loop    setbit_scan
        jmp     short setbit_dispatch_done
setbit_found:
        mov     ax,dx
        not     ax
        and     word ptr cs:second_level_pending,ax
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    ds
        push    es
        mov     ax,word ptr cs:task_handle_segment
        mov     es,ax
        call    dword ptr cs:second_level_handlers[si]
        pop     es
        pop     ds
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     setbit_dispatch
setbit_dispatch_done:
        mov     byte ptr cs:second_level_active,0
setbit_done:
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     int15_handled

; Queue one PC-speaker tone. CX is a BIOS-tick duration and BX is Hertz, with
; zero selecting silence. A zero duration cancels the current entry; BX=0
; additionally clears every queued entry. Queue saturation is a nonblocking
; no-op in the foreground implementation.
int15_sound:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        pushf
        cli
        or      cx,cx
        jnz     short sound_enqueue
        or      bx,bx
        jz      short sound_cancel_all
        call    sound_advance
        jmp     short sound_call_done
sound_cancel_all:
        call    sound_clear
        jmp     short sound_call_done
sound_enqueue:
        cmp     word ptr cs:sound_count,SOUND_QUEUE_COUNT
        jae     short sound_call_done
        mov     ax,bx
        or      ax,ax
        jz      short sound_frequency_ready
        cmp     ax,20
        jae     short sound_frequency_ready
        mov     ax,20
sound_frequency_ready:
        mov     si,word ptr cs:sound_tail
        mov     word ptr cs:sound_frequency[si],ax
        mov     word ptr cs:sound_duration[si],cx
        add     si,2
        cmp     si,SOUND_QUEUE_COUNT * 2
        jb      short sound_tail_ready
        xor     si,si
sound_tail_ready:
        mov     word ptr cs:sound_tail,si
        inc     word ptr cs:sound_count
        cmp     word ptr cs:sound_count,1
        jne     short sound_call_done
        mov     word ptr cs:sound_remaining,cx
        mov     bx,ax
        call    sound_program
sound_call_done:
        popf
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     int15_handled

; Consume one clock tick from the active queue entry.
sound_tick:
        cmp     word ptr cs:sound_count,0
        je      short sound_tick_done
        cmp     word ptr cs:sound_remaining,0
        je      short sound_tick_advance
        dec     word ptr cs:sound_remaining
        jne     short sound_tick_done
sound_tick_advance:
        call    sound_advance
sound_tick_done:
        ret

; Remove the active queue entry, then start the next entry or silence.
sound_advance:
        cmp     word ptr cs:sound_count,0
        je      short sound_advance_silence
        mov     si,word ptr cs:sound_head
        add     si,2
        cmp     si,SOUND_QUEUE_COUNT * 2
        jb      short sound_head_ready
        xor     si,si
sound_head_ready:
        mov     word ptr cs:sound_head,si
        dec     word ptr cs:sound_count
        jz      short sound_advance_empty
        mov     bx,word ptr cs:sound_frequency[si]
        mov     ax,word ptr cs:sound_duration[si]
        mov     word ptr cs:sound_remaining,ax
        call    sound_program
        ret
sound_advance_empty:
        mov     word ptr cs:sound_head,0
        mov     word ptr cs:sound_tail,0
sound_advance_silence:
        mov     word ptr cs:sound_remaining,0
        xor     bx,bx
        call    sound_program
        ret

sound_clear:
        mov     word ptr cs:sound_head,0
        mov     word ptr cs:sound_tail,0
        mov     word ptr cs:sound_count,0
        mov     word ptr cs:sound_remaining,0
        xor     bx,bx
        call    sound_program
        ret

; Program PIT channel 2 for BX Hertz, or disconnect the PC speaker for zero.
sound_program:
        push    ax
        push    dx
        or      bx,bx
        jz      short sound_program_silence
        mov     al,0B6h
        out     43h,al
        mov     dx,0012h
        mov     ax,34DCh             ; 1,193,180 Hz PIT input clock
        div     bx
        mov     dx,ax
        out     42h,al
        mov     al,dh
        out     42h,al
        in      al,61h
        or      al,03h
        out     61h,al
        jmp     short sound_program_done
sound_program_silence:
        in      al,61h
        and     al,0FCh
        out     61h,al
sound_program_done:
        pop     dx
        pop     ax
        ret

; Find the first live mailbox whose bounded name exactly matches ES:DI,CX.
; A successful lookup returns BX=1 and the mailbox handle in DS:SI; failure
; returns BX=0 and preserves the caller's DS:SI.
int15_findmail:
        push    ax
        push    cx
        push    dx
        push    di
        push    es
        push    bp
        push    ds
        push    si
        xor     bx,bx
        jcxz    short findmail_not_found
        cmp     cx,MAILBOX_NAME_SIZE
        ja      short findmail_not_found
        mov     dx,di
        xor     bp,bp
findmail_scan:
        cmp     word ptr cs:mailbox_used[bp],1
        jne     short findmail_next
        cmp     word ptr cs:mailbox_name_length[bp],cx
        jne     short findmail_next
        push    cx
        mov     si,bp
        mov     cl,4
        shl     si,cl
        add     si,offset mailbox_names
        mov     di,dx
        push    cs
        pop     ds
        cld
        repe    cmpsb
        pop     cx
        je      short findmail_found
findmail_next:
        add     bp,2
        cmp     bp,MAILBOX_SLOT_COUNT * 2
        jb      short findmail_scan
findmail_not_found:
        pop     si
        pop     ds
        jmp     short findmail_done
findmail_found:
        add     sp,4                  ; discard saved SI and DS
        mov     ax,word ptr cs:mailbox_handle_segments[bp]
        mov     ds,ax
        xor     si,si
        mov     bx,1
findmail_done:
        pop     bp
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     ax
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
        push    ax                    ; any task's
        call    task_validate
        pop     ax
        jnc     short int15_isobj_valid
        call    timer_validate
        jnc     short int15_isobj_valid
        call    mailbox_validate
        jnc     short int15_isobj_valid
        call    keyboard_validate
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
        push    ax                    ; any task's
        call    task_validate
        pop     ax
        jc      short int15_object_type_timer
        mov     bl,08h                ; window/task object
        jmp     short int15_object_type_done
int15_object_type_timer:
        call    timer_validate
        jc      short int15_object_type_mailbox
        mov     bl,0Bh                ; timer object
        jmp     short int15_object_type_done
int15_object_type_mailbox:
        call    mailbox_validate
        jc      short int15_object_type_keyboard
        mov     bl,09h                ; mailbox object
        jmp     short int15_object_type_done
int15_object_type_keyboard:
        call    keyboard_validate
        jc      short int15_object_type_invalid
        mov     bl,0Ah                ; keyboard object
        jmp     short int15_object_type_done
int15_object_type_invalid:
        xor     bx,bx
int15_object_type_done:
        pop     si
        pop     ax
        jmp     int15_handled

; READ is overloaded for timers, keyboards, windows and mailboxes. Intercept
; only an explicit live mailbox handle; every other class remains available
; to the previous INT 15h provider.
int15_message_read_gateway:
        cmp     bl,7                  ; the task's OBJECTQ
        jne     short message_read_gateway_not7
        jmp     int15_message_objectq_read
message_read_gateway_not7:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,6                  ; a task's:  only the own one
        jne     short message_read_gateway_not6
        cmp     word ptr ss:[bp+10],0
        jne     short message_read_gateway_chain
        mov     ax,word ptr ss:[bp+12]
        cmp     ax,word ptr cs:task_handle_segment
        jne     short message_read_gateway_chain
        jmp     short message_read_gateway_objectq
message_read_gateway_not6:
        cmp     bl,0
        jne     short message_read_gateway_chain
        cmp     word ptr ss:[bp+10],0
        jne     short message_read_gateway_chain
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short message_read_gateway_keyboard
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_mailbox_read
message_read_gateway_keyboard:
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short message_read_gateway_not_timer
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_timer_read
message_read_gateway_not_timer:
        mov     ax,word ptr ss:[bp+12]
        call    pointer_validate
        jc      short message_read_gateway_not_pointer
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_pointer_read
message_read_gateway_not_pointer:
        call    objectq_validate
        jnc     short message_read_gateway_objectq_own
        call    kobj_validate
        jc      short message_read_gateway_not_kobj
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_kobj_read
message_read_gateway_not_kobj:
        mov     ax,word ptr ss:[bp+12]
        call    keyboard_validate
        jc      short message_read_gateway_chain
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_keyboard_read
message_read_gateway_objectq_own:
        push    ax                    ; only the own one
        call    caller_tag
        xor     ah,ah
        pop     si
        cmp     ax,si
        jne     short message_read_gateway_chain
message_read_gateway_objectq:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_objectq_read
message_read_gateway_chain:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_chain

; ADDR shares BH=03h with the later CONNECT window message. Claim only an
; explicit live mailbox handle and leave every window use in the old chain.
int15_message_addr_gateway:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0
        jne     short message_addr_gateway_chain
        cmp     word ptr ss:[bp+10],0
        jne     short message_addr_gateway_chain
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short message_addr_gateway_chain
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_mailbox_addr
message_addr_gateway_chain:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_chain

; SUBFROM is also overloaded for windows, object queues and object flags.
; Claim only an explicit live mailbox and chain every other use unchanged.
int15_message_ref_gateway:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0
        jne     short message_ref_gateway_chain
        cmp     word ptr ss:[bp+10],0
        jne     short message_ref_gateway_chain
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short message_ref_gateway_bits
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_mailbox_ref
message_ref_gateway_bits:
        cmp     bh,0Bh                ; SUBFROM of a keyboard or pointer
        jne     short message_ref_gateway_chain
        jmp     mailbox_ref_keyboard
message_ref_gateway_chain:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_chain

; BH=11h is mailbox SETNAME for a mailbox handle and window AT for a window
; handle or the current task's default window. Resolve the overloaded
; selector before consuming either call's different stack layout.
int15_message_at_gateway:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,1
        je      short message_at_gateway_window
        cmp     bl,0
        jne     short message_at_gateway_chain
        cmp     word ptr ss:[bp+10],0
        jne     short message_at_gateway_chain
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jnc     short message_at_gateway_mailbox
        call    own_window
        je      short message_at_gateway_window
        call    wobj_validate         ; a window object:  its cursor to
        jc      short message_at_gateway_chain ; the row and column
        mov     al,byte ptr ss:[bp+14]
        mov     ah,byte ptr ss:[bp+18]
        mov     word ptr cs:wobj_cursor[si],ax
        pop     si
        pop     ax
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled
message_at_gateway_window:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_window_at
message_at_gateway_mailbox:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_mailbox_setname
message_at_gateway_chain:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_chain

; Return a pointer to and consume the oldest ready mailbox record. The public
; READ ABI expands one input handle DWORD into a length DWORD followed by a
; pointer DWORD. Empty reads are nonblocking in API 0.x and return null/zero
; with Carry set until scheduler-backed waits exist.
int15_message_mailbox_read:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        mov     word ptr cs:message_result_len_lo,0
        mov     word ptr cs:message_result_len_hi,0
        mov     word ptr cs:message_result_ptr_off,0
        mov     word ptr cs:message_result_ptr_seg,0
        or      word ptr ss:[bp+8],1
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jnc     short mailbox_read_valid
        jmp     mailbox_read_done
mailbox_read_valid:
        cmp     word ptr cs:mailbox_open[si],1
        je      short mailbox_read_open
        jmp     mailbox_read_done
mailbox_read_open:
        cmp     word ptr cs:mailbox_count[si],0
        jne     short mailbox_read_available
        call    mailbox_wait
        jnc     mailbox_read_open
        jmp     mailbox_read_done
mailbox_read_available:
        mov     dx,si
        mov     bx,si
        shl     bx,1
        add     bx,word ptr cs:mailbox_head[si]
        mov     di,bx
        shl     di,1
        mov     ax,word ptr cs:mailbox_message_length[di]
        mov     word ptr cs:message_result_len_lo,ax
        cmp     byte ptr cs:mailbox_message_reference[bx],0
        je      short mailbox_read_resident_pointer
        mov     di,bx
        shl     di,1
        mov     ax,word ptr cs:mailbox_message_pointer_off[di]
        mov     word ptr cs:message_result_ptr_off,ax
        mov     ax,word ptr cs:mailbox_message_pointer_seg[di]
        mov     word ptr cs:message_result_ptr_seg,ax
        jmp     short mailbox_read_pointer_ready
mailbox_read_resident_pointer:
        mov     di,bx
        mov     cl,7
        shl     di,cl
        add     di,offset mailbox_message_data
        mov     word ptr cs:message_result_ptr_off,di
        mov     ax,cs
        mov     word ptr cs:message_result_ptr_seg,ax
mailbox_read_pointer_ready:
        mov     si,dx
        mov     di,bx
        shl     di,1
        mov     ax,word ptr cs:mailbox_message_sender[di]
        mov     word ptr cs:mailbox_sender[si],ax
        mov     ax,word ptr cs:mailbox_message_length[di]
        sub     word ptr cs:mailbox_bytes[si],ax
        xor     ax,ax
        mov     al,byte ptr cs:mailbox_message_status[bx]
        mov     word ptr cs:mailbox_status[si],ax
        dec     word ptr cs:mailbox_count[si]
        cmp     word ptr cs:mailbox_noted[si],0
        je      short $+7
        dec     word ptr cs:mailbox_noted[si]
        inc     word ptr cs:mailbox_head[si]
        cmp     word ptr cs:mailbox_head[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_read_head_ready
        mov     word ptr cs:mailbox_head[si],0
mailbox_read_head_ready:
        and     word ptr ss:[bp+8],0FFFEh
mailbox_read_done:
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     message_expand4

; Replace an explicit mailbox handle with the task handle of the sender of
; the most recently consumed message. Before the first successful read the
; result is the null handle.
int15_message_mailbox_addr:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        mov     ax,word ptr ss:[bp+12]
        mov     word ptr ss:[bp+10],0
        mov     word ptr ss:[bp+12],0
        call    mailbox_validate
        jc      short mailbox_addr_done
        mov     ax,word ptr cs:mailbox_sender[si]
        mov     word ptr ss:[bp+12],ax
mailbox_addr_done:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_handled

; HANDLE uses the TopView message ABI:  a selector that takes a handle on the
; stack (00h, 02h, 04h, 06h, 0Ch) replaces that DWORD with the result; one
; without (01h, 03h, 05h, 07h, 0Dh) pushes it, as DESQview 2.80 does.
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
        cmp     bl,3                  ; current task's mailbox
        je      message_handle_mailbox
        cmp     bl,2                  ; that of the task on the stack
        je      short message_handle_task_mailbox
        cmp     bl,5                  ; current task's keyboard
        je      message_handle_keyboard
        cmp     bl,4                  ; that of the task on the stack
        je      message_handle_task_keyboard
        cmp     bl,7                  ; current task's OBJECTQ
        je      short message_handle_objectq
        cmp     bl,6                  ; that of the task on the stack
        je      short message_handle_task_objectq
        cmp     bl,5                  ; parent:  not there
        je      message_handle_none
        cmp     bl,7
        je      message_handle_none
        cmp     bl,0Dh
        je      message_handle_none
        jmp     message_handle_null
message_handle_stacked:
        cmp     word ptr ss:[bp+10],0
        jne     message_handle_null
        mov     ax,word ptr ss:[bp+12]
        push    ax                    ; any task's
        call    task_validate
        pop     ax
        jnc     message_handle_done
        call    timer_validate
        jnc     message_handle_done
        call    mailbox_validate
        jc      message_handle_null
        jmp     message_handle_done
message_handle_current:
        mov     ax,word ptr cs:task_handle_segment
        jmp     short message_handle_push
message_handle_task_mailbox:
        cmp     word ptr ss:[bp+10],0
        jne     short message_handle_null
        mov     ax,word ptr ss:[bp+12]
        call    task_validate
        jc      short message_handle_null
        call    task_mailbox_of
        jc      short message_handle_null
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        mov     word ptr ss:[bp+12],ax
        jmp     short message_handle_done
message_handle_objectq:
        mov     ax,word ptr cs:task_handle_segment
        call    task_validate
        jc      short message_handle_none
        call    keyboard_of
        inc     ax
        jmp     short message_handle_push
message_handle_task_objectq:
        cmp     word ptr ss:[bp+10],0
        jne     short message_handle_null
        mov     ax,word ptr ss:[bp+12]
        call    task_validate
        jc      short message_handle_null
        call    keyboard_of
        inc     ax
        mov     word ptr ss:[bp+12],ax
        jmp     short message_handle_done
message_handle_keyboard:
        mov     ax,word ptr cs:task_handle_segment
        call    task_validate
        jc      short message_handle_none
        call    keyboard_of
        jmp     short message_handle_push
message_handle_task_keyboard:
        cmp     word ptr ss:[bp+10],0
        jne     short message_handle_null
        mov     ax,word ptr ss:[bp+12]
        call    task_validate
        jc      short message_handle_null
        call    keyboard_of
        mov     word ptr ss:[bp+12],ax
        jmp     short message_handle_done
message_handle_mailbox:
        call    task_mailbox
        jc      short message_handle_none
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        jmp     short message_handle_push
message_handle_none:
        xor     ax,ax
message_handle_push:
        mov     word ptr cs:message_result_ptr_off,0
        mov     word ptr cs:message_result_ptr_seg,ax
        pop     si
        pop     ax
        jmp     message_push4
message_handle_null:
        mov     word ptr ss:[bp+10],0
        mov     word ptr ss:[bp+12],0
message_handle_done:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_handled

; NEW allocates a resident timer or mailbox object and pushes its handle on
; the caller's stack (as DESQview 2.80 does:  nothing is passed on the stack
; for these classes); unsupported classes and pool exhaustion push a null
; pointer.
int15_message_new:
        push    bp
        mov     bp,sp
        push    ax
        push    cx
        push    si
        mov     word ptr cs:message_result_ptr_off,0
        mov     word ptr cs:message_result_ptr_seg,0
        cmp     bl,0Bh                ; TIMER object class
        je      message_new_timer
        cmp     bl,09h                ; MAILBOX object class
        je      message_new_mailbox
        cmp     bl,0Fh                ; POINTER object class
        je      short message_new_pointer
        cmp     bl,0Ah                ; KEYBOARD object class
        je      short message_new_keyboard
        cmp     bl,08h                ; WINDOW class
        jne     short message_new_other
        jmp     message_new_window
message_new_other:
        jmp     message_new_done
message_new_keyboard:
        xor     si,si
        mov     cx,KOBJ_COUNT
message_new_kobj_scan:
        cmp     word ptr cs:kobj_used[si],0
        je      short message_new_kobj_found
        add     si,2
        loop    message_new_kobj_scan
        jmp     message_new_done
message_new_kobj_found:
        mov     word ptr cs:kobj_used[si],1
        call    caller_tag
        xor     ah,ah
        mov     word ptr cs:kobj_owner[si],ax
        mov     word ptr cs:kobj_flags[si],0
        mov     word ptr cs:kobj_window[si],0
        mov     ax,word ptr cs:kobj_handle_segments[si]
        mov     word ptr cs:message_result_ptr_seg,ax
        jmp     message_new_done
message_new_pointer:
        xor     si,si
        mov     cx,POINTER_SLOT_COUNT
message_new_pointer_scan:
        cmp     word ptr cs:pointer_used[si],0
        je      short message_new_pointer_found
        add     si,2
        loop    message_new_pointer_scan
        jmp     message_new_done
message_new_pointer_found:
        mov     word ptr cs:pointer_used[si],1
        call    caller_tag
        xor     ah,ah
        mov     word ptr cs:pointer_owner[si],ax
        xor     ax,ax
        mov     word ptr cs:pointer_open[si],ax
        mov     word ptr cs:pointer_flags[si],ax
        mov     word ptr cs:pointer_count[si],ax
        mov     word ptr cs:pointer_noted[si],ax
        mov     word ptr cs:pointer_last[si],0FFFFh
        mov     ax,word ptr cs:pointer_handle_segments[si]
        mov     word ptr cs:message_result_ptr_seg,ax
        jmp     message_new_done
message_new_timer:
        xor     si,si
        mov     cx,TIMER_SLOT_COUNT
message_new_scan:
        cmp     word ptr cs:timer_used[si],0
        je      short message_new_found
        add     si,2
        loop    message_new_scan
        jmp     message_new_done
message_new_found:
        mov     word ptr cs:timer_used[si],1
        mov     word ptr cs:timer_open[si],0
        mov     word ptr cs:timer_state[si],0
        mov     word ptr cs:timer_noted[si],0
        push    ax
        call    caller_tag
        xor     ah,ah
        mov     word ptr cs:timer_owner[si],ax
        pop     ax
        mov     ax,word ptr cs:timer_handle_segments[si]
        mov     word ptr cs:message_result_ptr_seg,ax
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
        call    caller_tag
        xor     ah,ah
        mov     word ptr cs:mailbox_owner[si],ax
        mov     word ptr cs:mailbox_open[si],0
        mov     word ptr cs:mailbox_status[si],0
        mov     word ptr cs:mailbox_sender[si],0
        mov     word ptr cs:mailbox_flags[si],0
        mov     word ptr cs:mailbox_lock_count[si],0
        mov     word ptr cs:mailbox_lock_waiter[si],0
        mov     word ptr cs:mailbox_name_length[si],0
        call    mailbox_clear_queue
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        mov     word ptr cs:message_result_ptr_seg,ax
message_new_done:
        pop     si
        pop     cx
        pop     ax
        jmp     message_push4

; NEW 08h, its 8 DWORDs (top first):  the entry address, task, stack,
; buffer, columns, rows, the title's length and address.  Without an
; entry (its segment 0):  a window object (wobj_create) of that size and
; title, at the top left, not drawn; its handle in place of the 8 DWORDs.
; A task window:  0.
message_new_window:
        push    di
        push    ds
        xor     di,di
        cmp     word ptr ss:[bp+12],0
        je      short message_new_window_only
        call    subtask_new           ; an entry point:  a subtask
        jmp     short message_new_window_done
message_new_window_only:
        mov     ch,byte ptr ss:[bp+30]
        mov     cl,byte ptr ss:[bp+26]
        call    wobj_create
        jc      short message_new_window_done
        mov     ax,si
        add     ax,2
        xchg    ax,word ptr cs:wtarget
        push    ax
        mov     cx,word ptr ss:[bp+34]
        lds     si,dword ptr ss:[bp+38]
        call    wobj_set_title
        pop     ax
        xchg    ax,word ptr cs:wtarget
        sub     ax,2
        mov     si,ax
        mov     di,word ptr cs:wobj_handle_segments[si]
message_new_window_done:
        mov     word ptr ss:[bp+38],0
        mov     word ptr ss:[bp+40],di
        pop     ds
        pop     di
        pop     si
        pop     cx
        pop     ax
        push    ax                    ; the frame over 28 bytes
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+36],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+34],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp+32],ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp+30],ax
        pop     ax
        pop     bp
        add     sp,28
        jmp     int15_handled

; FREE message class 00h consumes and pops a timer pointer from the caller's
; stack. Invalid, stale and non-timer handles are harmless no-ops, but the
; documented stack pop still occurs.
int15_message_free:
        cmp     bl,1                  ; the own window/task (nothing on
        jne     short message_free_explicit ; the stack):  a subtask ends
        push    ax
        call    caller_tag
        dec     ax
        call    subtask_free          ; (itself:  no return)
        pop     ax
        jmp     int15_handled
message_free_explicit:
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
        call    wobj_validate
        jc      short message_free_not_window
        call    wobj_free
        jmp     short message_free_done
message_free_not_window:
        call    kobj_validate
        jc      short message_free_not_kobj
        mov     word ptr cs:kobj_used[si],0
        jmp     short message_free_done
message_free_not_kobj:
        call    pointer_validate
        jc      short message_free_not_pointer
        mov     word ptr cs:pointer_used[si],0
        jmp     short message_free_done
message_free_not_pointer:
        call    mailbox_validate
        jc      short message_free_not_mailbox
        call    mailbox_release
        jmp     short message_free_done
message_free_not_mailbox:
        call    task_validate         ; a subtask
        jc      short message_free_done
        dec     ax
        call    subtask_free
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
        je      short timer_query_handle_ok
        jmp     timer_query_invalid
timer_query_handle_ok:
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
        jc      short timer_query_mailbox
        call    timer_elapsed
        cmp     bh,08h
        jne     short timer_query_not_sizeof
        jmp     timer_query_store
timer_query_not_sizeof:
        cmp     bh,09h
        je      short timer_query_length
        cmp     bh,0Fh
        jne     timer_query_invalid
        xor     ax,ax                 ; STATUS
        xor     dx,dx
        cmp     word ptr cs:timer_open[si],0
        jne     short timer_query_status_open
        mov     dx,8000h              ; closed
        jmp     timer_query_store
timer_query_status_open:
        cmp     word ptr cs:timer_state[si],1
        jne     short timer_query_store
        mov     dx,4000h              ; open and running
        jmp     short timer_query_store
timer_query_mailbox:
        call    mailbox_validate
        jc      short timer_query_keyboard
        cmp     bh,08h
        je      short mailbox_query_count
        cmp     bh,09h
        je      short mailbox_query_bytes
        cmp     bh,0Fh
        je      short mailbox_query_status
        cmp     bh,16h
        jne     short timer_query_invalid
        mov     ax,word ptr cs:mailbox_flags[si]
        xor     dx,dx
        jmp     short timer_query_store
mailbox_query_status:
        mov     ax,word ptr cs:mailbox_status[si]
        xor     dx,dx
        jmp     short timer_query_store
mailbox_query_count:
        mov     ax,word ptr cs:mailbox_count[si]
        xor     dx,dx
        jmp     short timer_query_store
mailbox_query_bytes:
        mov     ax,word ptr cs:mailbox_bytes[si]
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
timer_query_keyboard:
        push    si
        call    kobj_validate
        pop     si
        jnc     short timer_query_kobj
        call    keyboard_validate
        jc      short timer_query_invalid
timer_query_kobj:
        cmp     bh,0Fh
        jne     short timer_query_invalid
        mov     al,byte ptr cs:keyboard_scan ; STATUS:  the last key's scan
        xor     ah,ah                 ; code (keystroke mode)
        xor     dx,dx
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
        cmp     bl,7                  ; the task's OBJECTQ:  no handle, it
        jne     short timer_open_close_object ; is always there
        jmp     int15_handled
timer_open_close_object:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     timer_open_close_done
        mov     ax,word ptr ss:[bp+12]
        call    kobj_validate
        jc      short timer_open_close_not_kobj
        mov     word ptr cs:kobj_window[si],0
        cmp     bh,0Ch                ; CLOSE:  the handle
        jne     timer_open_close_done
        push    si                    ; OPEN:  and the window (an object's
        mov     ax,word ptr ss:[bp+16] ; index + 2, else 0:  the task's)
        call    wobj_validate
        mov     ax,0
        jc      short timer_open_kobj_window
        lea     ax,[si+2]
timer_open_kobj_window:
        pop     si
        mov     word ptr cs:kobj_window[si],ax
        pop     si
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled
timer_open_close_not_kobj:
        mov     ax,word ptr ss:[bp+12]
        call    pointer_validate
        jc      short timer_open_close_timer
        mov     word ptr cs:pointer_count[si],0
        mov     word ptr cs:pointer_noted[si],0
        mov     word ptr cs:pointer_open[si],0
        cmp     bh,0Ch                ; CLOSE:  the handle
        jne     timer_open_close_done
        mov     word ptr cs:pointer_open[si],1 ; OPEN:  the window under
        push    si
        mov     ax,word ptr ss:[bp+16]
        call    wobj_validate
        mov     ax,0
        jc      short timer_open_pointer_window
        lea     ax,[si+2]
timer_open_pointer_window:
        pop     si
        mov     word ptr cs:pointer_window[si],ax
        pop     si                    ; it too (any:  the screen is the
        pop     ax                    ; window)
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled
timer_open_close_timer:
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
        cmp     bh,0Dh                ; CLOSE of a locked mailbox:  one
        jne     short timer_open_close_unlocked ; LOCK less
        cmp     word ptr cs:mailbox_lock_count[si],0
        je      short timer_open_close_unlocked
        dec     word ptr cs:mailbox_lock_count[si]
        jnz     short timer_open_close_done
        push    ax                    ; the last:  to a waiting task, so
        mov     ax,word ptr cs:mailbox_lock_waiter[si] ; one that locks
        or      ax,ax                 ; again at once does not starve it
        jz      short timer_unlock_free ; (as DESQview)
        mov     word ptr cs:mailbox_lock_owner[si],ax
        mov     word ptr cs:mailbox_lock_count[si],1
        mov     word ptr cs:mailbox_lock_waiter[si],0
        or      ah,80h                ; (given:  its LOCK takes it as is)
        mov     word ptr cs:mailbox_lock_waiter[si],ax
timer_unlock_free:
        pop     ax
        jmp     short timer_open_close_done
timer_open_close_unlocked:
        mov     word ptr cs:mailbox_status[si],0
        cmp     bh,0Ch
        jne     short mailbox_close
        mov     word ptr cs:mailbox_open[si],1
        jmp     short timer_open_close_done
mailbox_close:
        mov     word ptr cs:mailbox_open[si],0
        test    word ptr cs:mailbox_flags[si],0004h
        jnz     short timer_open_close_done
        call    mailbox_clear_queue
timer_open_close_done:
        pop     si
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled

int15_message_timer_add:
        cmp     bh,05h                ; WRITE to a window
        jne     short timer_add_not_window
        cmp     bl,01h
        jne     short timer_add_window_handle
        jmp     int15_message_window_write
timer_add_window_handle:
        cmp     bl,0
        jne     short timer_add_not_window
        push    bp
        mov     bp,sp
        cmp     word ptr ss:[bp+10],0
        jne     short timer_add_not_own
        push    ax
        mov     ax,word ptr ss:[bp+12]
        call    own_window
        je      short timer_add_own
        push    si
        call    wobj_validate         ; or a window object
        pop     si
        jc      short timer_add_not_own_ax
timer_add_own:
        pop     ax
        pop     bp
        jmp     int15_message_window_write
timer_add_not_own_ax:
        pop     ax
timer_add_not_own:
        push    ax
        push    si
        mov     ax,word ptr ss:[bp+12]
        call    pointer_validate      ; a pointer:  its position
        pop     si
        pop     ax
        jc      short timer_add_not_pointer_w
        pop     bp
        jmp     int15_message_pointer_write
timer_add_not_pointer_w:
        pop     bp
timer_add_not_window:
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
        jc      timer_add_mailbox
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
        mov     word ptr cs:timer_noted[si],0
timer_add_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; READ of a timer (DESQview 2.80, measured):  waits (PAUSE) until it has
; expired, its handle replaced by the time it expired at (hundredths since
; midnight); its expiry is then no longer for the OBJECTQ.
int15_message_timer_read:
        push    bp
        mov     bp,sp
        push    ax
        push    dx
        push    si
        mov     ax,word ptr ss:[bp+12]
        call    timer_validate
timer_read_wait:
        call    timer_elapsed         ; (read once:  until started again)
        cmp     word ptr cs:timer_state[si],2
        jne     short timer_read_pause
        cmp     word ptr cs:timer_noted[si],2
        jne     short timer_read_expired
timer_read_pause:
        sti
        call    api_pause
        cli
        jmp     short timer_read_wait
timer_read_expired:
        mov     word ptr cs:timer_noted[si],2
        mov     ax,word ptr cs:timer_start_lo[si]
        mov     dx,word ptr cs:timer_start_hi[si]
        add     ax,word ptr cs:timer_duration_lo[si]
        adc     dx,word ptr cs:timer_duration_hi[si]
        cmp     dx,0083h              ; past midnight
        jb      short timer_read_store
        ja      short timer_read_wrap
        cmp     ax,0D600h
        jb      short timer_read_store
timer_read_wrap:
        sub     ax,0D600h
        sbb     dx,0083h
timer_read_store:
        mov     word ptr ss:[bp+10],ax
        mov     word ptr ss:[bp+12],dx
        pop     si
        pop     dx
        pop     ax
        pop     bp
        jmp     int15_handled

; ADDTO on a mailbox copies one bounded message into resident storage.  The
; public stack contains status, length, address and finally the mailbox
; handle.  A closed/full mailbox or an invalid/oversize message sets Carry;
; the documented sixteen argument bytes are consumed in either case.
timer_add_mailbox:
        cmp     bh,05h
        je      short timer_write_mailbox
        cmp     bh,0Ah
        jne     timer_add_done
        call    mailbox_validate
        jnc     short timer_add_mailbox_ok
        call    pointer_validate      ; a pointer:  its bits
        jc      short timer_add_not_pointer
        mov     ax,word ptr ss:[bp+14]
        or      word ptr cs:pointer_flags[si],ax
        jmp     timer_add_done
timer_add_not_pointer:
        call    kobj_validate
        jc      short timer_add_not_kobj
        mov     ax,word ptr ss:[bp+14]
        or      word ptr cs:kobj_flags[si],ax
        jmp     timer_add_done
timer_add_not_kobj:
        mov     ax,word ptr ss:[bp+12]
        call    keyboard_validate     ; a keyboard:  its bits (field mode,
        jc      timer_add_done  ; cursor, ..)
        mov     ax,word ptr ss:[bp+14]
        or      word ptr cs:keyboard_flags,ax
        jmp     timer_add_done
timer_add_mailbox_ok:
        call    message_swap22
        call    mailbox_add_value
        pop     si
        pop     dx
        pop     cx
        pop     ax
        call    message_shift16
        pop     bp
        add     sp,16
        jmp     int15_handled
timer_write_mailbox:
        call    mailbox_validate
        jc      short timer_write_mailbox_done
        call    message_swap18
        call    mailbox_write_value
timer_write_mailbox_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled

; WRITE to the task's window (BL=01h, or 00h with its handle on top):  the
; length DWORD on the address (top first, as DESQview 2.80), the bytes go
; out as BIOS teletype output (CR, LF, BS and BEL act, the rest is shown),
; as DESQview's window output; both DWORDs (and the handle) are popped.
int15_message_window_write:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    cx
        push    si
        push    ds
        mov     word ptr cs:wobj_made,0
        mov     si,10                 ; BL=01h:  length at BP+10
        or      bl,bl
        jnz     short window_write_args
        mov     ax,word ptr ss:[bp+12] ; BL=00h:  a window object's handle?
        call    wobj_validate
        jc      short window_write_task
        call    wobj_enter
window_write_task:
        mov     si,14                 ; BL=00h:  below the handle
window_write_args:
        add     si,bp
        cmp     word ptr ss:[si+2],0
        jne     short window_write_done
        mov     cx,word ptr ss:[si]
        lds     si,dword ptr ss:[si+4]
        jcxz    short window_write_done
        mov     ah,0Fh                ; the active page
        int     10h
        sti
        cld
        call    window_output
        cli
window_write_done:
        call    wobj_leave
        pop     ds
        pop     si
        pop     cx
        pop     bx
        pop     ax
        cmp     word ptr cs:wobj_made,0 ; E6h:  the new window's handle is
        je      short window_write_plain ; the result (in the address's place)
        push    si
        mov     si,word ptr cs:wobj_made
        mov     si,word ptr cs:wobj_handle_segments[si-2]
        or      bl,bl
        jnz     short window_write_made1
        mov     word ptr ss:[bp+18],0
        mov     word ptr ss:[bp+20],si
        pop     si
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled
window_write_made1:
        mov     word ptr ss:[bp+14],0
        mov     word ptr ss:[bp+16],si
        pop     si
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled
window_write_plain:
        or      bl,bl
        jnz     short window_write_pop8
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled
window_write_pop8:
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; DS:SI, CX bytes to the task's window (BH = the page):  text as BIOS
; teletype output, in the window colour once a stream set one; ESC and a
; byte below 20h start a stream (type, length word, opcodes):  type 00h
; (window) is interpreted (window_stream), the others are skipped.
window_output:
        push    ax
        push    dx
        push    di
window_output_next:
        jcxz    window_output_ret
        lodsb
        dec     cx
        cmp     al,1Bh
        jne     short window_output_text
        jcxz    window_output_text
        cmp     byte ptr [si],20h
        jae     short window_output_text
        cmp     cx,3
        jb      short window_output_ret
        mov     dl,byte ptr [si]      ; type
        mov     di,word ptr [si+1]    ; length
        add     si,3
        sub     cx,3
        cmp     di,cx
        jbe     short window_output_length
        mov     di,cx
window_output_length:
        sub     cx,di
        add     di,si                 ; its end
        or      dl,dl
        jnz     short window_output_not_window
        mov     byte ptr cs:field_style,7 ; (E5h:  for this stream)
        call    window_stream
        jmp     short window_output_skip
window_output_not_window:
        cmp     dl,10h
        jne     short window_output_not_manager
        call    window_manager
        jmp     short window_output_skip
window_output_not_manager:
        cmp     dl,01h
        jne     short window_output_skip
        call    window_query
window_output_skip:
        mov     si,di
        jmp     short window_output_next
window_output_text:
        call    window_text_char
        jmp     short window_output_next
window_output_ret:
        pop     di
        pop     dx
        pop     ax
        ret

; AL as text:  teletype, or in the window colour (BEL, BS, LF and CR act;
; LF begins the next line at its start, as DESQview's windows).
window_text_char:
        cmp     al,0Ah
        jne     short window_text_char_go
        mov     al,0Dh
        call    window_text_char_go
        mov     al,0Ah
window_text_char_go:
        cmp     word ptr cs:wtarget,0 ; (a window object:  its teletype)
        jne     short window_tty
        cmp     byte ptr cs:window_color,0
        je      short window_tty
        cmp     al,07h
        je      short window_tty
        cmp     al,08h
        je      short window_tty
        cmp     al,0Ah
        je      short window_tty
        cmp     al,0Dh
        je      short window_tty
        push    ax
        mov     ah,byte ptr cs:window_color
        call    window_put
        pop     ax
        ret
window_tty:
        cmp     word ptr cs:wtarget,0
        je      short window_tty_bios
        jmp     wobj_tty
window_tty_bios:
        push    ax
        push    bx
        mov     ah,0Eh
        mov     bl,07h
        int     10h
        pop     bx
        pop     ax
        ret

; Character AL in attribute AH at the cursor, the cursor on (BH = page).
window_put:
        cmp     word ptr cs:wtarget,0
        je      short window_put_bios
        jmp     wobj_put
window_put_bios:
        push    ax
        push    bx
        push    cx
        push    dx
        mov     bl,ah
        mov     ah,09h
        mov     cx,1
        int     10h
        mov     ah,03h                ; the cursor on (DESQview:  no
        int     10h                   ; scrolling at the window's end)
        push    ax
        push    bx
        mov     ah,0Fh
        int     10h
        mov     al,ah                 ; AL:  the columns
        pop     bx
        inc     dl
        cmp     dl,al
        jb      short window_put_move
        push    es
        mov     ax,40h
        mov     es,ax
        mov     al,byte ptr es:[84h]  ; the last row
        pop     es
        or      al,al
        jnz     short window_put_rows
        mov     al,24
window_put_rows:
        cmp     dh,al
        jae     short window_put_last
        xor     dl,dl
        inc     dh
        jmp     short window_put_move
window_put_last:
        dec     dl                    ; (the last cell:  it stays)
window_put_move:
        pop     ax
        mov     ah,02h
        int     10h
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; CX times character AL in attribute AH.
window_run:
        jcxz    window_run_ret
window_run_one:
        call    window_put
        loop    window_run_one
window_run_ret:
        ret

; AH = the window colour, or 07h before a stream set one.
window_attr:
        mov     ah,byte ptr cs:window_color
        cmp     word ptr cs:wtarget,0 ; a window object:  0 is a colour too
        jne     short window_attr_ret
        call    window_logical_test ; the task's, logical (DAh)
        jnz     short window_attr_logical
        or      ah,ah
        jnz     short window_attr_ret
        mov     ah,07h
window_attr_ret:
        ret
window_attr_logical:
        push    bx
        mov     bl,ah
        dec     bl
        and     bx,0Fh
        mov     ah,byte ptr cs:wobj_logical[bx]
        pop     bx
        ret

; AL = the next stream byte (SI up to DI), CF:  the stream ended.
window_byte:
        cmp     si,di
        jae     short window_byte_end
        lodsb
        clc
        ret
window_byte_end:
        stc
        ret

; DX = the cursor (BH = page); window_cursor_set sets it again.
window_cursor_get:
        cmp     word ptr cs:wtarget,0
        je      short window_cursor_get_bios
        push    si
        mov     si,word ptr cs:wtarget
        mov     dx,word ptr cs:wobj_cursor[si-2]
        pop     si
        ret
window_cursor_get_bios:
        push    ax
        push    cx
        mov     ah,03h
        int     10h
        pop     cx
        pop     ax
        ret
window_cursor_set:
        cmp     word ptr cs:wtarget,0
        je      short window_cursor_set_bios
        push    si
        mov     si,word ptr cs:wtarget
        mov     word ptr cs:wobj_cursor[si-2],dx
        pop     si
        jmp     wobj_show_cursor
window_cursor_set_bios:
        push    ax
        mov     ah,02h
        int     10h
        pop     ax
        ret

; A window stream (type 00h) at SI up to DI, as DESQview's (RBIL table
; 00440) for a window as large as the screen:  text and blanks (00h-9Fh),
; the logical cursor (A0h/A1h, B0h/B1h, C0h, C8h), the output colour
; (E2h), clear (E3h), redraw and no-op (E4h, E7h) and the name (EFh,
; skipped); window geometry (A2h-AFh, B2h-BFh, C1h-C7h, C9h-CFh) has no
; effect, as the window is the screen.  Another opcode ends the stream.
window_stream:
        push    ax
        push    cx
        push    dx
window_stream_next:
        call    window_byte
        jnc     short window_stream_op
        jmp     window_stream_ret
window_stream_op:
        mov     cl,al
        and     cx,001Fh              ; N in the opcode (0:  32)
        jnz     short window_stream_n
        mov     cl,32
window_stream_n:
        cmp     al,20h
        jb      window_stream_blanks
        cmp     al,40h
        jb      window_stream_repeat
        cmp     al,60h
        jb      window_stream_attr_blanks
        cmp     al,80h
        jb      window_stream_literal
        cmp     al,0A0h
        jae     short window_stream_not_counted
        jmp     window_stream_counted
window_stream_not_counted:
        cmp     al,0B0h
        jae     short window_stream_not_set
        jmp     window_stream_set
window_stream_not_set:
        cmp     al,0C0h
        jae     short window_stream_not_rel
        jmp     window_stream_rel
window_stream_not_rel:
        cmp     al,0D0h
        jae     short window_stream_not_pair
        jmp     window_stream_pair
window_stream_not_pair:
        cmp     al,0E0h               ; D0h-DFh:  flags
        jae     short window_stream_not_flag
        call    window_stream_flag
        jmp     window_stream_next
window_stream_not_flag:
        cmp     al,0E2h
        je      window_stream_color
        cmp     al,0E3h
        je      window_stream_clear
        cmp     al,0E4h
        jne     short window_stream_not_redraw
        call    window_stream_redraw
        jmp     window_stream_next
window_stream_not_redraw:
        cmp     al,0E5h               ; the menu style:  bits 5,4 01b two-key
        jne     short window_stream_not_style ; menus, entries of 8 bytes
        call    window_byte
        jc      short window_stream_style_done
        and     al,30h
        cmp     al,10h
        mov     al,7
        jne     short window_stream_style_set
        inc     al
window_stream_style_set:
        mov     byte ptr cs:field_style,al
window_stream_style_done:
        jmp     window_stream_next
window_stream_not_style:
        cmp     al,0E6h               ; a new window, the rest in it
        jne     short window_stream_not_new
        jmp     window_stream_new
window_stream_not_new:
        cmp     al,0E8h               ; E8h-EBh scrolling:  2 arguments
        jb      short window_stream_not_scroll
        cmp     al,0EBh
        ja      short window_stream_not_scroll
        call    window_byte
        call    window_byte
        jmp     window_stream_next
window_stream_not_scroll:
        cmp     al,0E7h
        je      window_stream_next
        cmp     al,0EFh
        je      window_stream_name
        cmp     al,0F0h
        jb      short window_stream_stop
        call    window_field_op       ; F0h-FFh:  the input fields
        jnc     window_stream_next
window_stream_stop:
        jmp     window_stream_ret
window_stream_blanks:
        mov     al,' '
        call    window_attr
        call    window_run
        jmp     window_stream_next
window_stream_repeat:
        call    window_byte
        jc      window_stream_end
        call    window_attr
        call    window_run
        jmp     window_stream_next
window_stream_attr_blanks:
        call    window_byte           ; (DESQview 2.80:  the attribute only,
        jc      short window_stream_end ; the characters stay)
        jcxz    window_stream_attr_none
        push    bx
        mov     bl,al
        mov     bh,byte ptr cs:window_page
window_stream_attr_cell:
        call    wcell_read
        mov     ah,bl
        call    window_put
        loop    window_stream_attr_cell
        pop     bx
window_stream_attr_none:
        jmp     window_stream_next
window_stream_literal:
        call    window_byte
        jc      short window_stream_end
        call    window_attr
        call    window_put
        loop    window_stream_literal
        jmp     window_stream_next
window_stream_color:
        call    window_byte
        jc      short window_stream_end
        mov     byte ptr cs:window_color,al ; (a window object's:  swapped
        jmp     window_stream_next    ; in, wobj_enter)
window_stream_clear:
        cmp     word ptr cs:wtarget,0
        je      short window_stream_clear_bios
        call    wobj_clear
        jmp     window_stream_next
window_stream_clear_bios:
        call    window_clear_bios
        jmp     window_stream_next
; The task's window (the screen) blank in its colour.
window_clear_bios:
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        call    window_attr
        mov     bh,ah
        mov     ax,40h
        mov     es,ax
        mov     dh,byte ptr es:[84h]  ; rows - 1 (EGA and later)
        or      dh,dh
        jnz     short window_clear_rows
        mov     dh,24
window_clear_rows:
        mov     dl,byte ptr es:[4Ah]
        dec     dl
        xor     cx,cx
        mov     ax,0600h
        int     10h
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
window_stream_end:
        jmp     window_stream_ret
; F0h-FFh (opcode AL) in a window stream (SI up to DI):  the fields of the
; table FFh set up (field_header:  the caller's stream, as DESQview keeps
; using it); CF:  the stream ends.
window_field_op:
        push    bx
        push    cx
        push    dx
        push    es
        push    ax
        mov     ah,0Fh
        int     10h
        mov     byte ptr cs:window_page,bh
        pop     ax
        cmp     al,0FFh
        jne     short field_op_not_ff
        mov     word ptr cs:field_header,si ; FFh:  the header and N entries
        mov     word ptr cs:field_header+2,ds ; of 7 bytes (E5h:  or 8)
        mov     al,byte ptr cs:field_style
        mov     byte ptr cs:field_esize,al
        mov     cl,byte ptr [si]
        xor     ch,ch
        xor     ah,ah
        mul     cx
        add     ax,6
        add     si,ax
        cmp     si,di
        jbe     short field_op_ff_paint
        mov     si,di
field_op_ff_paint:
        call    field_paint_selects
        jmp     field_op_ok
field_op_not_ff:
        cmp     al,0FDh               ; FDh, FEh:  modified / and selected
        jb      short field_op_not_reset ; bits off
        mov     ah,0FEh
        cmp     al,0FDh
        je      short field_op_reset
        mov     ah,0FCh
field_op_reset:
        call    field_count
        jc      field_op_ok
        mov     dl,1
field_op_reset_one:
        mov     al,dl
        call    field_entry
        and     byte ptr es:[bx+4],ah
        call    field_paint
        inc     dl
        loop    field_op_reset_one
        jmp     field_op_ok
field_op_not_reset:
        cmp     al,0FCh               ; FCh:  a new header
        jne     short field_op_not_fc
        mov     cx,6
        les     bx,dword ptr cs:field_header
        mov     ax,es
        or      ax,ax
        jz      short field_op_skip
field_op_fc:
        call    window_byte
        jc      field_op_end
        mov     byte ptr es:[bx],al
        inc     bx
        loop    field_op_fc
        jmp     field_op_ok
field_op_skip:
        add     si,cx
        cmp     si,di
        jbe     field_op_ok
        mov     si,di
        jmp     field_op_ok
field_op_not_fc:
        cmp     al,0F7h               ; F7h:  the broadcast fields (type bit
        jne     short field_op_numbered ; 5) in field order, their sizes of
        call    field_count           ; bytes each
        jc      field_op_end
        mov     dl,1
field_op_broadcast:
        mov     al,dl
        call    field_entry
        test    byte ptr es:[bx+4],20h
        jz      short field_op_broadcast_next
        call    field_contents
        jc      field_op_end
field_op_broadcast_next:
        inc     dl
        loop    field_op_broadcast
        jmp     field_op_ok
field_op_numbered:
        mov     dh,al                 ; the others:  a field number first
        call    window_byte
        jc      field_op_end
        mov     dl,al
        cmp     dh,0F4h
        je      short field_op_cursor
        cmp     dh,0F0h
        je      short field_op_clear
        cmp     dh,0F1h
        je      short field_op_fill
        cmp     dh,0F2h
        je      short field_op_color
        cmp     dh,0F3h
        je      field_op_contents
        cmp     dh,0F6h
        je      field_op_type
        cmp     dh,0F5h
        je      field_op_entry
        cmp     dh,0F8h               ; F8h-FBh:  scrolling by one row /
        jb      field_op_end          ; column, blanks come in
        mov     al,dl
        call    field_entry
        jc      field_op_ok
        mov     cx,0100h              ; F8h up:  each cell from below
        cmp     dh,0F8h
        je      short field_op_scroll
        mov     cx,0FF00h             ; F9h down
        cmp     dh,0F9h
        je      short field_op_scroll
        mov     cx,0001h              ; FAh left:  from the right
        cmp     dh,0FAh
        je      short field_op_scroll
        mov     cx,00FFh              ; FBh right
field_op_scroll:
        call    field_scroll
        jmp     field_op_ok
field_op_cursor:
        mov     al,dl
        call    field_entry
        jc      field_op_ok
        mov     dx,word ptr es:[bx]   ; DL row, DH column
        xchg    dl,dh
        call    field_cursor_set
        jmp     field_op_ok
field_op_clear:
        mov     ax,0720h              ; (AH:  keep the attribute)
        jmp     short field_op_fill_go
field_op_fill:
        call    window_byte
        jc      field_op_end
        mov     ah,07h
field_op_fill_go:
        push    ax
        mov     al,dl
        call    field_entry
        pop     ax
        jc      field_op_ok
        call    field_fill_char
        jmp     field_op_ok
field_op_color:
        call    window_byte
        jc      field_op_end
        push    ax
        mov     al,dl
        call    field_entry
        pop     ax
        jc      field_op_ok
        call    field_fill_attr
        jmp     field_op_ok
field_op_contents:
        mov     al,dl
        call    field_entry
        jc      field_op_end
        call    field_contents
        jc      field_op_end
        jmp     field_op_ok
field_op_type:
        call    window_byte
        jc      field_op_end
        push    ax
        mov     al,dl
        call    field_entry
        pop     ax
        jc      field_op_ok
        mov     byte ptr es:[bx+4],al
        call    field_paint           ; (selected / deselected:  its colour)
        jmp     short field_op_ok
field_op_entry:
        mov     al,dl
        call    field_entry
        mov     cl,byte ptr cs:field_esize
        xor     ch,ch
        jc      field_op_skip
field_op_entry_byte:
        call    window_byte
        jc      short field_op_end
        mov     byte ptr es:[bx],al
        inc     bx
        loop    field_op_entry_byte
field_op_ok:
        clc
        jmp     short field_op_ret
field_op_end:
        stc
field_op_ret:
        pop     es
        pop     dx
        pop     cx
        pop     bx
        ret

; window_cursor_get/set on window_page (BX kept).
field_cursor_get:
        push    bx
        mov     bh,byte ptr cs:window_page
        call    window_cursor_get
        pop     bx
        ret
field_cursor_set:
        push    bx
        mov     bh,byte ptr cs:window_page
        call    window_cursor_set
        pop     bx
        ret

; CX = the number of fields (CF:  no table).
field_count:
        push    bx
        push    es
        les     bx,dword ptr cs:field_header
        mov     cx,es
        stc
        jcxz    field_count_ret
        mov     cl,byte ptr es:[bx]
        xor     ch,ch
        clc
        jcxz    field_count_none
        jmp     short field_count_ret
field_count_none:
        stc
field_count_ret:
        pop     es
        pop     bx
        ret

; ES:BX = the entry of field AL (1 .. N), CF:  none.
field_entry:
        push    ax
        push    cx
        call    field_count
        jc      short field_entry_ret
        or      al,al
        jz      short field_entry_no
        cmp     al,cl
        ja      short field_entry_no
        les     bx,dword ptr cs:field_header
        dec     al
        mov     cl,byte ptr cs:field_esize
        mul     cl
        add     bx,ax
        add     bx,6
        clc
        jmp     short field_entry_ret
field_entry_no:
        stc
field_entry_ret:
        pop     cx
        pop     ax
        ret

; the cells of field ES:BX:  DX (DH row, DL column) of the first, CX their
; number; field_next_cell steps DX (CF:  past the end).
field_first_cell:
        mov     dh,byte ptr es:[bx]
        mov     dl,byte ptr es:[bx+1]
        push    ax
        mov     al,byte ptr es:[bx+2]
        sub     al,byte ptr es:[bx]
        inc     al
        mov     cl,byte ptr es:[bx+3]
        sub     cl,byte ptr es:[bx+1]
        inc     cl
        mul     cl
        mov     cx,ax
        pop     ax
        ret
field_next_cell:
        inc     dl
        cmp     dl,byte ptr es:[bx+3]
        jbe     short field_next_ok
        mov     dl,byte ptr es:[bx+1]
        inc     dh
        cmp     dh,byte ptr es:[bx+2]
        jbe     short field_next_ok
        stc
        ret
field_next_ok:
        clc
        ret

; DX one cell back in field ES:BX (CF:  before the start).
field_prev_cell:
        cmp     dl,byte ptr es:[bx+1]
        je      short field_prev_row
        dec     dl
        clc
        ret
field_prev_row:
        mov     dl,byte ptr es:[bx+3]
        cmp     dh,byte ptr es:[bx]
        je      short field_prev_none
        dec     dh
        clc
        ret
field_prev_none:
        stc
        ret

; field ES:BX scrolled:  each cell gets the character of the one CH rows /
; CL columns (signed) from it, a blank where that is outside the field;
; the attributes and the cursor kept.
field_scroll:
        push    ax
        push    cx
        push    dx
        push    si
        call    field_cursor_get
        push    dx
        mov     si,cx
        mov     al,ch
        add     al,cl
        js      short field_scroll_back
        mov     dh,byte ptr es:[bx]   ; up / left:  from the first cell
        mov     dl,byte ptr es:[bx+1]
field_scroll_fwd:
        call    field_scroll_cell
        call    field_next_cell
        jnc     short field_scroll_fwd
        jmp     short field_scroll_done
field_scroll_back:
        mov     dh,byte ptr es:[bx+2] ; down / right:  from the last cell
        mov     dl,byte ptr es:[bx+3]
field_scroll_bwd:
        call    field_scroll_cell
        call    field_prev_cell
        jnc     short field_scroll_bwd
field_scroll_done:
        pop     dx
        call    field_cursor_set
        pop     si
        pop     dx
        pop     cx
        pop     ax
        ret

; cell DX of field ES:BX gets the character of cell DX + SI (SI high rows,
; low columns), a blank outside the field.
field_scroll_cell:
        push    dx
        mov     ax,si
        add     dh,ah
        add     dl,al
        mov     al,' '
        call    field_inside
        jc      short field_scroll_put
        call    field_cursor_set
        push    bx
        mov     bh,byte ptr cs:window_page
        call    wcell_read
        pop     bx
field_scroll_put:
        pop     dx
        call    field_cursor_set
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_char
        pop     cx
        pop     bx
        ret

; DX inside field ES:BX:  CF clear.
field_inside:
        cmp     dh,byte ptr es:[bx]
        jb      short field_inside_no
        cmp     dh,byte ptr es:[bx+2]
        ja      short field_inside_no
        cmp     dl,byte ptr es:[bx+1]
        jb      short field_inside_no
        cmp     dl,byte ptr es:[bx+3]
        ja      short field_inside_no
        clc
        ret
field_inside_no:
        stc
        ret

; field ES:BX filled with character AL (the attributes kept), the cursor
; kept.
field_fill_char:
        push    cx
        push    dx
        push    ax
        call    field_cursor_get
        pop     ax
        push    dx
        call    field_first_cell
field_fill_char_one:
        call    field_cursor_set
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_char
        pop     cx
        pop     bx
        call    field_next_cell
        loop    field_fill_char_one
        pop     dx
        call    field_cursor_set
        pop     dx
        pop     cx
        ret

; field ES:BX in attribute AL (the characters kept), the cursor kept.
field_fill_attr:
        push    cx
        push    dx
        push    ax
        call    field_cursor_get
        pop     ax
        push    dx
        call    field_first_cell
field_fill_attr_one:
        call    field_cursor_set
        push    ax
        push    bx
        push    cx
        push    ax
        mov     bh,byte ptr cs:window_page
        call    wcell_read
        pop     bx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_charattr
        pop     cx
        pop     bx
        pop     ax
        call    field_next_cell
        loop    field_fill_attr_one
        pop     dx
        call    field_cursor_set
        pop     dx
        pop     cx
        ret

; F3h:  the field's size of stream bytes (SI up to DI) into field ES:BX;
; CF:  the stream ended.
field_contents:
        push    cx
        push    dx
        call    field_cursor_get
        push    dx
        call    field_first_cell
field_contents_one:
        call    window_byte
        jc      short field_contents_end
        call    field_cursor_set
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_char
        pop     cx
        pop     bx
        call    field_next_cell
        loop    field_contents_one
        clc
field_contents_end:
        pop     dx
        pushf
        call    field_cursor_set
        popf
        pop     dx
        pop     cx
        ret

; READ of the keyboard in field mode (field_header):  the field manager,
; as DESQview 2.80 in keystroke-free fields:  typing goes into the
; fill-in field (class 10b) the cursor is in (nothing while it is in none),
; Tab / Shift+Tab to the next / previous one, the arrows and BS in it,
; Enter (status 00h), Esc (1Bh) and a full auto-Enter field (04h) return.
; Then the header's current field, the select field 0, the data:  packed
; characters of all fields (also for the numbered modes, not done yet).
; message_result_* set; the scan code (STATUS) is the reason.
field_read:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        mov     ah,0Fh
        push    bx
        int     10h
        mov     byte ptr cs:window_page,bh
        pop     bx
        call    field_current         ; SI = the field (0:  none)
        call    field_mouse_click     ; (presses before the READ:  gone)
        or      si,si                 ; alternate mode (BDh):  a select
        jnz     short field_read_key  ; field pointed at
        call    field_point_init
field_read_key:
        mov     ah,1
        int     16h
        jnz     short field_read_got
        call    field_mouse_click     ; a left click on a select field:
        jnc     short field_read_idle ; selected, status 1 (as a key)
        mov     al,1
        jmp     field_read_done
field_read_idle:
        sti
        call    api_pause
        cli
        jmp     short field_read_key
field_read_got:
        sti
        xor     ah,ah
        int     16h
        cli
        cmp     al,0Dh
        jne     short field_read_not_enter
        call    field_select_key      ; a select field with Enter as its
        jnc     short field_read_enter_point ; key:  selected (status 1)
        mov     al,1
        jmp     field_read_done
field_read_enter_point:
        or      si,si                 ; Enter on the pointed at field:
        jnz     short field_read_enter ; selected (as its key)
        call    field_point_select
        jnc     short field_read_enter
        mov     al,1
        jmp     field_read_done
field_read_enter:
        xor     al,al
        jmp     field_read_done
field_read_not_enter:
        cmp     al,1Bh
        jne     short field_read_not_esc
        call    field_select_key      ; Esc:  a select field with it as
                                      ; its key selects that (status 1)
        jnc     short field_read_esc
        mov     al,1
field_read_esc:
        jmp     field_read_done
field_read_not_esc:
        cmp     al,09h
        jne     short field_read_not_tab
        mov     dl,1
        call    field_step
        jmp     short field_read_key
field_read_not_tab:
        cmp     ax,0F00h              ; Shift+Tab
        jne     short field_read_not_btab
        mov     dl,-1
        call    field_step
        jmp     short field_read_key
field_read_not_btab:
        or      al,al                 ; an extended key:  a select field
        jnz     short field_read_not_ext_select ; with it (00h, its scan
        call    field_select_key      ; code as the second key) selects
        jnc     short field_read_not_ext_select ; that
        mov     al,1
        jmp     field_read_done
field_read_not_ext_select:
        or      si,si
        jnz     short field_read_in_field
        or      al,al                 ; the cursor keys:  the pointed at
        jnz     short field_read_select ; select field on
        call    field_point_key
        jmp     field_read_key
field_read_select:
        call    field_select_key      ; outside a fill-in field:  a select
        jnc     field_read_key  ; field's key selects it, returns with
        mov     al,1                  ; status 1; others nothing
        jmp     field_read_done
field_read_in_field:
        mov     cx,si
        push    ax
        mov     al,cl
        call    field_entry
        pop     ax
        cmp     al,08h
        je      short field_read_bs
        or      al,al
        jz      field_read_ext
        cmp     al,20h
        jb      field_read_key
        test    byte ptr es:[bx+5],10h ; force upper case
        jz      short field_read_case
        cmp     al,'a'
        jb      short field_read_case
        cmp     al,'z'
        ja      short field_read_case
        sub     al,20h
field_read_case:
        test    byte ptr es:[bx+5],20h ; from the right end (numbers)
        jz      short field_read_left
        call    field_right_char
        or      byte ptr es:[bx+4],01h
        jmp     field_read_key
field_read_left:
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_char
        pop     cx
        pop     bx
        or      byte ptr es:[bx+4],01h ; modified
        call    field_cursor_get
        call    field_next_cell
        jnc     short field_read_moved
        test    byte ptr es:[bx+5],80h ; full:  auto Enter
        jz      short field_read_full_next
        mov     al,04h
        jmp     short field_read_done
field_read_full_next:
        test    byte ptr es:[bx+5],40h ; next field
        jz      short field_read_key_far
        mov     dl,1
        call    field_step
        jmp     short field_read_key_far
field_read_moved:
        call    field_cursor_set
field_read_key_far:
        jmp     field_read_key
field_read_bs:
        call    field_cursor_get
        cmp     dl,byte ptr es:[bx+1]
        jbe     short field_read_key_far
        dec     dl
        call    field_cursor_set
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        mov     al,20h
        call    wcell_char
        pop     cx
        pop     bx
        or      byte ptr es:[bx+4],01h
        jmp     short field_read_key_far
field_read_ext:
        call    field_cursor_get
        cmp     ah,4Bh                ; left
        jne     short field_read_not_left
        cmp     dl,byte ptr es:[bx+1]
        jbe     short field_read_key_far
        dec     dl
        call    field_cursor_set
        jmp     short field_read_key_far
field_read_not_left:
        cmp     ah,4Dh                ; right
        jne     short field_read_key_far
        call    field_next_cell
        jc      short field_read_key_far
        call    field_cursor_set
        jmp     short field_read_key_far
field_read_done:
        mov     byte ptr cs:keyboard_scan,al ; STATUS:  why
        les     bx,dword ptr cs:field_header
        mov     ax,si
        or      al,al
        jz      short field_read_keep
        mov     byte ptr es:[bx+2],al ; the current field
field_read_keep:
        cmp     byte ptr cs:field_alt,0 ; (alternate mode:  the pointed at
        jne     short field_read_point ; select field stays)
        mov     byte ptr es:[bx+3],0
field_read_point:
        mov     al,byte ptr es:[bx+1]
        push    ax
        call    field_data            ; CX bytes in field_buffer
        pop     ax
        test    al,03h                ; mode 00:  no data
        jnz     short field_read_len
        xor     cx,cx
field_read_len:
        test    al,04h                ; modified bits off at the return
        jz      short field_read_result
        push    ax
        push    cx                    ; (the data's length)
        mov     ah,0FEh
        call    field_count
        jc      short field_read_nobits
        mov     dl,1
field_read_bits:
        mov     al,dl
        call    field_entry
        and     byte ptr es:[bx+4],0FEh
        inc     dl
        loop    field_read_bits
field_read_nobits:
        pop     cx
        pop     ax
field_read_result:
        mov     word ptr cs:message_result_len_lo,cx
        mov     word ptr cs:message_result_len_hi,0
        mov     word ptr cs:message_result_ptr_off,offset field_buffer
        mov     word ptr cs:message_result_ptr_seg,cs
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; The selected and pointed at select fields in their colour (the others
; keep the window's), as DESQview 2.80.
field_paint_selects:
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        call    field_count
        jc      short field_paint_ret
        mov     dl,1
field_paint_one:
        mov     al,dl                 ; (DESQview 2.80:  only the selected
        call    field_entry           ; and the pointed at ones; the others
        test    byte ptr es:[bx+4],02h ; keep the window's colours)
        jnz     short field_paint_this
        call    field_pointed
        jc      short field_paint_skip
field_paint_this:
        call    field_paint
field_paint_skip:
        inc     dl
        loop    field_paint_one
field_paint_ret:
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; field ES:BX, if a select field, in its colour (pointed at, alternate
; mode:  the header's pointed at colour).
field_paint:
        push    ax
        mov     al,byte ptr es:[bx+4]
        and     al,0C0h
        cmp     al,0C0h
        jne     short field_paint_done
        call    field_pointable       ; (keyboard only:  not on the screen)
        jc      short field_paint_done
        call    field_pointed
        jc      short field_paint_normal
        push    es
        push    bx
        les     bx,dword ptr cs:field_header
        mov     al,byte ptr es:[bx+4]
        pop     bx
        pop     es
        jmp     short field_paint_attr
field_paint_normal:
        mov     al,byte ptr es:[bx+6]
        test    byte ptr es:[bx+4],02h
        jz      short field_paint_attr
        push    es
        push    bx
        les     bx,dword ptr cs:field_header
        mov     al,byte ptr es:[bx+5]
        pop     bx
        pop     es
field_paint_attr:
        call    field_fill_attr
field_paint_done:
        pop     ax
        ret

; AL typed into field ES:BX that fills from its right end:  its contents
; one cell to the left, AL in the last one, the cursor there.
field_right_char:
        push    ax
        push    cx
        push    dx
        mov     byte ptr cs:field_rc_char,al
        call    field_first_cell      ; DX the first cell, CX the cells
        mov     word ptr cs:field_rc_left,cx
field_right_shift:
        dec     word ptr cs:field_rc_left
        jz      short field_right_last
        mov     word ptr cs:field_rc_cell,dx
        call    field_next_cell       ; the next cell's character
        call    field_cursor_set
        push    bx
        mov     bh,byte ptr cs:window_page
        call    wcell_read
        pop     bx
        push    dx                    ; into this cell
        mov     dx,word ptr cs:field_rc_cell
        call    field_cursor_set
        call    field_right_put
        pop     dx
        jmp     short field_right_shift
field_right_last:
        call    field_cursor_set
        mov     al,byte ptr cs:field_rc_char
        call    field_right_put
        pop     dx
        pop     cx
        pop     ax
        ret
field_right_put:
        push    bx
        push    cx
        mov     bh,byte ptr cs:window_page
        mov     cx,1
        call    wcell_char
        pop     cx
        pop     bx
        ret

; CF clear:  field ES:BX is the one pointed at (alternate mode, BDh).
field_pointed:
        push    ax
        push    cx
        push    dx
        push    bx
        push    es
        cmp     byte ptr cs:field_alt,0
        je      short field_pointed_no
        mov     ax,bx                 ; its number:  (BX - table - 6) /
        les     bx,dword ptr cs:field_header ; entry size + 1
        sub     ax,bx
        sub     ax,6
        mov     cl,byte ptr cs:field_esize
        div     cl
        inc     al
        cmp     al,byte ptr es:[bx+3]
        jne     short field_pointed_no
        clc
        jmp     short field_pointed_ret
field_pointed_no:
        stc
field_pointed_ret:
        pop     es
        pop     bx
        pop     dx
        pop     cx
        pop     ax
        ret

; CF clear:  field ES:BX may be pointed at (a select field, its start not
; right of / below its end:  not keyboard only).
field_pointable:
        push    ax
        mov     al,byte ptr es:[bx+4]
        and     al,0C0h
        cmp     al,0C0h
        jne     short field_pointable_no
        mov     ax,word ptr es:[bx+2] ; end row, column
        xchg    al,ah
        cmp     ah,byte ptr es:[bx]
        jb      short field_pointable_no
        ja      short field_pointable_yes
        cmp     al,byte ptr es:[bx+1]
        jb      short field_pointable_no
field_pointable_yes:
        pop     ax
        clc
        ret
field_pointable_no:
        pop     ax
        stc
        ret

; Alternate mode at a READ:  the header's current select field (or the
; first that may be pointed at) pointed at and painted.
field_point_init:
        cmp     byte ptr cs:field_alt,0
        je      short field_point_init_ret
        push    ax
        push    bx
        push    es
        les     bx,dword ptr cs:field_header
        mov     al,byte ptr es:[bx+3]
        call    field_entry
        jc      short field_point_init_first
        call    field_pointable
        jnc     short field_point_init_set
field_point_init_first:
        mov     byte ptr cs:field_point_from,0
        push    dx
        mov     dl,1
        call    field_point_move
        pop     dx
        jmp     short field_point_init_done
field_point_init_set:
        call    field_point_set
field_point_init_done:
        pop     es
        pop     bx
        pop     ax
field_point_init_ret:
        ret

; Field AL pointed at:  the header's current select field, the old one and
; it painted again.
field_point_set:
        push    ax
        push    bx
        push    es
        push    ax
        les     bx,dword ptr cs:field_header
        mov     ah,byte ptr es:[bx+3]
        mov     byte ptr es:[bx+3],al
        mov     al,ah
        call    field_entry
        jc      short field_point_set_new
        call    field_paint
field_point_set_new:
        pop     ax
        call    field_entry
        jc      short field_point_set_ret
        call    field_paint
field_point_set_ret:
        pop     es
        pop     bx
        pop     ax
        ret

; From the pointed at field (field_point_from:  0 for before the first)
; DL (1 / -1) on to the next one that may be pointed at, round.
field_point_move:
        push    ax
        push    bx
        push    cx
        push    es
        call    field_count
        jc      short field_point_move_ret
        mov     al,byte ptr cs:field_point_from
field_point_move_one:
        add     al,dl
        or      al,al
        jnz     short field_point_move_low
        mov     al,cl
field_point_move_low:
        cmp     al,cl
        jbe     short field_point_move_chk
        mov     al,1
field_point_move_chk:
        call    field_entry
        jc      short field_point_move_ret
        call    field_pointable
        jnc     short field_point_move_found
        loop    field_point_move_one
        jmp     short field_point_move_ret
field_point_move_found:
        call    field_point_set
field_point_move_ret:
        pop     es
        pop     cx
        pop     bx
        pop     ax
        ret

; An extended key (AH) outside fill-in fields, alternate mode:  Up / Left
; the previous select field pointed at, Down / Right the next.
field_point_key:
        cmp     byte ptr cs:field_alt,0
        je      short field_point_key_ret
        push    bx
        push    dx
        push    es
        mov     dl,-1
        cmp     ah,48h
        je      short field_point_key_go
        cmp     ah,4Bh
        je      short field_point_key_go
        mov     dl,1
        cmp     ah,50h
        je      short field_point_key_go
        cmp     ah,4Dh
        jne     short field_point_key_done
field_point_key_go:
        les     bx,dword ptr cs:field_header
        mov     dh,byte ptr es:[bx+3]
        mov     byte ptr cs:field_point_from,dh
        call    field_point_move
field_point_key_done:
        pop     es
        pop     dx
        pop     bx
field_point_key_ret:
        ret

; Enter, alternate mode:  the pointed at field selected and modified,
; painted; CF set then (as its key).
field_point_select:
        cmp     byte ptr cs:field_alt,0
        je      short field_point_select_no
        push    ax
        push    bx
        push    es
        les     bx,dword ptr cs:field_header
        mov     al,byte ptr es:[bx+3]
        call    field_entry
        jc      short field_point_select_none
        call    field_pointable
        jc      short field_point_select_none
        or      byte ptr es:[bx+4],03h
        call    field_paint
        pop     es
        pop     bx
        pop     ax
        stc
        ret
field_point_select_none:
        pop     es
        pop     bx
        pop     ax
field_point_select_no:
        clc
        ret

; A mouse driver's (INT 33h) left button presses since the last call:
; at the last one the select field under the pointer (text cell = pixel
; / 8) selected, modified and painted, CF set then (DESQview 2.80:  a
; click on a select field returns as its key does).
field_mouse_click:
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        call    mouse_driver          ; no driver:  nothing
        jc      short field_mouse_no
        mov     ax,5
        xor     bx,bx
        int     33h
        or      bx,bx
        jz      short field_mouse_no
        shr     cx,1                  ; (8086:  no SHR by 3)
        shr     cx,1
        shr     cx,1
        shr     dx,1
        shr     dx,1
        shr     dx,1
        mov     dh,dl                 ; DH row, DL column
        mov     dl,cl
        call    field_count
        jc      short field_mouse_no
        mov     al,1
field_mouse_one:
        call    field_entry
        mov     ah,byte ptr es:[bx+4]
        and     ah,0C0h
        cmp     ah,0C0h
        jne     short field_mouse_next
        call    field_inside
        jc      short field_mouse_next
        or      byte ptr es:[bx+4],03h
        call    field_paint
        stc
        jmp     short field_mouse_ret
field_mouse_next:
        inc     al
        loop    field_mouse_one
field_mouse_no:
        clc
field_mouse_ret:
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; key AL:  with keyboard selection (header bit 6) the select field with
; that activation key (either case) selected and modified, painted; CF set
; then.
field_select_key:
        push    ax
        push    bx
        push    cx
        push    dx
        push    es
        or      al,al
        jnz     short field_select_char
        cmp     byte ptr cs:field_esize,8 ; an extended key:  two-key menus
        jne     short field_select_no ; only (first key 00h, the second
        mov     al,ah                 ; its scan code)
        mov     ah,0
        jmp     short field_select_go
field_select_char:
        cmp     al,'a'
        jb      short field_select_case
        cmp     al,'z'
        ja      short field_select_case
        sub     al,20h
field_select_case:
        mov     ah,al
        mov     al,0FFh               ; (no second key)
field_select_go:
        mov     byte ptr cs:field_select_second,al
        les     bx,dword ptr cs:field_header
        test    byte ptr es:[bx+1],40h
        jz      short field_select_no
        call    field_count
        jc      short field_select_no
        mov     dl,1
field_select_one:
        mov     al,dl
        call    field_entry
        mov     al,byte ptr es:[bx+4]
        and     al,0C0h
        cmp     al,0C0h
        jne     short field_select_next
        mov     al,byte ptr es:[bx+5]
        cmp     al,'a'
        jb      short field_select_cmp
        cmp     al,'z'
        ja      short field_select_cmp
        sub     al,20h
field_select_cmp:
        cmp     al,ah
        jne     short field_select_next
        or      al,al                 ; 00h:  the second key too
        jnz     short field_select_hit
        mov     al,byte ptr es:[bx+7]
        cmp     al,byte ptr cs:field_select_second
        jne     short field_select_next
field_select_hit:
        or      byte ptr es:[bx+4],03h
        call    field_paint
        stc
        jmp     short field_select_ret
field_select_next:
        inc     dl
        loop    field_select_one
field_select_no:
        clc
field_select_ret:
        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; SI = the fill-in field the cursor is in (0:  none).
field_current:
        push    ax
        push    cx
        push    dx
        xor     si,si
        call    field_count
        jc      short field_current_ret
        call    field_cursor_get
        mov     al,1
field_current_one:
        call    field_entry
        mov     ah,byte ptr es:[bx+4]
        and     ah,0C0h
        cmp     ah,80h
        jne     short field_current_next
        call    field_inside
        jc      short field_current_next
        mov     ah,0
        mov     si,ax
        jmp     short field_current_ret
field_current_next:
        inc     al
        loop    field_current_one
field_current_ret:
        pop     dx
        pop     cx
        pop     ax
        ret

; SI = the next (DL = 1) or previous (DL = -1) fill-in field after SI,
; the cursor to its start.
field_step:
        push    ax
        push    cx
        push    dx
        call    field_count
        jc      short field_step_ret
        mov     ax,si
field_step_one:
        add     al,dl
        or      al,al
        jnz     short field_step_low
        mov     al,cl
field_step_low:
        cmp     al,cl
        jbe     short field_step_chk
        mov     al,1
field_step_chk:
        call    field_entry
        mov     ah,byte ptr es:[bx+4]
        and     ah,0C0h
        cmp     ah,80h
        je      short field_step_found
        loop    field_step_one
        jmp     short field_step_ret
field_step_found:
        xor     ah,ah
        mov     si,ax
        mov     dh,byte ptr es:[bx]
        mov     dl,byte ptr es:[bx+1]
        call    field_cursor_set
field_step_ret:
        pop     dx
        pop     cx
        pop     ax
        ret

; CX = the bytes of all fields' characters (packed, in field order) in
; field_buffer (FIELD_BUFFER_SIZE at most), as numbered records in the
; header's modes 10b/11b; the cursor kept.
field_data:
        push    ax
        push    bx
        push    dx
        push    si
        push    di
        push    es
        call    field_cursor_get
        push    dx
        mov     di,offset field_buffer
        call    field_count
        jc      field_data_end
        mov     al,1
field_data_field:
        push    cx
        push    ax
        call    field_entry
        xor     si,si                 ; modes 10b/11b:  numbered records,
        push    es                    ; byte field, word length, the data
        push    bx                    ; (11b:  modified fields only)
        les     bx,dword ptr cs:field_header
        mov     ah,byte ptr es:[bx+1]
        pop     bx
        pop     es
        test    ah,02h
        jz      short field_data_plain
        test    ah,01h
        jz      short field_data_record
        test    byte ptr es:[bx+4],01h
        jz      short field_data_next
field_data_record:
        cmp     di,offset field_buffer + FIELD_BUFFER_SIZE - 3
        ja      short field_data_next
        mov     si,di
        mov     byte ptr cs:[di],al
        add     di,3
field_data_plain:
        mov     ah,byte ptr es:[bx+4] ; a select field:  "Y" / "N" (header
        and     ah,0C0h               ; bit 3 clear)
        cmp     ah,0C0h
        jne     short field_data_chars
        push    es
        push    bx
        les     bx,dword ptr cs:field_header
        test    byte ptr es:[bx+1],08h
        pop     bx
        pop     es
        jnz     short field_data_chars
        cmp     di,offset field_buffer + FIELD_BUFFER_SIZE
        jae     short field_data_next
        mov     al,'N'
        test    byte ptr es:[bx+4],02h
        jz      short field_data_yn
        mov     al,'Y'
field_data_yn:
        mov     byte ptr cs:[di],al
        inc     di
        jmp     short field_data_next
field_data_chars:
        call    field_first_cell
field_data_cell:
        cmp     di,offset field_buffer + FIELD_BUFFER_SIZE
        jae     short field_data_next
        call    field_cursor_set
        push    bx
        mov     bh,byte ptr cs:window_page
        call    wcell_read
        pop     bx
        mov     byte ptr cs:[di],al
        inc     di
        call    field_next_cell
        loop    field_data_cell
field_data_next:
        or      si,si
        jz      short field_data_unnumbered
        mov     ax,di
        sub     ax,si
        sub     ax,3
        mov     word ptr cs:[si+1],ax
field_data_unnumbered:
        pop     ax
        pop     cx
        inc     al
        dec     cx
        jz      short field_data_end
        jmp     field_data_field
field_data_end:
        pop     dx
        call    field_cursor_set
        mov     cx,di
        sub     cx,offset field_buffer
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     bx
        pop     ax
        ret

window_stream_name:
        call    window_byte
        jc      window_stream_end
        mov     cl,al
        xor     ch,ch
        cmp     word ptr cs:wtarget,0 ; a window object:  its title
        je      short window_stream_name_skip
        call    wobj_set_title
window_stream_name_skip:
        add     si,cx
        cmp     si,di
        jbe     short window_stream_name_done
        mov     si,di
window_stream_name_done:
        jmp     window_stream_next
window_stream_counted:
        mov     dl,al                 ; 80h-9Fh:  N = 3 bits:  the next byte
        mov     ch,al
        and     ch,07h
        call    window_byte
        jc      window_stream_end
        mov     cl,al
        or      cx,cx
        jnz     short window_stream_counted_n
        mov     cx,0800h
window_stream_counted_n:
        and     dl,18h
        jz      window_stream_blanks
        cmp     dl,08h
        je      window_stream_repeat
        cmp     dl,10h
        je      window_stream_attr_blanks
        jmp     window_stream_literal
window_stream_set:
        mov     dl,al                 ; A0h row, A1h column, others:  1 arg
        call    window_byte
        jc      window_stream_end
        cmp     dl,0A4h               ; A4h, A5h:  a window object's place
        je      short window_stream_set_place
        cmp     dl,0A5h
        je      short window_stream_set_place
        cmp     dl,0A1h
        ja      short window_stream_next_far
        push    dx
        mov     cl,al
        call    window_cursor_get
        pop     ax
        cmp     al,0A0h
        jne     short window_stream_set_col
        mov     dh,cl
        jmp     short window_stream_set_go
window_stream_set_col:
        mov     dl,cl
window_stream_set_go:
        call    window_cursor_set
window_stream_next_far:
        jmp     window_stream_next
window_stream_set_place:
        call    wobj_place
        jmp     window_stream_next
window_stream_rel:
        mov     dl,al                 ; B0h rows, B1h columns, signed
        call    window_byte
        jc      window_stream_end
        cmp     dl,0B4h               ; B4h, B5h:  a window object moved
        je      short window_stream_set_place
        cmp     dl,0B5h
        je      short window_stream_set_place
        cmp     dl,0B1h
        ja      short window_stream_next_far
        mov     cl,al
        mov     al,dl
        call    window_cursor_get
        cmp     al,0B0h
        jne     short window_stream_rel_col
        add     dh,cl
        jmp     short window_stream_set_go
window_stream_rel_col:
        add     dl,cl
        jmp     short window_stream_set_go
window_stream_pair:
        cmp     al,0CEh               ; CEh, CFh:  no arguments
        jae     short window_stream_next_far
        mov     dl,al
        call    window_byte
        jc      window_stream_end
        mov     ch,al
        call    window_byte
        jc      window_stream_end
        mov     cl,al
        mov     al,dl
        cmp     al,0C0h
        je      short window_stream_pair_set
        cmp     al,0C2h               ; C2h, CAh:  a window object's place
        je      short window_stream_pair_place
        cmp     al,0CAh
        je      short window_stream_pair_place
        cmp     al,0C8h
        jne     short window_stream_next_far
        call    window_cursor_get
        add     dh,ch
        add     dl,cl
        jmp     short window_stream_set_go
window_stream_pair_set:
        mov     dh,ch
        mov     dl,cl
        jmp     short window_stream_set_go
window_stream_pair_place:
        mov     dl,0A4h               ; C2h as A4h, A5h; CAh as B4h, B5h
        cmp     al,0C2h
        je      short window_stream_pair_row
        mov     dl,0B4h
window_stream_pair_row:
        mov     al,ch
        call    wobj_place            ; the row
        inc     dl
        mov     al,cl
        call    wobj_place            ; the column
        jmp     window_stream_next
window_stream_ret:
        pop     dx
        pop     cx
        pop     ax
        ret

; A manager stream (type 10h) at SI up to DI:  BCh / BDh the standard /
; alternate field mode (the cursor keys in menus), BEh, BFh nothing,
; C0h-C2h the window (object) on top, C3h, C4h (2 arguments) nothing;
; another opcode ends it.
window_manager:
        push    ax
window_manager_next:
        call    window_byte
        jc      short window_manager_ret
        cmp     al,0BCh
        jne     short window_manager_not_bc
        mov     byte ptr cs:field_alt,0
        jmp     short window_manager_next
window_manager_not_bc:
        cmp     al,0BDh
        jne     short window_manager_not_bd
        mov     byte ptr cs:field_alt,1
        jmp     short window_manager_next
window_manager_not_bd:
        cmp     al,0BEh
        je      short window_manager_next
        cmp     al,0BFh
        je      short window_manager_next
        cmp     al,0C3h
        je      short window_manager_two
        cmp     al,0C4h
        je      short window_manager_two
        cmp     al,0C0h
        jb      short window_manager_ret
        cmp     al,0C2h
        ja      short window_manager_ret
        call    wobj_top
        jmp     short window_manager_next
window_manager_two:
        call    window_byte
        call    window_byte
        jmp     short window_manager_next
window_manager_ret:
        pop     ax
        ret

; The target window object on top:  a double frame, drawn again over the
; others (theirs single again); the task's window:  nothing.
wobj_top:
        push    cx
        push    si
        push    di
        mov     di,word ptr cs:wtarget
        or      di,di
        jz      short wobj_top_ret
        sub     di,2
        xor     si,si
        mov     cx,WOBJ_COUNT
wobj_top_others:
        cmp     si,di
        je      short wobj_top_next
        test    word ptr cs:wobj_flags[si],WF_TOP
        jz      short wobj_top_next
        and     word ptr cs:wobj_flags[si],not WF_TOP
        test    word ptr cs:wobj_flags[si],WF_DRAWN
        jz      short wobj_top_next
        test    word ptr cs:wobj_flags[si],WF_FRAME
        jz      short wobj_top_next
        call    wobj_frame
wobj_top_next:
        add     si,2
        loop    wobj_top_others
        mov     si,di
        or      word ptr cs:wobj_flags[si],WF_TOP
        test    word ptr cs:wobj_flags[si],WF_VISIBLE
        jz      short wobj_top_ret
        call    wobj_redraw
wobj_top_ret:
        pop     di
        pop     si
        pop     cx
        ret

; E6h rows, columns (SI up to DI):  a new window object (wobj_create) and
; the rest of the stream in it; its handle is the WRITE's result
; (wobj_made).  For a window object as the target:  a window of its own.
window_stream_new:
        call    window_byte
        jc      window_stream_ret
        mov     ch,al
        call    window_byte
        jc      window_stream_ret
        mov     cl,al
        push    si
        call    wobj_create
        mov     ax,si
        pop     si
        jc      window_stream_ret
        mov     word ptr cs:wobj_made,ax
        add     word ptr cs:wobj_made,2
        cmp     word ptr cs:wtarget,0 ; (one level:  the task's window)
        jne     window_stream_ret
        push    si
        mov     si,ax
        call    wobj_enter
        pop     si
        call    window_stream         ; the rest
        call    wobj_leave
        jmp     window_stream_ret

; D0h-DFh (AL):  a window object's flags (visible D4h/D5h, frame D6h/D7h,
; logical / physical colours DAh/DBh); the task's window:  nothing.
window_stream_flag:
        push    si
        mov     si,word ptr cs:wtarget
        or      si,si
        jnz     short window_stream_flag_wobj
        cmp     al,0DAh               ; the task's window:  logical
        jne     short window_stream_flag_task_db ; colours on / off
        push    ax
        mov     al,1
        call    window_logical_set
        pop     ax
window_stream_flag_task_db:
        cmp     al,0DBh
        jne     short window_stream_flag_ret
        push    ax
        xor     al,al
        call    window_logical_set
        pop     ax
        jmp     short window_stream_flag_ret
window_stream_flag_wobj:
        sub     si,2
        cmp     al,0D4h
        jne     short window_stream_flag_not_d4
        or      word ptr cs:wobj_flags[si],WF_VISIBLE
        test    word ptr cs:wobj_flags[si],WF_DRAWN
        jnz     short window_stream_flag_not_d4
        call    wobj_redraw
window_stream_flag_not_d4:
        cmp     al,0D5h
        jne     short window_stream_flag_not_d5
        and     word ptr cs:wobj_flags[si],not WF_VISIBLE
        call    wobj_undraw
window_stream_flag_not_d5:
        cmp     al,0D6h
        jne     short window_stream_flag_not_d6
        or      word ptr cs:wobj_flags[si],WF_FRAME
window_stream_flag_not_d6:
        cmp     al,0D7h
        jne     short window_stream_flag_not_d7
        and     word ptr cs:wobj_flags[si],not WF_FRAME
window_stream_flag_not_d7:
        cmp     al,0DAh
        jne     short window_stream_flag_not_da
        or      word ptr cs:wobj_flags[si],WF_LOGICAL
        call    wobj_paint_all
window_stream_flag_not_da:
        cmp     al,0DBh
        jne     short window_stream_flag_ret
        and     word ptr cs:wobj_flags[si],not WF_LOGICAL
        call    wobj_paint_all
window_stream_flag_ret:
        pop     si
        ret

; E4h:  a window object drawn again where it is now (or taken off the
; screen when hidden); the task's window:  nothing.
window_stream_redraw:
        push    si
        mov     si,word ptr cs:wtarget
        or      si,si
        jz      short window_stream_redraw_ret
        sub     si,2
        call    wobj_redraw
window_stream_redraw_ret:
        pop     si
        ret

; A4h/A5h (row / column, DL) to AL, B4h/B5h (signed) by AL:  the place of
; the target window object (DESQview:  of its contents; seen at the next
; E4h); the task's window:  nothing.
wobj_place:
        push    si
        mov     si,word ptr cs:wtarget
        or      si,si
        jz      short wobj_place_ret
        sub     si,2
        cmp     dl,0A4h
        jne     short wobj_place_not_a4
        mov     byte ptr cs:wobj_pos[si+1],al
wobj_place_not_a4:
        cmp     dl,0A5h
        jne     short wobj_place_not_a5
        mov     byte ptr cs:wobj_pos[si],al
wobj_place_not_a5:
        cmp     dl,0B4h
        jne     short wobj_place_not_b4
        add     byte ptr cs:wobj_pos[si+1],al
wobj_place_not_b4:
        cmp     dl,0B5h
        jne     short wobj_place_ret
        add     byte ptr cs:wobj_pos[si],al
wobj_place_ret:
        pop     si
        ret

; CX bytes of the stream at SI as the target window object's title.
wobj_set_title:
        push    ax
        push    cx
        push    si
        push    di
        push    es
        mov     di,word ptr cs:wtarget
        sub     di,2
        cmp     cx,WOBJ_TITLE_SIZE
        jbe     short wobj_set_title_len
        mov     cx,WOBJ_TITLE_SIZE
wobj_set_title_len:
        mov     word ptr cs:wobj_tlen[di],cx
        mov     ax,di
        shl     ax,1
        shl     ax,1
        shl     ax,1
        shl     ax,1                  ; (index * 2) * 16 = slot * 32
        add     ax,offset wobj_title
        mov     di,ax
        push    cs
        pop     es
        cld
        rep     movsb
        pop     es
        pop     di
        pop     si
        pop     cx
        pop     ax
        ret

; The window object SI the target (wtarget):  its colour and field table
; in window_color / field_header, the task's kept; wobj_leave undoes it.
wobj_enter:
        push    ax
        mov     ax,si
        add     ax,2
        mov     word ptr cs:wtarget,ax
        mov     al,byte ptr cs:window_color
        mov     byte ptr cs:wtarget_color,al
        mov     ax,word ptr cs:wobj_color[si]
        mov     byte ptr cs:window_color,al
        mov     ax,word ptr cs:field_header
        mov     word ptr cs:wtarget_fields,ax
        mov     ax,word ptr cs:field_header+2
        mov     word ptr cs:wtarget_fields+2,ax
        mov     al,byte ptr cs:field_esize
        mov     byte ptr cs:wtarget_esize,al
        mov     ax,word ptr cs:wobj_esize[si]
        mov     byte ptr cs:field_esize,al
        push    si
        shl     si,1
        mov     ax,word ptr cs:wobj_fields[si]
        mov     word ptr cs:field_header,ax
        mov     ax,word ptr cs:wobj_fields[si+2]
        mov     word ptr cs:field_header+2,ax
        pop     si
        pop     ax
        ret
wobj_leave:
        push    ax
        push    si
        mov     si,word ptr cs:wtarget
        or      si,si
        jz      short wobj_leave_ret
        sub     si,2
        mov     al,byte ptr cs:window_color
        xor     ah,ah
        mov     word ptr cs:wobj_color[si],ax
        mov     al,byte ptr cs:field_esize
        mov     word ptr cs:wobj_esize[si],ax
        mov     al,byte ptr cs:wtarget_esize
        mov     byte ptr cs:field_esize,al
        shl     si,1
        mov     ax,word ptr cs:field_header
        mov     word ptr cs:wobj_fields[si],ax
        mov     ax,word ptr cs:field_header+2
        mov     word ptr cs:wobj_fields[si+2],ax
        mov     al,byte ptr cs:wtarget_color
        mov     byte ptr cs:window_color,al
        mov     ax,word ptr cs:wtarget_fields
        mov     word ptr cs:field_header,ax
        mov     ax,word ptr cs:wtarget_fields+2
        mov     word ptr cs:field_header+2,ax
        mov     word ptr cs:wtarget,0
wobj_leave_ret:
        pop     si
        pop     ax
        ret

; AX handle:  SI = its window object's index, CF:  none.
wobj_validate:
        push    cx
        xor     si,si
        mov     cx,WOBJ_COUNT
wobj_validate_scan:
        cmp     ax,word ptr cs:wobj_handle_segments[si]
        jne     short wobj_validate_next
        cmp     word ptr cs:wobj_used[si],1
        jne     short wobj_validate_no
        clc
        jmp     short wobj_validate_ret
wobj_validate_next:
        add     si,2
        loop    wobj_validate_scan
wobj_validate_no:
        stc
wobj_validate_ret:
        pop     cx
        ret

; A new window object of CH rows, CL columns (1-25, 1-80):  SI = its index
; (CF:  no room).  As DESQview's:  framed, its contents at 1,1, visible but
; not drawn before an E4h or D4h, blanks in 71h, physical colours.
wobj_create:
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        or      ch,ch
        jnz     short wobj_create_rows
        inc     ch
wobj_create_rows:
        cmp     ch,25
        jbe     short wobj_create_cols
        mov     ch,25
wobj_create_cols:
        or      cl,cl
        jnz     short wobj_create_cols2
        inc     cl
wobj_create_cols2:
        cmp     cl,80
        jbe     short wobj_create_slot
        mov     cl,80
wobj_create_slot:
        xor     si,si
        mov     bx,WOBJ_COUNT
wobj_create_scan:
        cmp     word ptr cs:wobj_used[si],0
        je      short wobj_create_found
        add     si,2
        dec     bx
        jnz     short wobj_create_scan
        jmp     wobj_create_fail
wobj_create_found:
        mov     word ptr cs:wobj_size[si],cx
        mov     al,ch                 ; bytes:  rows * cols * 2 + (rows + 2)
        mul     cl                    ; * (cols + 2) * 2
        mov     bx,ax
        mov     al,ch
        add     al,2
        mov     dl,cl
        add     dl,2
        mul     dl
        add     ax,bx
        shl     ax,1
        mov     cx,ax
        call    wobj_alloc
        jc      wobj_create_fail
        mov     word ptr cs:wobj_buf[si],ax
        mov     word ptr cs:wobj_bytes[si],cx
        mov     word ptr cs:wobj_used[si],1
        call    caller_tag
        xor     ah,ah
        mov     word ptr cs:wobj_owner[si],ax
        mov     word ptr cs:wobj_pos[si],0101h
        mov     word ptr cs:wobj_cursor[si],0
        mov     word ptr cs:wobj_color[si],71h ; (DESQview 2.80, a task
        mov     word ptr cs:wobj_flags[si],WF_VISIBLE + WF_FRAME ; with no
        push    ax                    ; colours set; else its colours)
        mov     al,byte ptr cs:window_color
        or      al,al
        jz      short wobj_create_colour
        cmp     word ptr cs:wtarget,0
        jne     short wobj_create_colour
        xor     ah,ah
        mov     word ptr cs:wobj_color[si],ax
        call    window_logical_test
        jz      short wobj_create_colour
        or      word ptr cs:wobj_flags[si],WF_LOGICAL
wobj_create_colour:
        pop     ax
        mov     word ptr cs:wobj_esize[si],7
        mov     word ptr cs:wobj_tlen[si],0
        push    si
        shl     si,1
        mov     word ptr cs:wobj_fields[si],0
        mov     word ptr cs:wobj_fields[si+2],0
        pop     si
        mov     ax,7120h
        call    wobj_fill
        clc
        jmp     short wobj_create_ret
wobj_create_fail:
        stc
wobj_create_ret:
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; CX bytes of wobj_pool for a window object:  AX = their offset (CF:  no
; room); the first gap that fits (the blocks of the used objects).
wobj_alloc:
        push    bx
        push    dx
        push    di
        xor     ax,ax                 ; candidates:  0 and each block's end
        mov     di,-2
wobj_alloc_try:
        mov     dx,ax
        add     dx,cx
        jc      short wobj_alloc_next
        cmp     dx,WOBJ_POOL_SIZE
        ja      short wobj_alloc_next
        xor     bx,bx                 ; overlaps a used block?
wobj_alloc_check:
        cmp     word ptr cs:wobj_used[bx],0
        je      short wobj_alloc_check_next
        cmp     dx,word ptr cs:wobj_buf[bx]
        jbe     short wobj_alloc_check_next
        push    dx
        mov     dx,word ptr cs:wobj_buf[bx]
        add     dx,word ptr cs:wobj_bytes[bx]
        cmp     ax,dx
        pop     dx
        jb      short wobj_alloc_next
wobj_alloc_check_next:
        add     bx,2
        cmp     bx,WOBJ_COUNT * 2
        jb      short wobj_alloc_check
        clc
        jmp     short wobj_alloc_ret
wobj_alloc_next:
        add     di,2
        cmp     di,WOBJ_COUNT * 2
        jae     short wobj_alloc_fail
        cmp     word ptr cs:wobj_used[di],0
        je      short wobj_alloc_next
        mov     ax,word ptr cs:wobj_buf[di]
        add     ax,word ptr cs:wobj_bytes[di]
        jmp     short wobj_alloc_try
wobj_alloc_fail:
        stc
wobj_alloc_ret:
        pop     di
        pop     dx
        pop     bx
        ret

; Window object SI gone:  off the screen, its block free.
wobj_free:
        call    wobj_undraw
        mov     word ptr cs:wobj_used[si],0
        ret

; Its contents all AL in attribute AH.
wobj_fill:
        push    ax
        push    cx
        push    di
        push    es
        push    ax
        mov     ax,word ptr cs:wobj_size[si]
        mul     ah
        mov     cx,ax
        pop     ax
        push    cs
        pop     es
        mov     di,word ptr cs:wobj_buf[si]
        add     di,offset wobj_pool
        cld
        rep     stosw
        pop     es
        pop     di
        pop     cx
        pop     ax
        ret

; E3h:  the target's contents blanks in the output colour, then on the
; screen.
wobj_clear:
        push    ax
        push    si
        mov     si,word ptr cs:wtarget
        sub     si,2
        call    window_attr
        mov     al,' '
        call    wobj_fill
        call    wobj_paint_all
        pop     si
        pop     ax
        ret

; DI = the offset in CS of cell DX (DH row, DL column) of window object
; SI's contents, CF:  outside them (DI then a scratch cell).
wobj_cell:
        cmp     dh,byte ptr cs:wobj_size[si+1]
        jae     short wobj_cell_out
        cmp     dl,byte ptr cs:wobj_size[si]
        jb      short wobj_cell_in
wobj_cell_out:
        mov     di,offset wobj_scratch
        stc
        ret
wobj_cell_in:
        push    ax
        push    dx
        mov     al,dh
        mul     byte ptr cs:wobj_size[si]
        xor     dh,dh
        add     ax,dx
        shl     ax,1
        add     ax,word ptr cs:wobj_buf[si]
        add     ax,offset wobj_pool
        mov     di,ax
        pop     dx
        pop     ax
        clc
        ret

; ES:DI = the screen cell DX (DH row, DL column), CF:  off the screen.
wobj_screen:
        push    ax
        push    bx
        push    dx
        mov     ax,40h
        mov     es,ax
        mov     bl,byte ptr es:[84h]  ; rows - 1 (EGA and later)
        or      bl,bl
        jnz     short wobj_screen_rows
        mov     bl,24
wobj_screen_rows:
        cmp     dh,bl
        ja      short wobj_screen_off
        mov     bx,word ptr es:[4Ah]  ; columns
        cmp     dl,bl
        jae     short wobj_screen_off
        mov     al,dh
        mul     bl
        xor     dh,dh
        add     ax,dx
        shl     ax,1
        add     ax,word ptr es:[4Eh]  ; the page
        mov     di,ax
        mov     ax,0B800h
        cmp     word ptr es:[63h],3B4h
        jne     short wobj_screen_seg
        mov     ax,0B000h
wobj_screen_seg:
        mov     es,ax
        clc
        jmp     short wobj_screen_ret
wobj_screen_off:
        stc
wobj_screen_ret:
        pop     dx
        pop     bx
        pop     ax
        ret

; AH to the screen's attribute:  with WF_LOGICAL a colour 1-16 (the low
; nibble, 0 for 16) through wobj_logical; else as it is (DESQview:  through
; the creating window's colour translation, which MaxView's windows do
; not have).
wobj_attr:
        test    word ptr cs:wobj_flags[si],WF_LOGICAL
        jz      short wobj_attr_ret
        push    bx
        mov     bl,ah
        dec     bl
        and     bx,0Fh
        mov     ah,byte ptr cs:wobj_logical[bx]
        pop     bx
wobj_attr_ret:
        ret

; Cell DX of window object SI's contents to the screen, if it is drawn.
wobj_paint_cell:
        test    word ptr cs:wobj_flags[si],WF_DRAWN
        jz      short wobj_paint_cell_ret
        push    ax
        push    dx
        push    di
        push    es
        call    wobj_cell
        jc      short wobj_paint_cell_off
        mov     ax,word ptr cs:[di]
        call    wobj_attr
        add     dx,word ptr cs:wobj_pos[si]
        call    wobj_screen
        jc      short wobj_paint_cell_off
        mov     word ptr es:[di],ax
wobj_paint_cell_off:
        pop     es
        pop     di
        pop     dx
        pop     ax
wobj_paint_cell_ret:
        ret

; All its contents to the screen (if drawn).
wobj_paint_all:
        push    cx
        push    dx
        xor     dx,dx
wobj_paint_all_cell:
        call    wobj_paint_cell
        inc     dl
        cmp     dl,byte ptr cs:wobj_size[si]
        jb      short wobj_paint_all_cell
        xor     dl,dl
        inc     dh
        cmp     dh,byte ptr cs:wobj_size[si+1]
        jb      short wobj_paint_all_cell
        pop     dx
        pop     cx
        ret

; E4h for window object SI:  off the screen, then (visible) on it again at
; its place:  the screen under it saved, the frame (07h:  single lines,
; the title after the top left corner, as DESQview 2.80) and the contents.
wobj_redraw:
        call    wobj_undraw
        test    word ptr cs:wobj_flags[si],WF_VISIBLE
        jnz     short wobj_redraw_draw
        ret
wobj_redraw_draw:
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        mov     dx,word ptr cs:wobj_pos[si]
        mov     cx,word ptr cs:wobj_size[si]
        test    word ptr cs:wobj_flags[si],WF_FRAME
        jz      short wobj_redraw_rect
        sub     dx,0101h
        add     cx,0202h
wobj_redraw_rect:
        mov     word ptr cs:wobj_drawn[si],dx
        mov     word ptr cs:wobj_dsize[si],cx
        or      word ptr cs:wobj_flags[si],WF_DRAWN
        call    wobj_save_cells       ; the screen under it saved
        test    word ptr cs:wobj_flags[si],WF_FRAME
        jz      short wobj_redraw_contents
        call    wobj_frame
wobj_redraw_contents:
        call    wobj_paint_all
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; BX = the offset in CS of the saved screen of window object SI.
wobj_saved:
        push    ax
        mov     ax,word ptr cs:wobj_size[si]
        mul     ah
        shl     ax,1
        add     ax,word ptr cs:wobj_buf[si]
        add     ax,offset wobj_pool
        mov     bx,ax
        pop     ax
        ret

; The screen in its drawn rectangle into the saved screen (AL = 0) or back
; from it (AL = 1).
wobj_save_cells:
        xor     al,al
wobj_cells:
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        call    wobj_saved
        mov     dx,word ptr cs:wobj_drawn[si]
        mov     cx,word ptr cs:wobj_dsize[si]
wobj_cells_row:
        push    cx
        push    dx
wobj_cells_col:
        push    di
        call    wobj_screen
        jc      short wobj_cells_skip
        or      al,al
        jnz     short wobj_cells_back
        push    ax
        mov     ax,word ptr es:[di]
        mov     word ptr cs:[bx],ax
        pop     ax
        jmp     short wobj_cells_skip
wobj_cells_back:
        push    ax
        mov     ax,word ptr cs:[bx]
        mov     word ptr es:[di],ax
        pop     ax
wobj_cells_skip:
        pop     di
        add     bx,2
        inc     dl
        dec     cl
        jnz     short wobj_cells_col
        pop     dx
        pop     cx
        inc     dh
        dec     ch
        jnz     short wobj_cells_row
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; Window object SI off the screen (the saved screen back), if drawn.
wobj_undraw:
        test    word ptr cs:wobj_flags[si],WF_DRAWN
        jz      short wobj_undraw_ret
        push    ax
        mov     al,1
        call    wobj_cells
        pop     ax
        and     word ptr cs:wobj_flags[si],not WF_DRAWN
wobj_undraw_ret:
        ret

; The drawn window objects off the screen (the top one first), into
; wobj_off; wobj_on_all draws them again (the top one last) over what the
; task's window shows then.
wobj_off_all:
        push    ax
        push    cx
        push    si
        mov     word ptr cs:wobj_off,0
        mov     ax,WF_TOP
        call    wobj_off_pass
        xor     ax,ax
        call    wobj_off_pass
        pop     si
        pop     cx
        pop     ax
        ret
wobj_off_pass:                        ; those with WF_TOP as in AX
        xor     si,si
        mov     cx,WOBJ_COUNT
wobj_off_next:
        cmp     word ptr cs:wobj_used[si],0
        je      short wobj_off_skip
        test    word ptr cs:wobj_flags[si],WF_DRAWN
        jz      short wobj_off_skip
        push    dx
        mov     dx,word ptr cs:wobj_flags[si]
        and     dx,WF_TOP
        cmp     dx,ax
        pop     dx
        jne     short wobj_off_skip
        call    wobj_undraw
        push    cx
        mov     cx,si
        shr     cx,1
        push    ax
        mov     ax,1
        shl     ax,cl
        or      word ptr cs:wobj_off,ax
        pop     ax
        pop     cx
wobj_off_skip:
        add     si,2
        loop    wobj_off_next
        ret
wobj_on_all:
        push    ax
        push    cx
        push    si
        xor     ax,ax
        call    wobj_on_pass
        mov     ax,WF_TOP
        call    wobj_on_pass
        pop     si
        pop     cx
        pop     ax
        ret
wobj_on_pass:
        xor     si,si
        mov     cx,WOBJ_COUNT
wobj_on_next:
        push    cx
        mov     cx,si
        shr     cx,1
        push    ax
        mov     ax,1
        shl     ax,cl
        test    word ptr cs:wobj_off,ax
        pop     ax
        pop     cx
        jz      short wobj_on_skip
        push    dx
        mov     dx,word ptr cs:wobj_flags[si]
        and     dx,WF_TOP
        cmp     dx,ax
        pop     dx
        jne     short wobj_on_skip
        call    wobj_redraw
wobj_on_skip:
        add     si,2
        loop    wobj_on_next
        ret

; The frame of window object SI around its drawn rectangle.
wobj_frame:
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        mov     dx,word ptr cs:wobj_drawn[si]
        mov     cx,word ptr cs:wobj_dsize[si]
        mov     word ptr cs:wobj_fchars,offset wobj_single
        test    word ptr cs:wobj_flags[si],WF_TOP
        jz      short wobj_frame_style
        mov     word ptr cs:wobj_fchars,offset wobj_double
wobj_frame_style:
        mov     al,0                  ; the top:  the corner, the title, lines
        call    wobj_frame_char
        call    wobj_frame_cell
        mov     bx,si                 ; the title's characters
        shl     bx,1
        shl     bx,1
        shl     bx,1
        shl     bx,1
        add     bx,offset wobj_title
        push    cx
        mov     ch,byte ptr cs:wobj_tlen[si]
        sub     cl,2
wobj_frame_top:
        inc     dl
        mov     al,1
        call    wobj_frame_char
        or      ch,ch
        jz      short wobj_frame_top_line
        mov     al,byte ptr cs:[bx]
        inc     bx
        dec     ch
wobj_frame_top_line:
        call    wobj_frame_cell
        dec     cl
        jnz     short wobj_frame_top
        pop     cx
        inc     dl
        mov     al,2
        call    wobj_frame_char
        call    wobj_frame_cell
        mov     bl,ch                 ; the sides
        sub     bl,2
wobj_frame_side:
        inc     dh
        mov     dl,byte ptr cs:wobj_drawn[si]
        mov     al,3
        call    wobj_frame_char
        call    wobj_frame_cell
        add     dl,cl
        dec     dl
        call    wobj_frame_cell
        dec     bl
        jnz     short wobj_frame_side
        inc     dh                    ; the bottom
        mov     dl,byte ptr cs:wobj_drawn[si]
        mov     al,4
        call    wobj_frame_char
        call    wobj_frame_cell
        mov     bl,cl
        sub     bl,2
        mov     al,1
        call    wobj_frame_char
wobj_frame_bottom:
        inc     dl
        call    wobj_frame_cell
        dec     bl
        jnz     short wobj_frame_bottom
        inc     dl
        mov     al,5
        call    wobj_frame_char
        call    wobj_frame_cell
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret
; AX = the frame's character AL (0-5 of wobj_fchars) in 07h.
wobj_frame_char:
        push    bx
        mov     bx,word ptr cs:wobj_fchars
        xlat    byte ptr cs:[bx]
        mov     ah,07h
        pop     bx
        ret
wobj_frame_cell:
        push    di
        push    es
        call    wobj_screen
        jc      short wobj_frame_cell_off
        mov     word ptr es:[di],ax
wobj_frame_cell_off:
        pop     es
        pop     di
        ret

; During a field READ on the target window object (wobj_hwcursor):  the
; hardware cursor at its cursor on the screen.
wobj_show_cursor:
        cmp     byte ptr cs:wobj_hwcursor,0
        je      short wobj_show_cursor_ret
        push    ax
        push    bx
        push    dx
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        add     dx,word ptr cs:wobj_pos[si]
        mov     ah,02h
        mov     bh,0
        int     10h
        pop     si
        pop     dx
        pop     bx
        pop     ax
wobj_show_cursor_ret:
        ret

; SI = the target window object's index.
wobj_target:
        mov     si,word ptr cs:wtarget
        sub     si,2
        ret

; AL in attribute AH at the target's cursor, the cursor on; past the end
; of a row it stays there (column = width), the next character goes to
; the next row (at the bottom:  the contents up, blanks in AH below), as
; DESQview's.
wobj_put:
        push    dx
        push    di
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        cmp     dl,byte ptr cs:wobj_size[si]
        jb      short wobj_put_cell
        xor     dl,dl
        call    wobj_newline
wobj_put_cell:
        call    wobj_cell
        mov     word ptr cs:[di],ax
        call    wobj_paint_cell
        inc     dl
        mov     word ptr cs:wobj_cursor[si],dx
        pop     si
        pop     di
        pop     dx
        ret

; DH one row on (at the bottom:  the contents up, blanks in AH below).
wobj_newline:
        inc     dh
        cmp     dh,byte ptr cs:wobj_size[si+1]
        jb      short wobj_newline_ret
        dec     dh
        push    ax
        push    bx
        push    cx
        push    dx
        push    di
        push    es
        push    ds
        push    ax                    ; (AH:  the blanks' attribute)
        xor     dx,dx
        call    wobj_cell             ; DI = row 0
        mov     ax,word ptr cs:wobj_size[si]
        mov     bl,al
        xor     bh,bh                 ; BX = a row's cells
        mov     al,ah
        dec     al
        mul     bl
        mov     cx,ax                 ; the cells of rows 1 ..
        push    si
        mov     si,bx
        shl     si,1
        add     si,di
        push    cs
        pop     ds
        push    cs
        pop     es
        cld
        rep     movsw
        pop     si
        pop     ax
        mov     al,' '
        mov     cx,bx
        rep     stosw                 ; the last row blank
        pop     ds
        pop     es
        pop     di
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        call    wobj_paint_all
wobj_newline_ret:
        ret

; Teletype output to the target window object:  CR, LF, BS act, BEL is
; ignored, the rest in the output colour.
wobj_tty:
        push    dx
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        cmp     al,0Dh
        jne     short wobj_tty_not_cr
        xor     dl,dl
        jmp     short wobj_tty_cursor
wobj_tty_not_cr:
        cmp     al,0Ah
        jne     short wobj_tty_not_lf
        push    ax
        call    window_attr
        call    wobj_newline
        pop     ax
        jmp     short wobj_tty_cursor
wobj_tty_not_lf:
        cmp     al,08h
        jne     short wobj_tty_not_bs
        or      dl,dl
        jz      short wobj_tty_cursor
        dec     dl
        jmp     short wobj_tty_cursor
wobj_tty_not_bs:
        cmp     al,07h
        je      short wobj_tty_ret
        push    ax
        call    window_attr
        call    wobj_put
        pop     ax
        jmp     short wobj_tty_ret
wobj_tty_cursor:
        mov     word ptr cs:wobj_cursor[si],dx
wobj_tty_ret:
        pop     si
        pop     dx
        ret

; The field manager's cells at the cursor of the target (BH = the page for
; the task's window):  wcell_read AL character, AH attribute; wcell_char
; AL (the attribute kept); wcell_charattr AL in attribute BL.
wcell_read:
        cmp     word ptr cs:wtarget,0
        jne     short wcell_read_obj
        mov     ah,08h
        int     10h
        ret
wcell_read_obj:
        push    dx
        push    di
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        call    wobj_cell
        mov     ax,word ptr cs:[di]
        pop     si
        pop     di
        pop     dx
        ret
wcell_char:
        cmp     word ptr cs:wtarget,0
        jne     short wcell_char_obj
        push    ax
        mov     ah,0Ah
        int     10h
        pop     ax
        ret
wcell_char_obj:
        push    dx
        push    di
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        call    wobj_cell
        mov     byte ptr cs:[di],al
        call    wobj_paint_cell
        pop     si
        pop     di
        pop     dx
        ret
wcell_charattr:
        cmp     word ptr cs:wtarget,0
        jne     short wcell_charattr_obj
        push    ax
        mov     ah,09h
        int     10h
        pop     ax
        ret
wcell_charattr_obj:
        push    dx
        push    di
        push    si
        call    wobj_target
        mov     dx,word ptr cs:wobj_cursor[si]
        call    wobj_cell
        mov     byte ptr cs:[di],al
        mov     byte ptr cs:[di+1],bl
        call    wobj_paint_cell
        pop     si
        pop     di
        pop     dx
        ret

; A query stream (type 01h) at SI up to DI, as DESQview's (RBIL table
; 00446):  the answers go into the caller's stream in place, for a window
; that is the screen (origin 0,0, the screen's size, no frame).  A0h-ABh,
; AFh and E2h fill the next byte, C0h-C5h the next two, D0h-DFh become the
; flag of the state; another opcode ends the stream.
window_query:
        push    ax
        push    cx
        push    dx
        push    es
        mov     ax,40h
        mov     es,ax
        mov     ch,byte ptr es:[84h]  ; rows (EGA and later)
        inc     ch
        cmp     ch,1
        ja      short window_query_rows
        mov     ch,25
window_query_rows:
        mov     cl,byte ptr es:[4Ah]  ; columns
window_query_next:
        call    window_byte
        jnc     short window_query_op
        jmp     window_query_ret
window_query_op:
        cmp     al,0D0h
        jb      short window_query_value
        cmp     al,0E0h
        jae     short window_query_value
        ; flags:  the state's opcode in place of the asked one
        and     al,0FEh
        cmp     al,0D6h               ; framed / unframed:  no frame
        jne     short window_query_flag
        inc     al
window_query_flag:
        cmp     al,0D0h               ; may extend off-screen / always
        jne     short window_query_flag_set ; fully displayed:  displayed
        inc     al
window_query_flag_set:
        mov     byte ptr [si-1],al
        jmp     short window_query_next
window_query_value:
        cmp     al,0C0h
        jb      short window_query_one
        cmp     al,0C5h
        ja      short window_query_one
        call    window_query_pair     ; DH, DL
        cmp     si,di
        jae     short window_query_ret
        mov     byte ptr [si],dh
        inc     si
        cmp     si,di
        jae     short window_query_ret
        mov     byte ptr [si],dl
        inc     si
        jmp     short window_query_next
window_query_one:
        cmp     al,0E2h
        je      short window_query_color
        cmp     al,0AFh
        je      short window_query_mode
        cmp     al,0A0h
        jb      short window_query_ret
        cmp     al,0ABh
        ja      short window_query_ret
        push    ax                    ; A0h-ABh:  the pair's row (even)
        and     al,0FEh               ; or column (odd)
        sub     al,0A0h
        shr     al,1
        add     al,0C0h
        call    window_query_pair
        pop     ax
        test    al,1
        jz      short window_query_one_row
        mov     dh,dl
window_query_one_row:
        mov     al,dh
        jmp     short window_query_store
window_query_color:
        push    ax
        call    window_attr
        mov     al,ah
        pop     dx
        jmp     short window_query_store
window_query_mode:
        push    bx
        mov     ah,0Fh                ; 44h in colour text, as DESQview 2.80
        int     10h                   ; gave there, 0 else
        pop     bx
        cmp     al,2
        jb      short window_query_mode_other
        cmp     al,3
        ja      short window_query_mode_other
        mov     al,44h
        jmp     short window_query_store
window_query_mode_other:
        xor     al,al
window_query_store:
        cmp     si,di
        jae     short window_query_ret
        mov     byte ptr [si],al
        inc     si
        jmp     window_query_next
window_query_ret:
        pop     es
        pop     dx
        pop     cx
        pop     ax
        ret

; DH, DL = the pair of query opcode AL (C0h-C5h; CH, CL the screen's rows,
; columns):  the cursor, the scroll origin, the window position, its size,
; the viewport origin, the virtual screen's size.
window_query_pair:
        xor     dx,dx
        cmp     al,0C0h
        jne     short window_query_pair_size
        jmp     window_cursor_get
window_query_pair_size:
        cmp     al,0C3h
        je      short window_query_pair_screen
        cmp     al,0C5h
        jne     short window_query_pair_ret
window_query_pair_screen:
        mov     dx,cx
window_query_pair_ret:
        ret

; LOCK (BH=14h) of a mailbox (BL=00h; 02h and 03h come here as 00h):
; exclusive access, as TopView's:  the caller's again and again (each
; needs a CLOSE), another task's waits (PAUSE) until all its CLOSEs.
int15_message_lock:
        push    bp
        mov     bp,sp
        push    ax
        push    dx
        push    si
        cmp     bl,0
        jne     lock_done
        cmp     word ptr ss:[bp+10],0
        jne     short lock_pop
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short lock_pop
        call    caller_tag
        xor     ah,ah
        mov     dx,ax
lock_try:
        mov     ax,dx                 ; given to it (CLOSE):  its now
        or      ah,80h
        cmp     word ptr cs:mailbox_lock_waiter[si],ax
        jne     short lock_not_given
        mov     word ptr cs:mailbox_lock_waiter[si],0
        jmp     short lock_pop
lock_not_given:
        cmp     word ptr cs:mailbox_lock_count[si],0
        je      short lock_take
        cmp     word ptr cs:mailbox_lock_owner[si],dx
        je      short lock_take
        cmp     byte ptr cs:core_running,0 ; (alone:  no other task)
        je      short lock_take
        cmp     word ptr cs:mailbox_lock_waiter[si],0 ; the next to get it
        jne     short lock_wait
        mov     word ptr cs:mailbox_lock_waiter[si],dx
lock_wait:
        sti
        call    api_pause
        cli
        jmp     short lock_try
lock_take:
        cmp     word ptr cs:mailbox_lock_waiter[si],dx ; (it waited:  no
        jne     short lock_take_owner ; more)
        mov     word ptr cs:mailbox_lock_waiter[si],0
lock_take_owner:
        mov     word ptr cs:mailbox_lock_owner[si],dx
        inc     word ptr cs:mailbox_lock_count[si]
lock_pop:
        pop     si
        pop     dx
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled
lock_done:
        pop     si
        pop     dx
        pop     ax
        pop     bp
        jmp     int15_handled

; SUBFROM queues the caller's far pointer rather than copying its bytes. The
; producer must keep that storage valid until the record is read or erased.
mailbox_ref_keyboard:                 ; SUBFROM of a keyboard / pointer:
        call    pointer_validate      ; bits off
        jc      short mailbox_ref_not_pointer
        mov     ax,word ptr ss:[bp+14]
        not     ax
        and     word ptr cs:pointer_flags[si],ax
        jmp     short mailbox_ref_bits_done
mailbox_ref_not_pointer:
        call    kobj_validate
        jc      short mailbox_ref_not_kobj
        mov     ax,word ptr ss:[bp+14]
        not     ax
        and     word ptr cs:kobj_flags[si],ax
        jmp     short mailbox_ref_bits_done
mailbox_ref_not_kobj:
        mov     ax,word ptr ss:[bp+12]
        call    keyboard_validate
        jc      short mailbox_ref_done
        mov     ax,word ptr ss:[bp+14]
        not     ax
        and     word ptr cs:keyboard_flags,ax
mailbox_ref_bits_done:
        and     word ptr ss:[bp+8],0FFFEh
        pop     si
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled
int15_message_mailbox_ref:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        or      word ptr ss:[bp+8],1
        cmp     bl,0
        jne     short mailbox_ref_done
        cmp     word ptr ss:[bp+10],0
        jne     short mailbox_ref_done
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short mailbox_ref_keyboard
        call    message_swap22
        call    mailbox_add_reference
mailbox_ref_done:
        pop     si
        pop     ax
        call    message_shift16
        pop     bp
        add     sp,16
        jmp     int15_handled

; ERASE cancels a live timer interval or discards every queued mailbox
; message.  It consumes one explicit handle DWORD.
int15_message_erase:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0
        jne     short message_erase_done
        cmp     word ptr ss:[bp+10],0
        jne     short message_erase_done
        mov     ax,word ptr ss:[bp+12]
        call    own_window
        jne     short message_erase_not_own
        call    wobj_off_all          ; (the window objects stay on it)
        call    window_clear_bios     ; a window (DESQview 2.80):  blank,
        call    wobj_on_all
        push    bx                    ; the cursor at its top left
        push    dx
        mov     bh,byte ptr cs:window_page
        xor     dx,dx
        call    window_cursor_set
        pop     dx
        pop     bx
        jmp     short message_erase_done
message_erase_not_own:
        call    wobj_validate
        jc      short message_erase_not_wobj
        call    wobj_enter
        call    wobj_clear
        push    dx
        xor     dx,dx
        call    window_cursor_set
        pop     dx
        call    wobj_leave
        jmp     short message_erase_done
message_erase_not_wobj:
        call    timer_validate
        jc      short message_erase_mailbox
        mov     word ptr cs:timer_state[si],0
        jmp     short message_erase_done
message_erase_mailbox:
        call    mailbox_validate
        jc      short message_erase_done
        call    mailbox_clear_queue
message_erase_done:
        pop     si
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled

; SETNAME copies a bounded, non-NUL-terminated mailbox name into resident
; storage. The public stack contains length, address and finally the mailbox
; handle; all three DWORDs are consumed. A zero length clears the name.
int15_message_mailbox_setname:
        push    bp
        mov     bp,sp
        call    message_swap18
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        cmp     bl,0
        jne     short mailbox_setname_done
        cmp     word ptr ss:[bp+10],0
        jne     short mailbox_setname_done
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short mailbox_setname_done
        cmp     word ptr ss:[bp+20],0
        jne     short mailbox_setname_done
        mov     cx,word ptr ss:[bp+18]
        cmp     cx,MAILBOX_NAME_SIZE
        ja      short mailbox_setname_done
        jcxz    short mailbox_setname_store_length
        cmp     word ptr ss:[bp+16],0
        je      short mailbox_setname_done
        mov     dx,si
        mov     bx,si
        push    cx
        mov     cl,4
        shl     bx,cl
        pop     cx
        add     bx,offset mailbox_names
        mov     ax,word ptr ss:[bp+16]
        mov     ds,ax
        mov     si,word ptr ss:[bp+14]
        push    cs
        pop     es
        mov     di,bx
        cld
        rep     movsb
        mov     si,dx
mailbox_setname_store_length:
        mov     ax,word ptr ss:[bp+18]
        mov     word ptr cs:mailbox_name_length[si],ax
mailbox_setname_done:
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled

; Position the logical cursor of the sole foreground window. Selector 00h
; consumes column, row and an explicit window handle; selector 01h consumes
; column and row for the task's default window. Coordinates are DWORDs but
; valid foreground text coordinates fit in their low byte.
int15_message_window_at:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    dx
        push    si
        push    es
        cmp     bl,0
        jne     short window_at_default
        cmp     word ptr ss:[bp+16],0
        jne     short window_at_done
        cmp     word ptr ss:[bp+20],0
        jne     short window_at_done
        cmp     word ptr ss:[bp+14],00FFh
        ja      short window_at_done
        cmp     word ptr ss:[bp+18],00FFh
        ja      short window_at_done
        mov     dl,byte ptr ss:[bp+14] ; column on top, as DESQview
        mov     dh,byte ptr ss:[bp+18]
        jmp     short window_at_apply
window_at_default:
        cmp     word ptr ss:[bp+12],0
        jne     short window_at_done
        cmp     word ptr ss:[bp+16],0
        jne     short window_at_done
        cmp     word ptr ss:[bp+10],00FFh
        ja      short window_at_done
        cmp     word ptr ss:[bp+14],00FFh
        ja      short window_at_done
        mov     dl,byte ptr ss:[bp+10]
        mov     dh,byte ptr ss:[bp+14]
window_at_apply:
        mov     si,dx
        mov     ah,0Fh
        int     10h
        cmp     al,3
        jbe     short window_at_text_mode
        cmp     al,7
        jne     short window_at_done
window_at_text_mode:
        mov     dx,si
        cmp     dl,ah
        jae     short window_at_done
        mov     ax,40h
        mov     es,ax
        mov     al,byte ptr es:[84h]
        or      al,al
        jnz     short window_at_rows_ready
        mov     al,24
window_at_rows_ready:
        cmp     dh,al
        ja      short window_at_done
        mov     ah,02h
        int     10h
window_at_done:
        pop     es
        pop     si
        pop     dx
        pop     bx
        pop     ax
        cmp     bl,0
        jne     short window_at_shift_default
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled
window_at_shift_default:
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; BH=12h:  READN of the task's window (BL=01h:  the count on the stack;
; BL=00h:  its handle, then the count):  the next N characters from the
; cursor on (it moves past them), as DESQview; their length and address
; in place of the arguments.  Else mailbox GETNAME.
int15_message_readn_gateway:
        cmp     bl,1
        je      short readn_gateway_go
        cmp     bl,0
        jne     readn_gateway_getname
        push    bp
        mov     bp,sp
        push    ax
        cmp     word ptr ss:[bp+10],0
        jne     readn_gateway_not
        mov     ax,word ptr ss:[bp+12]
        call    own_window
        jne     readn_gateway_not
        pop     ax
        pop     bp
readn_gateway_go:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     si,10                 ; the count's place
        cmp     bl,0
        jne     short readn_count
        mov     si,14
readn_count:
        mov     cx,word ptr ss:[bp+si]
        cmp     word ptr ss:[bp+si+2],0
        je      short readn_count_ok
        mov     cx,READN_SIZE
readn_count_ok:
        cmp     cx,READN_SIZE
        jbe     short readn_count_max
        mov     cx,READN_SIZE
readn_count_max:
        mov     word ptr cs:message_result_len_lo,cx
        mov     word ptr cs:message_result_len_hi,0
        mov     word ptr cs:message_result_ptr_off,offset readn_buf
        mov     word ptr cs:message_result_ptr_seg,cs
        push    si
        push    di
        mov     di,offset readn_buf
        mov     bh,byte ptr cs:window_page
        push    cx
        mov     ah,03h
        int     10h                   ; DX:  the cursor (CX:  its shape)
        pop     cx
        jcxz    readn_end
readn_next:
        mov     ah,02h
        int     10h
        mov     ah,08h
        int     10h
        mov     byte ptr cs:[di],al
        inc     di
        inc     dl
        push    ax
        push    bx
        mov     ah,0Fh
        int     10h                   ; AH:  the columns
        cmp     dl,ah
        jb      short readn_same_row
        xor     dl,dl
        inc     dh
readn_same_row:
        pop     bx
        pop     ax
        loop    readn_next
        mov     ah,02h
        int     10h
readn_end:
        pop     di
        pop     si
        cmp     si,10
        je      short readn_expand
        mov     ax,word ptr cs:message_result_len_lo ; in place
        mov     word ptr ss:[bp+10],ax
        mov     word ptr ss:[bp+12],0
        mov     word ptr ss:[bp+14],offset readn_buf
        mov     word ptr ss:[bp+16],cs
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        pop     bp
        jmp     int15_handled
readn_expand:
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        jmp     message_expand4
readn_gateway_not:
        pop     ax
        pop     bp
readn_gateway_getname:
        jmp     int15_message_mailbox_getname

; GETNAME copies at most the caller's buffer size and returns that byte count
; in the original length DWORD. Names are deliberately not NUL-terminated.
int15_message_mailbox_getname:
        push    bp
        mov     bp,sp
        call    message_swap18
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        mov     cx,word ptr ss:[bp+18]
        mov     dx,word ptr ss:[bp+20]
        mov     word ptr ss:[bp+18],0
        mov     word ptr ss:[bp+20],0
        cmp     bl,0
        jne     short mailbox_getname_done
        cmp     word ptr ss:[bp+10],0
        jne     short mailbox_getname_done
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short mailbox_getname_done
        or      dx,dx
        jne     short mailbox_getname_done
        mov     ax,word ptr cs:mailbox_name_length[si]
        cmp     cx,ax
        jbe     short mailbox_getname_count_ready
        mov     cx,ax
mailbox_getname_count_ready:
        mov     word ptr ss:[bp+18],cx
        jcxz    short mailbox_getname_done
        cmp     word ptr ss:[bp+16],0
        je      short mailbox_getname_zero_result
        mov     bx,si
        push    cx
        mov     cl,4
        shl     bx,cl
        pop     cx
        add     bx,offset mailbox_names
        push    cs
        pop     ds
        mov     si,bx
        mov     ax,word ptr ss:[bp+16]
        mov     es,ax
        mov     di,word ptr ss:[bp+14]
        cld
        rep     movsb
        jmp     short mailbox_getname_done
mailbox_getname_zero_result:
        mov     word ptr ss:[bp+18],0
mailbox_getname_done:
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; READINTO copies and removes the oldest queued mailbox message. The original
; call blocks when empty; foreground API 0.x instead returns zero with Carry
; set until scheduler-backed task waits exist. A short destination truncates
; the copied record and still consumes that record.
; BH=13h:  REDRAW of a window (BL=01h:  the own one, nothing on the stack;
; BL=00h:  the window on the stack, popped), else mailbox READINTO.
int15_message_redraw_gateway:
        cmp     bl,1
        jne     short redraw_gateway_explicit
        jmp     int15_handled         ; (the own window:  the screen)
redraw_gateway_explicit:
        cmp     bl,0
        je      short redraw_gateway_handle
        jmp     int15_message_mailbox_readinto
redraw_gateway_handle:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     short redraw_gateway_mailbox
        mov     ax,word ptr ss:[bp+12]
        call    own_window
        je      short redraw_gateway_done
        call    wobj_validate
        jc      short redraw_gateway_mailbox
        test    word ptr cs:wobj_flags[si],WF_VISIBLE
        jz      short redraw_gateway_done
        call    wobj_redraw
redraw_gateway_done:
        pop     si
        pop     ax
        call    message_shift4
        pop     bp
        add     sp,4
        jmp     int15_handled
redraw_gateway_mailbox:
        pop     si
        pop     ax
        pop     bp
int15_message_mailbox_readinto:
        push    bp
        mov     bp,sp
        call    message_swap18
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        mov     cx,word ptr ss:[bp+18]
        mov     dx,word ptr ss:[bp+20]
        mov     word ptr ss:[bp+18],0
        mov     word ptr ss:[bp+20],0
        or      word ptr ss:[bp+8],1
        cmp     bl,0
        je      short mailbox_readinto_selector_ok
        jmp     mailbox_readinto_done
mailbox_readinto_selector_ok:
        cmp     word ptr ss:[bp+10],0
        je      short mailbox_readinto_handle_offset_ok
        jmp     mailbox_readinto_done
mailbox_readinto_handle_offset_ok:
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jnc     short mailbox_readinto_handle_ok
        jmp     mailbox_readinto_done
mailbox_readinto_handle_ok:
        cmp     word ptr cs:mailbox_open[si],1
        je      short mailbox_readinto_open
        jmp     mailbox_readinto_done
mailbox_readinto_open:
        cmp     word ptr cs:mailbox_count[si],0
        jne     short mailbox_readinto_available
        call    mailbox_wait
        jnc     mailbox_readinto_open
        jmp     mailbox_readinto_done
mailbox_readinto_available:
        or      dx,dx
        je      short mailbox_readinto_size_high_ok
        jmp     mailbox_readinto_done
mailbox_readinto_size_high_ok:
        mov     ax,cx
        or      ax,ax
        jnz     short mailbox_readinto_capacity_ok
        jmp     mailbox_readinto_done
mailbox_readinto_capacity_ok:
        cmp     word ptr ss:[bp+16],0
        jne     short mailbox_readinto_destination_ok
        jmp     mailbox_readinto_done
mailbox_readinto_destination_ok:
        mov     dx,si                 ; retain mailbox table word index
        mov     bx,si
        shl     bx,1
        add     bx,word ptr cs:mailbox_head[si]
        mov     di,bx
        shl     di,1
        mov     cx,word ptr cs:mailbox_message_length[di]
        cmp     cx,ax
        jbe     short mailbox_readinto_size_ready
        mov     cx,ax
mailbox_readinto_size_ready:
        mov     word ptr ss:[bp+18],cx
        cmp     byte ptr cs:mailbox_message_reference[bx],0
        jne     short mailbox_readinto_reference_source
        mov     si,bx
        push    cx
        mov     cl,7
        shl     si,cl
        pop     cx
        add     si,offset mailbox_message_data
        push    cs
        pop     ds
        jmp     short mailbox_readinto_source_ready
mailbox_readinto_reference_source:
        mov     di,bx
        shl     di,1
        mov     si,word ptr cs:mailbox_message_pointer_off[di]
        mov     ds,word ptr cs:mailbox_message_pointer_seg[di]
mailbox_readinto_source_ready:
        mov     ax,word ptr ss:[bp+16]
        mov     es,ax
        mov     di,word ptr ss:[bp+14]
        cld
        rep     movsb
        mov     si,dx
        mov     di,bx
        shl     di,1
        mov     ax,word ptr cs:mailbox_message_sender[di]
        mov     word ptr cs:mailbox_sender[si],ax
        mov     ax,word ptr cs:mailbox_message_length[di]
        sub     word ptr cs:mailbox_bytes[si],ax
        xor     ax,ax
        mov     al,byte ptr cs:mailbox_message_status[bx]
        mov     word ptr cs:mailbox_status[si],ax
        dec     word ptr cs:mailbox_count[si]
        cmp     word ptr cs:mailbox_noted[si],0
        je      short $+7
        dec     word ptr cs:mailbox_noted[si]
        inc     word ptr cs:mailbox_head[si]
        cmp     word ptr cs:mailbox_head[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_readinto_head_ready
        mov     word ptr cs:mailbox_head[si],0
mailbox_readinto_head_ready:
        and     word ptr ss:[bp+8],0FFFEh
mailbox_readinto_done:
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        call    message_shift8
        pop     bp
        add     sp,8
        jmp     int15_handled

; SETFLAGS retains the supported TopView mailbox-control bits: place messages
; in common memory (advisory in this resident pool), allow writes while closed,
; and preserve queued messages across CLOSE. DV/X stream/EMS flags are masked.
int15_message_mailbox_setflags:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        cmp     bl,0
        jne     short mailbox_setflags_done
        cmp     word ptr ss:[bp+10],0
        jne     short mailbox_setflags_done
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short mailbox_setflags_done
        cmp     word ptr ss:[bp+16],0
        jne     short mailbox_setflags_done
        mov     ax,word ptr ss:[bp+14]
        and     ax,0007h
        mov     word ptr cs:mailbox_flags[si],ax
mailbox_setflags_done:
        pop     si
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
        mov     byte ptr cs:alloc_tag,1 ; (the pool is the task's own)
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
        mov     byte ptr cs:alloc_tag,1 ; (common memory:  nobody's)
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
        mov     al,cs:alloc_tag       ; owner tag (1:  nobody's)
        mov     byte ptr cs:[si],al
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

; Switch from the caller's stack to a bounded resident stack owned by the
; foreground task. The INT frame is rebuilt on the new stack so IRET resumes
; immediately after the OSTACK call. The public contract forbids nesting;
; a repeated OSTACK is therefore left as a safe no-op.
int15_ostack:
        cmp     byte ptr cs:task_stack_active,0
        jne     int15_handled
        mov     word ptr cs:task_stack_saved_ax,ax
        mov     word ptr cs:task_stack_saved_bp,bp
        mov     ax,ss
        mov     word ptr cs:task_stack_user_ss,ax
        mov     word ptr cs:task_stack_user_sp,sp
        add     word ptr cs:task_stack_user_sp,8
        mov     bp,sp
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr cs:task_stack_return_ip,ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr cs:task_stack_return_cs,ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr cs:task_stack_return_flags,ax
        mov     byte ptr cs:task_stack_active,1
        cli
        mov     ax,cs
        mov     ss,ax
        mov     sp,offset task_internal_stack_top
        mov     ax,word ptr cs:task_stack_return_flags
        push    ax
        mov     ax,word ptr cs:task_stack_return_cs
        push    ax
        mov     ax,word ptr cs:task_stack_return_ip
        push    ax
        mov     bp,word ptr cs:task_stack_saved_bp
        mov     ax,word ptr cs:task_stack_saved_ax
        iret

; A call (AH=12h) begins:  its critical section (BEGINC of the core), and
; the task's API stack, as DESQview's calls run on its own stacks:  the
; caller's then holds only the interrupt frame (a DV C library subtask's
; is 256 bytes).  The handler's flags, the interrupt frame and the
; arguments (API_COPY bytes) are copied there; api_leave copies back what
; is left of them, with what the call pushed or popped, as the caller's.
api_enter:
        mov     byte ptr cs:api_crit,1
        pop     word ptr cs:api_ret
        mov     word ptr cs:api_ax,ax
        cmp     byte ptr cs:core_running,0 ; (alone:  INT 15h is ours)
        je      short api_enter_alone
        mov     ax,101Bh              ; BEGINC (the core)
        int     15h
api_enter_alone:
        mov     word ptr cs:api_cx,cx
        mov     word ptr cs:api_si,si
        mov     word ptr cs:api_di,di
        mov     word ptr cs:api_ds,ds
        mov     word ptr cs:api_es,es
        mov     ax,ss
        mov     word ptr cs:api_user_ss,ax
        mov     word ptr cs:api_user_sp,sp
        mov     ds,ax
        mov     si,sp
        push    cs
        pop     es
        mov     di,offset api_stack_top - API_COPY
        mov     cx,API_COPY / 2
        cld
        rep     movsw
        mov     ax,cs
        cli
        mov     ss,ax
        mov     sp,offset api_stack_top - API_COPY
        sti
        mov     ax,word ptr cs:api_ax
        mov     cx,word ptr cs:api_cx
        mov     si,word ptr cs:api_si
        mov     di,word ptr cs:api_di
        mov     ds,word ptr cs:api_ds
        mov     es,word ptr cs:api_es
        jmp     word ptr cs:api_ret

; The end of a call (int15_handled, int15_chain):  back on the caller's
; stack with what is left of the copied frame and arguments (the API
; stack's top less API_COPY was the caller's SP), then ENDC.  Registers
; and flags kept.
api_leave:
        cmp     byte ptr cs:api_crit,0
        je      api_leave_ret
        cmp     word ptr cs:api_nest,0 ; a nested INT 15h's end
        je      short api_leave_call
        dec     word ptr cs:api_nest
        ret
api_leave_call:
        pop     word ptr cs:api_ret
        pushf
        pop     word ptr cs:api_flags
        mov     word ptr cs:api_ax,ax
        mov     word ptr cs:api_cx,cx
        mov     word ptr cs:api_si,si
        mov     word ptr cs:api_di,di
        mov     word ptr cs:api_ds,ds
        mov     word ptr cs:api_es,es
        mov     si,sp                 ; what is left:  SP .. the top
        mov     cx,offset api_stack_top
        sub     cx,si
        mov     di,word ptr cs:api_user_sp ; the caller's SP for it
        add     di,si
        sub     di,offset api_stack_top - API_COPY
        mov     word ptr cs:api_user_sp,di
        mov     es,word ptr cs:api_user_ss
        push    cs
        pop     ds
        cld
        cli
        rep     movsb
        mov     ss,word ptr cs:api_user_ss
        mov     sp,word ptr cs:api_user_sp
        sti
        mov     byte ptr cs:api_crit,0
        cmp     byte ptr cs:core_running,0
        je      short api_leave_alone
        mov     ax,101Ch              ; ENDC
        int     15h
api_leave_alone:
        mov     ax,word ptr cs:api_ax
        mov     cx,word ptr cs:api_cx
        mov     si,word ptr cs:api_si
        mov     di,word ptr cs:api_di
        mov     ds,word ptr cs:api_ds
        mov     es,word ptr cs:api_es
        push    word ptr cs:api_flags
        popf
        jmp     word ptr cs:api_ret
api_leave_ret:
        ret

; APP_START (AX=102Ch):  ES:DI the DVP, BX its size.  The host (task 0)
; starts its program as a new task (MAXVIEW, MVRUN:  mvhost_appstart), we
; wait for it (10 s at most, one request at a time):  BX = the new task's
; handle, 0 if none (also without the core).  Only BX changes, as in DV.
int15_app_start:
        push    ax
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        xor     dx,dx                 ; (the answer)
        cmp     byte ptr cs:core_running,0
        je      app_start_done
app_start_free:
        cli
        cmp     byte ptr cs:appreq_state,0
        je      short app_start_take
        sti
        call    api_pause             ; another task's request first
        jmp     short app_start_free
app_start_take:
        mov     byte ptr cs:appreq_state,3
        sti
        cld
        mov     cx,bx
        cmp     cx,APPREQ_MAX
        jbe     short app_start_size
        mov     cx,APPREQ_MAX
app_start_size:
        mov     word ptr cs:appreq_size,cx
        push    es
        pop     ds
        mov     si,di
        push    cs
        pop     es
        mov     di,offset appreq_dvp
        rep     movsb
        mov     ax,word ptr cs:task_handle_segment
        sub     ax,word ptr cs:task_objects_base
        shr     ax,1
        mov     byte ptr cs:appreq_from,al
        mov     word ptr cs:appreq_task,0
        mov     byte ptr cs:appreq_state,1
        mov     ax,40h
        mov     ds,ax
        mov     cx,word ptr ds:[6Ch]
app_start_wait:
        call    api_pause
        cmp     byte ptr cs:appreq_state,2
        je      short app_start_answer
        mov     ax,word ptr ds:[6Ch]
        sub     ax,cx
        cmp     ax,182
        jb      short app_start_wait
        cli                           ; no host answers:  taken back
        cmp     byte ptr cs:appreq_state,2
        je      short app_start_answer
        mov     byte ptr cs:appreq_state,0
        sti
        jmp     short app_start_done
app_start_answer:
        sti
        mov     ax,word ptr cs:appreq_task
        mov     byte ptr cs:appreq_state,0
        or      ax,ax
        jz      short app_start_done
        cmp     ax,TASK_OBJECT_COUNT
        jae     short app_start_done
        push    ax
        call    task_bit              ; its handle valid from now on
        or      word ptr cs:task_live[si],dx
        pop     ax
        shl     ax,1                  ; (TASK_OBJECT_SIZE / 16)
        add     ax,word ptr cs:task_objects_base
        mov     dx,ax
app_start_done:
        mov     bx,dx
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     ax
        jmp     int15_handled

; PAUSE inside a call:  its critical section open meanwhile, so the other
; tasks run (AX:  1000h after it, as the PAUSE left it).
api_pause:
        cmp     byte ptr cs:core_running,0 ; (alone:  INT 15h is ours, and
        je      short api_pause_alone ; no other task)
        cmp     byte ptr cs:api_crit,0
        je      short api_pause_plain
        mov     ax,101Ch
        int     15h
        mov     ax,1000h
        int     15h
        mov     ax,101Bh
        int     15h
        mov     ax,1000h
        ret
api_pause_plain:
        mov     ax,1000h
        int     15h
        ret
api_pause_alone:
        mov     ax,1000h
        ret

; Rebuild the USTACK return frame on the original user stack. Calls without a
; preceding OSTACK are outside the public contract and remain safe no-ops.
int15_ustack:
        cmp     byte ptr cs:task_stack_active,1
        jne     int15_handled
        mov     word ptr cs:task_stack_saved_ax,ax
        mov     word ptr cs:task_stack_saved_bp,bp
        mov     bp,sp
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr cs:task_stack_return_ip,ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr cs:task_stack_return_cs,ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr cs:task_stack_return_flags,ax
        mov     byte ptr cs:task_stack_active,0
        cli
        mov     ax,word ptr cs:task_stack_user_ss
        mov     ss,ax
        mov     sp,word ptr cs:task_stack_user_sp
        mov     ax,word ptr cs:task_stack_return_flags
        push    ax
        mov     ax,word ptr cs:task_stack_return_cs
        push    ax
        mov     ax,word ptr cs:task_stack_return_ip
        push    ax
        mov     bp,word ptr cs:task_stack_saved_bp
        mov     ax,word ptr cs:task_stack_saved_ax
        iret

int15_handled:
        call    api_leave
        cmp     byte ptr cs:message_bl,0 ; (BL as the caller passed it)
        je      short int15_handled_bl
        mov     bl,byte ptr cs:message_bl
        mov     byte ptr cs:message_bl,0
int15_handled_bl:
        popf
        iret
int15_chain:
        call    api_leave
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

pointer_validate:
        push    cx
        xor     si,si
        mov     cx,POINTER_SLOT_COUNT
pointer_validate_scan:
        cmp     ax,word ptr cs:pointer_handle_segments[si]
        jne     short pointer_validate_next
        cmp     word ptr cs:pointer_used[si],1
        jne     short pointer_validate_invalid
        clc
        jmp     short pointer_validate_done
pointer_validate_next:
        add     si,2
        loop    pointer_validate_scan
pointer_validate_invalid:
        stc
pointer_validate_done:
        pop     cx
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

; Clear queue metadata for mailbox table word index SI.  Payload bytes need
; not be scrubbed because no public pointer exposes resident queue storage.
mailbox_clear_queue:
        mov     word ptr cs:mailbox_count[si],0
        mov     word ptr cs:mailbox_noted[si],0
        mov     word ptr cs:mailbox_head[si],0
        mov     word ptr cs:mailbox_tail[si],0
        mov     word ptr cs:mailbox_bytes[si],0
        ret

; Copy an ADDTO-by-value message into the mailbox selected by SI. BP is the
; outer message frame.  Carry is returned through the caller's saved FLAGS.
mailbox_add_value:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        or      word ptr ss:[bp+8],1
        cmp     word ptr cs:mailbox_open[si],1
        je      short mailbox_add_value_open
        test    word ptr cs:mailbox_flags[si],0002h
        jnz     short mailbox_add_value_open
        jmp     mailbox_add_value_done
mailbox_add_value_open:
        cmp     word ptr cs:mailbox_count[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_add_value_room
        jmp     mailbox_add_value_done
mailbox_add_value_room:
        cmp     word ptr ss:[bp+20],0
        jne     mailbox_add_value_done
        mov     cx,word ptr ss:[bp+18]
        cmp     cx,MAILBOX_MESSAGE_SIZE
        ja      mailbox_add_value_done
        jcxz    short mailbox_add_pointer_ok
        cmp     word ptr ss:[bp+16],0
        je      short mailbox_add_value_done
mailbox_add_pointer_ok:
        mov     dx,si                 ; retain mailbox table word index
        mov     bx,si
        shl     bx,1                  ; four entries per mailbox
        add     bx,word ptr cs:mailbox_tail[si]
        mov     byte ptr cs:mailbox_message_reference[bx],0
        mov     al,byte ptr ss:[bp+22]
        mov     byte ptr cs:mailbox_message_status[bx],al
        mov     di,bx
        shl     di,1
        mov     word ptr cs:mailbox_message_length[di],cx
        mov     ax,word ptr cs:task_handle_segment
        mov     word ptr cs:mailbox_message_sender[di],ax
        add     word ptr cs:mailbox_bytes[si],cx
        inc     word ptr cs:mailbox_count[si]
        inc     word ptr cs:mailbox_tail[si]
        cmp     word ptr cs:mailbox_tail[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_add_tail_ready
        mov     word ptr cs:mailbox_tail[si],0
mailbox_add_tail_ready:
        mov     di,bx
        push    cx
        mov     cl,7
        shl     di,cl
        pop     cx
        add     di,offset mailbox_message_data
        mov     ax,word ptr ss:[bp+16]
        mov     ds,ax
        mov     si,word ptr ss:[bp+14]
        push    cs
        pop     es
        cld
        rep     movsb
        mov     si,dx
        and     word ptr ss:[bp+8],0FFFEh
mailbox_add_value_done:
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; Copy a WRITE message into mailbox SI. WRITE omits the status DWORD used by
; ADDTO and stores status zero. BP is the outer message frame.
mailbox_write_value:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        or      word ptr ss:[bp+8],1
        cmp     word ptr cs:mailbox_open[si],1
        je      short mailbox_write_value_open
        test    word ptr cs:mailbox_flags[si],0002h
        jnz     short mailbox_write_value_open
        jmp     mailbox_write_value_done
mailbox_write_value_open:
        cmp     word ptr cs:mailbox_count[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_write_value_room
        jmp     mailbox_write_value_done
mailbox_write_value_room:
        cmp     word ptr ss:[bp+20],0
        jne     mailbox_write_value_done
        mov     cx,word ptr ss:[bp+18]
        cmp     cx,MAILBOX_MESSAGE_SIZE
        ja      short mailbox_write_value_done
        jcxz    short mailbox_write_pointer_ok
        cmp     word ptr ss:[bp+16],0
        je      short mailbox_write_value_done
mailbox_write_pointer_ok:
        mov     dx,si
        mov     bx,si
        shl     bx,1
        add     bx,word ptr cs:mailbox_tail[si]
        mov     byte ptr cs:mailbox_message_reference[bx],0
        mov     byte ptr cs:mailbox_message_status[bx],0
        mov     di,bx
        shl     di,1
        mov     word ptr cs:mailbox_message_length[di],cx
        mov     ax,word ptr cs:task_handle_segment
        mov     word ptr cs:mailbox_message_sender[di],ax
        add     word ptr cs:mailbox_bytes[si],cx
        inc     word ptr cs:mailbox_count[si]
        inc     word ptr cs:mailbox_tail[si]
        cmp     word ptr cs:mailbox_tail[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_write_tail_ready
        mov     word ptr cs:mailbox_tail[si],0
mailbox_write_tail_ready:
        mov     di,bx
        push    cx
        mov     cl,7
        shl     di,cl
        pop     cx
        add     di,offset mailbox_message_data
        mov     ax,word ptr ss:[bp+16]
        mov     ds,ax
        mov     si,word ptr ss:[bp+14]
        push    cs
        pop     es
        cld
        rep     movsb
        mov     si,dx
        and     word ptr ss:[bp+8],0FFFEh
mailbox_write_value_done:
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; Queue a SUBFROM-by-reference record for mailbox table index SI. The caller
; stack has the same status/length/address/handle layout as ADDTO.
mailbox_add_reference:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        or      word ptr ss:[bp+8],1
        cmp     word ptr cs:mailbox_open[si],1
        je      short mailbox_add_reference_open
        test    word ptr cs:mailbox_flags[si],0002h
        jnz     short mailbox_add_reference_open
        jmp     mailbox_add_reference_done
mailbox_add_reference_open:
        cmp     word ptr cs:mailbox_count[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_add_reference_room
        jmp     mailbox_add_reference_done
mailbox_add_reference_room:
        cmp     word ptr ss:[bp+20],0
        jne     short mailbox_add_reference_done
        mov     cx,word ptr ss:[bp+18]    ; (any length:  not copied; the
        jcxz    short mailbox_add_reference_pointer_ok ; DV C library's
        ; tsk_new hands a subtask its stack so)
        cmp     word ptr ss:[bp+16],0
        je      short mailbox_add_reference_done
mailbox_add_reference_pointer_ok:
        mov     dx,si
        mov     bx,si
        shl     bx,1
        add     bx,word ptr cs:mailbox_tail[si]
        mov     byte ptr cs:mailbox_message_reference[bx],1
        mov     al,byte ptr ss:[bp+22]
        mov     byte ptr cs:mailbox_message_status[bx],al
        mov     di,bx
        shl     di,1
        mov     word ptr cs:mailbox_message_length[di],cx
        mov     ax,word ptr cs:task_handle_segment
        mov     word ptr cs:mailbox_message_sender[di],ax
        mov     ax,word ptr ss:[bp+14]
        mov     word ptr cs:mailbox_message_pointer_off[di],ax
        mov     ax,word ptr ss:[bp+16]
        mov     word ptr cs:mailbox_message_pointer_seg[di],ax
        add     word ptr cs:mailbox_bytes[si],cx
        inc     word ptr cs:mailbox_count[si]
        inc     word ptr cs:mailbox_tail[si]
        cmp     word ptr cs:mailbox_tail[si],MAILBOX_QUEUE_DEPTH
        jb      short mailbox_add_reference_tail_ready
        mov     word ptr cs:mailbox_tail[si],0
mailbox_add_reference_tail_ready:
        mov     si,dx
        and     word ptr ss:[bp+8],0FFFEh
mailbox_add_reference_done:
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
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

; Expand an explicit handle DWORD into two result DWORDs. The mailbox READ
; handler has already restored every public register and staged its length and
; pointer below. Software INT keeps hardware interrupts disabled while this
; small resident scratch frame is rewritten.
message_expand4:
        mov     word ptr cs:message_saved_ax,ax
        mov     ax,word ptr ss:[bp]
        mov     word ptr cs:message_saved_bp,ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp-2],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+2],ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+4],ax
        mov     ax,word ptr cs:message_result_len_lo
        mov     word ptr ss:[bp+6],ax
        mov     ax,word ptr cs:message_result_len_hi
        mov     word ptr ss:[bp+8],ax
        mov     ax,word ptr cs:message_result_ptr_off
        mov     word ptr ss:[bp+10],ax
        mov     ax,word ptr cs:message_result_ptr_seg
        mov     word ptr ss:[bp+12],ax
        mov     sp,bp
        sub     sp,2
        mov     bp,word ptr cs:message_saved_bp
        mov     ax,word ptr cs:message_saved_ax
        jmp     int15_handled

; Push one result DWORD (message_result_ptr) for a message that takes no
; handle on the stack (NEW, HANDLE of a default object), as DESQview does:
; the frame moves down four bytes and the DWORD lands where the caller's
; stack top was.  BP as at the handler's entry (its saved BP at [BP]), the
; handler's other registers already restored.
message_push4:
        mov     word ptr cs:message_saved_ax,ax
        mov     ax,word ptr ss:[bp]
        mov     word ptr cs:message_saved_bp,ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp-2],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+2],ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+4],ax
        mov     ax,word ptr cs:message_result_ptr_off
        mov     word ptr ss:[bp+6],ax
        mov     ax,word ptr cs:message_result_ptr_seg
        mov     word ptr ss:[bp+8],ax
        mov     sp,bp
        sub     sp,2
        mov     bp,word ptr cs:message_saved_bp
        mov     ax,word ptr cs:message_saved_ax
        jmp     int15_handled

; BL = 03h, the current task's mailbox, for a mailbox message:  its handle
; goes on the caller's stack as if the caller had pushed it, with BL = 00h,
; and the message takes it as any (BL is 03h again at the return).  HANDLE,
; NEW, FREE and the messages without a mailbox meaning go on unchanged, as
; when there is no mailbox for the task (the pool is full).
message_default_mailbox:
        call    mailbox_message
        jc      short message_default_go
        push    ax
        push    si
        call    task_mailbox
        jc      short message_default_none
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        pop     si
        mov     byte ptr cs:message_bl,3
; AX = the handle to put on the caller's stack (the caller's AX pushed,
; message_bl set):  as if the caller had pushed it; BL = 00h.
message_insert:
        push    bp
        mov     bp,sp                 ; BP, AX, PUSHF, IP, CS, FLAGS
        sub     sp,4
        push    si
        mov     si,word ptr ss:[bp]
        mov     word ptr ss:[bp-4],si
        mov     si,word ptr ss:[bp+2]
        mov     word ptr ss:[bp-2],si
        mov     si,word ptr ss:[bp+4]
        mov     word ptr ss:[bp],si
        mov     si,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+2],si
        mov     si,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+4],si
        mov     si,word ptr ss:[bp+10]
        mov     word ptr ss:[bp+6],si
        mov     word ptr ss:[bp+8],0  ; the handle, where the caller's
        mov     word ptr ss:[bp+10],ax ; stack top was
        pop     si
        pop     bp
        pop     ax
        xor     bl,bl
        jmp     message_dispatch_go
message_default_none:
        pop     si
        pop     ax
message_default_go:
        jmp     message_dispatch_go

; A task of the multitasking core new to MAXVTSR (its state block starts
; with no task handle):  its object is that of its number (APPNUM, which the
; core answers).  Task 0's in the meantime, so the APPNUM call itself finds
; one.
task_handle_init:
        push    ax
        push    dx
        push    si
        mov     ax,word ptr cs:task_objects_base
        mov     word ptr cs:task_handle_segment,ax
        mov     ax,0DE07h
        int     15h
        cmp     ax,TASK_OBJECT_COUNT
        jb      short task_handle_number
        xor     ax,ax
task_handle_number:
        call    task_bit
        or      word ptr cs:task_live[si],dx
        pop     si
        pop     dx
        shl     ax,1                  ; (TASK_OBJECT_SIZE / 16)
        add     ax,word ptr cs:task_objects_base
        mov     word ptr cs:task_handle_segment,ax
        pop     ax
        ret

; SI:DX = the word and bit of task AX (0 .. 31) in task_live.
task_bit:
        push    cx
        mov     cx,ax
        mov     si,ax
        shr     si,1
        shr     si,1
        shr     si,1
        and     si,0FFFEh
        and     cl,0Fh
        mov     dx,1
        shl     dx,cl
        pop     cx
        ret

; AX a task handle (segment) of a live task (since its first INT 15h until
; its end, D708h):  CF clear, AX = its tag (number + 1, as caller_tag);
; else CF set, AX kept.
task_validate:
        push    dx
        mov     dx,ax
        sub     dx,word ptr cs:task_objects_base
        jb      short task_validate_no
        test    dx,1
        jnz     short task_validate_no
        shr     dx,1
        cmp     dx,TASK_OBJECT_COUNT
        jae     short task_validate_no
        push    ax
        push    si
        mov     ax,dx
        push    dx
        call    task_bit
        test    word ptr cs:task_live[si],dx
        pop     dx
        pop     si
        pop     ax
        jz      short task_validate_no
        inc     dx
        mov     ax,dx
        pop     dx
        clc
        ret
task_validate_no:
        pop     dx
        stc
        ret

; CF clear:  BH is a message with a mailbox meaning (HANDLE, NEW and FREE
; are not:  they read BL themselves).
mailbox_message:
        cmp     bh,3
        jb      short mailbox_message_no
        cmp     bh,6
        je      short mailbox_message_no
        cmp     bh,7
        je      short mailbox_message_no
        cmp     bh,10h
        je      short mailbox_message_no
        cmp     bh,16h
        ja      short mailbox_message_no
        clc
        ret
mailbox_message_no:
        stc
        ret

; BL = 02h, the own mailbox of the task whose handle is on the stack:  the
; handle is replaced by that mailbox's and BL = 00h (03h again at the
; return), as message_default_mailbox.
message_task_mailbox:
        call    mailbox_message
        jc      short message_task_go
        push    bp
        mov     bp,sp                 ; BP, PUSHF, IP, CS, FLAGS, handle
        push    ax
        push    si
        cmp     word ptr ss:[bp+10],0
        jne     short message_task_none
        mov     ax,word ptr ss:[bp+12]
        call    task_validate
        jc      short message_task_none
        call    task_mailbox_of
        jc      short message_task_none
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        mov     word ptr ss:[bp+12],ax
        xor     bl,bl
        mov     byte ptr cs:message_bl,2
message_task_none:
        pop     si
        pop     ax
        pop     bp
message_task_go:
        jmp     message_dispatch_go

; AX a keyboard handle of any task:  CF clear (AX kept), else CF set.
keyboard_validate:
        push    dx
        mov     dx,ax
        sub     dx,word ptr cs:keyboard_objects_base
        jb      short keyboard_validate_no
        test    dx,1
        jnz     short keyboard_validate_no
        shr     dx,1
        cmp     dx,TASK_OBJECT_COUNT
        jae     short keyboard_validate_no
        push    ax
        push    si
        mov     ax,dx
        call    task_bit
        test    word ptr cs:task_live[si],dx
        pop     si
        pop     ax
        jz      short keyboard_validate_no
        pop     dx
        clc
        ret
keyboard_validate_no:
        pop     dx
        stc
        ret

; AX an OBJECTQ handle of a live task:  CF clear, AX = its tag; else CF.
objectq_validate:
        push    ax
        dec     ax
        call    keyboard_validate
        jc      short objectq_validate_no
        sub     ax,word ptr cs:keyboard_objects_base
        shr     ax,1
        inc     ax
        add     sp,2
        clc
        ret
objectq_validate_no:
        pop     ax
        stc
        ret

; READ of the task's OBJECTQ (BL=07h, 06h with the own task handle, 00h with
; its OBJECTQ handle):  waits for an object of the task with input and gives
; its handle (pushed for 07h, in place of the stacked one else), as
; DESQview 2.80:  a timer of the task that expired, a mailbox of the task
; with a message not given yet, the task's keyboard with a key; each
; expiry and message once.  PAUSE while waiting.
int15_message_objectq_read:
        push    bp
        mov     bp,sp
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
objectq_read_wait:
        call    caller_tag
        xor     ah,ah
        mov     dx,ax                 ; DX = the tag
        xor     si,si
        mov     cx,TIMER_SLOT_COUNT
objectq_read_timer:
        cmp     word ptr cs:timer_used[si],0
        je      short objectq_read_timer_next
        cmp     word ptr cs:timer_owner[si],dx
        jne     short objectq_read_timer_next
        cmp     word ptr cs:timer_noted[si],0
        jne     short objectq_read_timer_next
        push    dx
        call    timer_elapsed         ; (expired:  state 2)
        pop     dx
        cmp     word ptr cs:timer_state[si],2
        jne     short objectq_read_timer_next
        mov     word ptr cs:timer_noted[si],1
        mov     ax,word ptr cs:timer_handle_segments[si]
        jmp     objectq_read_found
objectq_read_timer_next:
        add     si,2
        loop    objectq_read_timer
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
objectq_read_mailbox:
        cmp     word ptr cs:mailbox_used[si],0
        je      short objectq_read_mailbox_next
        cmp     word ptr cs:mailbox_owner[si],dx
        jne     short objectq_read_mailbox_next
        mov     ax,word ptr cs:mailbox_noted[si]
        cmp     ax,word ptr cs:mailbox_count[si]
        jae     short objectq_read_mailbox_next
        inc     word ptr cs:mailbox_noted[si]
        mov     ax,word ptr cs:mailbox_handle_segments[si]
        jmp     short objectq_read_found
objectq_read_mailbox_next:
        add     si,2
        loop    objectq_read_mailbox
        call    pointer_poll          ; a pointer with a message
        xor     si,si
        mov     cx,POINTER_SLOT_COUNT
objectq_read_pointer:
        cmp     word ptr cs:pointer_used[si],0
        je      short objectq_read_pointer_next
        cmp     word ptr cs:pointer_owner[si],dx
        jne     short objectq_read_pointer_next
        cmp     word ptr cs:pointer_count[si],0
        je      short objectq_read_pointer_next
        cmp     word ptr cs:pointer_noted[si],0
        jne     short objectq_read_pointer_next
        mov     word ptr cs:pointer_noted[si],1
        mov     ax,word ptr cs:pointer_handle_segments[si]
        jmp     objectq_read_found
objectq_read_pointer_next:
        add     si,2
        loop    objectq_read_pointer
        mov     ah,1                  ; a key:  for the keyboard object
        int     16h                   ; of the task's window on top (else
        jz      short objectq_read_pause ; one opened to a window object),
        call    kobj_focus            ; else the task's keyboard
        jnc     short objectq_read_found
        mov     ax,dx
        call    keyboard_of
        jmp     short objectq_read_found
objectq_read_pause:
        sti
        call    api_pause
        cli
        jmp     objectq_read_wait
objectq_read_found:
        mov     word ptr cs:message_result_ptr_off,0
        mov     word ptr cs:message_result_ptr_seg,ax
        pop     si
        pop     dx
        pop     cx
        pop     bx
        cmp     bl,7
        jne     short objectq_read_replace
        pop     ax
        jmp     message_push4
objectq_read_replace:
        mov     word ptr ss:[bp+10],0
        mov     word ptr ss:[bp+12],ax
        pop     ax
        pop     bp
        jmp     int15_handled

; AX = the keyboard of the task with tag AX (task_validate's).
keyboard_of:
        dec     ax
        shl     ax,1
        add     ax,word ptr cs:keyboard_objects_base
        ret

; CF clear:  BH is a message with a keyboard meaning here (READ, STATUS,
; ADDTO, SUBFROM).
keyboard_message:
        cmp     bh,04h
        je      short keyboard_message_yes
        cmp     bh,0Ah                ; ADDTO, SUBFROM:  its bits
        je      short keyboard_message_yes
        cmp     bh,0Bh
        je      short keyboard_message_yes
        cmp     bh,0Fh
        je      short keyboard_message_yes
        stc
        ret
keyboard_message_yes:
        clc
        ret

; BL = 05h, the current task's keyboard:  its handle goes on the stack as
; for BL = 03h (message_insert); BL = 04h:  the task handle on the stack is
; replaced by that task's keyboard.
message_default_keyboard:
        call    keyboard_message
        jc      short message_keyboard_go
        push    ax
        mov     ax,word ptr cs:task_handle_segment
        call    task_validate
        jc      short message_keyboard_none
        call    keyboard_of
        mov     byte ptr cs:message_bl,5
        jmp     message_insert
message_keyboard_none:
        pop     ax
message_keyboard_go:
        jmp     message_dispatch_go
message_task_keyboard:
        call    keyboard_message
        jc      short message_keyboard_go
        push    bp
        mov     bp,sp
        push    ax
        cmp     word ptr ss:[bp+10],0
        jne     short message_task_keyboard_none
        mov     ax,word ptr ss:[bp+12]
        call    task_validate
        jc      short message_task_keyboard_none
        call    keyboard_of
        mov     word ptr ss:[bp+12],ax
        xor     bl,bl
        mov     byte ptr cs:message_bl,4
message_task_keyboard_none:
        pop     ax
        pop     bp
        jmp     message_dispatch_go

; READ of a keyboard (keystroke mode, as DESQview):  waits for a key (with
; PAUSE while the multitasking core runs) and leaves length 1 on top of the
; address of its character; a zero character's scan code is STATUS's.
; READ of pointer SI:  waits (PAUSE) for its message and gives it,
; DESQview's (RBIL table 00437):  word row, word column, byte status (01h
; left / 02h right button, 80h pressed / 40h released in press-release
; mode), with API level 2.00 on the byte field under it (6 bytes, else 5).
int15_message_pointer_read:
        push    bp
        mov     bp,sp
        push    ax
        push    dx
        push    si
        mov     ax,word ptr ss:[bp+12]
        call    pointer_validate
pointer_read_wait:
        cmp     word ptr cs:pointer_count[si],0
        jne     short pointer_read_got
        call    pointer_poll
        cmp     word ptr cs:pointer_count[si],0
        jne     short pointer_read_got
        sti
        call    api_pause
        cli
        jmp     short pointer_read_wait
pointer_read_got:
        mov     word ptr cs:pointer_count[si],0
        mov     word ptr cs:pointer_noted[si],0
        mov     ax,5
        cmp     word ptr cs:api_level,0200h
        jb      short pointer_read_len
        inc     ax
pointer_read_len:
        mov     word ptr cs:message_result_len_lo,ax
        mov     word ptr cs:message_result_len_hi,0
        mov     word ptr cs:message_result_ptr_off,10h
        mov     ax,word ptr cs:pointer_handle_segments[si]
        mov     word ptr cs:message_result_ptr_seg,ax
        pop     si
        pop     dx
        pop     ax
        jmp     message_expand4

; The mouse (INT 33h) for the calling task's first open pointer without a
; waiting message, if the task is in the foreground (D70Ah):  a press
; (AX=05h, left before right), with bit 2 a release (AX=06h), without bit
; 0 a move to another cell (AX=03h) become its message.  Cells are pixels
; / 8; the window is the screen.
; CF clear:  a mouse driver (INT 33h not null and not the BIOS's IRET).
mouse_driver:
        push    ax
        push    bx
        push    es
        xor     ax,ax
        mov     es,ax
        les     bx,dword ptr es:[33h*4]
        mov     ax,es
        or      ax,bx
        jz      short mouse_driver_no
        cmp     byte ptr es:[bx],0CFh
        je      short mouse_driver_no
        clc
        jmp     short mouse_driver_ret
mouse_driver_no:
        stc
mouse_driver_ret:
        pop     es
        pop     bx
        pop     ax
        ret

; WRITE (BL=00h) to a pointer object:  its handle, the column, the row
; (DWORDs, top first):  the mouse pointer there, relative to the window it
; is opened to (a window object's contents; else the screen); 12 bytes
; popped.
int15_message_pointer_write:
        push    bp
        mov     bp,sp
        push    ax
        push    cx
        push    dx
        push    si
        call    mouse_driver
        jc      short pointer_write_done
        mov     ax,word ptr ss:[bp+12]
        call    pointer_validate
        jc      short pointer_write_done
        mov     cx,word ptr ss:[bp+14] ; column, row
        mov     dx,word ptr ss:[bp+18]
        mov     si,word ptr cs:pointer_window[si]
        or      si,si
        jz      short pointer_write_cells
        sub     si,2
        add     cl,byte ptr cs:wobj_pos[si]
        add     dl,byte ptr cs:wobj_pos[si+1]
pointer_write_cells:
        xor     ch,ch                 ; cells to pixels (8 x 8)
        xor     dh,dh
        shl     cx,1
        shl     cx,1
        shl     cx,1
        shl     dx,1
        shl     dx,1
        shl     dx,1
        mov     ax,4
        int     33h
pointer_write_done:
        pop     si
        pop     dx
        pop     cx
        pop     ax
        call    message_shift12
        pop     bp
        add     sp,12
        jmp     int15_handled

pointer_poll:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    es
        call    mouse_driver          ; a driver?
        jnc     short pointer_poll_driver
        jmp     pointer_poll_ret
pointer_poll_driver:
        call    caller_tag
        xor     ah,ah
        mov     dx,ax
        mov     ax,word ptr cs:foreground_task
        cmp     ax,0FFFFh
        je      short pointer_poll_fg
        inc     ax                    ; (tag = number + 1)
        cmp     ax,dx
        je      short pointer_poll_fg
        jmp     pointer_poll_ret
pointer_poll_fg:
        xor     si,si
        mov     cx,POINTER_SLOT_COUNT
pointer_poll_find:
        cmp     word ptr cs:pointer_used[si],0
        je      short pointer_poll_find_next
        cmp     word ptr cs:pointer_owner[si],dx
        jne     short pointer_poll_find_next
        cmp     word ptr cs:pointer_open[si],0
        je      short pointer_poll_find_next
        cmp     word ptr cs:pointer_count[si],0
        je      short pointer_poll_found
        jmp     pointer_poll_ret      ; (one message at a time)
pointer_poll_find_next:
        add     si,2
        loop    pointer_poll_find
        jmp     pointer_poll_ret
pointer_poll_found:
        mov     di,1                  ; DI = the status
pointer_poll_press:
        mov     ax,5
        lea     bx,[di-1]
        int     33h
        or      bx,bx
        jnz     short pointer_poll_event_press
        inc     di
        cmp     di,2
        jbe     short pointer_poll_press
        test    word ptr cs:pointer_flags[si],04h ; releases too
        jz      short pointer_poll_move
        mov     di,1
pointer_poll_release:
        mov     ax,6
        lea     bx,[di-1]
        int     33h
        or      bx,bx
        jnz     short pointer_poll_event_release
        inc     di
        cmp     di,2
        jbe     short pointer_poll_release
pointer_poll_move:
        test    word ptr cs:pointer_flags[si],01h ; buttons only
        jnz     short pointer_poll_ret
        mov     ax,3
        int     33h
        mov     di,bx
        and     di,3
        call    pointer_cell
        cmp     ax,word ptr cs:pointer_last[si]
        je      short pointer_poll_ret
        jmp     short pointer_poll_store
pointer_poll_event_release:
        or      di,40h
        jmp     short pointer_poll_event
pointer_poll_event_press:
        test    word ptr cs:pointer_flags[si],04h
        jz      short pointer_poll_event
        or      di,80h
pointer_poll_event:
        call    pointer_cell
pointer_poll_store:
        mov     word ptr cs:pointer_last[si],ax
        push    ax
        mov     ax,word ptr cs:pointer_handle_segments[si]
        mov     es,ax
        pop     ax
        xor     bx,bx
        mov     bl,ah
        mov     word ptr es:[10h],bx  ; row
        mov     bl,al
        mov     word ptr es:[12h],bx  ; column
        mov     bx,di
        mov     byte ptr es:[14h],bl
        mov     dx,ax                 ; the field under it
        push    es
        call    pointer_field
        pop     es
        mov     byte ptr es:[15h],al
        mov     word ptr cs:pointer_count[si],1
pointer_poll_ret:
        pop     es
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; AX = the cell (AH row, AL column) of the pixel position CX, DX.
pointer_cell:
        mov     ax,dx
        shr     ax,1
        shr     ax,1
        shr     ax,1
        mov     ah,al
        push    cx
        shr     cx,1
        shr     cx,1
        shr     cx,1
        mov     al,cl
        pop     cx
        ret

; AL = the number of the field of the task's table at cell DX (DH row, DL
; column), 0:  none.
pointer_field:
        push    bx
        push    cx
        push    es
        call    field_count
        jc      short pointer_field_none
        mov     al,1
pointer_field_one:
        call    field_entry
        call    field_inside
        jnc     short pointer_field_ret
        inc     al
        loop    pointer_field_one
pointer_field_none:
        xor     al,al
pointer_field_ret:
        pop     es
        pop     cx
        pop     bx
        ret

int15_message_keyboard_read:
        push    bp
        mov     bp,sp
        push    ax
        test    byte ptr cs:keyboard_flags,1 ; field mode with a field table
        jz      short keyboard_read_wait
        cmp     word ptr cs:field_header+2,0
        je      short keyboard_read_wait
        call    field_read
        pop     ax
        jmp     message_expand4
keyboard_read_wait:
        mov     ah,1
        int     16h
        jnz     short keyboard_read_key
        cmp     byte ptr cs:core_running,0
        je      short keyboard_read_key ; (alone:  INT 16h waits)
        sti
        call    api_pause
        cli
        jmp     short keyboard_read_wait
keyboard_read_key:
        sti
        xor     ah,ah
        int     16h
        cli
        mov     byte ptr cs:keyboard_char,al
        or      al,al                 ; the scan code only for a zero
        jz      short keyboard_read_scan ; character, as DESQview
        xor     ah,ah
keyboard_read_scan:
        mov     byte ptr cs:keyboard_scan,ah
        mov     word ptr cs:message_result_len_lo,1
        mov     word ptr cs:message_result_len_hi,0
        mov     word ptr cs:message_result_ptr_off,offset keyboard_char
        mov     word ptr cs:message_result_ptr_seg,cs
        pop     ax
        jmp     message_expand4

; SI = the word index of the calling task's own mailbox, CF:  none.  Made
; (open, as DESQview gives every task one) at its first use; it goes when
; the task ends (D708h).
task_mailbox:
        push    ax
        call    caller_tag
        xor     ah,ah
        call    task_mailbox_of
        pop     ax
        ret

; SI = the word index of the own mailbox of the task with tag AX, CF:
; none (made as task_mailbox).
task_mailbox_of:
        push    ax
        push    cx
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
task_mailbox_scan:
        cmp     word ptr cs:mailbox_used[si],0
        je      short task_mailbox_next
        cmp     word ptr cs:mailbox_default[si],0
        je      short task_mailbox_next
        cmp     word ptr cs:mailbox_owner[si],ax
        je      short task_mailbox_done
task_mailbox_next:
        add     si,2
        loop    task_mailbox_scan
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
task_mailbox_free:
        cmp     word ptr cs:mailbox_used[si],0
        je      short task_mailbox_new
        add     si,2
        loop    task_mailbox_free
        stc
        jmp     short task_mailbox_ret
task_mailbox_new:
        mov     word ptr cs:mailbox_used[si],1
        mov     word ptr cs:mailbox_owner[si],ax
        mov     word ptr cs:mailbox_default[si],1
        mov     word ptr cs:mailbox_open[si],1
        mov     word ptr cs:mailbox_status[si],0
        mov     word ptr cs:mailbox_sender[si],0
        mov     word ptr cs:mailbox_flags[si],0
        mov     word ptr cs:mailbox_lock_count[si],0
        mov     word ptr cs:mailbox_lock_waiter[si],0
        mov     word ptr cs:mailbox_name_length[si],0
        call    mailbox_clear_queue
task_mailbox_done:
        clc
task_mailbox_ret:
        pop     cx
        pop     ax
        ret

; READ and READINTO of an empty open mailbox wait for a message, as under
; DESQview, while the multitasking core switches (D709h):  one PAUSE, then
; the mailbox (BP+10, the explicit handle) again.  CF:  no wait (no core,
; or the mailbox is gone or closed); else SI is its index again.
mailbox_wait:
        cmp     byte ptr cs:core_running,0
        je      short mailbox_wait_no
        push    ax
        sti
        call    api_pause
        cli
        mov     ax,word ptr ss:[bp+12]
        call    mailbox_validate
        jc      short mailbox_wait_gone
        cmp     word ptr cs:mailbox_open[si],1
        jne     short mailbox_wait_gone
        pop     ax
        clc
        ret
mailbox_wait_gone:
        pop     ax
mailbox_wait_no:
        stc
        ret

; DESQview's order of the DWORDs below a mailbox handle (RBIL's, top
; first:  length on the address, status on length and address) is not the
; one these handlers read:  swap the DWORDs at BP+14 and BP+18 (WRITE,
; SETNAME, GETNAME, READINTO), or at BP+14 and BP+22 (ADDTO, SUBFROM),
; so they find them where they look.
message_swap18:
        push    ax
        mov     ax,word ptr ss:[bp+14]
        xchg    ax,word ptr ss:[bp+18]
        mov     word ptr ss:[bp+14],ax
        mov     ax,word ptr ss:[bp+16]
        xchg    ax,word ptr ss:[bp+20]
        mov     word ptr ss:[bp+16],ax
        pop     ax
        ret
message_swap22:
        push    ax
        mov     ax,word ptr ss:[bp+14]
        xchg    ax,word ptr ss:[bp+22]
        mov     word ptr ss:[bp+14],ax
        mov     ax,word ptr ss:[bp+16]
        xchg    ax,word ptr ss:[bp+24]
        mov     word ptr ss:[bp+16],ax
        pop     ax
        ret

; Release the mailbox with word index SI.
mailbox_release:
        mov     word ptr cs:mailbox_used[si],0
        mov     word ptr cs:mailbox_default[si],0
        mov     word ptr cs:mailbox_open[si],0
        mov     word ptr cs:mailbox_status[si],0
        mov     word ptr cs:mailbox_sender[si],0
        mov     word ptr cs:mailbox_flags[si],0
        mov     word ptr cs:mailbox_lock_count[si],0
        mov     word ptr cs:mailbox_lock_waiter[si],0
        mov     word ptr cs:mailbox_name_length[si],0
        jmp     mailbox_clear_queue

; AL = the calling task's tag:  its number (APPNUM, the multitasking core
; answers it) + 1.  Its mailboxes go when the task ends (D708h), as
; DESQview frees them with the window.
; ZF set:  AX is the current task's window handle (a subtask's:  also
; its task's, whose window it shares; a task's:  also its subtasks', as
; the DV C library's tsk_new writes to it).
; SI = the number of the task whose window the caller writes to (its
; own, or its task's for a subtask), or CF.
window_owner:
        push    ax
        call    caller_tag
        dec     ax
        cmp     ax,TASK_OBJECT_COUNT
        jae     short window_owner_none
        mov     si,ax
        shl     si,1
        mov     ax,word ptr cs:sub_parent[si]
        or      ax,ax
        jz      short window_owner_own
        dec     ax
        cmp     ax,TASK_OBJECT_COUNT
        jae     short window_owner_none
        mov     si,ax
        pop     ax
        clc
        ret
window_owner_own:
        shr     si,1
        pop     ax
        clc
        ret
window_owner_none:
        pop     ax
        stc
        ret

; AL to the logical-colours flag of the caller's window.
window_logical_set:
        push    si
        call    window_owner
        jc      short window_logical_set_ret
        mov     byte ptr cs:window_logical[si],al
window_logical_set_ret:
        pop     si
        ret

; ZF clear:  the caller's window has logical colours (DAh).
window_logical_test:
        push    si
        call    window_owner
        jc      short window_logical_test_no
        cmp     byte ptr cs:window_logical[si],0
        pop     si
        ret
window_logical_test_no:
        cmp     si,si
        pop     si
        ret

own_window:
        cmp     ax,word ptr cs:task_handle_segment
        je      short own_window_ret
        push    ax
        push    bx
        push    cx
        push    si
        mov     bx,ax
        call    caller_tag
        mov     cx,ax                 ; (the caller's tag)
        dec     ax
        cmp     ax,TASK_OBJECT_COUNT
        jae     short own_window_child
        mov     si,ax
        shl     si,1
        mov     ax,word ptr cs:sub_parent[si]
        or      ax,ax
        jz      short own_window_child
        dec     ax                    ; its task's handle
        shl     ax,1                  ; (TASK_OBJECT_SIZE / 16)
        add     ax,word ptr cs:task_objects_base
        cmp     ax,bx
        je      short own_window_pop
own_window_child:
        mov     ax,bx                 ; a subtask of the caller
        call    task_validate
        jc      short own_window_no
        dec     ax
        mov     si,ax
        shl     si,1
        cmp     word ptr cs:sub_parent[si],cx
        jmp     short own_window_pop
own_window_no:
        or      sp,sp                 ; (ZF clear)
own_window_pop:
        pop     si
        pop     cx
        pop     bx
        pop     ax
own_window_ret:
        ret

; NEW 08h with an entry point (the caller's frame at BP):  a subtask
; (DESQview:  started there with DS = ES = SS a stack of its own, the
; handle of its task in DX:CX) by the multitasking core (INT 15h AX=
; DEF0h); DI = its handle, else 0.  Its stack:  SUB_SIZE bytes here.
subtask_new:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    es
        xor     di,di
        xor     si,si
        mov     cx,SUB_COUNT
subtask_new_slot:
        cmp     word ptr cs:sub_owner[si],0
        je      short subtask_new_have
        add     si,2
        loop    subtask_new_slot
        jmp     short subtask_new_ret
subtask_new_have:
        mov     word ptr cs:sub_owner[si],0FFFFh ; (taken)
        push    si
        mov     ax,si                 ; its stack's segment
        mov     cl,8                  ; (SUB_SIZE / 2)
        shl     ax,cl
        add     ax,offset sub_stacks
        mov     cl,4
        shr     ax,cl
        mov     dx,cs
        add     ax,dx
        mov     si,ax
        mov     dx,word ptr cs:task_handle_segment ; DX:CX its task
        xor     cx,cx
        les     bx,dword ptr ss:[bp+10] ; the entry point
        mov     di,SUB_SIZE
        mov     ax,0DEF0h
        int     15h
        pop     si
        jc      short subtask_new_fail
        mov     dx,ax                 ; its number
        inc     ax
        mov     word ptr cs:sub_owner[si],ax
        call    caller_tag            ; its task
        mov     si,dx
        shl     si,1
        mov     word ptr cs:sub_parent[si],ax
        mov     ax,dx                 ; its handle valid from now on
        push    dx
        call    task_bit
        or      word ptr cs:task_live[si],dx
        pop     dx
        mov     di,dx
        shl     di,1                  ; (TASK_OBJECT_SIZE / 16)
        add     di,word ptr cs:task_objects_base
        jmp     short subtask_new_ret
subtask_new_fail:
        mov     word ptr cs:sub_owner[si],0
        xor     di,di
subtask_new_ret:
        pop     es
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; Subtask AX (its number) ends (INT 15h AX=DEF1h:  the core; the current
; one:  no return); not a subtask:  nothing.
subtask_free:
        push    ax
        push    bx
        mov     bx,ax
        mov     ax,0DEF1h
        int     15h
        pop     bx
        pop     ax
        ret

caller_tag:
        mov     ax,word ptr cs:task_handle_segment
        call    task_validate
        jnc     short caller_tag_done
        mov     al,1
caller_tag_done:
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

; Relocate the frame over a mailbox handle, address and length.
message_shift12:
        push    ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+20],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+18],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp+16],ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp+14],ax
        pop     ax
        ret

; Relocate the frame over a mailbox handle plus address, length and status.
message_shift16:
        push    ax
        mov     ax,word ptr ss:[bp+8]
        mov     word ptr ss:[bp+24],ax
        mov     ax,word ptr ss:[bp+6]
        mov     word ptr ss:[bp+22],ax
        mov     ax,word ptr ss:[bp+4]
        mov     word ptr ss:[bp+20],ax
        mov     ax,word ptr ss:[bp+2]
        mov     word ptr ss:[bp+18],ax
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

; The window objects (type 00h, as the tasks' windows).
initialize_window_objects:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     bx,offset wobj_objects
        xor     si,si
        mov     cx,WOBJ_COUNT
initialize_wobj_loop:
        mov     ax,bx
        shr     ax,1
        shr     ax,1
        shr     ax,1
        shr     ax,1
        mov     dx,cs
        add     ax,dx
        mov     word ptr wobj_handle_segments[si],ax
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],0
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        add     bx,32
        add     si,2
        loop    initialize_wobj_loop
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; The keyboard objects of NEW 0Ah (the tasks' own:  keyboard_objects).
initialize_keyboard_objects2:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        mov     bx,offset kobj_objects
        xor     si,si
        mov     cx,KOBJ_COUNT
initialize_kobj_loop:
        mov     ax,bx
        shr     ax,1
        shr     ax,1
        shr     ax,1
        shr     ax,1
        mov     dx,cs
        add     ax,dx
        mov     word ptr kobj_handle_segments[si],ax
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Eh],ax
        add     bx,32
        add     si,2
        loop    initialize_kobj_loop
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; AX handle:  SI = its keyboard object's index, CF:  none.
kobj_validate:
        push    cx
        xor     si,si
        mov     cx,KOBJ_COUNT
kobj_validate_scan:
        cmp     ax,word ptr cs:kobj_handle_segments[si]
        jne     short kobj_validate_next
        cmp     word ptr cs:kobj_used[si],1
        jne     short kobj_validate_no
        clc
        jmp     short kobj_validate_ret
kobj_validate_next:
        add     si,2
        loop    kobj_validate_scan
kobj_validate_no:
        stc
kobj_validate_ret:
        pop     cx
        ret

; AX = the keyboard object of task DX (its tag) that gets the keys:  the
; one opened to its window object on top, else one opened to a window
; object; CF:  none (the task's keyboard).
kobj_focus:
        push    bx
        push    cx
        push    si
        mov     bx,WF_TOP
kobj_focus_pass:
        xor     si,si
        mov     cx,KOBJ_COUNT
kobj_focus_scan:
        cmp     word ptr cs:kobj_used[si],1
        jne     short kobj_focus_next
        cmp     word ptr cs:kobj_owner[si],dx
        jne     short kobj_focus_next
        mov     ax,word ptr cs:kobj_window[si]
        or      ax,ax
        jz      short kobj_focus_next
        push    si
        mov     si,ax
        mov     ax,word ptr cs:wobj_flags[si-2]
        pop     si
        and     ax,bx
        cmp     ax,bx
        jne     short kobj_focus_next
        mov     ax,word ptr cs:kobj_handle_segments[si]
        clc
        jmp     short kobj_focus_ret
kobj_focus_next:
        add     si,2
        loop    kobj_focus_scan
        or      bx,bx                 ; then without the top
        mov     bx,0
        jnz     short kobj_focus_pass
        stc
kobj_focus_ret:
        pop     si
        pop     cx
        pop     bx
        ret

; READ of a keyboard object:  in field mode, opened to a window object
; with a field table, the field manager on that window; else keystrokes.
int15_message_kobj_read:
        push    bp
        mov     bp,sp
        push    ax
        push    si
        mov     ax,word ptr ss:[bp+12]
        call    kobj_validate
        jc      short kobj_read_keys
        test    byte ptr cs:kobj_flags[si],1
        jz      short kobj_read_keys
        mov     ax,word ptr cs:kobj_window[si]
        or      ax,ax
        jz      short kobj_read_task
        mov     si,ax
        sub     si,2
        cmp     word ptr cs:wobj_used[si],1
        jne     short kobj_read_keys
        call    wobj_enter
        cmp     word ptr cs:field_header+2,0
        je      short kobj_read_none
        push    bx                    ; the hardware cursor in the window
        push    cx                    ; meanwhile, the task's kept
        push    dx
        mov     ah,03h
        mov     bh,0
        int     10h
        mov     word ptr cs:wobj_task_cursor,dx
        mov     byte ptr cs:wobj_hwcursor,1
        call    wobj_show_cursor
        call    field_read
        mov     byte ptr cs:wobj_hwcursor,0
        mov     dx,word ptr cs:wobj_task_cursor
        mov     ah,02h
        mov     bh,0
        int     10h
        pop     dx
        pop     cx
        pop     bx
        call    wobj_leave
        pop     si
        pop     ax
        jmp     message_expand4
kobj_read_none:
        call    wobj_leave
kobj_read_keys:
        pop     si
        jmp     keyboard_read_wait
kobj_read_task:
        pop     si
        pop     ax
        pop     bp
        jmp     int15_message_keyboard_read

; The pointer objects (type 0Fh), as the timers'.
initialize_pointer_objects:
        push    ax
        push    bx
        push    cx
        push    si
        mov     bx,offset pointer_objects
        xor     si,si
        mov     cx,POINTER_SLOT_COUNT
initialize_pointer_loop:
        mov     ax,bx
        shr     ax,1
        shr     ax,1
        shr     ax,1
        shr     ax,1
        push    dx
        mov     dx,cs
        add     ax,dx
        pop     dx
        mov     word ptr pointer_handle_segments[si],ax
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],0Fh
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        add     bx,POINTER_OBJECT_SIZE
        add     si,2
        loop    initialize_pointer_loop
        pop     si
        pop     cx
        pop     bx
        pop     ax
        ret

; One task object per task of the multitasking core:  task N's handle is
; task_objects_base + 2 * N (32-byte objects), as DESQview has one per task.
initialize_task_objects:
        push    ax
        push    bx
        push    cx
        mov     ax,cs
        mov     bx,offset task_object
        mov     cl,4
        shr     bx,cl
        add     ax,bx
        mov     word ptr task_objects_base,ax
        mov     bx,offset task_object
        mov     cx,TASK_OBJECT_COUNT
initialize_task_loop:
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],0
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        mov     byte ptr [bx+10h],1
        add     bx,TASK_OBJECT_SIZE
        add     ax,TASK_OBJECT_SIZE / 16
        loop    initialize_task_loop
        pop     cx
        pop     bx
        pop     ax
        ret

; One keyboard object per task:  task N's is keyboard_objects_base + 2 * N,
; its OBJECTQ the paragraph after it.
initialize_keyboard_objects:
        push    ax
        push    bx
        push    cx
        mov     ax,cs
        mov     bx,offset keyboard_objects
        mov     cl,4
        shr     bx,cl
        add     ax,bx
        mov     word ptr keyboard_objects_base,ax
        mov     bx,offset keyboard_objects
        mov     cx,TASK_OBJECT_COUNT
initialize_keyboard_loop:
        mov     word ptr [bx+4],0FEDCh
        mov     word ptr [bx+6],0Ah
        mov     word ptr [bx+8],0
        mov     word ptr [bx+0Ah],ax
        mov     word ptr [bx+0Ch],0
        mov     word ptr [bx+0Eh],ax
        inc     ax                    ; its second paragraph:  the task's
        mov     word ptr [bx+14h],0FEDCh ; OBJECTQ (type 0Ch)
        mov     word ptr [bx+16h],0Ch
        mov     word ptr [bx+18h],0
        mov     word ptr [bx+1Ah],ax
        mov     word ptr [bx+1Ch],0
        mov     word ptr [bx+1Eh],ax
        dec     ax
        add     bx,TASK_OBJECT_SIZE
        add     ax,TASK_OBJECT_SIZE / 16
        loop    initialize_keyboard_loop
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
        je      int2f_status
        cmp     ax,MUX_INFO
        je      int2f_info
        cmp     ax,MUX_RESET
        je      int2f_reset
        cmp     ax,MUX_TASK_INFO
        jne     short int2f_not_task_info
        jmp     int2f_task_info
int2f_not_task_info:
        cmp     ax,MUX_CAPS2
        jne     short int2f_not_caps2
        jmp     int2f_caps2
int2f_not_caps2:
        cmp     ax,MUX_CAPS3
        jne     short int2f_not_caps3
        jmp     int2f_caps3
int2f_not_caps3:
        cmp     ax,MUX_SOUND_INFO
        jne     short int2f_not_sound_info
        jmp     int2f_sound_info
int2f_not_sound_info:
        cmp     ax,MUX_TASK_END
        jne     short int2f_not_task_end
        jmp     int2f_task_end
int2f_not_task_end:
        cmp     ax,MUX_FOREGROUND
        jne     short int2f_not_foreground
        mov     word ptr cs:foreground_task,bx
        xor     ax,ax
        popf
        iret
int2f_not_foreground:
        cmp     ax,MUX_CORE
        jne     short int2f_not_core
        mov     byte ptr cs:core_running,bl
        xor     ax,ax
        popf
        iret
int2f_not_core:
        cmp     ax,MUX_APP_START
        jne     short int2f_not_app_start
        mov     ax,1
        cmp     byte ptr cs:appreq_state,1
        jne     short int2f_app_start_none
        push    cs
        pop     es
        mov     bx,offset appreq_state
        xor     ax,ax
int2f_app_start_none:
        popf
        iret
int2f_not_app_start:
        cmp     ax,MUX_TASK_STATE
        jne     short int2f_not_task_state
        push    cs
        pop     es
        mov     bx,offset task_state_begin
        mov     cx,offset task_state_end - offset task_state_begin
        mov     dx,offset task_state_pool - offset task_state_begin
        xor     ax,ax                 ; (DX:  what a new task inherits, the
                                      ; rest starts zero)
        popf
        iret
int2f_not_task_state:
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
        mov     word ptr cs:second_level_used,0
        mov     word ptr cs:second_level_pending,0
        mov     byte ptr cs:second_level_active,0
        mov     byte ptr cs:task_stack_active,0
        mov     word ptr cs:task_stack_user_ss,0
        mov     word ptr cs:task_stack_user_sp,0
        pushf
        cli
        push    bx
        call    sound_clear
        pop     bx
        popf
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
; D708h, BX = task:  it ended (the multitasking core):  its mailboxes go
; (its GETMEM pool went with its state block); common memory and timers stay (DESQview keeps them too
; when a window is closed)
int2f_task_end:
        push    ax
        push    cx
        push    dx
        push    si
        cli
        mov     ax,bx                 ; its handle no longer valid
        cmp     ax,TASK_OBJECT_COUNT
        jae     short task_end_dead
        call    task_bit
        not     dx
        and     word ptr cs:task_live[si],dx
task_end_dead:
        mov     al,bl
        inc     al                    ; its tag
        xor     ah,ah
        xor     si,si                 ; a subtask:  its stack, its task
        mov     cx,SUB_COUNT
task_end_sub:
        cmp     word ptr cs:sub_owner[si],ax
        jne     short task_end_sub_next
        mov     word ptr cs:sub_owner[si],0
task_end_sub_next:
        add     si,2
        loop    task_end_sub
        cmp     bx,TASK_OBJECT_COUNT
        jae     short task_end_noparent
        mov     si,bx
        shl     si,1
        mov     word ptr cs:sub_parent[si],0
        mov     byte ptr cs:window_logical[bx],0
task_end_noparent:
        xor     ah,ah
        xor     si,si
        mov     cx,MAILBOX_SLOT_COUNT
task_end_mbx:
        cmp     word ptr cs:mailbox_used[si],0
        je      short task_end_mbx_next
        cmp     word ptr cs:mailbox_owner[si],ax
        jne     short task_end_mbx_next
        push    ax
        call    mailbox_release
        pop     ax
task_end_mbx_next:
        cmp     word ptr cs:mailbox_lock_waiter[si],ax ; no more waiting
        jne     short task_end_mbx_waiter
        mov     word ptr cs:mailbox_lock_waiter[si],0
task_end_mbx_waiter:
        cmp     word ptr cs:mailbox_lock_owner[si],ax ; its locks off
        jne     short task_end_mbx_lock
        mov     word ptr cs:mailbox_lock_count[si],0
        test    byte ptr cs:mailbox_lock_waiter[si+1],80h
        jz      short task_end_mbx_lock
        mov     word ptr cs:mailbox_lock_waiter[si],0
task_end_mbx_lock:
        add     si,2
        loop    task_end_mbx
        xor     si,si                 ; its windows
        mov     cx,WOBJ_COUNT
task_end_wobj:
        cmp     word ptr cs:wobj_owner[si],ax
        jne     short task_end_wobj_next
        mov     word ptr cs:wobj_used[si],0
        mov     word ptr cs:wobj_flags[si],0
task_end_wobj_next:
        add     si,2
        loop    task_end_wobj
        xor     si,si                 ; its keyboards
        mov     cx,KOBJ_COUNT
task_end_kobj:
        cmp     word ptr cs:kobj_owner[si],ax
        jne     short task_end_kobj_next
        mov     word ptr cs:kobj_used[si],0
task_end_kobj_next:
        add     si,2
        loop    task_end_kobj
        xor     si,si                 ; its pointers
        mov     cx,POINTER_SLOT_COUNT
task_end_ptr:
        cmp     word ptr cs:pointer_owner[si],ax
        jne     short task_end_ptr_next
        mov     word ptr cs:pointer_used[si],0
task_end_ptr_next:
        add     si,2
        loop    task_end_ptr
        pop     si
        pop     dx
        pop     cx
        pop     ax
        xor     ax,ax
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
int2f_sound_info:
        cli
        push    si
        xor     bx,bx
        mov     si,word ptr cs:sound_head
        cmp     word ptr cs:sound_count,0
        je      short int2f_sound_empty
        mov     bx,word ptr cs:sound_frequency[si]
int2f_sound_empty:
        mov     cx,word ptr cs:sound_remaining
        mov     dx,word ptr cs:sound_count
        pop     si
        popf
        iret
int2f_chain:
        popf
        jmp     dword ptr cs:old2f

old10          dd 0
old15          dd 0
old1c          dd 0
old21          dd 0
old2f          dd 0
; The state of the task calling (DESQview keeps it per window):  the
; multitasking core saves and loads this block on each task switch
; (D707h), the internal stack of OSTACK with it.
task_state_begin label byte
critical_depth dw 0
api_level      dw 0100h
task_flags     dw TASK_JUSTIFY
error_mode     db 0
debug_column   db 0
keyboard_mouse db 0
second_level_active db 0
second_level_used dw 0
second_level_pending dw 0
second_level_handlers dd SECOND_LEVEL_COUNT dup(0)
task_stack_active db 0
task_stack_user_ss dw 0
task_stack_user_sp dw 0
task_stack_saved_ax dw 0
task_stack_saved_bp dw 0
task_stack_return_ip dw 0
task_stack_return_cs dw 0
task_stack_return_flags dw 0
message_saved_ax dw 0
message_saved_bp dw 0
message_bl     db 0                   ; BL was 02h/03h (a task's mailbox)
message_result_len_lo dw 0
message_result_len_hi dw 0
message_result_ptr_off dw 0
message_result_ptr_seg dw 0
; GETMEM (system memory) per task, as DESQview's in the window's memory:
; a new task starts with it all free, and it goes with the task
; the stream, field READ and window object being worked on:  per task, as
; a task waits (PAUSE) in a field READ while others write (subtasks too)
wobj_fchars    dw 0                    ; wobj_single or wobj_double
wobj_scratch   dw 0                    ; wobj_cell's outside
wobj_off       dw 0                    ; wobj_off_all's (bit N:  object N)
wobj_hwcursor  db 0                    ; a field READ on a window object:
wobj_task_cursor dw 0                  ;   the task's cursor meanwhile
field_esize    db 7                    ; the field table's entry size and
field_style    db 7                    ;   E5h's for the rest of the stream
field_alt      db 0                    ; BDh:  the cursor keys in menus
field_point_from db 0
field_select_second db 0
field_rc_char  db 0                    ; field_right_char's
field_rc_left  dw 0
field_rc_cell  dw 0
wtarget_esize  db 7
wobj_made      dw 0                    ; E6h made window object index + 2
wtarget        dw 0                    ; the stream's window:  0 the task's,
                                      ; else a window object's index + 2
wtarget_color  db 0                   ; the task's window_color and
wtarget_fields dd 0                   ;   field_header meanwhile
task_state_pool label byte
task_internal_stack db TASK_STACK_SIZE dup(0) ; OSTACK's (not inherited)
task_internal_stack_top label byte
api_stack      db API_STACK_SIZE dup(0) ; a call's (api_enter)
api_stack_top  label byte
api_crit       db 0                   ; 1:  in a call (its critical section;
                                      ; not inherited:  a subtask is made in one)
api_nest       dw 0                   ; INT 15h nested in a call (int15_handler)
api_user_ss    dw 0                   ; the caller's stack
api_user_sp    dw 0
api_ret        dw 0                   ; api_enter's / api_leave's scratch
api_flags      dw 0
api_ax         dw 0
api_cx         dw 0
api_si         dw 0
api_di         dw 0
api_ds         dw 0
api_es         dw 0
task_handle_segment dw 0              ; the task's own object (0:  not yet,
                                      ; int15_handler finds it)
window_color   db 0                   ; window stream E2h (0:  none yet)
window_page    db 0                   ; the page (field manager)
field_header   dd 0                   ; FFh's table in the caller's stream
keyboard_flags dw 0                   ; ADDTO/SUBFROM bits (0:  field mode)
field_buffer   db FIELD_BUFFER_SIZE dup(0) ; READ's data in field mode
keyboard_char  db 0                   ; the last key READ gave (its buffer)
keyboard_scan  db 0                   ;   and its scan code (STATUS)
system_used    db SYSTEM_SLOT_COUNT dup(0)
system_pool    db (SYSTEM_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)
readn_buf      db READN_SIZE dup(0)   ; READN's characters (the task's)
task_state_end label byte
sound_head     dw 0
sound_tail     dw 0
sound_count    dw 0
sound_remaining dw 0
sound_frequency dw SOUND_QUEUE_COUNT dup(0)
sound_duration dw SOUND_QUEUE_COUNT dup(0)
video_segment  dw 0B800h
printc_page    db 0
printc_columns db 80
printc_last_row db 24
task_objects_base dw 0                ; task 0's object (initialize_task_objects)
keyboard_objects_base dw 0            ; task 0's keyboard
task_live      dw 2 dup(0)            ; bit N:  task N lives
install_path   db 67 dup(0)
alloc_tag      db 1
common_used    db COMMON_SLOT_COUNT dup(0)
wobj_used      dw WOBJ_COUNT dup(0)
wobj_handle_segments dw WOBJ_COUNT dup(0)
wobj_owner     dw WOBJ_COUNT dup(0)    ; caller_tag at its making
wobj_pos       dw WOBJ_COUNT dup(0)    ; its contents' origin:  row, column
wobj_size      dw WOBJ_COUNT dup(0)    ; rows, columns
wobj_cursor    dw WOBJ_COUNT dup(0)    ; the logical cursor:  row, column
wobj_color     dw WOBJ_COUNT dup(0)    ; the output colour (E2h)
wobj_flags     dw WOBJ_COUNT dup(0)    ; WF_*
wobj_buf       dw WOBJ_COUNT dup(0)    ; its block in wobj_pool:  the
wobj_bytes     dw WOBJ_COUNT dup(0)    ;   contents, then the saved screen
wobj_drawn     dw WOBJ_COUNT dup(0)    ; drawn:  the top left (frame incl.)
wobj_dsize     dw WOBJ_COUNT dup(0)    ;   and the size
wobj_tlen      dw WOBJ_COUNT dup(0)
wobj_fields    dd WOBJ_COUNT dup(0)    ; its field table (FFh)
wobj_title     db (WOBJ_COUNT * WOBJ_TITLE_SIZE) dup(0)
WOBJ_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      WOBJ_OBJECT_PAD dup (0) ; (segment:0000 handles)
wobj_objects   db (WOBJ_COUNT * 32) dup(0)
wobj_pool      db WOBJ_POOL_SIZE dup(0)
; DESQview 2.80's logical colours 1-16 (DAh; the attribute's low nibble,
; 0 for 16), as its default colours show them
wobj_logical   db 31h,71h,20h,12h,4Bh,50h,30h,60h
               db 13h,17h,02h,21h,3Ch,05h,03h,06h
wobj_single    db 0DAh,0C4h,0BFh,0B3h,0C0h,0D9h ; the frame's characters
wobj_double    db 0C9h,0CDh,0BBh,0BAh,0C8h,0BCh ;   (on top:  double)
wobj_esize     dw WOBJ_COUNT dup(7)    ; its field table's entry size
kobj_used      dw KOBJ_COUNT dup(0)
kobj_handle_segments dw KOBJ_COUNT dup(0)
kobj_owner     dw KOBJ_COUNT dup(0)
kobj_flags     dw KOBJ_COUNT dup(0)    ; ADDTO/SUBFROM bits (0:  field mode)
kobj_window    dw KOBJ_COUNT dup(0)    ; OPEN:  a window object's index + 2
KOBJ_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      KOBJ_OBJECT_PAD dup (0) ; (segment:0000 handles)
kobj_objects   db (KOBJ_COUNT * 32) dup(0)
pointer_used   dw POINTER_SLOT_COUNT dup(0)
pointer_window dw POINTER_SLOT_COUNT dup(0) ; OPEN:  a window object's
                                      ;   index + 2, else 0
pointer_handle_segments dw POINTER_SLOT_COUNT dup(0)
pointer_owner  dw POINTER_SLOT_COUNT dup(0) ; caller_tag at NEW
pointer_open   dw POINTER_SLOT_COUNT dup(0) ; OPEN to a window
pointer_flags  dw POINTER_SLOT_COUNT dup(0) ; ADDTO/SUBFROM bits
pointer_count  dw POINTER_SLOT_COUNT dup(0) ; 1:  a message waits
pointer_noted  dw POINTER_SLOT_COUNT dup(0) ; 1:  given by the OBJECTQ
pointer_last   dw POINTER_SLOT_COUNT dup(0) ; the last cell (movement)
POINTER_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      POINTER_OBJECT_PAD dup (0) ; (segment:0000 handles)
pointer_objects db (POINTER_SLOT_COUNT * POINTER_OBJECT_SIZE) dup(0)
foreground_task dw 0FFFFh              ; the core's (D70Ah)
timer_used     dw TIMER_SLOT_COUNT dup(0)
timer_handle_segments dw TIMER_SLOT_COUNT dup(0)
timer_open     dw TIMER_SLOT_COUNT dup(0)
timer_state    dw TIMER_SLOT_COUNT dup(0)
timer_owner    dw TIMER_SLOT_COUNT dup(0) ; caller_tag at NEW
timer_noted    dw TIMER_SLOT_COUNT dup(0) ; 1:  its expiry was in the OBJECTQ
timer_start_lo dw TIMER_SLOT_COUNT dup(0)
timer_start_hi dw TIMER_SLOT_COUNT dup(0)
timer_duration_lo dw TIMER_SLOT_COUNT dup(0)
timer_duration_hi dw TIMER_SLOT_COUNT dup(0)
mailbox_used   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_owner  dw MAILBOX_SLOT_COUNT dup(0) ; caller_tag at NEW
mailbox_default dw MAILBOX_SLOT_COUNT dup(0) ; 1:  its owner's own mailbox
core_running   db 0                   ; D709h
appreq_state   db 0                   ; APP_START:  1 asked, 2 answered (by
appreq_from    db 0                   ; the host, D70Bh), 3 being filled;
appreq_task    dw 0                   ; the asking task, the new one (0:
appreq_size    dw 0                   ; none), the DVP
appreq_dvp     db APPREQ_MAX dup(0)
mailbox_handle_segments dw MAILBOX_SLOT_COUNT dup(0)
mailbox_open   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_status dw MAILBOX_SLOT_COUNT dup(0)
mailbox_sender dw MAILBOX_SLOT_COUNT dup(0)
mailbox_flags  dw MAILBOX_SLOT_COUNT dup(0)
mailbox_lock_owner dw MAILBOX_SLOT_COUNT dup(0) ; LOCK:  the task's tag
mailbox_lock_count dw MAILBOX_SLOT_COUNT dup(0) ;   and its LOCKs
mailbox_lock_waiter dw MAILBOX_SLOT_COUNT dup(0) ; a task waiting for it
                                      ; (8000h + tag:  given to it)
mailbox_name_length dw MAILBOX_SLOT_COUNT dup(0)
mailbox_count  dw MAILBOX_SLOT_COUNT dup(0)
mailbox_noted  dw MAILBOX_SLOT_COUNT dup(0) ; of them, given by the OBJECTQ
mailbox_head   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_tail   dw MAILBOX_SLOT_COUNT dup(0)
mailbox_bytes  dw MAILBOX_SLOT_COUNT dup(0)
mailbox_message_status db MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_reference db MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_length dw MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_sender dw MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_pointer_off dw MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_pointer_seg dw MAILBOX_ENTRY_COUNT dup(0)
mailbox_message_data db (MAILBOX_ENTRY_COUNT * MAILBOX_MESSAGE_SIZE) dup(0)
mailbox_names  db (MAILBOX_SLOT_COUNT * MAILBOX_NAME_SIZE) dup(0)
common_pool    db (COMMON_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)

; Keep this label paragraph-aligned: GETFOREGROUND returns segment:0000.
; Dynamic alignment remains correct as the resident code grows.
TASK_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      TASK_OBJECT_PAD dup (0)
task_object    label byte             ; TASK_OBJECT_COUNT of them, each:
                                      ;   previous and next task objects,
                                      ;   FEDCh (DESQview's object
                                      ;   signature), 0 (window/task), its
                                      ;   public handle, its canonical
                                      ;   address, task flag and window
                                      ;   number, header storage
        db      (TASK_OBJECT_COUNT * TASK_OBJECT_SIZE) dup(0)

KEYBOARD_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      KEYBOARD_OBJECT_PAD dup (0)
keyboard_objects db (TASK_OBJECT_COUNT * TASK_OBJECT_SIZE) dup(0)

; NEW/FREE timers use separate paragraph-aligned 32-byte headers. They expose
; pointer-compatible identities now; countdown messages are not implemented.
TIMER_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      TIMER_OBJECT_PAD dup (0)
timer_objects  db (TIMER_SLOT_COUNT * TIMER_OBJECT_SIZE) dup(0)

MAILBOX_OBJECT_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      MAILBOX_OBJECT_PAD dup (0)
mailbox_objects db (MAILBOX_SLOT_COUNT * MAILBOX_OBJECT_SIZE) dup(0)

; The subtasks' stacks (NEW 08h with an entry point), their owners (task
; number + 1, FFFFh:  being made); each task's parent (number + 1, 0:  not
; a subtask).
SUB_PAD equ (16 - ((($ - start) + 100h) mod 16)) mod 16
        db      SUB_PAD dup (0)
sub_stacks     db (SUB_COUNT * SUB_SIZE) dup(0)
sub_owner      dw SUB_COUNT dup(0)
sub_parent     dw TASK_OBJECT_COUNT dup(0)
window_logical db TASK_OBJECT_COUNT dup(0) ; DAh on a task's window:  E2h's
                                      ; colours 1-16 (wobj_logical); its
                                      ; subtasks' too (window_owner)

installed_msg  db 'Open MaxView resident API 0.36 installed.',13,10,'$'
already_msg    db 'Open MaxView resident API is already installed.',13,10,'$'

resident_end:

        end     start
