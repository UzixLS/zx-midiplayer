;

    MODULE    SETTINGS_ESXDOS

__MODULE_SETTINGS_ESXDOS_BEGIN__    equ $

    DEFINE __MODULE_SETTINGS_IO_IMPLEMENTED__

; esxDOS API calls
F_OPEN      equ 0x9a
F_CLOSE     equ 0x9b
F_READ      equ 0x9d
F_WRITE     equ 0x9e

; F_OPEN mode, any/all of:
esx_mode_read           equ $01 ; request read access
esx_mode_write          equ $02 ; request write access
esx_mode_use_header     equ $40 ; read/write +3DOS header
; plus one of:
esx_mode_open_exist     equ $00 ; only open existing file
esx_mode_open_creat     equ $08 ; open existing or create file
esx_mode_creat_noexist  equ $04 ; create new file, error if exists
esx_mode_creat_trunc    equ $0c ; create new file, delete existing

    IFNDEF __MACRO_ESXDOSCALL
        MACRO ESXDOSCALL api
            rst 0x08
            db api
        ENDM ;ESXDOSCALL
        DEFINE __MACRO_ESXDOSCALL
    ENDIF ;__MACRO_ESXDOSCALL

esx_settings_load:
    ld a, F_READ
    ; read access, only open existing file
    ld b, esx_mode_read|esx_mode_open_exist
    jr _esx_file_io
esx_settings_save:
    ld a, F_WRITE
    ; write access, open existing or create file
    ld b, esx_mode_write|esx_mode_open_creat
    ; fall through to _esx_file_io

; IN - A - API CALL, B - access mode
; OUT -  F - Z on success, NZ on fail
_esx_file_io:
    ld (.api_call), a
    ; A - drive; IX - filespecz; B - access mode; DE - 3DOS header (8), if used
    ld a, '*'   ; default drive
    ld ix, _esx_settings_file
    ; B preloaded ; ld b, esx_mode_???
    ESXDOSCALL F_OPEN   ; AF,BC,DE,HL always NOT preserved
    ; CF=0 - success, A - handle; CF=1 - error, A - errno
    jr c, .esx_error
    ld (.fd), a

    ; READ/WRITE: A - handle, IX - address, BC - length
    ld ix, var_settings
    ld bc, settings_t
.api_call   equ $+1
    ESXDOSCALL 0x00     ; AF,BC,DE,HL always not preserved
    ; CF=0 - success, BC - nread, HL - last read+1; CF=1 - error, BC - nread, A - errno
    ; CF=0 - success, BC - nwrtitten ; CF=1 - error, BC - nwritten
    jr c, .close
    ; EOF is not an error, check BC to determine if all bytes requested were read.
    ld hl, settings_t
    sbc hl, bc  ; here CF=0 due to JR C above
    jr z, .close; requested length == n(read|written), CF=0 by definition
    scf         ; CF=1 indicating error

.close:
    ; NOTE: AF is expected to have return status of READ/WRITE call
    push af     ; \AF/ save READ/WRITE call status
    ; A - handle
.fd     equ $+1
    ld a, 0xde  ; SMC   ; file descriptor
    ESXDOSCALL F_CLOSE  ; AF,BC,DE,HL always not preserved
    ; CF=0 - success, A=0; CF=1 - error, A - errno
    jr c, .esx_error_close
    pop af      ; /AF\ check READ/WRITE status
    jr c, .esx_error

    xor a   ; ZF=1 - SUCCESS
    ret
.esx_error_close:
    pop af      ; /AF\ discard READ/WRITE status
.esx_error:
    or 0xff ; ZF=0 - ERROR
    ret

_esx_settings_file: defb "zxmidipl.cfg", 0

__MODULE_SETTINGS_ESXDOS_SIZE__ equ $-__MODULE_SETTINGS_ESXDOS_BEGIN__

    DISPLAY "settings esxDOS @",__MODULE_SETTINGS_ESXDOS_BEGIN__," size: ",__MODULE_SETTINGS_ESXDOS_SIZE__

    ENDMODULE;SETTINGS_ESXDOS

settings_load   equ SETTINGS_ESXDOS.esx_settings_load
settings_save   equ SETTINGS_ESXDOS.esx_settings_save

; EOF vim: et:ai:ts=4:sw=4:
