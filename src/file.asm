; Page         128  +3
; 0 000
; 1 001        slow
; 2 010 0x8000
; 3 011        slow
; 4 100             slow
; 5 101 0x4000 slow slow
; 6 110             slow
; 7 111 altscr slow slow

    align 8
file_pages: db #10, #14, #16, #13

file_base_addr equ #c000
file_page_size equ #4000


; IN  - HL - file position
; OUT -  A - data
; OUT - HL - next file position
; OUT -  F - garbage
; OUT - BC - garbage
file_get_next_byte:
    ld a, h                          ; compare requested page with current page
    and #c0                          ; ... page_number = position[7:6]
.pg:cp #0f                           ; ... self modifying code! see bellow and file_load
    jp z, .get                       ; ...
.switch_page:
    ld (.pg+1), a                    ;
    ld bc, file_pages                ; A = *(file_pages + (page_number >> 6))
    rlca : rlca                      ; ...
    add a, c                         ; ...
    ld c, a                          ; ...
    ld a, (bc)                       ; ...
    ld bc, #7ffd                     ;
    out (c), a                       ;
.get:
    ld a, h                          ; position = position[5:0]
    and #3f                          ; ...
    add a, high file_base_addr       ; A = *(base_addr + position)
    ld b, a                          ; ...
    ld c, l                          ; ...
    ld a, (bc)                       ; ...
    inc hl                           ; position++
    ret                              ;



trdos_sector_size            equ 256
trdos_max_files              equ 128
trdos_file_header_size       equ 16
trdos_catalogue_sectors      equ (trdos_max_files*trdos_file_header_size)/trdos_sector_size

trdos_var_next_sector        equ #5cf4
trdos_var_next_track         equ #5cf5
trdos_var_basic_interceptor  equ #5cc2
trdos_var_err_sp             equ #5c3d
trdos_var_current_drive      equ #5d19

trdos_entrypoint_commandline equ #3d00
trdos_entrypoint_basic_cmd   equ #3d03
trdos_entrypoint_chan_in     equ #3d06
trdos_entrypoint_chan_out    equ #3d0d
trdos_entrypoint_exec_fun    equ #3d13 ; IN - C - function number
trdos_entrypoint_init        equ #3d21
trdos_entrypoint_jump        equ #3d2f

trdos_fun_reset_vg           equ #00
trdos_fun_select_drive       equ #01 ; IN - A - drive number
trdos_fun_select_track       equ #02 ; IN - A - track number
trdos_fun_select_sector      equ #03 ; IN - A - sector number
trdos_fun_set_buffer_addr    equ #04 ; IN - HL - buffer address
trdos_fun_read_block         equ #05 ; IN - HL - dst addr, IN - B - sectors count, IN - D - track number, IN - E - sector number
trdos_fun_write_block        equ #06 ; IN - HL - src addr, IN - B - sectors count, IN - D - track number, IN - E - sector number
trdos_fun_print_dir          equ #07 ; IN - A - channel number
trdos_fun_read_file_header   equ #08 ; IN - A - file number
trdos_fun_write_file_header  equ #09 ; IN - A - file number
trdos_fun_find_file          equ #0a ; OUT - C - file number
trdos_fun_write_code_file    equ #0b ; IN - HL - src addr, DE - len
trdos_fun_write_basic_file   equ #0c ;
trdos_fun_exit               equ #0d
trdos_fun_load_file          equ #0e ; IN - A == #00 - addr/len from cat ; A == #03 - HL - addr, DE - len ; A == #FF - HL - addr, len from cat
trdos_fun_delete_file        equ #12
trdos_fun_set_file_header    equ #13 ; IN - HL - src addr
trdos_fun_get_file_header    equ #14 ; IN - HL - dst addr
trdos_fun_scan_bad_track     equ #15 ; IN - D - sector number
trdos_fun_select_side_0      equ #16
trdos_fun_select_side_1      equ #17
trdos_fun_reconfig_floppy    equ #18


trdos_basic_interceptor:
    ex (sp), hl                      ;
    push af                          ;
    push de                          ;
    push hl                          ;
    ld de, #0d6b                     ; #0d6b - clear screen procedure in basic48 rom
    xor a                            ;
    sbc hl, de                       ;
    jr z, .handle_screen_clear       ;
    pop hl                           ;
    pop de                           ;
    pop af                           ;
    ex (sp), hl                      ;
    ret                              ;
.handle_screen_clear:
    pop hl                           ;
    pop de                           ;
    ld a, 1                          ;
    ld (var_trdos_cleared_screen), a ; var_trdos_cleared_screen=1
    pop af                           ;
    ld hl, #0d6e                     ; do not clear all screen, just clear low area
    ex (sp), hl                      ;
    ret                              ;


trdos_err_handler:
    ld a, LAYOYT_ERR_FE     ;
    out (#fe), a            ;
    ld a, (iy)              ; iy = &err_nr
    inc a                   ;
    ld (var_trdos_error), a ;
    ld a, #ff               ; reset error code
    ld (iy), a              ;
    ret                     ;


; OUT -  F - Z when ok, NZ when not ok
trdos_exec_fun:
    push iy                                ;
    push af                                ;
    xor a                                  ;
    ld (var_trdos_error), a                ;
.setup_basic_interceptor:
    ld a, #c3                              ; "jp trdos_basic_interceptor"
    ld (trdos_var_basic_interceptor+0), a  ; ...
    ld iy, trdos_basic_interceptor         ; ...
    ld (trdos_var_basic_interceptor+1), iy ; ...
    pop af                                 ;
.setup_error_handler:
    ld iy, (trdos_var_err_sp)              ;
    ld (.A+2), iy                          ;
    ld iy, .call_end                       ;
    push iy                                ;
    ld iy, trdos_err_handler               ;
    push iy                                ;
    ld (trdos_var_err_sp), sp              ;
.call:
    ld iy, (var_basic_iy)                  ; im1 require IY
    im 1                                   ; trdos may crash with im != 1
    call trdos_entrypoint_exec_fun         ;
    pop af                                 ;
    pop af                                 ;
.call_end:
    ld a, high int_im2_vector_table        ; set back IM2 interrupt table address (trdos may change it)
    ld i, a                                ; ...
    im 2                                   ; ...
    ld (var_basic_iy), iy                  ; save IY back
.restore_error_handler:
.A  ld iy, 0                               ; self modifying code! see .setup_error_handler
    ld (trdos_var_err_sp), iy              ;
.restore_basic_interceptor:
    ld a, #c9                              ; "ret"
    ld (trdos_var_basic_interceptor+0), a  ; ...
.restore_screen:
    ld a, (var_trdos_cleared_screen)       ; if (cleared_screen != 0) redraw screen
    or a                                   ; ...
    jr z, .exit                            ; ...
    xor a                                  ; ...
    ld (var_trdos_cleared_screen), a       ; ...
    call screen_redraw                     ; ...
.exit:
    pop iy                                 ;
    ld a, (var_trdos_error)                ; check error code != 0
    or a                                   ;
    ret                                    ;


; OUT -  F - Z when ok, NZ when not ok
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
file_load_catalogue:
    xor a                                 ; set zero byte to first file name - same as clearing file list
    ld (file_buffer), a                   ; ...
    ld c, trdos_fun_select_drive          ; select drive A/B/C/D
    ld a, (var_current_drive)             ; ...
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    ld c, trdos_fun_reconfig_floppy       ; init floppy disk parameters
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    ld c, trdos_fun_read_block            ; read file table
    ld hl, file_buffer                    ; ...
    ld b, trdos_catalogue_sectors         ; ...
    ld de, #0000                          ; ...
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    call file_catalogue_optimize          ;
    call file_catalogue_format_extensions ;
    xor a                                 ; Z=1
    ret                                   ;

; OUT - AF - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
file_catalogue_optimize:          ; reorganize catalogue to skip all deleted files
    ld b, trdos_max_files         ;
    ld de, trdos_file_header_size ;
    ld hl, file_buffer            ; HL = pointer for entries_all
    ld ix, file_buffer            ; IX = pointer for entries_good
.loop:
    ld a, (hl)                    ;
    or a                          ; if first byte == #00 - no entry
    jr z, .bad_entry              ; ...
    dec a                         ; if first byte == #01 - deleted entry
    jr z, .bad_entry              ; ...
.good_entry:
    ld a, (hl)                    ; save good entry
    ld (ix), a                    ; ...
    inc hl                        ; ...
    inc ix                        ; ...
    dec e                         ; ...
    jr nz, .good_entry            ; ...
    ld e, trdos_file_header_size  ;
    djnz .loop                    ;
    jp .exit                      ;
.bad_entry:
    add hl, de                    ; HL += trdos_file_header_size
    djnz .loop                    ;
.exit:
    xor a                         ; place NULL byte to the last entry. This entry may be +1 byte above trdos_max_files*trdos_file_header_size
    ld (ix), a                    ; ... boundary. So file_buffer should be at least trdos_max_files*trdos_file_header_size+1 bytes
    ret                           ;

; OUT - AF - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
file_catalogue_format_extensions:
    ld b, trdos_max_files         ;
    ld de, trdos_file_header_size ;
    ld ix, file_buffer            ;
.loop:
    ld a, (ix+9)                  ; if 2nd and 3rd extensions symbols are in ascii range - assume extension is 3-chars-wide
    cp '0'                        ; ...
    jp c, .invalid_extension      ; ...
    cp 'z'+1                      ; ...
    jp nc, .invalid_extension     ; ...
    ld a, (ix+10)                 ; ...
    cp '0'                        ; ...
    jp c, .invalid_extension      ; ...
    cp 'z'+1                      ; ...
    jp nc, .invalid_extension     ; ...
    add ix, de                    ;
    djnz .loop                    ;
.invalid_extension:
    ld a, ' '                     ; if extension is 1-char wide - write space to 2nd and 3rd bytes
    ld (ix+9), a                  ; ...
    ld (ix+10), a                 ; ...
    add ix, de                    ;
    djnz .loop                    ;
    ret                           ;


; IN  - IX - pointer to byte after 3-char file extension string
; OUT - A  - icon
; OUT - F  - garbage
file_menu_generator_get_icon:
.check_mid_extension:
    ld a, (ix-3)                         ; if extension is "mid" - set appropriate icon
    cp 'm' : jr z, 1f                    ;
    cp 'M' : jr nz, .check_rmi_extension ;
1:  ld a, (ix-2)                         ;
    cp 'i' : jr z, 1f                    ;
    cp 'I' : jr nz, .check_rmi_extension ;
1:  ld a, (ix-1)                         ;
    cp 'd' : jr z, .set_icon             ;
    cp 'D' : jr z, .set_icon             ;
.check_rmi_extension:
    ld a, (ix-3)                         ; if extension is "rmi" - set appropriate icon
    cp 'r' : jr z, 1f                    ;
    cp 'R' : jr nz, .no_icon             ;
1:  ld a, (ix-2)                         ;
    cp 'm' : jr z, 1f                    ;
    cp 'M' : jr nz, .no_icon             ;
1:  ld a, (ix-1)                         ;
    cp 'i' : jr z, .set_icon             ;
    cp 'I' : jr z, .set_icon             ;
.no_icon:
    ld a, ' '                            ; if extension isn't recognized - set empty icon (space)
    ret                                  ;
.set_icon:
    ld a, udg_melody                     ;
    ret                                  ;


; IN  - DE - entry number
; OUT -  F - NZ when ok, Z when not ok
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
file_menu_generator:
    xor a                     ; if (entry_number >= 128) - return not ok
    or d                      ; ...
    jp z, 1f                  ; ...
    xor a                     ; ... set Z flag
    ret                       ; ...
1:  ld a, e                   ; ...
    cp trdos_max_files        ; ...
    jp c, 1f                  ; ...
    xor a                     ; ... set Z flag
    ret                       ; ...
1:  sla e : rl d              ; entry_number = entry_number * 16
    sla e : rl d              ; ...
    sla e : rl d              ; ...
    sla e : rl d              ; ...
    ld hl, file_buffer        ; HL = file_buffer + entry_number * 16
    add hl, de                ; ...
    ld a, (hl)                ; if first byte == 0x00 or 0xFF - return error (no entry)
    or a                      ; ...
    ret z                     ; ...
    inc a                     ; ...
    ret z                     ; ...
    ld ix, tmp_menu_string+2  ;
    ld b, 8                   ;
.filenamecopy:                ;
    ld a, (hl)                ;
    ld (ix), a                ;
    inc hl                    ;
    inc ix                    ;
    djnz .filenamecopy        ;
    ld a, '.'                 ;
    ld (ix), a                ;
    inc ix                    ;
    ld b, 3                   ;
.extcopy:
    ld a, (hl)                ;
    ld (ix), a                ;
    inc hl                    ;
    inc ix                    ;
    djnz .extcopy             ;
.filesize:
    ld a, ' '                 ;
    ld (ix), a                ;
    ld a, '$'                 ;
    ld (ix+1), a              ;
    ld a, (hl)                ; print file_size[2]
    and #f0                   ; ...
    .4 rra                    ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (ix+4), a              ; ...
    ld a, (hl)                ; print file_size[3]
    and #0f                   ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (ix+5), a              ; ...
    inc hl                    ;
    ld a, (hl)                ; print file_size[0]
    and #f0                   ; ...
    .4 rra                    ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (ix+2), a              ; ...
    ld a, (hl)                ; print file_size[1]
    and #0f                   ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (ix+3), a              ; ...
.null:
    xor a                     ; write NULL byte to the end of string
    ld (ix+6), a              ; ...
.icon:
    call file_menu_generator_get_icon ; A = icon
    ld ix, tmp_menu_string    ;
    ld (ix), a                ;
    ld a, ' '                 ; space
    ld (ix+1), a              ;
    or 1                      ; set NZ flag
    ret                       ;


; OUT - IX - pointer to 0-terminated string
; OUT - AF - garbage
file_get_current_file_name:
    ld a, (var_current_file_number+0) ;
    ld e, a                           ;
    ld a, (var_current_file_number+1) ;
    ld d, a                           ;
    call file_menu_generator          ;
    .2 inc ix                         ; skip icon
    xor a                             ; remove size
    ld (ix+8+1+3), 0                  ; ...
    ret                               ;

; OUT - BC - file size
file_get_current_file_size:
    ld a, (var_current_file_size+0)   ;
    ld c, a                           ;
    ld a, (var_current_file_size+1)   ;
    ld b, a                           ;
    ret                               ;


; IN  -  E - file number [0..127]
; OUT -  F - Z when ok, NZ when not ok
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
file_load:
    xor a                                   ;
    ld (var_current_file_number+1), a       ;
    ld a, e                                 ;
    ld (var_current_file_number+0), a       ;
.select_page:
    ld a, (file_pages)                      ; select first page for file
    ld bc, #7ffd                            ; ...
    out (c), a                              ; ...
.load_file_params:
    sla e : rl d                            ; entry_number = entry_number * 16
    sla e : rl d                            ; ...
    sla e : rl d                            ; ...
    sla e : rl d                            ; ...
    ld ix, file_buffer                      ; IX = file_buffer + entry_number * 16
    add ix, de                              ; ...
    ld a, (ix+#0)                           ; if name[0] == NULL - incorrect entry, exit
    or a                                    ; ...
    jr nz, 1f                               ; ...
    or 1                                    ; ... set NZ flag
    ret                                     ; ...
1:  ld a, (ix+#b)                           ; file size in bytes
    ld (var_current_file_size+0), a         ; ...
    ld a, (ix+#c)                           ; ...
    ld (var_current_file_size+1), a         ; ...
    ld b, (ix+#d)                           ; sectors count
    ld e, (ix+#e)                           ; sector n
    ld d, (ix+#f)                           ; track n
    ld c, trdos_fun_read_block              ;
    ld hl, file_pages                       ; HL = pointer to pages table
.loop:
    push bc                                 ;
    push hl                                 ;
    ld a, file_page_size/trdos_sector_size  ; if (sectors_count > max) sector_count = max
    cp b                                    ; ...
    jp nc, 1f                               ; ...
    ld b, a                                 ; ...
1:  ld hl, file_base_addr                   ;
    call trdos_exec_fun                     ; memcpy( hl, de, b )
    pop hl                                  ;
    pop bc                                  ;
    ret nz                                  ;
.loop_check_next_page:
    ld a, b                                 ; B = B - 64
    sub file_page_size/trdos_sector_size    ; ...
    ld b, a                                 ; ...
    jp c, .exit                             ; if (B <= 0) exit
    jp z, .exit                             ; ...
    ld d, b                                 ;
    inc hl                                  ; set next page
    ld a, (hl)                              ; ...
    ld bc, #7ffd                            ; ...
    out (c), a                              ; ...
    ld b, d                                 ; B = sectors left
    ld c, trdos_fun_read_block              ;
    ld de, (trdos_var_next_sector)          ; DE = next position
    jp .loop                                ;
.exit:
    ld a, #0f                               ; reset page
    ld (file_get_next_byte.pg+1), a         ; ...
    xor a                                   ; Z=1
    ret                                     ;


file_init:
    ld a, (trdos_var_current_drive) ;
    ld (var_boot_drive), a          ;
    ld (var_current_drive), a       ;
    ld a, (var_trdos_present)       ; if there is no trdos - stub trdos_exec_fun()
    or a                            ;
    ret nz                          ;
    ld hl, trdos_exec_fun           ; ...
    ld (hl), #f6 : inc hl           ; ... or 1
    ld (hl), #01 : inc hl           ; ...
    ld (hl), #c9                    ; ... ret
    ret                             ;
