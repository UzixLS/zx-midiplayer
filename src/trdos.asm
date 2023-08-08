; TR-DOS directory entry:
; 0......7 8 9  B  D E F
; NNNNNNNN T AA LL C S T
; N  - file name
; T  - file type
; AA - start address for "C" file, full file length for "B" file
; LL - full file lenghth for "C" file, program length for "B" file
; C  - sectors count
; S  - starting sector
; T  - starting tracl


trdos_disks                  equ 4
trdos_sector_size            equ 256
trdos_max_files              equ 128
trdos_file_header_size       equ 16
trdos_directory_sectors      equ (trdos_max_files*trdos_file_header_size)/trdos_sector_size

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


; OUT -  F - Z on success, NZ on fail
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


; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
trdos_directory_load:
    xor a                                 ; set zero byte to first file name - same as clearing file list
    ld (disk_buffer), a                   ; ...
    ld c, trdos_fun_select_drive          ; select drive A/B/C/D
    ld a, (var_disks.current_n)           ; ...
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    ld c, trdos_fun_reconfig_floppy       ; init floppy disk parameters
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    ld c, trdos_fun_read_block            ; read file table
    ld hl, disk_buffer                    ; ...
    ld b, trdos_directory_sectors         ; ...
    ld de, #0000                          ; ...
    call trdos_exec_fun                   ; ...
    ret nz                                ;
    call trdos_directory_optimize         ;
    call trdos_directory_format_extensions ;
    xor a                                 ; Z=1
    ret                                   ;


; OUT - AF - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
trdos_directory_optimize:         ; reorganize directory to skip all deleted files
    ld b, trdos_max_files         ;
    ld de, trdos_file_header_size ;
    ld hl, disk_buffer            ; HL = pointer for entries_all
    ld ix, disk_buffer            ; IX = pointer for entries_good
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
    jr .exit                      ;
.bad_entry:
    add hl, de                    ; HL += trdos_file_header_size
    djnz .loop                    ;
.exit:
    xor a                         ; place NULL byte to the last entry. This entry may be +1 byte above trdos_max_files*trdos_file_header_size
    ld (ix), a                    ; ... boundary. So disk_buffer should be at least trdos_max_files*trdos_file_header_size+1 bytes
    ret                           ;


; OUT - AF - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
trdos_directory_format_extensions:
    ld b, trdos_max_files         ;
    ld de, trdos_file_header_size ;
    ld ix, disk_buffer            ;
.loop:
    ld a, (ix+9)                  ; if 2nd and 3rd extensions symbols are in ascii range - assume extension is 3-chars-wide
    cp '0'                        ; ...
    jr c, .invalid_extension      ; ...
    cp 'z'+1                      ; ...
    jr nc, .invalid_extension     ; ...
    ld a, (ix+10)                 ; ...
    cp '0'                        ; ...
    jr c, .invalid_extension      ; ...
    cp 'z'+1                      ; ...
    jr nc, .invalid_extension     ; ...
    add ix, de                    ;
    djnz .loop                    ;
.invalid_extension:
    ld a, ' '                     ; if extension is 1-char wide - write space to 2nd and 3rd bytes
    ld (ix+9), a                  ; ...
    ld (ix+10), a                 ; ...
    add ix, de                    ;
    djnz .loop                    ;
    ret                           ;


; IN  - DE - entry number (<128)
; OUT -  F - Z on success, NZ on fail
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
trdos_file_menu_generator:
    ex de, hl                 ; HL = disk_buffer + entry_number * 16
    .4 add hl, hl             ; ...
    ld de, disk_buffer        ; ...
    add hl, de                ; ...
    ld a, (hl)                ; if first byte == 0x00 or 0xFF - return error (no entry)
    or a                      ; ...
    jr z, .noentry            ; ...
    inc a                     ; ...
    jr z, .noentry            ; ...
    ld de, tmp_menu_string+2  ;
.name:
    ld bc, 8                  ;
    ldir                      ;
.dot:
    ld a, '.'                 ;
    ld (de), a                ;
    inc de                    ;
.ext:
    push hl                   ;
    ld c, 3                   ;
    ldir                      ;
.filesize:
    ld a, ' '                 ;
    ld (de), a                ;
    inc de                    ;
    ld a, '$'                 ;
    ld (de), a                ;
    inc de                    ;
    inc hl                    ;
    ld b, 2                   ;
1:  ld a, (hl)                ; hi
    and #f0                   ; ...
    .4 rra                    ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (de), a                ; ...
    inc de                    ; ...
    ld a, (hl)                ; lo
    and #0f                   ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (de), a                ; ...
    inc de                    ; ...
    dec hl                    ;
    djnz 1b                   ;
.null:
    xor a                     ; write NULL byte to the end of string
    ld (de), a                ; ...
.icon:
    pop hl                    ;
    call disks_get_icon_by_extension ; A = icon
    ld ix, tmp_menu_string    ;
    ld (ix), a                ;
    ld a, ' '                 ; space
    ld (ix+1), a              ;
    xor a                     ; set Z flag
    ret                       ;
.noentry:
    or 1                      ;
    ret                       ;


; IN  -  E - file number [0..127]
; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
trdos_file_load:
    xor a                                   ;
    ld (var_current_file_number+1), a       ;
    ld a, e                                 ;
    ld (var_current_file_number+0), a       ;
.load_file_params:
    sla e : rl d                            ; entry_number = entry_number * 16
    sla e : rl d                            ; ...
    sla e : rl d                            ; ...
    sla e : rl d                            ; ...
    ld hl, disk_buffer                      ; HL = disk_buffer + entry_number * 16
    add hl, de                              ; ...
    ld a, (hl)                              ; if name[0] == NULL - incorrect entry, exit
    or a                                    ; ...
    jr nz, 1f                               ; ...
    or 1                                    ; ... set NZ flag
    ret                                     ; ...
1:  ld de, var_current_file_name            ; copy file name
    ld bc, 8                                ; ...
    ldir                                    ; ...
    ld a, '.' : ld (de), a : inc de         ; ... '.'
    ld bc, 3                                ; ... extension
    ldir                                    ; ...
    ld b, (hl) : inc hl                     ; file size in bytes
    ld c, (hl) : inc hl                     ; ...
    ld (var_current_file_size), bc          ; ...
    ld b, (hl) : inc hl                     ; sectors count
    ld e, (hl) : inc hl                     ; sector n
    ld d, (hl) : inc hl                     ; track n
    ld c, trdos_fun_read_block              ;
    ld hl, 0                                ; HL = current_file_position
.loop:
    push hl                                 ;
    push bc                                 ;
    push bc                                 ;
    call file_switch_page                   ;
    pop bc                                  ;
    ld a, file_page_size/trdos_sector_size  ; if (sectors_count > max) sector_count = max
    cp b                                    ; ...
    jr nc, 1f                               ; ...
    ld b, a                                 ; ...
1:  ld hl, file_base_addr                   ;
    call trdos_exec_fun                     ; memcpy( hl, de, b )
    pop bc                                  ;
    pop hl                                  ;
    ret nz                                  ;
.loop_check_next_page:
    ld a, b                                 ; sectors_count -= 64
    sub file_page_size/trdos_sector_size    ; ...
    ld b, a                                 ; ...
    jr c, .exit                             ; if (sectors_count <= 0) exit
    jr z, .exit                             ; ...
    ld a, high file_page_size               ; current_file_position += page_size
    add a, h                                ; ...
    ld h, a                                 ; ...
    ld de, (trdos_var_next_sector)          ;
    jr .loop                                ;
.exit:
    xor a                                   ; set Z flag
    ret                                     ;


; OUT -  F - Z=1 (no)
; OUT -  A - 0
trdos_entry_is_directory:
    xor a                           ;
    ret                             ;


trdos_init:
    ld a, (var_trdos_present)       ;
    or a                            ;
    jr z, .no_trdos                 ;
.trdos_ok:
    ld a, (trdos_var_current_drive) ;
    ld (var_disks.boot_n), a        ;
    ld (var_disks.current_n), a     ;
    ret                             ;
.no_trdos:
    ld hl, trdos_exec_fun           ; if there is no trdos - stub trdos_exec_fun()
    ld (hl), #f6 : inc hl           ; ... or 1
    ld (hl), #01 : inc hl           ; ...
    ld (hl), #c9                    ; ... ret
    ret                             ;
