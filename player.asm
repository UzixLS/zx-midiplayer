; IN  - HL - file position of first track data byte
player_loop:
    ld a, #ff                      ; issue reset status
    di : call uart_putc : ei       ; ...
    halt : ei                      ; wait 20ms just for safety
.loop:
    call smf_get_first_track       ;
    jr z, .end                     ;
.process_current_track:
    call smf_process_track         ; A = status, HL = track position, BC = data len
    jp c, .next_track              ; if C == 1 (delayed) then go to the next track
    jp z, .next_track              ; if Z == 1 (no data) then go to the next track
.status_check:
    cp #ff                         ; do not send meta events to midi device
    jp nz, .status_send            ; ...
    call smf_handle_meta           ; ... instead, process it locally. HL = next track position
    jp .process_current_track      ; ...
.status_send:
    ld ixh, b : ld ixl, c          ; IX = data len
    di : call uart_putc : ei       ; send status
.data_send:
    ld a, ixh                      ; if len == 0 then go for next status
    or ixl                         ; ...
    jr z, .process_current_track   ; ...
    call file_get_next_byte        ; A = data
    di : call uart_putc : ei       ; send data
    dec ix                         ; len--
    jp .data_send                  ; ...
.next_track:
    call smf_get_next_track        ;
    jr z, .loop                    ;
    jp .process_current_track      ;
.end:
    ld a, #ff                      ; issue reset status
    di : call uart_putc : ei       ; ...
    ret                            ;


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
    ret                          ;
