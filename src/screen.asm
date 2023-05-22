screens_base    equ #C000
screens_page    equ 7
screen_menu_ptr equ #C002
screen_play_ptr equ #C004
screen_help_ptr equ #C006

    export screens_base
    export screens_page


; IN  - DE - pointer to pointer to rle-packed screen data
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
screen_load:
    ld a, #10 + screens_page                  ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
    ld h, (ix+1)                              ;
    ld l, (ix+0)                              ;
    ld de, #4000                              ;
    call rle_unpack                           ;
    ld a, #10                                 ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
    ret                                       ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
screen_select_menu:
    ld hl, .load                              ;
    ld (var_current_screen), hl               ;
.load:
    ld ix, screen_menu_ptr                    ;
    call screen_load                          ;
.print:
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_VERSION ;
    ld ix, buildversion                       ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_FREQ    ;
    ld a, (var_device.cpu_freq)               ;
    cp CPU_3_5_MHZ  : jr nz, 1f : ld ix, str_3_5_mhz  : jr 2f ;
1:  cp CPU_3_54_MHZ : jr nz, 1f : ld ix, str_3_54_mhz : jr 2f ;
1:  cp CPU_7_MHZ    : jr nz, 1f : ld ix, str_7_mhz    : jr 2f ;
1:  cp CPU_14_MHZ   : jr nz, 1f : ld ix, str_14_mhz   : jr 2f ;
1:  cp CPU_28_MHZ   : jr nz, 3f : ld ix, str_28_mhz   : jr 2f ;
2:  call print_string0                        ;
3:  inc hl                                    ;
    ld a, (var_device.int_type)               ;
    cp INT_50_HZ : jr nz, 1f : ld ix, str_50_hz : jr 2f ;
1:  cp INT_49_HZ : jr nz, 1f : ld ix, str_49_hz : jr 2f ;
1:  cp INT_48_HZ : jr nz, 3f : ld ix, str_48_hz : jr 2f ;
2:  call print_string0                        ;
3:
.menus:
    ld iy, main_menu                          ;
    call menu_draw                            ;
    ld iy, file_menu                          ;
    call menu_draw                            ;
    call menu_main_file_set_style             ;
    ret                                       ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
screen_select_player:
    ld hl, .load                              ;
    ld (var_current_screen), hl               ;
.load:
    ld ix, screen_play_ptr                    ;
    call screen_load                          ;
.print:
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_TITLE        ;
    ld ix, str_untitled                       ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_FILENAME     ;
    ld ix, str_unnamed                        ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER        ;
    ld ix, str_zerotimer                      ;
    call print_string0                        ;
    ret                                       ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
screen_select_help:
    ld hl, .load                              ;
    ld (var_current_screen), hl               ;
.load:
    ld ix, screen_help_ptr                    ;
    call screen_load                          ;
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    ret                                       ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
screen_redraw:
    ld hl, (var_current_screen)               ;
    jp (hl)                                   ;
