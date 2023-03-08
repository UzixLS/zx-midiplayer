    ASSERT LAYOUT_BARS_N==16
    ASSERT LAYOUT_BARS_HEIGHT==8*8

    STRUCT vis_state_t
_zerobyte   BYTE 0              ; used in vis_init
bar_current BLOCK LAYOUT_BARS_N ;
bar_diff    BLOCK LAYOUT_BARS_N ;
    ENDS


; IN - A  - command byte
; IN - HL - file position
; OUT - BC - garbage
vis_process_command:
    ld ixl, a                                    ;
    and #f0                                      ; (command == 0x80 || command == 0x90)?
    cp #90                                       ;
    jp z, .note_on                               ;
    ; cp #80                                       ;
    ; jp z, .note_off                              ;
    ld a, ixl                                    ;
    ret                                          ;
.note_on:
    ld a, ixl                                    ; BC = channel number
    and #0f                                      ; ...
    ld c, a                                      ; ...
    ld b, 0                                      ; ...
    push hl                                      ;
    call file_get_next_byte                      ; A = note number
    call file_get_next_byte                      ; A = velocity
    srl a : srl a                                ; 32 lines (4*8)
    ld hl, var_vis_state+vis_state_t.bar_current ;
    add hl, bc                                   ;
    sub (hl)                                     ; A = new - current
    jr z, 1f                                     ;
    ld hl, var_vis_state+vis_state_t.bar_diff    ;
    add hl, bc                                   ;
    ld (hl), a                                   ; diff = A
1:  pop hl                                       ;
    ld a, ixl                                    ;
    ret                                          ;
; .note_off:
;     ld a, ixl                                    ; BC = channel number
;     and #0f                                      ; ...
;     ld c, a                                      ; ...
;     ld b, 0                                      ; ...
;     push hl                                      ;
;     ld hl, var_vis_state+vis_state_t.bar_current ;
;     add hl, bc                                   ;
;     xor a                                        ;
;     sub (hl)                                     ; A = -current
;     ld hl, var_vis_state+vis_state_t.bar_diff    ;
;     add hl, bc                                   ;
;     ld (hl), a                                   ; diff = A
;     pop hl                                       ;
;     ld a, ixl                                    ;
;     ret                                          ;


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
    ld a, %00001111                              ;
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
    nop
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
