    STRUCT player_state_t
flags            BYTE 0
last_int_counter BYTE 0
subseconds_l     BYTE 0
subseconds_h     BYTE 0
seconds_l        BYTE 0
seconds_h        BYTE 0
minutes_l        BYTE 0
minutes_h        BYTE 0
    ENDS

PLAYER_FLAG_TITLE_SET equ 0
PLAYER_FLAG_FF        equ 1



player_loop:
    xor a                                     ;
    ld (uart_txbuf_len), a                    ;
    ld (var_player_state.flags), a            ;
    ld (var_player_state.last_int_counter), a ;
    ld (var_player_state.subseconds_l), a     ;
    ld a, '0'                                 ;
    ld (var_player_state.subseconds_h), a     ;
    ld (var_player_state.seconds_l), a        ;
    ld (var_player_state.seconds_h), a        ;
    ld (var_player_state.minutes_l), a        ;
    ld (var_player_state.minutes_h), a        ;
.init:
    call player_reset_chip         ;
    call vis_init                  ;
    call file_get_current_file_name;
    call player_set_filename       ;
    call smf_get_bytes_left        ;
    call player_set_size           ;
    call smf_get_num_tracks        ;
    call player_set_tracks         ;
    call smf_get_ppqn              ;
    call player_set_ppqn           ;
    call smf_get_tempo             ;
    call player_set_tempo          ;
    call player_redraw_buttons     ;
    ld a, (var_int_counter)        ;
    ld (var_player_state.last_int_counter), a ;
.loop:
    call vis_process_frame         ;
    call player_update_timer       ;
    ld hl, var_player_state.last_int_counter ;
    ld a, (var_player_state.flags) ; if in fast forward mode - skip halt
    bit PLAYER_FLAG_FF, a          ; ...
    jp z, .no_ff                   ; ...
.ff:
    ld (var_input_no_beep), a      ;
    res PLAYER_FLAG_FF, a          ;
    ld (var_player_state.flags), a ;
    call player_redraw_buttons     ;
    ld a, (var_int_counter)        ;
    ld (hl), a                     ;
    jp .frame_start                ;
.no_ff:
    xor a                          ;
    ld (var_input_no_beep), a      ;
    ld a, (var_int_counter)        ; if (last_int_counter != current_int_counter) - skip halt
    cp (hl)                        ; ...
    jr nz, 1f                      ; ...
    xor a : out (#fe), a           ;
    halt                           ;
    inc a : out (#fe), a           ;
1:  inc (hl)                       ; increment last_int_counter
.frame_start:
    call uart_flush_txbuf          ;
    call input_process             ;
    ld a, b                        ;
    cp INPUT_KEY_RIGHT             ; fast forward while holding right key
    jr nz, 1f                      ; ...
    ld hl, var_player_state.flags  ; ...
    set PLAYER_FLAG_FF, (hl)       ; ...
    call player_redraw_buttons     ; ...
    jr .process_tracks             ; ...
1:  ld a, (var_input_key)          ;
    cp INPUT_KEY_BACK              ;
    jr z, .end                     ;
    cp INPUT_KEY_ACT               ;
    jr z, .load_next_file          ;
    cp INPUT_KEY_DOWN              ;
    jr z, .load_next_file          ;
    cp INPUT_KEY_UP                ;
    jr z, .load_prev_file          ;
.process_tracks:
    call smf_get_first_track       ;
    jr z, .load_next_file          ;
.process_current_track:
    call smf_process_track         ; A = status, HL = track position, BC = data len
    jp c, .next_track              ; if C == 1 (delayed) then go to the next track
    jp z, .next_track              ; if Z == 1 (no data) then go to the next track
.status_check:
    cp #ff                         ; do not send meta events to midi device
    jp nz, .vis                    ; ...
    call smf_handle_meta           ; ... instead, process it locally. HL = next track position
    jp .process_current_track      ; ...
.vis:
    call vis_process_command       ;
.status_send:
    ld ixh, b : ld ixl, c          ; IX = data len
    call uart_putc_txbuf           ; send status
.data_send:
    ld a, ixh                      ; if len == 0 then go for next status
    or ixl                         ; ...
    jr z, .process_current_track   ; ...
    call file_get_next_byte        ; A = data
    call uart_putc_txbuf           ; send data
    dec ix                         ; len--
    jp .data_send                  ; ...
.next_track:
    call smf_get_next_track        ;
    jp nz, .process_current_track  ;
    call smf_next_int              ;
    jp .loop                       ;
.load_prev_file:
    ld a, 1                          ;
    ld (var_player_prevfile_flag), a ;
    jr .end                          ;
.load_next_file:
    ld a, 1                          ;
    ld (var_player_nextfile_flag), a ;
.end:
    call uart_flush_txbuf            ;
    ; call player_reset_chip           ;
    ; ret                              ;


player_reset_chip:
    ld a, #ff                      ; issue reset status
    di : call uart_putc : ei       ; ...
    halt                           ; wait 20ms just for safety
    ld ixl, #b0                    ; set controller message for channels #0..#f
    ld a, ixl                      ;
.loop:
    di : call uart_putc : ei       ;
    ld a, 123                      ; 123 = All notes off (this message stops all the notes that are currently playing)
    di : call uart_putc : ei       ;
    xor a                          ; 0 = value
    di : call uart_putc : ei       ;
    inc ixl                        ;
    ld a, ixl                      ;
    cp #c0                         ;
    jp nz, .loop                   ;
    ret                            ;


; IN  - DE - string len
; IN  - HL - file position
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
player_set_title:
    ld ix, var_player_state.flags            ; if title already has been set - exit
    bit PLAYER_FLAG_TITLE_SET, (ix)          ; ...
    ret nz                                   ; ...
    set PLAYER_FLAG_TITLE_SET, (ix)          ; ...
    xor a                                    ; if (len > 255 || len == 0) exit
    or d                                     ; ...
    ret nz                                   ; ...
    or e                                     ; ...
    ret z                                    ; ...
    ld ixh, LAYOUT_TITLE_LEN                 ; IXH = maxlen
    ld ixl, e                                ; IXL = len
    LD_SCREEN_ADDRESS de, LAYOUT_TITLE       ;
.printloop:
    call file_get_next_byte                  ; A = char
    cp 32                                    ; if (char < 32 ' ' || char > 126 '~') - non printable
    jr c, 1f                                 ; ...
    cp 126+1                                 ; ...
    jr c, 2f                                 ; ...
1:  ld a, udg_nonprintable                   ; ...
2:  ex de, hl                                ;
    push de                                  ;
    call print_char                          ;
    pop de                                   ;
    ex de, hl                                ;
    dec ixh                                  ; maxlen--
    jr z, .title_is_too_long                 ;
    inc e                                    ; screen_position++
    dec ixl                                  ; len--
    jr nz, .printloop                        ;
    ex de, hl                                ;
.append_trailing_spaces:
    ld a, ' '                                ;
    call print_char                          ;
    inc l                                    ;
    dec ixh                                  ; maxlen--
    jr nz, .append_trailing_spaces           ;
    ret                                      ;
.title_is_too_long:
    dec ixl                                  ; if this was last char - just exit
    ret z                                    ; ...
    ex de, hl                                ; otherwise print elipsis at last position
    ld a, udg_ellipsis                       ; ...
    jp print_char                            ; ...


; IN  - A  - tracks value
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
player_set_tracks:
    push hl                              ;
    LD_SCREEN_ADDRESS hl, LAYOUT_TRACKS  ;
    call print_hex                       ;
    pop hl                               ;
    ret                                  ;

; IN  - BC - ppqn value
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
player_set_ppqn:
    push bc                              ;
    LD_SCREEN_ADDRESS hl, LAYOUT_PPQN    ;
    ld a, b                              ;
    call print_hex                       ;
    pop bc                               ;
    ld a, c                              ;
    jp print_hex                         ;

; IN - AIX - tempo value
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
player_set_tempo:
    LD_SCREEN_ADDRESS hl, LAYOUT_TEMPO   ;
    call print_hex                       ;
    ld a, ixh                            ;
    jp print_hex                         ;

; IN  - IX - pointer to string
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
player_set_filename:
    LD_SCREEN_ADDRESS hl, LAYOUT_FILENAME                     ;
    call print_string0                                        ;
.fill_tail_with_spaces:
    ld a, l                                                   ; if (printed_chars < total chars) - fill tail with spaces
    and #1f                                                   ; ... screen address (HL): 010yyyyy yyyxxxxx
    cp (low LAYOUT_FILENAME)+LAYOUT_FILENAME_LEN              ; ...
    ret nc                                                    ; ...
    ld a, ' '                                                 ; ...
    call print_char                                           ; ...
    inc l                                                     ; ...
    jr .fill_tail_with_spaces                                 ; ...

; IN  - IX  - size value
; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
player_set_size:
    LD_SCREEN_ADDRESS hl, LAYOUT_SIZE    ;
    ld a, ixh                            ;
    call print_hex                       ;
    ld a, ixl                            ;
    jp print_hex                         ;


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
player_update_timer:
    ld a, (var_player_state.subseconds_l)            ;
    inc a                                            ;
    cp 5                                             ; 50 hz
    jr z, .subseconds_l_roll                         ;
    ld (var_player_state.subseconds_l), a            ;
    ret                                              ;
.subseconds_l_roll:
    xor a                                            ;
    ld (var_player_state.subseconds_l), a            ;
.next_subsecond_h:
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER+6             ;
    ld a, (var_player_state.subseconds_h)            ;
    inc a                                            ;
    cp '9'+1                                         ;
    jr z, .subseconds_h_roll                         ;
    ld (var_player_state.subseconds_h), a            ;
    jp print_char                                    ; print subsecond = x
.subseconds_h_roll:
    ld a, '0'                                        ;
    ld (var_player_state.subseconds_h), a            ;
    call print_char                                  ; print subsecond = 0
.next_second_l:
    ; call smf_get_bytes_left                        ; update size every second
    ld ix, (var_smf_file.bytes_left)                 ; ...
    call player_set_size                             ; ...
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER+4             ;
    ld a, (var_player_state.seconds_l)               ;
    inc a                                            ;
    cp '9'+1                                         ;
    jr z, .seconds_l_roll                            ;
    ld (var_player_state.seconds_l), a               ;
    jp print_char                                    ; print second_l = x
.seconds_l_roll:
    ld a, '0'                                        ;
    ld (var_player_state.seconds_l), a               ;
    call print_char                                  ; print second_l = 0
.next_second_h:
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER+3             ;
    ld a, (var_player_state.seconds_h)               ;
    inc a                                            ;
    cp '6'                                           ;
    jr z, .seconds_h_roll                            ;
    ld (var_player_state.seconds_h), a               ;
    jp print_char                                    ; print second_h = x
.seconds_h_roll:
    ld a, '0'                                        ;
    ld (var_player_state.seconds_h), a               ;
    call print_char                                  ; print second_h = 0
.next_minute_l:
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER+1             ;
    ld a, (var_player_state.minutes_l)               ;
    inc a                                            ;
    cp '9'+1                                         ;
    jr z, .minutes_l_roll                            ;
    ld (var_player_state.minutes_l), a               ;
    jp print_char                                    ; print minute_l = x
.minutes_l_roll:
    ld a, '0'                                        ;
    ld (var_player_state.minutes_l), a               ;
    call print_char                                  ; print minute_l = 0
.next_minute_h:
    LD_SCREEN_ADDRESS hl, LAYOUT_TIMER+0             ;
    ld a, (var_player_state.minutes_h)               ;
    inc a                                            ;
    cp '9'+1                                         ;
    jr z, .minutes_h_roll                            ;
    ld (var_player_state.minutes_h), a               ;
    jp print_char                                    ; print minute_h = x
.minutes_h_roll:
    ld a, '0'                                        ;
    ld (var_player_state.minutes_h), a               ;
    jp print_char                                    ; print minute_h = 0


; OUT - AF - garbage
; OUT - IX - garbage
player_redraw_buttons:
    push hl                                                ;
    ld ix, var_player_state.flags                          ;
.play_button:
    ld a, LAYOUT_PLAYBUTTON_ACTIVE_ATTR                    ;
    LD_ATTR_ADDRESS hl, LAYOUT_PLAYER_BUTTONBAR+#0002      ;
    ld (hl), a : inc hl : ld (hl), a : inc hl : ld (hl), a ;
    LD_ATTR_ADDRESS hl, LAYOUT_PLAYER_BUTTONBAR+#0102      ;
    ld (hl), a : inc hl : ld (hl), a : inc hl : ld (hl), a ;
.rewind_button:
    bit PLAYER_FLAG_FF, (ix)                               ;
    ld a, LAYOUT_PLAYBUTTON_ATTR                           ;
    jr z, 1f                                               ;
    ld a, LAYOUT_PLAYBUTTON_ACTIVE_ATTR                    ;
1:  LD_ATTR_ADDRESS hl, LAYOUT_PLAYER_BUTTONBAR+#0005      ;
    ld (hl), a : inc hl : ld (hl), a                       ;
    LD_ATTR_ADDRESS hl, LAYOUT_PLAYER_BUTTONBAR+#0105      ;
    ld (hl), a : inc hl : ld (hl), a                       ;
    pop hl                                                 ;
    ret                                                    ;
