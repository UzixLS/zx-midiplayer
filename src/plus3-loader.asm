;

    OPT --syntax=abf
    DEVICE ZXSPECTRUM128

        ORG 0x4000

    MODULE      LOADER_PLUS3

    MACRO PLUS3CALL api
        call PLUS3API.plus3api
        dw api
    ENDM

__LOADER_PLUS3_START__ equ $

FILENO  equ 0x07    ; arbitrary number used as file descriptor

bankm equ 5B5Ch ;system variable that holds the last value output to 7FFDh

    ;   76543210
    ;   FBPPPCCC
    MACRO STATUS colour
        ld a, colour
        call status
    ENDM

main:
        STATUS %10100000    ; flashing green bg

        ; FIXME: duplicated in plus3dos
        ld de, 0x1b04   ; cache at bufer 0x13, size 0x08
        ld hl, 0x2000   ; RAMdisk at buffer 0x20, size 0x00 (OFF)
        PLUS3CALL 0x013F ; DOS_SET_1345  ; BC DE HL IX corrupt

        ; move screens data to the appropriate page(s)
        ld hl, _screens
        ld de, P3DOS_SCREENS_PTR
        call p3_load
        call P3DOS_SCREENS_PTR
        STATUS 0xff     ; next char attribute

        ; load +3 DOS driver, optional
        ld hl, _p3_driver
        ld de, 0x7000   ; FIXME: defined conditionally in plus3dos.asm
        call p3_load
        ; no init necessary, just a library for the main
        STATUS 0xff     ; next char attribute

        ; main code block
        ld hl, _main
        ld de, begin
        call p3_load
        STATUS 0xff     ; next char attribute
        STATUS %10100000    ; flashing green bg

        jp begin    ; jump to the main code

p3_load:
        push hl     ; file name
        push de     ; \LA/ load address
        STATUS %00100000    ; green bg
        ; HL preloaded with 0xff terminated file name
        ld b, FILENO
        ld c, 1 ; MODE_RD
        ld de, 0x0001   ; Open the file, read the header (if any)
        PLUS3CALL DOS_OPEN
        pop hl      ; /LA\ load address
        jr nc, .close

        STATUS %11100000    ; flashing bright green bg
        ld b, FILENO
        ld a, (bankm)
        and 0x07
        ld c, a
        ; HL has been pop'ped off the stack earlier
        ld de, 0    ; up to 64k
        PLUS3CALL DOS_READ
.close:
        STATUS %10001000    ; flashing blue bg
        ld b, FILENO
        PLUS3CALL DOS_CLOSE

        STATUS %00001000    ; blue bg
        pop hl      ; file name ptr
        ret

status:
        cp 0xff
        jr nz, .show
        push hl
        ld hl, .ptr
        inc (hl)
        pop hl
        ret
.show
.ptr equ $ + 1
        ld (0x5ae2), a
        ret

    DEFINE   _PLUS3_NO_IM_CHANGE    ; leave interrupt mode as is
    INCLUDE "plus3-api.asm"

FILES: ;      12345678.123
_screens:
        defb 'zxmidipl.gfx', 0xff
_p3_driver:
        defb 'zxmidipl.drv', 0xff
_main:
        defb 'zxmidipl.bin', 0xff

__LOADER_PLUS3_LENGTH__    equ $-__LOADER_PLUS3_START__
    ENDMODULE ; LOADER_PLUS3

    DISPLAY "+3 DOS Loader @", LOADER_PLUS3.__LOADER_PLUS3_START__
    SAVE3DOS "zxmidipl.ldr", LOADER_PLUS3.__LOADER_PLUS3_START__, LOADER_PLUS3.__LOADER_PLUS3_LENGTH__

; EOF vim: et:ai:ts=4:sw=4:
