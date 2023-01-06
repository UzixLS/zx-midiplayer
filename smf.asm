    STRUCT chunk_header_t
id            DWORD
len           DWORD
    ENDS

    STRUCT chunk_mthd_t
header        chunk_header_t
format        WORD
num_tracks    WORD
division      WORD
    ENDS

    STRUCT chunk_mtrk_t
header        chunk_header_t
data          BLOCK 0
    ENDS

    STRUCT smf_file_t
num_tracks    BYTE
track_ptr     WORD
track_len     WORD
last_status   BYTE
ppqn          WORD
tempo         DWORD
tick_duration WORD
    ENDS


default_tempo = 500000     ; defined by MIDI standard
tick_delay_loop_len = 8    ; us
tick_delay_correction = 14 ; № of delay loops to skip


; IN  - IX - pointer to beginning of file
; OUT -  F - Z = 0 on success, 1 on error
; OUT - IX - pointer to next byte after end of chunk
; OUT - AF - garbage
; OUT - BC - garbage
smf_parse_file_header:
    ld a, (ix+chunk_header_t.id+0) : cp 'M' : ret nz
    ld a, (ix+chunk_header_t.id+1) : cp 'T' : ret nz
    ld a, (ix+chunk_header_t.id+2) : cp 'h' : ret nz
    ld a, (ix+chunk_header_t.id+3) : cp 'd' : ret nz
    ld a, (ix+chunk_header_t.len+0) : cp 0 : ret nz
    ld a, (ix+chunk_header_t.len+1) : cp 0 : ret nz
    ld a, (ix+chunk_header_t.len+2) : cp 0 : ret nz
    ld a, (ix+chunk_header_t.len+3) : cp 6 : ret nz
    ld a, (ix+chunk_mthd_t.format+0) : cp 0 : ret nz
    ld a, (ix+chunk_mthd_t.format+1) : cp 0 : ret nz
    ld a, (ix+chunk_mthd_t.num_tracks+0) : cp 0 : ret nz
    ld a, (ix+chunk_mthd_t.num_tracks+1) : ld (var_smf_file.num_tracks), a
    ld a, (ix+chunk_mthd_t.division+0) : ld (var_smf_file.ppqn+1), a ; MIDI is big endian, Z80 is little endian
    ld a, (ix+chunk_mthd_t.division+1) : ld (var_smf_file.ppqn+0), a ; XXX
    ld bc, chunk_mthd_t ; MThd len
    add ix, bc
    ret

; IN  - IX - pointer to file
; OUT -  F - Z = 0 on success, 1 on error
; OUT - IX - pointer to next byte after end of chunk
; OUT - AF - garbage
; OUT - BC - garbage
smf_parse_track_header:
    ld a, (ix+chunk_header_t.id+0) : cp 'M' : ret nz
    ld a, (ix+chunk_header_t.id+1) : cp 'T' : ret nz
    ld a, (ix+chunk_header_t.id+2) : cp 'r' : ret nz
    ld a, (ix+chunk_header_t.id+3) : cp 'k' : ret nz
    ld a, (ix+chunk_header_t.len+0) : cp 0 : ret nz
    ld a, (ix+chunk_header_t.len+1) : cp 0 : ret nz
    ld b, (ix+chunk_header_t.len+2)
    ld c, (ix+chunk_header_t.len+3)
    ld (var_smf_file.track_len), bc
    ld bc, chunk_mtrk_t
    add ix, bc
    ld (var_smf_file.track_ptr), ix
    ld bc, (var_smf_file.track_len)
    add ix, bc
    ret

; IN  - IX - pointer to file
; OUT -  F - Z = 0 on success, 1 on error
smf_parse:
    call smf_parse_file_header
    ret nz
    call smf_parse_track_header
    ld bc, (default_tempo >>  0)&0xFFFF : ld (var_smf_file.tempo+0), bc
    ld bc, (default_tempo >> 16)&0xFFFF : ld (var_smf_file.tempo+2), bc
    call smf_update_tick_duration
    ret


; IN  - HL - track position
; OUT -  A - data
; OUT - HL - next track position
; OUT - IX - pointer to data byte
smf_get_next_byte:
    ld ix, (var_smf_file.track_ptr) ; IX = &track[position]
    ex de, hl                       ; ...
    add ix, de                      ; ...
    ex de, hl                       ; ...
    ld a, (ix)                      ; A = track[position]
    inc hl                          ; position++
    ret                             ;


; IN  - HL - track position
; OUT - BC - int value (limited to 0x3FFF, should be enought)
; OUT - HL - next track position
; OUT - IX - pointer to last data byte
; OUT - AF - garbage
smf_parse_varint:
    call smf_get_next_byte    ; A = byte - fvvvvvvV - f - flag, v - value
    ld b, 0                   ;
    ld c, a                   ;
    rlca                      ; if (flag == 0) - no more bytes, exit
    ret nc                    ; ...
    res 7, c                  ; len = ((len & 0x7F) << 7)
    ld b, c                   ; ...
    ld c, 0                   ; ...
    srl b                     ; ... B = 00vvvvvv; Cflag = bit0
    rr c                      ; ... C = V0000000
    call smf_get_next_byte    ; A = byte - fvvvvvvv
    rlca                      ;
    jr c, .have_more_bytes    ;
    srl a                     ; A = 0vvvvvvv
    or c                      ; A = Vvvvvvvv, len = len | (byte & 0x7F)
    ld c, a                   ; ...
    ret                       ;
.have_more_bytes:
    ld bc, #3fff              ; set max value 0x3FFF, all other bytes will be skipped
.loop:
    call smf_get_next_byte    ; loop until all varint bytes skipped
    rlca                      ; ...
    jr c, .loop               ; ...
    ret                       ;


; IN  - HL - track position
; OUT -  A - status byte
; OUT - BC - data len
; OUT - HL - next track position
; OUT - DE - time delta
; OUT -  F - garbage
; OUT - IX - garbage
smf_get_next_status:
    ex hl, de                                 ; check if end of track reached
    ld hl, (var_smf_file.track_len)           ; ...
    or a                                      ; clear C flag
    sbc hl, de                                ; if (HL==DE) Z=1,C=0; if (HL<DE) Z=0,C=1; if (HL>DE) Z=0,C=0
    ex hl, de                                 ; ...
    jr z, .eof                                ; ...
    jr c, .eof                                ; ...
.parse_time_delta:
    call smf_parse_varint                     ; BC = time delta
    ld d, b : ld e, c                         ; DE = BC
.parse_status_byte:
    call smf_get_next_byte                    ; A = byte
    bit 7, a                                  ; if this isn't status byte - reuse last one ("Running Status")
    jr nz, .is_meta_event                     ; ...
    ld a, (var_smf_file.last_status)          ; ...
    dec hl                                    ; ...
.is_meta_event:
    cp #ff                                    ; A == 0xFF?
    jr nz, .is_sysex                          ; ... no
    push de                                   ;
    push hl                                   ; save HL (next track position)
    inc hl                                    ; "FF cc ll... dd..." - cc - command, ll - length, dd - data
    call smf_parse_varint                     ; BC = ll - length of dd, HL = next track position (pointing to dd)
    pop de                                    ; DE = prev track position
    or a                                      ; reset C flag
    sbc hl, de                                ; get length of cc and ll (HL = HL - DE - C flag)
    add hl, bc                                ; sum length of cc/ll and dd
    ld b, h : ld c, l                         ; BC = total data len
    ex hl, de                                 ; restore HL (next track position)
    pop de                                    ;
    ld a, #ff                                 ; restore status byte = 0xFF
    ret
.is_sysex:
    cp #f0                                    ; check 0xF0 <= byte < 0xF8
    jr c, .is_note                            ; ...
    jr z, .is_sysex_yes                       ; ...
    cp #f8                                    ; ...
    jr nc, .eof                               ; ...
.is_sysex_yes:
    push af                                   ;
    call smf_parse_varint                     ;
    pop af                                    ;
    ret                                       ;
.is_note:
    ld (var_smf_file.last_status), a          ;
    ld ixl, a                                 ;
    and #f0                                   ; "sssscccc" - s - status byte, c - channel number
    ld bc, 2                                  ;
    cp #90 : jr nz, 1f         : or ixl : ret ; note on
1:  cp #80 : jr nz, 1f         : or ixl : ret ; note off
1:  cp #a0 : jr nz, 1f         : or ixl : ret ; key after-touch
1:  cp #b0 : jr nz, 1f         : or ixl : ret ; control change
1:  cp #c0 : jr nz, 1f : dec c : or ixl : ret ; program (patch) change
1:  cp #d0 : jr nz, 1f : dec c : or ixl : ret ; channel after-touch (aka "channel pressure")
1:  cp #e0 : jr nz, 1f         : or ixl : ret ; pitch wheel change
.eof:
1:  xor a                                     ; not valid command, set to zero
    ret


; OUT - HL - tick duration
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - IX - garbage
smf_update_tick_duration:                     ; = tempo/ppqn/tick_delay_loop_len - tick_delay_correction
    ld a, (var_smf_file.tempo+2)              ; ACIX = tempo
    ld c, a                                   ; ...
    xor a                                     ; ... tempo is 24 bit value
    ld ix, (var_smf_file.tempo)               ; ...
    ld de, (var_smf_file.ppqn)                ;
    call div32by16                            ; ACIX = tempo/ppqn
    ld d, ixh : ld e, ixl                     ; ACDE = ACIX
    assert tick_delay_loop_len == 8           ; power of 2
    srl a : rr c : rr d : rr e                ; ACDE = ACDE/tick_delay_loop_len
    srl a : rr c : rr d : rr e                ; ...
    srl a : rr c : rr d : rr e                ; ...
    or c                                      ; if (result > 0xFFFF) result = 0xFFFF
    jr z, 1f                                  ; ...
    ld hl, #ffff                              ; ...
    jp .save                                  ; ...
1:  ld bc, tick_delay_correction              ;
    ex hl, de                                 ;
    sbc hl, bc                                ; HL = HL - tick_delay_correction
    jp nc, .save                              ; if (result < 0) result = 0
    ld hl, 0                                  ; ...
.save:
    ld (var_smf_file.tick_duration), hl       ;
    ret                                       ;


; IN  - DE - ticks count
; OUT - DE - 0
; OUT - AF - garbage
smf_delay:
    ld a, d
    or e
    ret z
    push bc
    push hl
.delay_loop:
    ld bc, (var_smf_file.tick_duration) ; (20)
.delay_inner_loop:                      ; CPU freq = 3.5MHz: (4+6+4+4+10) * 1e6/3.5e6 = 8us (see tick_delay_loop_len)
    nop                                 ; (4)
    dec bc                              ; (6)
    ld a, b                             ; (4)
    or c                                ; (4)
    jp nz, .delay_inner_loop            ; (10)
    dec de                              ; (6)
    ld a, d                             ; (4)
    or e                                ; (4)
    jp nz, .delay_loop                  ; (10)
    pop hl
    pop bc
    ret


; IN  - BC - data len
; IN  - HL - track position
; OUT - HL - next track position
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - IX - garbage
smf_handle_meta:
    ld a, b                      ; if (len == 0) - exit
    or c                         ; ...
    ret z                        ; ...
    call smf_get_next_byte       ; A = cmd
    dec bc                       ; ...
.tempo:
    cp #51                       ; tempo
    jr nz, .title                ; ...
    ld a, b                      ; len should == 4
    or a                         ; ...
    jr nz, .exit                 ; ...
    ld a, c                      ; ...
    cp 4                         ; ...
    jr nz, .exit                 ; ...
    inc hl                       ; skip ll
    dec bc                       ; ...
    call smf_get_next_byte       ; tempo = tt tt tt
    dec bc                       ; ...
    ld (var_smf_file.tempo+2), a ; ... MIDI is big endian, Z80 is little endian
    call smf_get_next_byte       ; ...
    dec bc                       ; ...
    ld (var_smf_file.tempo+1), a ; ...
    call smf_get_next_byte       ; ...
    dec bc                       ; ...
    ld (var_smf_file.tempo+0), a ; ...
    push bc                      ;
    push hl                      ;
    call smf_update_tick_duration;
    pop hl                       ;
    pop bc                       ;
    jp .exit                     ;
.title:
    cp #03                       ; track title
    jr nz, .exit                 ; ...
    inc hl                       ; skip ll
    dec bc                       ; ...
    push bc                      ;
    push hl                      ;
    inc ix                       ; skip cmd and ll
    inc ix                       ; ...
    call player_set_title        ;
    pop hl                       ;
    pop bc                       ;
    ; jp .exit                     ;
.exit:
    add hl, bc
    ret
