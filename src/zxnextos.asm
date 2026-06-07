; Copyright 2024 TIsland Crew
; SPDX-License-Identifier: GPL-3.0+

    IFDEF ZXNEXTOS

    DISPLAY "Target:   *** ZX Next OS ***"

    ; calculate ZXNET output option offset (index), see settings.asm
    ; -1 for DB N, -2 for var_settings.output
    ; we rely on 'settings_menuentry_output.zxnext' being defined
    LUA
       sj.insert_define("__SETTINGS_ZXNEXT_OUTPUT_POS__", (_c("settings_menuentry_output.zxnext")-_c("settings_menuentry_output")-1-2)//2)
    ENDLUA

zxnextos_init:
    ; check is we have Z80N CPU, recommended way to detect Next
    ld  a, %10000000
    db  0xED, 0x24, 0x00, 0x00   ; mirror a : nop : nop
    ; at this point on Next A will be 1, otherwise it's 0x80
    dec a
    ret nz      ; we're not on Next

    ; now enable UART send routine:
    xor a                            ; Opcode for NOP
    ld (nextuart_putc), a            ; Enable UART send routine

    ; and, finally, adjust default settings (loaded data overrides)
    ld a, 1 ; FIXME: magic number! calculate like __SETTINGS_ZXNEXT_OUTPUT_POS__
    ld (var_settings.divmmc), a ; force enable DivMMC
    ld a, __SETTINGS_ZXNEXT_OUTPUT_POS__
    ld (var_settings.output), a ; force enable Next UART

    ret

    IFDEF DOS_ESXDOS
        DEFINE __ZXNEXT_IO_IMPLEMENTED__
    ENDIF;DOS_ESXDOS

    IFDEF DOS_PLUS3

    DEFINE __ZXNEXT_IO_IMPLEMENTED__
    ; this is extremely trimmed PLUS3 module, leaving only init in place
    ; basic init is necessary for settings save/load to work
    ; data I/O is handled by the DivMMC module, which is force enabled

PLUS3.__MODULE_DOS_PLUS3__BEGIN__ equ $

    MODULE      ZXNEXTOS
p3api:
        ld iy, (var_basic_iy)  ; restore IY
        ; execution continues to PLUS3API.plus3api
    INCLUDE "plus3-api.asm"

    MACRO PLUS3CALL api
        call ZXNEXTOS.p3api
        dw api
    ENDM

disk_init:
        ; no need to check var_plus3dos_present
        ; the rest copied from plus3dos, default drive needed to save settings
        ld a, 0xff  ; FFh (255) = get default drive
        PLUS3CALL DOS_SET_DRIVE   ; BC DE HL IX corrupt
        jr nc, 1f
        ld (var_disks.boot_n), a
1:
        ; disable recoverable error reporting (interactive Retry,Abort,Cancel?)
        xor a   ; A=0, disable error messages
        ; A = Enable (0xff)/disable (0)
        ; HL = Address of ALERT routine (if enabled)
        PLUS3CALL DOS_SET_MESSAGE   ; AF BC DE IX corrupt
        ; HL = address of previous ALERT routine (0 if none)

        ; FIXME: duplicated in plus3-loader
        ld de, 0x1b04   ; cache at bufer 0x1b, size 0x04
        ld hl, 0x2000   ; RAMdisk at buffer 0x20, size 0x00 (OFF)
        ; D = First buffer for cache
        ; E = Number of cache sector buffers
        ; H = First buffer for RAMdisk
        ; L = Number of RAMdisk sector buffers
        ; (Note that E + L <= 128)
        PLUS3CALL DOS_SET_1345  ; BC DE HL IX corrupt
        ; CF=1 - success, A - corrupt
        ; CF=0 - error, A=error code
        ;DEBUG: PLUS3CALL DOS_GET_1345  ; AF BC IX corrupt
        ret

disk_directory_load:
disk_entry_is_directory:
disk_file_load:
disk_directory_menu_generator:
        xor a   ; set ZF=1
        ; intentional fall-through to RET below
disk_enumerate_volumes:
disk_device_change:
        ; no op
        ret

    IFDEF __SETTINGS_ZXNEXT_OUTPUT_POS__
    ENDIF;__SETTINGS_ZXNEXT_OUTPUT_POS__

    ENDMODULE ; ZXNEXTOS

PLUS3.__MODULE_DOS_PLUS3_SIZE__ equ $-PLUS3.__MODULE_DOS_PLUS3__BEGIN__

    DISPLAY "ZX Next OS @",PLUS3.__MODULE_DOS_PLUS3__BEGIN__," size:",PLUS3.__MODULE_DOS_PLUS3_SIZE__

    ; it's DEFINE and not EQU because it's easier to check with IFDEF
    IFNDEF settings_block_size
        DEFINE settings_block_size 256
    ELSE
        ASSERT settings_block_size==256
    ENDIF;settings_block_size

plus3_init                  equ ZXNEXTOS.disk_init
plus3_scan_disks            equ ZXNEXTOS.disk_enumerate_volumes
plus3_entry_is_directory    equ ZXNEXTOS.disk_entry_is_directory
plus3_file_load             equ ZXNEXTOS.disk_file_load
plus3_directory_load        equ ZXNEXTOS.disk_directory_load
plus3_file_menu_generator   equ ZXNEXTOS.disk_directory_menu_generator

    ; compat shim

PLUS3DOS_ORG equ PLUS3.__MODULE_DOS_PLUS3__BEGIN__
    EXPORT PLUS3DOS_ORG     ; build.asm optionally creates .drv if < 0x8000

; has to be exported explicitly
PLUS3.disk_device_change    equ ZXNEXTOS.disk_device_change

PLUS3.FILENO                equ 7   ; arbitrary number, we don't keep files open

PLUS3.DOS_OPEN              equ ZXNEXTOS.DOS_OPEN
PLUS3.DOS_READ              equ ZXNEXTOS.DOS_READ
PLUS3.DOS_WRITE             equ ZXNEXTOS.DOS_WRITE
PLUS3.DOS_CLOSE             equ ZXNEXTOS.DOS_CLOSE
PLUS3.DD_L_OFF_MOTOR        equ ZXNEXTOS.DD_L_OFF_MOTOR

    ENDIF;DOS_PLUS3

    UNDEFINE __SETTINGS_ZXNEXT_OUTPUT_POS__

    IFNDEF __ZXNEXT_IO_IMPLEMENTED__
        LUA
            sj.warning("ZX Next OS target has no supported filesystem!")
            sj.warning("settings persistence will not work!")
        ENDLUA
    ELSE  ;__ZXNEXT_IO_IMPLEMENTED__
        UNDEFINE __ZXNEXT_IO_IMPLEMENTED__
    ENDIF;!__ZXNEXT_IO_IMPLEMENTED__

    ENDIF;ZXNEXTOS

; EOF vim: et:ai:ts=4:sw=4:
