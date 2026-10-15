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
;   INT 15h AX=101Bh/101Ch           nested critical-section markers
;   INT 15h AX=1022h, BX=0000h       TopView-compatible API identity
;   INT 15h AX=DE04h                 common-memory availability
;   INT 15h AX=DE07h                 foreground program number
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

DV_VERSION     equ 0280h
MUX_STATUS     equ 0D700h
MUX_INFO       equ 0D701h
MUX_RESET      equ 0D702h
MUX_TASK_INFO  equ 0D703h
MUX_CAPS2      equ 0D704h
MUX_SIGNATURE  equ 04F44h            ; "OD" in register byte order
MUX_VERSION    equ 000Ch
CAPABILITIES   equ 0FFFFh
CAPABILITIES2  equ 01FFh

MEM_SLOT_SIZE      equ 0100h
SYSTEM_SLOT_COUNT  equ 8
COMMON_SLOT_COUNT  equ 4
COMMON_TOTAL       equ COMMON_SLOT_COUNT * MEM_SLOT_SIZE

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
        cmp     ax,0DE04h             ; GET AVAILABLE COMMON MEMORY
        jne     short int15_not_common_status
        jmp     int15_common_status
int15_not_common_status:
        cmp     ax,0DE07h             ; APPNUM
        je      int15_appnum
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

int15_isobj:
        xor     bx,bx
        or      di,di
        jnz     int15_handled
        mov     bx,es
        cmp     bx,word ptr cs:task_handle_segment
        jne     short int15_isobj_invalid
        mov     bx,0FFFFh
        jmp     int15_handled
int15_isobj_invalid:
        xor     bx,bx
        jmp     int15_handled

int15_object_type:
        xor     bx,bx
        or      di,di
        jnz     int15_handled
        mov     bx,es
        cmp     bx,word ptr cs:task_handle_segment
        jne     short int15_object_type_invalid
        mov     bl,08h                ; window/task object
        jmp     int15_handled
int15_object_type_invalid:
        xor     bx,bx
        jmp     int15_handled

int15_foreground:
        mov     bx,word ptr cs:task_handle_segment
        jmp     int15_handled

int15_dosuser:
        mov     bx,word ptr cs:task_handle_segment
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

; Traverse the only window/task object in foreground mode.  A null start
; returns the resident task handle; that handle returns a null end marker.
int15_objnext:
        mov     ax,es
        or      ax,ax
        jnz     short objnext_existing
        or      di,di
        jnz     short objnext_invalid
        mov     ax,word ptr cs:task_handle_segment
        mov     es,ax
        xor     di,di
        xor     ax,ax
        jmp     int15_handled
objnext_existing:
        or      di,di
        jnz     short objnext_invalid
        cmp     ax,word ptr cs:task_handle_segment
        jne     short objnext_invalid
        xor     ax,ax
        mov     es,ax
        xor     di,di
        jmp     int15_handled
objnext_invalid:
        mov     ax,1
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
        jmp     short int15_handled

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
        je      short int2f_caps2
        jmp     short int2f_chain
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
video_segment  dw 0B800h
task_handle_segment dw 0
install_path   db 67 dup(0)
system_used    db SYSTEM_SLOT_COUNT dup(0)
common_used    db COMMON_SLOT_COUNT dup(0)
system_pool    db (SYSTEM_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)
common_pool    db (COMMON_SLOT_COUNT * MEM_SLOT_SIZE) dup(0)

; Keep this label paragraph-aligned: GETFOREGROUND returns segment:0000.
        org     1200h
task_object    label byte
        dw      0,0                   ; previous and next task objects
        dw      0FEDCh                ; DESQview-compatible object signature
        dw      0                     ; window/task object type
        dw      0,0                   ; public handle, patched at install
        dw      0,0                   ; canonical address, patched at install
        db      1,0                   ; task flag and internal window number
        dw      0,0,0,0,0,0,0        ; bounded public header storage

installed_msg  db 'Open MaxView resident API 0.12 installed.',13,10,'$'
already_msg    db 'Open MaxView resident API is already installed.',13,10,'$'

resident_end:

        end     start
