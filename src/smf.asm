    STRUCT chunk_riff_header_t
id            DWORD ; "RIFF"
len           DWORD
id2           DWORD ; "RMID"
id3           DWORD ; "data"
len2          DWORD
    ENDS

    STRUCT chunk_header_t
id            DWORD ; "MThd" or "MTrk"
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
num_tracks        BYTE
ppqn              WORD
tempo             DWORD
tick_duration     WORD
tracks            BLOCK max_tracks*smf_track_t
_zerobyte         BYTE 0   ; this is read by smf_get_next_track and written by smf_parse (flags=0)
    ENDS

    STRUCT smf_track_t
flags             BYTE
last_status       BYTE
start             WORD
end               WORD
position          WORD
int_acked_counter WORD
wait_duration     DWORD
    ENDS

SMF_TRACK_FLAGS_VALID  = 0
SMF_TRACK_FLAGS_PLAY   = 1
SMF_TRACK_FLAGS_DELAY  = 2

default_tempo = 500000     ; defined by MIDI standard
max_tracks = 40


; IN  - HL - position of beginning of file
; OUT - HL - position of next byte after end of chunk
; OUT - AF - garbage
; OUT - BC - garbage
smf_parse_file_header_rmi:
    push hl                                    ;
    call .sub                                  ;
    pop hl                                     ;
    jr z, .is_riff                             ;
    ret                                        ;
.is_riff:
    ld bc, chunk_riff_header_t                 ; skip riff header
    add hl, bc                                 ; ...
    ret                                        ;
.sub
    call file_get_next_byte : cp 'R' : ret nz  ;
    call file_get_next_byte : cp 'I' : ret nz  ;
    call file_get_next_byte : cp 'F' : ret nz  ;
    call file_get_next_byte : cp 'F' : ret nz  ;
    xor a                                      ; set Z flag
    ret                                        ;


; IN  - HL - position of beginning of file
; OUT -  F - Z = 1 on success, 0 on error
; OUT - HL - position of next byte after end of chunk
; OUT - AF - garbage
; OUT - BC - garbage
smf_parse_file_header:
    call file_get_next_byte : cp 'M' : ret nz                  ; chunk_header_t.id[0]
    call file_get_next_byte : cp 'T' : ret nz                  ; chunk_header_t.id[1]
    call file_get_next_byte : cp 'h' : ret nz                  ; chunk_header_t.id[2]
    call file_get_next_byte : cp 'd' : ret nz                  ; chunk_header_t.id[3]
    call file_get_next_byte : cp 0   : ret nz                  ; chunk_header_t.len[0]
    call file_get_next_byte : cp 0   : ret nz                  ; chunk_header_t.len[1]
    call file_get_next_byte : cp 0   : ret nz                  ; chunk_header_t.len[2]
    call file_get_next_byte : cp 6   : ret nz                  ; chunk_header_t.len[3]
    call file_get_next_byte : cp 0   : ret nz                  ; chunk_mthd_t.format[0]
    call file_get_next_byte :                                  ; chunk_mthd_t.format[1]
    or 1 : cp 1 : ret nz                                       ; if (format != 0 && format != 1) - return error
    call file_get_next_byte : cp 0   : ret nz                  ; chunk_mthd_t.num_tracks[0]
    call file_get_next_byte : ld (var_smf_file.num_tracks), a  ; chunk_mthd_t.num_tracks[1]
    cp max_tracks                                              ; if (num_tracks>max_tracks) - return error
    jp c, 1f : jp z, 1f                                        ; ...
    or 1                                                       ; reset Z flag
    ret                                                        ; ...
1:  call file_get_next_byte : ld (var_smf_file.ppqn+1), a      ; chunk_mthd_t.division[0]
    call file_get_next_byte : ld (var_smf_file.ppqn+0), a      ; chunk_mthd_t.division[1]
    xor a                                                      ; set Z flag
    ret

; IN  - HL - position in file
; IN  - IY - pointer to smf_track_t
; OUT -  F - Z = 1 on success, 0 on error
; OUT - HL - position of next byte after end of chunk
; OUT - AF - garbage
; OUT - BC - garbage
smf_parse_track_header:
    call file_get_next_byte : cp 'M' : ret nz                  ; chunk_header_t.id+0
    call file_get_next_byte : cp 'T' : ret nz                  ; chunk_header_t.id+1
    call file_get_next_byte : cp 'r' : ret nz                  ; chunk_header_t.id+2
    call file_get_next_byte : cp 'k' : ret nz                  ; chunk_header_t.id+3
    call file_get_next_byte : cp 0 : ret nz                    ; chunk_header_t.len+0
    call file_get_next_byte : cp 0 : ret nz                    ; chunk_header_t.len+1
    call file_get_next_byte : ld b, a                          ; chunk_header_t.len+2
    call file_get_next_byte : ld c, a                          ; chunk_header_t.len+3
    ld (iy+smf_track_t.start+0), l                             ; save position to begin of track data
    ld (iy+smf_track_t.start+1), h                             ; ...
    ld (iy+smf_track_t.position+0), l                          ; save position to begin of track data
    ld (iy+smf_track_t.position+1), h                          ; ...
    add hl, bc                                                 ; save position to end of track data
    ld (iy+smf_track_t.end+0), l                               ; ...
    ld (iy+smf_track_t.end+1), h                               ; ...
    jr nc, 1f                                                  ; check if track is bigger than file
    or 1                                                       ; ... if yes - reset Z flag
    ret                                                        ; ... and exit
1:  ld a, (1<<SMF_TRACK_FLAGS_VALID)|(1<<SMF_TRACK_FLAGS_PLAY) ; set track flags
    ld (iy+smf_track_t.flags), a                               ; ...
    ld a, (var_int_counter+1)                                  ; set int counter
    ld (iy+smf_track_t.int_acked_counter+1), a                 ; ...
    xor a                                                      ; set Z flag
    ld (iy+smf_track_t.int_acked_counter+0), a                 ; ...
    ld (iy+smf_track_t.last_status), a                         ; ...
    ret                                                        ;

; OUT -  F - Z = 1 on success, 0 on error
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
smf_parse:
    ld bc, (default_tempo>> 0)&0xFFFF : ld (var_smf_file.tempo+0), bc ; set default tempo
    ld bc, (default_tempo>>16)&0xFFFF : ld (var_smf_file.tempo+2), bc ; ...
    ld hl, 0                          ; parse file header
    call smf_parse_file_header_rmi    ; ... skip rmi header if present
    call smf_parse_file_header        ; ...
    ret nz                            ; ... return on error
    ld a, (var_smf_file.num_tracks)   ; parse each track header
    ld ixl, a                         ; ...
    ld iy, var_smf_file.tracks        ; ...
    ld de, smf_track_t                ; ...
1:  call smf_parse_track_header       ; ...
    ret nz                            ; ... return on error
    add iy, de                        ; ...
    dec ixl                           ; ...
    jp nz, 1b                         ; ...
    xor a                             ; set next track flags = 0
    ld (iy+smf_track_t.flags), a      ; ...
    call smf_update_tick_duration     ;
    xor a                             ; set Z flag
    ret                               ;



; see smf_get_next_track
; if this function returns F/Z=1 then there is nothing to play anymore
smf_get_first_track:
    ld iy, var_smf_file.tracks-smf_track_t ;
    jp smf_get_next_track.entry            ;

; IN  - HL - current track position
; IN  - IY - pointer to current track
; OUT -  F - Z = 0 on success, 1 if there is no more tracks
; OUT - HL - current position of next track
; OUT - IY - pointer to next track
; OUT - AF - garbage
; OUT - BC - garbage
smf_get_next_track:
    ld (iy+smf_track_t.position+0), l ; IY->track_position = HL
    ld (iy+smf_track_t.position+1), h ; ...
.entry:
    ld bc, smf_track_t                ;
.next_track:
    add iy, bc                        ; IY += sizeof(smf_track_t)
    ld a, (iy+smf_track_t.flags)      ; if (!track_valid) return Z=1
    and 1<<SMF_TRACK_FLAGS_VALID      ; ...
    ret z                             ; ...
    ld a, (iy+smf_track_t.flags)      ; if (!track_play) check next track
    and 1<<SMF_TRACK_FLAGS_PLAY       ; ...
    jr z, .next_track                 ; ...
    ld l, (iy+smf_track_t.position+0) ; HL = IY->track_position
    ld h, (iy+smf_track_t.position+1) ; ...
    ret                               ;


; IN  - HL   - track position
; OUT - DEBC - int value (max 0x0FFFFFFF - 4 bytes)
; OUT - HL   - next track position
; OUT - AF   - garbage
smf_parse_varint:
    call file_get_next_byte   ; A = byte - fvvvvvvV - f - flag, v - value
    ld de, 0                  ;
    ld b, d                   ;
    ld c, a                   ;
    rlca                      ; if (flag == 0) - no more bytes, exit
    ret nc                    ; ...
    res 7, c                  ;
.loop:
    srl d                     ; before DEBC = 44444444 33333333 22222222 11111111; after DEBC = 43333333 32222222 21111111 10000000
    ld d, e                   ; ...
    rr d                      ; ... Cflag = 3
    ld e, b                   ; ...
    rr e                      ; ... Cflag = 2
    ld b, c                   ; ...
    rr b                      ; ... Cflag = 1
    ld c, 0                   ; ...
    rr c                      ; ...
    call file_get_next_byte   ; A = byte - fvvvvvvv
    bit 7, a                  ;
    jr nz, .have_more_bytes   ;
.last_byte:
    or c                      ;
    ld c, a                   ;
    ret                       ;
.have_more_bytes:
    res 7, a                  ;
    or c                      ;
    ld c, a                   ;
    jp .loop                  ;


; IN  - IY - pointer to smf_track_t
; OUT - F  - C=1 when delay is going on; C=0 when delay is expired
; OUT - A  - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
smf_check_delay:
    ld hl, (var_int_counter)                   ; HL (elapsed_counter) = (current_counter-acked_counter)
    ld e, (iy+smf_track_t.wait_duration+0)     ; ... DE = wait_duration[15:0]
    ld d, (iy+smf_track_t.wait_duration+1)     ; ...
    ld c, (iy+smf_track_t.int_acked_counter+0) ; ... BC = acked_counter
    ld b, (iy+smf_track_t.int_acked_counter+1) ; ...
    xor a                                      ; ... reset C flag
    sbc hl, bc                                 ; ...
    sbc hl, de                                 ; if (elapsed_counter < wait_duration) { return; } | if (HL==DE) Z=1,C=0; if (HL<DE) Z=0,C=1; if (HL>DE) Z=0,C=0
    ret c                                      ; ...
    ex de, hl                                  ; acked_counter += wait_duration
    add hl, bc                                 ; ...
    ld (iy+smf_track_t.int_acked_counter+0), l ; ...
    ld (iy+smf_track_t.int_acked_counter+1), h ; ...
.check_32bit_waitduration:
    or (iy+smf_track_t.wait_duration+2)        ; if (wait_duration[31:16] == 0) return expired
    or (iy+smf_track_t.wait_duration+3)        ; ... "or" also resets C flag
    jr nz, 1f                                  ;
    res SMF_TRACK_FLAGS_DELAY, (iy+smf_track_t.flags) ;
    ret                                        ;
1:  xor a                                      ; wait_duration[15:0] = 0x8000
    ld (iy+smf_track_t.wait_duration+0), a     ; ...
    ld a, #80                                  ; ...
    ld (iy+smf_track_t.wait_duration+1), a     ; ...
    ld a, (iy+smf_track_t.wait_duration+2)     ; wait_duration[31:16]--
    sub 1                                      ; ... unfortunately "dec" doesnt update C flag
    ld (iy+smf_track_t.wait_duration+2), a     ; ... so im using "sub"
    jr nc, 1f                                  ; ...
    dec (iy+smf_track_t.wait_duration+3)       ; ...
1:  scf                                        ; set C flag
    ret                                        ;


; IN  - DEBC - ticks count
; IN  - IY   - pointer to smf_track_t
; OUT - DEHL - wait_duraton
; OUT - AF   - garbage
; OUT - BC   - garbage
smf_set_delay:
    ld a, d                                           ;
    or e                                              ;
    jp z, .ticks16bit                                 ;
.ticks32bit:
    push bc                                           ;
    ld bc, (var_smf_file.tick_duration)               ;
    call mult_de_bc                                   ; DEHL = ticks_count[31:16] * tick_duration
    ld a, d                                           ; if (DEHL > 0xFFFF) IX = 0xFFFF; else IX = HL
    or e                                              ; ...
    jp z, 1f                                          ; ...
    ld ix, #ffff                                      ; ...
    jp 2f                                             ;
1:  ld d, h : ld e, l                                 ; ...
    ld ixh, d : ld ixl, e                             ; ...
2:  pop de                                            ;
    call mult_de_bc                                   ; DEHL = ticks_count[15:0] * tick_duration
    add ix, de                                        ; DEHL += (ticks_count[31:16] * tick_duration) * 65535
    ld d, ixh : ld e, ixl                             ; ....
    jp nc, .save                                      ; if (overflow) - DEHL = 0xffffffff
    ld de, #ffff                                      ; ....
    ld hl, #ffff                                      ; ....
    jp .save                                          ;
.ticks16bit:
    ld de, (var_smf_file.tick_duration)               ; DEHL (wait_duration) = ticks_count * tick_duration
    call mult_de_bc                                   ; ...
.save:
    ld a, h                                           ; wait_duration[31:0] = {wait_duration[30:15],0,wait_duration[14:0]}
    rla                                               ; ... this is required because smf_check_delay
    rl e                                              ; ... can't easily handle wait_duration[15:0] value >0xff00
    rl d                                              ; ... (at least this wouldn't be so fast)
    srl a                                             ; ...
    ld h, a                                           ; ...
    ld (iy+smf_track_t.wait_duration+0), l            ; save wait_duration
    ld (iy+smf_track_t.wait_duration+1), h            ; ...
    ld (iy+smf_track_t.wait_duration+2), e            ; ...
    ld (iy+smf_track_t.wait_duration+3), d            ; ...
    set SMF_TRACK_FLAGS_DELAY, (iy+smf_track_t.flags) ; set delay flag
    ret                                               ;


; IN  - HL - track position
; IN  - IY - pointer to smf_track_t
; OUT - HL - next track position
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
smf_get_next_delay:
    call smf_parse_varint                     ; DEBC = time delta
    ld a, b                                   ; if (delay == 0) then wait_duration = 0
    or c                                      ; ...
    or d                                      ; ...
    or e                                      ; ...
    jp nz, .time_delta_non_zero               ; ...
    ld (iy+smf_track_t.wait_duration+0), c    ; ... wait_duration = 0
    ld (iy+smf_track_t.wait_duration+1), b    ; ...
    ld (iy+smf_track_t.wait_duration+2), e    ; ...
    ld (iy+smf_track_t.wait_duration+3), d    ; ...
    ret                                       ;
.time_delta_non_zero:
    push hl                                   ;
    call smf_set_delay                        ; ... else - calculate and save wait_duration
    pop hl                                    ;
    ret                                       ;


; IN  - HL - track position
; IN  - IY - pointer to smf_track_t
; OUT -  A - status byte
; OUT - BC - data len
; OUT - HL - next track position
; OUT -  F - garbage
; OUT - DE - garbage
smf_get_next_status:
.parse_status_byte:
    call file_get_next_byte                   ; A = byte
    bit 7, a                                  ; if this isn't status byte - reuse last one ("Running Status")
    jr nz, .is_meta_event                     ; ...
    ld a, (iy+smf_track_t.last_status)        ; ...
    dec hl                                    ; ...
.is_meta_event:
    cp #ff                                    ; A == 0xFF?
    jr nz, .is_sysex                          ; ... no
    push hl                                   ; save HL (next track position)
    inc hl                                    ; "FF cc ll... dd..." - cc - command, ll - length, dd - data
    call smf_parse_varint                     ; DEBC = ll - length of dd, HL = next track position (pointing to dd)
    pop de                                    ; DE = prev track position ;XXX assume length is always <= 0xffff
    or a                                      ; reset C flag
    sbc hl, de                                ; get length of cc and ll (HL = HL - DE - C flag)
    add hl, bc                                ; sum length of cc/ll and dd
    ld b, h : ld c, l                         ; BC = total data len
    ex hl, de                                 ; restore HL (next track position)
    ld a, #ff                                 ; restore status byte = 0xFF
    ret                                       ;
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
    ld (iy+smf_track_t.last_status), a        ;
    ld d, a                                   ;
    and #f0                                   ; "sssscccc" - s - status byte, c - channel number
    ld bc, 2                                  ;
    cp #90 : jr nz, 1f         : or d : ret   ; note on
1:  cp #80 : jr nz, 1f         : or d : ret   ; note off
1:  cp #a0 : jr nz, 1f         : or d : ret   ; key after-touch
1:  cp #b0 : jr nz, 1f         : or d : ret   ; control change
1:  cp #c0 : jr nz, 1f : dec c : or d : ret   ; program (patch) change
1:  cp #d0 : jr nz, 1f : dec c : or d : ret   ; channel after-touch (aka "channel pressure")
1:  cp #e0 : jr nz, 1f         : or d : ret   ; pitch wheel change
.eof:
1:  xor a                                     ; not valid command, set to zero
    ret                                       ;


; IN  - HL - track position
; IN  - IY - pointer to smf_track_t
; OUT -  F - C=1 when delay is going on; C=0 when delay is expired
; OUT -  F - Z=1 when no more data on this track; Z=0 when ok
; OUT -  A - status byte (only when F/C=0)
; OUT - BC - data len (only when F/C=0)
; OUT - HL - next track position
; OUT - DE - garbage
smf_process_track:
    bit SMF_TRACK_FLAGS_DELAY, (iy+smf_track_t.flags) ;
    jr z, .check_end_of_track                         ;
    push hl                                           ;
    call smf_check_delay                              ;
    pop hl                                            ;
    jp nc, .get_status                                ; delay has been completed
    ret                                               ;
.check_end_of_track:
    ex hl, de                                         ; check if end of track reached
    ld l, (iy+smf_track_t.end+0)                      ; ...
    ld h, (iy+smf_track_t.end+1)                      ; ...
    or a                                              ; clear C flag
    sbc hl, de                                        ; if (HL==DE) Z=1,C=0; if (HL<DE) Z=0,C=1; if (HL>DE) Z=0,C=0
    ex hl, de                                         ; ...
    jr z, .end_of_file                                ; ...
    jr c, .end_of_file                                ; ...
.get_delay:
    call smf_get_next_delay                           ;
    bit SMF_TRACK_FLAGS_DELAY, (iy+smf_track_t.flags) ; if no delay - get status
    jr z, .get_status                                 ; ...
    push hl                                           ;
    call smf_check_delay                              ; check if delay has been completed prematurely
    pop hl                                            ;
    ret c                                             ; ... exit if no
.get_status:
    call smf_get_next_status                          ;
    or a                                              ; set Z flag if command is 0 (aka not valid)
    ret                                               ;
.end_of_file:
    res SMF_TRACK_FLAGS_PLAY, (iy+smf_track_t.flags)  ; clear play flag
    xor a                                             ; set Z flag
    ret                                               ;


; TODO: SMPTE; negative 'division' field value

; OUT - IX - tick duration
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
smf_update_tick_duration:                     ; tick_duration = tempo / ppqn / machine_constant, where machine_constant = (1000 * int_len_ms / 256)
    ld a, (var_smf_file.tempo+2)              ; ACIX = tempo
    ld c, a                                   ; ...
    xor a                                     ; ... tempo is 24 bit value
    ld ix, (var_smf_file.tempo)               ; ...
    ld de, (var_smf_file.ppqn)                ;
    call div32by16                            ; ACIX = tempo/ppqn
    ld a, (var_int_type)                      ; DE = machine_constant
    or a                                      ; ...
    jr nz, .int_48_8_hz                       ; ...
.int_50_0_hz:
    ld de, 78                                 ; ... 1000 * (1000/50) / 256
    jp 1f                                     ;
.int_48_8_hz:
    ld de, 80                                 ; ... 1000 * (1000/48.8) / 256
1:  xor a                                     ; ACIX = tempo / ppqn / machine_constant
    call div32by16                            ; ...
    or c                                      ; if (ACIX > 0xFFFF) ACIX = 0xFFFF
    jp z, .save                               ; ...
    ld ix, #ffff                              ; ...
.save:
    ld (var_smf_file.tick_duration), ix       ;
    ret                                       ;


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
    call file_get_next_byte      ; A = cmd
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
    call file_get_next_byte      ; tempo = tt tt tt
    dec bc                       ; ...
    ld (var_smf_file.tempo+2), a ; ... MIDI is big endian, Z80 is little endian
    call file_get_next_byte      ; ...
    dec bc                       ; ...
    ld (var_smf_file.tempo+1), a ; ...
    call file_get_next_byte      ; ...
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
    call player_set_title        ;
    pop hl                       ;
    pop bc                       ;
    ; jp .exit                     ;
.exit:
    add hl, bc                   ; next position += remaining data len
    ret                          ;
