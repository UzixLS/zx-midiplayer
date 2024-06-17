;

    DEVICE ZXSPECTRUM48
    ORG 0x8000

    DEFINE _PLUS3_NO_IM_CHANGE

file_base_addr  equ 0xc000
file_page_size equ #4000

_start:
    ld (var_basic_iy), iy
    ld a, 2     ; upper/main screen channel
    call 0x1601 ; CHAN-OPEN - https://skoolkid.github.io/rom/asm/1601.html

    DISPLAY "start: br '",$,"'"
    ld (.save_sp), sp
    ld sp, 0x7fef

    call test_mapping

    call trdos_init
    ;call test_1346

    call PLUS3.disk_directory_load
    ld de, 1
    call PLUS3.disk_directory_menu_generator
        DISPLAY "DONE: --debugger-command 'br ",$,"'"
    ld hl, tmp_menu_string+2
    call PUTS : ld a, 13 : rst 0x10
    ld de, 5
    call PLUS3.disk_directory_menu_generator
    ld hl, tmp_menu_string+2
    call PUTS : ld a, 13 : rst 0x10
    ld de, 9
    call PLUS3.disk_directory_menu_generator
    ld hl, tmp_menu_string+2
    call PUTS : ld a, 13 : rst 0x10
    ld de, 9
    call PLUS3.disk_file_load

.save_sp equ $ + 1
    ld sp, 0xdead
    ret

test_mapping:
        ld l, 'A'
.loop:
        ld a, 'P'
        cp l
        ret c
        ld a, l : rst 0x10 : ld a, ':' : rst 0x10
        call is_mapped
        jr nc, .next
        jr z, .unmapped
        ; for real scan make sure to ignore '4' -- RAMdisk
        add '0'
        jr .next
.unmapped:
        ld a, '-'
.next:
        rst 0x10
        ld a, ' ' : rst 0x10
        inc l
        jr .loop

is_mapped:  ; L - letter
        push hl
        push de
        ld bc, disk_buffer
        ; L=drive letter 'A' to 'P' (uppercase)
        ; BC=address of 18-byte buffer
        call PLUS3.plus3api
        dw 0x00F7   ; IDE_DOS_MAPPING ; AF BC DE HL corrupt
        ; CF=1 - sucess;
        ;   ZF0 - mapped, A=device (unit 0, 1), floppy (2,3), RAM (4); BC=partition #; buffer - text descr
        ;   ZF=1 - NOT mapped
        ; CF=0 - error; A=error code
        pop de
        pop hl
        ret

test_1346:
        call PLUS3.plus3api
        dw 0x013C   ; DOS_GET_1345    ; AF BC IX corrupt
        ; D = First buffer of cache
        ; E = Number of cache sector buffers
        ; H = First buffer of RAMdisk
        ; L = Number of RAMdisk sector buffers
        DISPLAY "test_1346: --debugger-command 'br ",$,"'"
        ld de, 0x2020 ; cache at buffer 0x20 (page 3), count 0x20 (16k)
        ld hl, 0x4000 ; RAMdisk at buffer 0x40 (page 4), size 0 (actually 4, min size)
        ; D = First buffer for cache
	    ; E = Number of cache sector buffers
	    ; H = First buffer for RAMdisk
	    ; L = Number of RAMdisk sector buffers
	    ; (Note that E + L <= 128)
        call PLUS3.plus3api
        dw 0x013F; DOS_SET_1345  ; BC DE HL IX corrupt
        ; CF=1 - success; A corrupt
        ; CF=0 - error; A = Error code
        call PLUS3.plus3api
        dw 0x013C ; DOS_GET_1345    ; AF BC IX corrupt
        ; D = First buffer of cache
        ; E = Number of cache sector buffers
        ; H = First buffer of RAMdisk
        ; L = Number of RAMdisk sector buffers
        ; DE 0x200F; HL 0x0000
        DISPLAY "TEST: --debugger-command 'br ",$,"'"
        nop
        ret

disks_get_icon_by_extension:
file_switch_page:
        ret ; do nothing
PUTS:
        ld a, (hl)
        or a
        ret z
        rst 0x10
        inc hl
        jr PUTS

disk_buffer_size    equ 8*256

    INCLUDE "../src/plus3dos.asm"

    EMPTYTAP "test.tap"
    SAVETAP  "test.tap",CODE,"utest.c",_start,$-_start

var_basic_iy        defw 0

var_current_file_number:    defb 0
var_current_file_size:      defw 0
var_trdos_present:          defb 0
    MODULE var_disks
boot_n:     defb 0
all:    block 16*16, 0
    ENDMODULE
disk_t      equ 16
disk_t.label equ 3
    MODULE PLUS3
DISK_DRIVER_PLUS3   equ 3
    ENDMODULE

var_current_file_name:      defs 8+3+1+1
tmp_menu_string: block 33, 0

disk_buffer equ $

; EOF vim: et:ai:ts=4:sw=4:
