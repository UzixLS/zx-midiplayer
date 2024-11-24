; Copyright 2024 TIsland Crew
; SPDX-License-Identifier: GPL-3.0+

; this file should be included by the build.asm

; === esxDOS ===
    PAGE 0

F_OPEN      equ 0x9a
F_CLOSE     equ 0x9b
F_READ      equ 0x9d
esx_mode_read           equ $01 ; request read access
esx_mode_use_header     equ $40 ; read/write +3DOS header
esx_mode_open_exist     equ $00 ; only open existing file

    MACRO ESXDOSCALL api
        rst 0x08
        db api
    ENDM ;ESXDOSCALL

    ; pack all binaries in one bundle

    PAGE 0
    OUTPUT "zxmidipl.esx"   ; building the bundle
    ORG 0
esx_screen:
    incbin "res/start.scr"
esx_main:
    incbin "build/main.bin"
esx_gfx:
    incbin "build/main.gfx"
esx_end:
    OUTEND

    MACRO NUM val
        db 0x0E, 0x00, 0x00: dw val : db 0x00
    ENDM ;NUM

; when building BASIC loader absolute address in memory is not important

    DEFINE RAMTOP   0x5fff
    DEFINE ESXBOOT  0x5b00

esx_boot_begin:
    dw 0x0100, esx_boot_end-$-4     ; BASIC line 1 + length
    db 0xFD, '0' : NUM RAMTOP       ; CLEAR RAMTOP
    db ':', 0xF9, 0xC0, '('         ; : RANDOMIZE USR (
    db '0' : NUM .bootstrap-esx_boot_begin  ; loader offset from BASIC start
    db '+', 0xBE, '0' : NUM 23635   ; + PEEK 23635
    db '+', '0' : NUM 256           ; + 256
    db '*', 0xBE, '0' : NUM 23636   ; * PEEK 23636
    db ')', ':', 0xEA               ; ) : REM

.bootstrap:
    ; BC - entry point per USR XYZ contract (.bootstrap)
    ld hl, .payload-.bootstrap
    add hl, bc      ; HL=absolute .payload address
    ld de, ESXBOOT  ; payload compiled to run @ESXBOOT
    push de         ; save launch address on stack
    ld bc, esxloader_end-esxloader
    ldir
    ret             ; go to launch address

.payload:
    PHASE ESXBOOT
esxloader:
    ld a, '*'   ; default drive
    ld ix, .filename
    ld b, esx_mode_read|esx_mode_use_header|esx_mode_open_exist
    ESXDOSCALL F_OPEN   ; AF,BC,DE,HL always NOT preserved
    ; CF=0 - success, A - handle; CF=1 - error, A - errno
    ret c
    ld (.fd), a

    xor a           ; ---EMbrd
    out (0xfe), a   ; black border

    ; NOTE: after F_READ we do not check if read all bytes for simplicity, however
    ; "EOF is not an error, check BC to determine if all bytes requested were read."

    ; load splash screen
    ld a, (.fd)     ; file handle
    ld ix, 0x4000   ; address
    ld bc, 0x1b00   ; length
    ESXDOSCALL F_READ   ; AF,BC,DE,HL always NOT preserved
    ; CF=0 - success, BC - nread, HL - last read+1; CF=1 - error, BC - nread, A - errno
    jr c, .close

    ; load main code
    ld a, (.fd)     ; file handle
    ld ix, begin    ; address
    ld bc, end-begin; length
    ESXDOSCALL F_READ   ; AF,BC,DE,HL always NOT preserved
    ; CF=0 - success, BC - nread, HL - last read+1; CF=1 - error, BC - nread, A - errno
    jr c, .close

    ; load runtime screens to bank 'screens_page'
    ld a, 0x10+screens_page
    ld bc, 0x7ffd
    out (c), a      ; page in screens bank
    ld a, (.fd)     ; file handle
    ld ix, 0xc000   ; address
    ld bc, esx_end-esx_gfx  ; length
    ESXDOSCALL F_READ   ; AF,BC,DE,HL always NOT preserved
    ; CF=0 - success, BC - nread, HL - last read+1; CF=1 - error, BC - nread, A - errno
    ld a, 0x10
    ld bc, 0x7ffd
    out (c), a      ; page in bank 0 before checking F_READ status
    jr c, .close

    ; all blocks loaded without error, launch the main code
    ld hl, main     ; save launch address on stack
    ex (sp), hl

.close:
.fd equ $+1
    ld a, 0xde ; SMC    ; file handle
    ESXDOSCALL F_CLOSE  ; AF,BC,DE,HL always NOT preserved
    ret             ; 'main' if there were no errors, caller otherwise
.filename:  defb "zxmidipl.esx", 0
esxloader_end:
    UNPHASE
    db 0x0d ; BASIC line end
esx_boot_end:
    DISPLAY "ESX Loader @", ESXBOOT, " (", esxloader_end-esxloader, ")"

    UNDEFINE ESXBOOT
    UNDEFINE RAMTOP

    SAVE3DOS "zxmidipl.bas",esx_boot_begin,esx_boot_end-esx_boot_begin,0,1

; EOF vim: et:ai:ts=4:sw=4:
