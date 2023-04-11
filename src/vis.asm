    ASSERT LAYOUT_BARS_N==16
    ASSERT LAYOUT_BARS_HEIGHT==8*8

    STRUCT vis_state_t
_zerobyte   BYTE 0              ; used in vis_init
bar_current BLOCK LAYOUT_BARS_N ;
bar_diff    BLOCK LAYOUT_BARS_N ;
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
; OUT - BC - garbage
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
    push hl                                      ;
    call file_get_next_byte                      ; C = note number
    and #7f                                      ; ...
    ld c, a                                      ; ...
    call file_get_next_byte                      ; D = velocity
    ld d, a                                      ; ...
    call vis_process_key                         ;
    ld hl, var_vis_state+vis_state_t.bar_current ;
    ld a, e                                      ;
    and #0f                                      ;
    ld c, a                                      ;
    ld b, 0                                      ;
    add hl, bc                                   ;
    ld a, d                                      ; A = velocity
    srl a : srl a                                ; 32 lines (4*8)
    sub (hl)                                     ; A = new - current
    jr z, 1f                                     ;
    ld hl, var_vis_state+vis_state_t.bar_diff    ;
    add hl, bc                                   ;
    ld (hl), a                                   ; diff = A
1:  pop hl                                       ;
    ld a, e                                      ;
    ret                                          ;
.note_off:
    push hl                                      ;
    call file_get_next_byte                      ; IXH = note number
    ld c, a                                      ;
    xor a                                        ;
    call vis_process_key                         ;
    pop hl                                       ;
    ld a, e                                      ;
    ret                                          ;


; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
; OUT - IXL - garbage
vis_process_frame:
    ld de, LAYOUT_BARS_N-1                       ;
.loop_next_chan:
    ld hl, var_vis_state+vis_state_t.bar_diff    ;
    add hl, de                                   ;
    ld a, (hl)                                   ;
    or a                                         ;
    jp z, .next_chan                             ;
    jp s, .bar_down                              ;
.bar_up:
    ld ixl, a                                    ; IXL = diff
    ld a, -LAYOUT_BARS_HEIGHT/2                  ; set diff
    ld (hl), a                                   ; ...
    ld hl, var_vis_state+vis_state_t.bar_current ; current += diff (IXL)
    add hl, de                                   ; ...
    ld b, (hl)                                   ; ...
    ld a, b                                      ; ...
    add ixl                                      ; ...
    ld (hl), a                                   ; ...
    ld a, (LAYOUT_BARS_Y + LAYOUT_BARS_HEIGHT)/2 ; B = Y coordinate
    sub b                                        ; ...
    sub ixl                                      ; ...
    sla a                                        ; ...
    ld b, a                                      ; ...
    ld a, e                                      ; C = X coordinate
    rlca : rlca : rlca                           ; ...
    add LAYOUT_BARS_X                            ; ...
    ld c, a                                      ; ...
    call get_pixel_address                       ;
.bar_up_loop:
    ld a, LAYOUT_BARS_PIXELS                     ;
    ld (hl), a                                   ;
    dec ixl                                      ;
    jp z, .next_chan                             ;
    call pixel_address_down                      ;
    call pixel_address_down                      ;
    jp .bar_up_loop                              ;
.bar_down:
    inc (hl)                                     ;
    ld hl, var_vis_state+vis_state_t.bar_current ;
    add hl, de                                   ;
    ld b, (hl)                                   ;
    dec (hl)                                     ;
    jp nz, 1f                                    ;
    ld hl, var_vis_state+vis_state_t.bar_diff    ;
    add hl, de                                   ;
    xor a                                        ;
    ld (hl), a                                   ;
1:  sla b                                        ;
    ld a, LAYOUT_BARS_Y + LAYOUT_BARS_HEIGHT     ;
    sub b                                        ;
    ld b, a                                      ;
    ld a, e                                      ;
    rlca : rlca : rlca                           ;
    add LAYOUT_BARS_X                            ;
    ld c, a                                      ;
    call get_pixel_address                       ;
    xor a                                        ;
    ld (hl), a                                   ;
.next_chan:
    dec e                                        ;
    jp p, .loop_next_chan                        ;
    ret                                          ;


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
