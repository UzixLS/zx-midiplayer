    ASSERT __SJASMPLUS__ >= 0x011402 ; SjASMPlus 1.20.2
    OPT --syntax=abf
    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION
    DEVICE ZXSPECTRUM128,stack_top

    includelua "lua/screen_address.lua"

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
    call load_screen0               ;
    ld iy, file_menu                ;
    call menu_first_draw            ;
.loop:
    ei : halt
    call input_process              ;
    ld iy, file_menu                ;
    call menu_handle_input          ;
    jp .loop                        ;


play_file:
    ld ix, file_base_addr     ;
    call smf_parse            ;
    ret nz                    ;
    call load_screen1         ;
    call player_loop          ;
    call load_screen0         ;
    ld iy, file_menu          ;
    call menu_draw            ;
    ret                       ;


; IN  - DE - entry number (assume < 128)
file_menu_callback:
    push de
    call file_load
    call play_file
    pop de
    ret

    include "config.inc"
    include "layout.inc"

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
    ifdef VERSION
    db VERSION, 0
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
