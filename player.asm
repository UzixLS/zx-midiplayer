; IN  - HL - file position of first track data byte
player_loop:
    ld a, #ff                      ; issue reset status
    call uart_putc                 ; ...
    ei
    halt
.next_status:
    call smf_get_next_status       ; A = status, HL = track position, BC = data len, DE = time delta
    or a                           ; if status = 0 then end
    jr z, .end                     ; ...
    ld ixl, a                      ; save A
    call smf_delay
.status_check:
    ld a, ixl                      ; restore A (status)
    cp #ff                         ; do not send meta events to midi device
    jr nz, .status_send            ; ...
    call smf_handle_meta           ; ... instead, process it locally. HL = next track position
    jr .next_status                ; ...
.status_send:
    ld iyh, b : ld iyl, c          ; IY = data len
    call uart_putc                 ; send status
.data_send:
    ld a, iyh                      ; if len == 0 then go for next status
    or iyl                         ; ...
    jr z, .next_status             ; ...
    call file_get_next_byte        ; A = data
    call uart_putc                 ; send data
    dec iy                         ; len--
    jr .data_send                  ; ...
.end:
    ld a, #ff                      ; issue reset status
    call uart_putc                 ; ...
    ret


; IN  - BC - string len
; OUT - AF - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
player_set_title:
    ld a, b                      ; len = min(len, LAYOUT_TITLE_LEN)
    or a                         ; ...
    jr z, 1f                     ; ...
    ld c, LAYOUT_TITLE_LEN       ; ...
    jr .loadstring               ; ...
1:  ld a, c                      ; ...
    cp LAYOUT_TITLE_LEN          ; ...
    jr c, .loadstring            ; ...
    ld c, LAYOUT_TITLE_LEN       ; ...
.loadstring:
    ld ix, var_tmp32             ;
    ld b, c                      ;
1:  call file_get_next_byte      ; A = char
    ld (ix), a                   ; *var_tmp32++ = A
    inc ix                       ; ...
    djnz 1b                      ; repeat while (--len)
    ld a, LAYOUT_TITLE_LEN       ; clear trailing characters
    sub c                        ; ...
    ld b, a                      ; ...
    ld a, 32                     ; ... 32 - space
1:  ld (ix), a                   ; ...
    inc ix                       ; ...
    djnz 1b                      ; repeat while (--len)
.printstring:
    ld b, LAYOUT_TITLE_LEN       ;
    ld hl, LAYOUT_TITLE          ;
    ld ix, var_tmp32             ;
    call print_stringl           ;
    ret
