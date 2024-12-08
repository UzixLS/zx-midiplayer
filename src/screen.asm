screens_base    equ #C000
screens_page    equ 1
screen_menu_ptr equ screens_base + 2
screen_play_ptr equ screens_base + 4
screen_help_ptr equ screens_base + 6

    export screens_base
    export screens_page


; IN  - HL - pointer to pointer to rle-packed screen data
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
screen_load:
    ld a, #10 + screens_page                  ;
    ld bc, #7ffd                              ;
    ld (bankm), a                             ;
    out (c), a                                ;
    ld e, (hl)                                ; src
    inc hl                                    ; ...
    ld d, (hl)                                ; ...
    ld hl, #4000                              ; dst
    ex de, hl                                 ;
    call rle_unpack                           ;
    ld a, #10                                 ;
    ld bc, #7ffd                              ;
    ld (bankm), a                             ;
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
    ld hl, screen_menu_ptr                    ;
    call screen_load                          ;
.print:
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_VERSION ;
    ld ix, str_version                        ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_FREQ    ;
    ld a, (var_device.cpu_freq)               ;
    cp CPU_3_5_MHZ  : jr nz, 1f : ld ix, str_3_5_mhz  : jr 2f ;
1:  cp CPU_3_54_MHZ : jr nz, 1f : ld ix, str_3_54_mhz : jr 2f ;
1:  cp CPU_7_MHZ    : jr nz, 1f : ld ix, str_7_mhz    : jr 2f ;
1:  cp CPU_14_MHZ   : jr nz, 1f : ld ix, str_14_mhz   : jr 2f ;
1:  cp CPU_28_MHZ   : jr nz, 3f : ld ix, str_28_mhz   : jr 2f ;
2:  call print_string0                        ;
3:  LD_SCREEN_ADDRESS hl, LAYOUT_INFO_INT     ;
    ld a, (var_device.int_type)               ;
    cp INT_50_HZ : jr nz, 1f : ld ix, str_50_hz : jr 2f ;
1:  cp INT_49_HZ : jr nz, 1f : ld ix, str_49_hz : jr 2f ;
1:  cp INT_48_HZ : jr nz, 3f : ld ix, str_48_hz : jr 2f ;
2:  call print_string0                        ;
3:
.menus:
    ld iy, main_menu                          ;
    call menu_draw                            ;
    ld iy, right_menu                         ;
    call menu_draw                            ;
    jp menu_main_right_set_style              ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
screen_select_player:
    ld hl, .load                              ;
    ld (var_current_screen), hl               ;
.load:
    ld hl, screen_play_ptr                    ;
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
    LD_SCREEN_ADDRESS hl, LAYOUT_SIZE-1       ;
    ld a, '$'                                 ;
    call print_char                           ;
    LD_SCREEN_ADDRESS hl, LAYOUT_TRACKS-1     ;
    ld a, '$'                                 ;
    call print_char                           ;
    LD_SCREEN_ADDRESS hl, LAYOUT_TEMPO-1      ;
    ld a, '$'                                 ;
    call print_char                           ;
    LD_SCREEN_ADDRESS hl, LAYOUT_PPQN-1       ;
    ld a, '$'                                 ;
    jp print_char                             ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
screen_select_help:
    ld hl, .load                              ;
    ld (var_current_screen), hl               ;
.load:
    ld hl, screen_help_ptr                    ;
    call screen_load                          ;
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    jp print_string0                          ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
screen_redraw:
    ld hl, (var_current_screen)               ;
    jp (hl)                                   ;
