;

    IFNDEF __MODULE_PLUS3_API_ASM__
    DEFINE __MODULE_PLUS3_API_ASM__

    ; global scope equates
DOS_VERSION     equ 0x0103  ; Get the DOS issue and version numbers.
DOS_OPEN        equ 0x0106  ; Open file
DOS_CLOSE       equ 0x0109  ; Close file
DOS_READ        equ 0x0112  ; Read data
DOS_WRITE       equ 0x0115  ; Write bytes to a file from memory.
DOS_CATALOG     equ 0x011E  ; Fills a buffer with part of the directory (sorted).
DOS_SET_DRIVE   equ 0x12D   ; Set the default drive
DOS_GET_POSITION equ 0x0133 ; Get the file pointer.
DOS_GET_EOF     equ 0x0139  ; Get the end of file (EOF) file position
DOS_GET_1345    equ 0x013C  ; Get the current location of the cache and RAMdisk.
DOS_SET_1345    equ 0x013F  ; Rebuild the sector cache and RAMdisk.
DOS_SET_MESSAGE equ 0x014E  ; Enable/disable disk error messages.
DD_ASK_1        equ 0x017B  ; Check to see if unit 1 is present.
DD_L_OFF_MOTOR  equ 0x019C  ; Turn off the motor.
; +3e DOS calls
IDE_DOS_MAPPING equ 0x00F7  ; Details of the current mapping of the specified drive letter.

    ; make sure to define _PLUS3_NO_IM_CHANGE
    ; if caller does not need interrupt mode changes!

    MODULE    PLUS3API

    DEFINE _SMC_W_ 0xdead
    DEFINE _SMC_B_ 0x5A

bankm equ 5B5Ch ;system variable that holds the last value output to 7FFDh
port1 equ 7FFDh ;address of ROM/RAM switching port in I/O map

        ; plus3dos.asm relies on this being the very first opcode
        ; it prepends ld iy, (var_basic_iy)
plus3api: ; +3DOS Trampoline, usage: call plus3api : dw DOS_OPEN
        ld (.save_de), de
        ex (sp), hl
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ex (sp),hl
        ld (.call), de
.save_de equ $ + 1
        ld de, _SMC_W_
        call PG_IN_DOS
.call equ $ + 1
        call _SMC_W_
        ;jr PG_IN_USR0
; https://worldofspectrum.org/ZXSpectrum128+3Manual/chapter8pt26.html
PG_IN_USR0: ; page in 48k ROM
        push af
        push bc
    IFNDEF _PLUS3_NO_IM_CHANGE
        im 2
    ENDIF; _PLUS3_NO_IM_CHANGE
        ; we restore previously selected page, PG_IN_DOS stores bankm here
save_bankm equ $ + 1
        ld a, _SMC_B_
PG_SWITCH:
        ld bc, port1
        di
        ld (bankm), a
        out (c), a
        ei
        pop bc
        pop af
        ret
; https://worldofspectrum.org/ZXSpectrum128+3Manual/chapter8pt26.html
; Calling +3DOS from BASIC
; "[...] DOS can only be called with RAM page 7 switched in at
; the top of memory, the stack held somewhere in that range
; 4000h...BFE0h, and ROM 2 (the DOS ROM) switched in at the bottom of
; memory (000h...3FFFh)."
PG_IN_DOS:
    IFNDEF _PLUS3_NO_IM_CHANGE
        im 1
    ENDIF; _PLUS3_NO_IM_CHANGE
        push af
        push bc
        ld a, (bankm)
        ld (save_bankm), a ; preserve to restore later
        ; we keep bit 3, normal(0)/shadow(1) screen
        res 4, a ; Bit 4 is the low bit of the ROM selection.
        or 0x07 ; 0000 0111
        jr PG_SWITCH

    UNDEFINE _SMC_B_
    UNDEFINE _SMC_W_

    ENDMODULE;PLUS3API

    ENDIF ;__MODULE_PLUS3_API_ASM__

; EOF vim: et:ai:ts=4:sw=4:
