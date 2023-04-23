    ASSERT LAYOUT_BARS_N==16
    ASSERT LAYOUT_BARS_HEIGHT==8*8

    STRUCT vis_state_t
_zerobyte   BYTE 0                ; used in vis_init
logo_step   BYTE 0                ;
bar_value   BLOCK LAYOUT_BARS_N*2 ; byte 0,2,4... - target_value, byte 1,3,5... - current_value
    ENDS



vis_piano_key_addresses:
    lua allpass
        x = _c("LAYOUT_PIANO_KEYS_X")
        y = _c("LAYOUT_PIANO_KEYS_Y")
        for key = 0, _c("LAYOUT_PIANO_KEYS")-1 do
            n = key % 12
            if n==1 or n==3 or n==6 or n==8 or n==10 then
                y_offset = _c("LAYOUT_PIANO_KEYS_Y_BLACK")
                x_append = 0
            else
                y_offset = 0
                x_append = 8
            end
            address = screen_address_pixel(x, y + y_offset)
            if y_offset ~= 0 then
                address = address | 0x8000
            end
            sj.add_word(address)
            x = x + x_append
            if x >= _c("LAYOUT_PIANO_KEYS_WIDTH") then
                x = 0
                y = y + _c("LAYOUT_PIANO_KEYS_Y_APPEND")
            end
        end
    endlua
    DW #4000 ; just for safety



; IN  - A  - velocity
; IN  - C  - note number
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - HL - garbage
; OUT - IX - garbage
vis_process_key:
    or a                                                                    ;
    jr z, .off                                                              ;
.on:
    ld ix, (LAYOUT_PIANO_KEYS_BLACK_ON << 8) | LAYOUT_PIANO_KEYS_WHITE_ON   ;
    jp 1f                                                                   ;
.off:
    ld ix, (LAYOUT_PIANO_KEYS_BLACK_OFF << 8) | LAYOUT_PIANO_KEYS_WHITE_OFF ;
1:  ld a, c                                                                 ; if (note < FIRST || note > last) ret
    sub PIANO_KEYS_FIRST                                                    ; ...
    ret c                                                                   ; ...
    cp LAYOUT_PIANO_KEYS                                                    ; ...
    ret nc                                                                  ; ...
    ld c, a                                                                 ; HL = vis_piano_key_addresses[key_number]
    sla c                                                                   ; ...
    ld b, 0                                                                 ; ...
    ld hl, vis_piano_key_addresses                                          ; ...
    add hl, bc                                                              ; ...
    ld c, (hl)                                                              ; ...
    inc hl                                                                  ; ...
    ld h, (hl)                                                              ; ...
    ld l, c                                                                 ; ...
    bit 7, h                                                                ; if (address & 0x8000) - assume black key
    jp nz, .black                                                           ; ...
.white:
    ld b, ixl                                                               ; ...
    jp 1f                                                                   ; ...
.black:
    res 7, h                                                                ; ...
    ld b, ixh                                                               ; ...
1:  DUP LAYOUT_PIANO_KEYS_ON_LINES
        ld (hl), b                                                          ; write to screen
        inc h                                                               ; ...
    EDUP
    ret                                                                     ;


; IN - A  - command byte
; IN - HL - file position
; OUT - F  - garbage
; OUT - DE - garbage
; OUT - IX - garbage
vis_process_command:
    ld e, a                                      ; E = command
    and #f0                                      ; (command == 0x80 || command == 0x90)?
    cp #90                                       ; ...
    jp z, .note_on                               ; ...
    cp #80                                       ; ...
    jp z, .note_off                              ; ...
    ld a, e                                      ;
    ret                                          ;
.note_on:
    push bc                                      ;
    push hl                                      ;
    call file_get_next_byte                      ; C = note number
    and #7f                                      ; ...
    ld c, a                                      ; ...
    push af                                      ;
    call file_get_next_byte                      ; D = velocity [0..127]
    ld d, a                                      ; ...
    call vis_process_key                         ;
    ld hl, var_vis_state+vis_state_t.bar_value   ;
    pop af                                       ; A = note number
    cp 95+1                                      ; if (note_number > 95) note_number = 95
    jp c, 1f                                     ; ...
    ld a, 95                                     ; ...
1:  sub 32                                       ; note_number = note_number - 32
    jp nc, 1f                                    ; if (note_number < 0) note_number = 0
    xor a                                        ; ...
1:  rra                                          ; HL = &target_value[channel]
    and #1e                                      ; ...
    ld c, a                                      ; ...
    ld b, 0                                      ; ...
    add hl, bc                                   ; ...
    srl d : srl d                                ; velocity = [0..31] - 4*8=32 lines
    ld (hl), d                                   ; target = velocity
    pop hl                                       ;
    pop bc                                       ;
    ld a, e                                      ;
    ret                                          ;
.note_off:
    push bc                                      ;
    push hl                                      ;
    call file_get_next_byte                      ; IXH = note number
    ld c, a                                      ;
    xor a                                        ; velocity = 0
    call vis_process_key                         ;
    pop hl                                       ;
    pop bc                                       ;
    ld a, e                                      ;
    ret                                          ;


; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
vis_process_frame:
.bars_animation:
    ld de, LAYOUT_BARS_N-1                       ; E = current bar number (X)
.loop_next_chan:
    ld hl, var_vis_state+vis_state_t.bar_value   ; HL = &target_value[channel]
    add hl, de                                   ; ...
    add hl, de                                   ; ...
    ld a, (hl)                                   ; A = target
    ld (hl), d                                   ; target = 0
    inc hl                                       ; HL = &current_value[channel]
    ld b, (hl)                                   ; B = current
    cp b                                         ;
    jp z, .next_chan                             ; if (target == current) next chan
    jp c, .bar_down                              ; if (target < current)
.bar_up:
    ld (hl), a                                   ; current = target
    ld c, a                                      ;
    sub b                                        ; D = diff = target - current
    ld d, a                                      ; ...
    ld a, (LAYOUT_BARS_Y + LAYOUT_BARS_HEIGHT)/2 ; B = Y coordinate
    sub c                                        ; ...
    sla a                                        ; ...
    ld b, a                                      ; ...
    ld a, e                                      ; C = X coordinate
    rlca : rlca : rlca                           ; ...
    add LAYOUT_BARS_X                            ; ...
    ld c, a                                      ; ...
    call get_pixel_address                       ; HL = address
    ld b, LAYOUT_BARS_PIXELS                     ; draw diff bars from top to bottom
.bar_up_loop:
    ld (hl), b                                   ; ...
    dec d                                        ; ... diff--
    jr z, .next_chan                             ; ...
    call pixel_address_down                      ; ...
    call pixel_address_down                      ; ...
    jp .bar_up_loop                              ; ...
.bar_down:
    dec (hl)                                     ; current--
    sla b                                        ; B = Y coordinate
    ld a, LAYOUT_BARS_Y + LAYOUT_BARS_HEIGHT     ; ...
    sub b                                        ; ...
    ld b, a                                      ; ...
    ld a, e                                      ; C = X coordinate
    rlca : rlca : rlca                           ; ...
    add LAYOUT_BARS_X                            ; ...
    ld c, a                                      ; ...
    call get_pixel_address                       ; HL = address
    ld (hl), d                                   ; clear bar line
.next_chan:
    dec e                                        ;
    jp p, .loop_next_chan                        ;
.logo_animation:                                 ;
    ld a, (var_vis_state+vis_state_t.logo_step)  ;
    dec a                                        ;
    ld (var_vis_state+vis_state_t.logo_step), a  ;
    srl a                                        ;
    ret nc                                       ;
    cp #7f                                       ;
    jr z, .clear_first_line                      ;
    cp LAYOUT_LOGO_LINES                         ;
    ret nc                                       ;
    LD_ATTR_ADDRESS hl, LAYOUT_LOGO              ; HL = address of top-left attribute byte
    ld b, 0                                      ; HL += line
    rlca : rlca : rlca : rla : rl b : rla : rl b ; ...
    ld c, a                                      ; ...
    add hl, bc                                   ; ...
.draw_line:
    ld a, LAYOUT_LOGO_FLASH_ATTR                 ;
    DUP LAYOUT_LOGO_COLUMNS
    ld (hl), a                                   ;
    inc l                                        ;
    EDUP
    call char_address_down                       ;
.clear_line:
    ld a, LAYOUT_LOGO_NORMAL_ATTR                ;
    DUP LAYOUT_LOGO_COLUMNS
    dec l                                        ;
    ld (hl), a                                   ;
    EDUP
    ret                                          ;
.clear_first_line:
    LD_ATTR_ADDRESS hl, LAYOUT_LOGO + LAYOUT_LOGO_COLUMNS ;
    jp .clear_line                                        ;


vis_init:
    ld de, var_vis_state+1   ;
    ld hl, var_vis_state     ;
    ld bc, vis_state_t-1     ;
    ldir                     ;
    ld b, LAYOUT_BARS_HEIGHT ;
    ld c, LAYOUT_BARS_N      ;
    ld h, LAYOUT_BARS_Y      ;
    ld l, LAYOUT_BARS_X      ;
    call clear_screen_area   ;
    ret                      ;
