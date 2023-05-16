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
    MACRO LD_ATTR_ADDRESS _reg, _yyxx
        lua allpass
            _pc("ld _reg, " .. screen_address_attr((_c("_yyxx")&0xff)*8, (_c("_yyxx")>>8)*8))
        endlua
    ENDM

    page 0
    org int_handler-(variables0_end-begin)
    assert $ >= #6000
begin:
    db "Code begin",0
    include "variables_low.asm"
variables0_end:

    org #7f7f
int_handler:
    push af                   ;
    ld a, (var_int_counter)   ;
    inc a                     ;
    ld (var_int_counter), a   ;
    pop af                    ;
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
    ld (var_basic_iy), iy           ; save IY as it's required for BASIC/TRDOS calls
    ld a, high int_im2_vector_table ; set IM2 interrupt table address (#8000-#8100)
    ld i, a                         ; ...
    im 2                            ; ...
    ld a, #10                       ; page BASIC48
    ld bc, #7ffd                    ; ...
    out (c), a                      ; ...
    call device_detect_cpu_int      ;
    call uart_init                  ;
    call input_detect_kempston      ;
    ld iy, main_menu                ;
    call menu_init                  ;
    ld iy, file_menu                ;
    call menu_init                  ;
    call screen_select_menu         ;
    call play_file                  ; file may be already loaded in ram
    xor a                           ; set black border
    out (#fe), a                    ; ...
.loop:
    ei : halt                       ;
    call input_process              ;
    ld a, (var_input_key)           ;
    cp INPUT_KEY_BACK               ;
    call z, menu_main_file_toggle   ;
    ld iy, (var_current_menu_ptr)   ;
    call menu_handle_input          ;
    jp .loop                        ;


exit:
    xor a        ; page BASIC128
    ld bc, #7ffd ; ...
    out (c), a   ; ...
    out (#fe), a ;
    rst 0        ;


help:
    call screen_select_help                   ;
.patch_int:
    ld a, (int_handler)                       ;
    push af                                   ;
    ld a, #c9                                 ; ret
    ld (int_handler), a                       ;
.patch_for_machine                            ;
    ld a, (var_lines_after_int_before_screen) ;
    add 121-1                                 ; 121th line on image - 1 line of correction
    ld (.A+1), a                              ;
    ld a, (var_horizontal_align+0)            ;
    ld (.B+1), a                              ;
    ld a, (var_horizontal_align+1)            ;
    ld (.B+2), a                              ;
    ld a, (var_tstates_per_line+0) : ld l, a  ;
    ld a, (var_tstates_per_line+1) : ld h, a  ;
    push hl                                   ;
    ld bc, -24                                ; number of tstates, see .border_lines_loop
    add hl, bc                                ;
    ld a, l : ld (.C+1), a                    ;
    ld a, h : ld (.C+2), a                    ;
    pop hl                                    ;
    ld bc, -64                                ; number of tstates, see .border_lines_loop
    add hl, bc                                ;
    ld a, l : ld (.D+1), a                    ;
    ld a, h : ld (.D+2), a                    ;
.loop:                                        ;
    ld e, 5                                   ;
.A  ld d, 0                                   ; self modifying code! See above
.B  ld hl, 0                                  ; self modifying code! See above
    ei : halt                                 ;
    call delay_tstate         ; (hl)          ; delay to align to next line beginning
.border_lines_loop:
.C  ld hl, 0                  ; (10)          ; 24 + HL T-states * D. Self modifying code! See above
    call delay_tstate         ; (hl)          ; ...
    dec d                     ; (4)           ; ...
    jp nz, .border_lines_loop ; (10)          ; ...
    ld a, LAYOUT_HELP_BORDER  ; (7)           ; 64 + HL T-states
    out (#fe), a              ; (11)          ; ...
.D  ld hl, 0                  ; (10)          ; ... self modifying code! See above
    call delay_tstate         ; (hl)          ; ...
    xor a                     ; (4)           ; ...
    dec e                     ; (4)           ; ...
    ld d, 7                   ; (7)           ; ...
    out (#fe), a              ; (11)          ; ...
    jp nz, .border_lines_loop ; (10)          ; ...
.process:
    call input_process                        ;
    ld a, (var_input_key)                     ;
    cp INPUT_KEY_BACK                         ;
    jr nz, .loop                              ;
.unpatch_int:
    pop af                                    ;
    ld (int_handler), a                       ;
    ei                                        ;
.exit
    jp screen_redraw                          ;


menu_main_file_toggle:
    ld a, (var_current_menu)      ;
    xor 1                         ;
    ld (var_current_menu), a      ;

menu_main_file_set_style:
    ld a, (var_current_menu)      ;
    or a                          ;
    jp nz, .select_file_menu      ;
.select_main_menu:
    ld iy, file_menu              ;
    call menu_style_inactive      ;
    ld iy, main_menu              ;
    ld (var_current_menu_ptr), iy ;
    jp menu_style_active          ;
.select_file_menu:
    ld iy, main_menu              ;
    call menu_style_inactive      ;
    ld iy, file_menu              ;
    ld (var_current_menu_ptr), iy ;
    jp menu_style_active          ;


play_file:
    ld ix, file_base_addr            ;
    call smf_parse                   ;
    jr z, 1f                         ;
    ld a, LAYOYT_ERR_FE              ;
    out (#fe), a                     ;
    ret                              ;
1:  call screen_select_player        ;
    call player_loop                 ;
    call screen_select_menu          ;
    ld a, (var_player_prevfile_flag) ; if prev flag is set - load prev file
    dec a                            ; ...
    jr z, .load_prev_file            ; ...
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
.load_prev_file:
    ld (var_player_prevfile_flag), a ; reset prevfile flag
    ld b, LOAD_NEXT_FILE_DELAY       ; just cosmetic delay
1:  ei : halt                        ; ...
    djnz 1b                          ; ...
    ld a, INPUT_KEY_UP               ; move cursor up
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
    call file_load      ;
    jp z, play_file     ; Z=0 - ok
    ld a, LAYOYT_ERR_FE ;
    out (#fe), a        ;
    ret                 ;


; IN  - DE - entry number
main_menu_callback:
    ld a, e                     ;
.bdi_drive:
    cp 3+1                      ;
    jr nc, .help                ;
    ld (var_current_drive), a   ;
    call file_load_catalogue    ;
    ld iy, file_menu            ;
    call menu_init              ;
    call menu_draw              ;
    call menu_main_file_toggle  ;
    ret
.help:
    cp 4                        ;
    jr nz, .exit                ;
    call help                   ;
    ret                         ;
.exit:
    cp 5                        ;
    jr nz, .unhandled_menu_item ;
    jp exit                     ;
.unhandled_menu_item:
    ret                         ;


; IN  - DE - entry number
; OUT -  F - NZ when ok, Z when not ok
; OUT - IX - pointer to 0-terminated string
main_menu_generator:
    ld hl, .entries_count-1 ; exit if DE >= entries_count
    xor a                   ; ...
    sbc hl, de              ; ...
    jp nc, 1f               ; ...
    xor a                   ; ... Z=1
    ret                     ; ...
1:  push de                 ;
    ld ix, .entries         ;
    sla e : rl d            ;
    add ix, de              ;
    ld e, (ix+0)            ;
    ld d, (ix+1)            ;
    ld ixl, e : ld ixh, d   ;
    pop de                  ;
    or 1                    ; Z=0
    ret                     ;
.entries:
    DW str_drive_a
    DW str_drive_b
    DW str_drive_c
    DW str_drive_d
    ; DW str_divmmc
    ; DW str_zxmmc
    ; DW str_zcontroller
    DW str_help
    DW str_exit
.entries_count = ($-.entries)/2


    include "rle_unpack.asm"
    include "delay_tstate.asm"
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

file_menu: menu_t file_menu_generator 0 file_menu_callback LAYOUT_FILEMENU_Y LAYOUT_FILEMENU_X LAYOUT_FILEMENU_LINES LAYOUT_FILEMENU_COLUMNS
main_menu: menu_t main_menu_generator 0 main_menu_callback LAYOUT_MAINMENU_Y LAYOUT_MAINMENU_X LAYOUT_MAINMENU_LINES LAYOUT_MAINMENU_COLUMNS


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
