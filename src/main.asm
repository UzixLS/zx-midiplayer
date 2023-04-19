    ASSERT __SJASMPLUS__ >= 0x011402 ; SjASMPlus 1.20.2
    OPT --syntax=abf
    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
    DEVICE ZXSPECTRUM128,stack_top

    includelua "lua/screen_address.lua"
    include "config.inc"
    include "layout.inc"

    MACRO LD_SCREEN_ADDRESS _reg, _yyxx
        lua allpass
            _pc("ld _reg, " .. screen_address_pixel((_c("_yyxx")&0xff)*8, (_c("_yyxx")>>8)*8))
        endlua
    ENDM

    page 0
    org int_handler-(variables0_end-variables0)
    assert $ >= #6000
begin:
    db "Code begin",0
variables0:
    include "variables_low.asm"
variables0_end:

    org #7f7f
int_handler:
    push af
    ld a, (var_int_counter+1)
    inc a
    ld (var_int_counter+1), a
    pop af
.A: ei                        ; (1 byte) self modifying code! see device_detect_cpu_int
    ret                       ; (1 byte) ...

    assert $ < 0x8000
    org #8000
int_im2_vector_table:
    assert int_handler == 0x7f7f
    .257 db #7f ; by Z80 user manual int vector is I * 256 + (D & 0xFE)
                ; but by other references and by T80/A-Z80 implementation int vector is I * 256 + D
                ; so we just play safe and use symmetric int handler address and vector table with one extra byte

main:
    di                              ;
    ld sp, stack_top                ;
    ld (var_basic_iy), iy           ; save IY as it required for BASIC/TRDOS calls
    ld a, high int_im2_vector_table ; set IM2 interrupt table address (#8000-#8100)
    ld i, a                         ; ...
    im 2                            ; ...
    xor a                           ; set black border
    out (#fe), a                    ; ...
    ld a, #10                       ; page BASIC48
    ld bc, #7ffd                    ; ...
    out (c), a                      ; ...
    call device_detect_cpu_int      ;
    call uart_init                  ;
    call input_detect_kempston      ;
    call play_file                  ; file may be already loaded in ram
    call file_load_catalogue        ;
    call screen_select_files        ;
    ld iy, file_menu                ;
    call menu_first_draw            ;
.loop:
    ei : halt
    call input_process              ;
    ld iy, file_menu                ;
    call menu_handle_input          ;
    jp .loop                        ;


play_file:
    ld ix, file_base_addr            ;
    call smf_parse                   ;
    ret nz                           ;
    call screen_select_player        ;
    call player_loop                 ;
    call screen_select_files         ;
    ld iy, file_menu                 ;
    call menu_draw                   ;
    ld a, (var_player_nextfile_flag) ; if nextfile flag is set - load next file
    dec a                            ; ...
    ret nz                           ; ... or exit if isn't set
.load_next_file:
    ld (var_player_nextfile_flag), a ; reset nextfile flag
    ld b, LOAD_NEXT_FILE_DELAY       ; just cosmetic delay
1:  ei : halt                        ; ...
    djnz 1b                          ; ...
    ld a, INPUT_KEY_DOWN             ; move cursor down
    call input_simulate_keypress     ; ...
    call menu_handle_input           ; ...
    ld b, LOAD_NEXT_FILE_DELAY       ; just cosmetic delay
1:  ei : halt                        ; ...
    djnz 1b                          ; ...
    ld a, INPUT_KEY_ACT              ; load file
    call input_simulate_keypress     ; ...
    jp menu_handle_input             ; ...


; IN  - DE - entry number (assume < 128)
file_menu_callback:
    push de
    call file_load
    call play_file
    pop de
    ret

    include "input.asm"
    include "menu.asm"
    include "file.asm"
    include "uart.asm"
    include "math.asm"
    include "smf.asm"
    include "player.asm"
    include "draw.asm"
    include "device.asm"
    include "screen.asm"
    include "vis.asm"

    include "udg.asm"
    include "strings.asm"

    include "variables.asm"

file_menu: menu_t file_menu_generator 0 file_menu_callback LAYOUT_FILEMENU_X LAYOUT_FILEMENU_Y LAYOUT_FILEMENU_LINES LAYOUT_FILEMENU_COLUMNS


buildversion:
    ifdef VERSION_DEF
    db VERSION_DEF, 0
    else
    db 0
    endif
builddate:
    db __DATE__, " ", __TIME__, 0
    db "Code end",0
end:
    display "Code entrypoint=", main, " start=", begin, " end=",end, " len=", /d, end-begin

    assert $ < stack_bottom
    org #BF00
stack_bottom:
    org #BFFF
stack_top:


    export begin
    export end
    export main
    export stack_top
    savebin "main.bin", begin, end-begin
