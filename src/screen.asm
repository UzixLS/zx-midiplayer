screen_size  equ 6912
screen0      equ #C000
screen0_page equ 7
screen1      equ screen0 + screen_size
screen1_page equ 7

    export screen_size
    export screen0
    export screen1
    export screen0_page
    export screen1_page


screen_select_menu:
    ld hl, .load                              ;
    ld (var_screen_proc_addr), hl             ;
.load:
    ld a, #10 + screen0_page                  ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
    ld de, #4000                              ;
    ld hl, screen0                            ;
    ld bc, screen_size                        ;
    ldir                                      ;
    ld a, #10                                 ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
.print:
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_VERSION ;
    ld ix, buildversion                       ;
    call print_string0                        ;
    LD_SCREEN_ADDRESS hl, LAYOUT_INFO_FREQ    ;
    ld a, (var_cpu_freq)                      ;
    cp CPU_FREQ_3_5_MHZ  : jr nz, 1f : ld ix, str_3_5_mhz  : jr 2f ;
1:  cp CPU_FREQ_3_54_MHZ : jr nz, 1f : ld ix, str_3_54_mhz : jr 2f ;
1:  cp CPU_FREQ_7_MHZ    : jr nz, 1f : ld ix, str_7_mhz    : jr 2f ;
1:  cp CPU_FREQ_14_MHZ   : jr nz, 1f : ld ix, str_14_mhz   : jr 2f ;
1:  cp CPU_FREQ_28_MHZ   : jr nz, 3f : ld ix, str_28_mhz   : jr 2f ;
2:  call print_string0                        ;
3:  inc hl                                    ;
    ld a, (var_int_type)                      ;
    cp INT_50_HZ   : jr nz, 1f : ld ix, str_50_hz : jr 2f ;
1:  cp INT_48_8_HZ : jr nz, 3f : ld ix, str_48_hz : jr 2f ;
2:  call print_string0                        ;
3:
.menus:
    ld iy, main_menu                          ;
    call menu_draw                            ;
    ld iy, file_menu                          ;
    call menu_draw                            ;
    call menu_main_file_set_style             ;
    ret                                       ;


screen_select_player:
    ld hl, .load                              ;
    ld (var_screen_proc_addr), hl             ;
.load:
    ld a, #10 + screen1_page                  ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
    ld de, #4000                              ;
    ld hl, screen1                            ;
    ld bc, screen_size                        ;
    ldir                                      ;
    ld a, #10                                 ;
    ld bc, #7ffd                              ;
    out (c), a                                ;
.print:
    LD_SCREEN_ADDRESS hl, LAYOUT_HEAD         ;
    ld ix, str_head                           ;
    call print_string0                        ;
    ret                                       ;


screen_redraw:
    ld hl, (var_screen_proc_addr)
    jp (hl)
