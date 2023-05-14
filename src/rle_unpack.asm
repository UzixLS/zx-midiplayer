; IN  - DE - destination
; IN  - HL - source
; OUT - DE - pointer to next untouched byte at dest
; OUT - HL - pointer to next byte after unpacked block
rle_unpack:
    ld b, 1                               ;
    ld a, (hl)                            ;
    inc hl                                ;
    cp (hl)                               ;
    jr nz, .fill                          ;
    inc hl                                ;
    ld b, (hl)                            ;
    inc hl                                ;
    inc b                                 ;
    ret z                                 ;
    inc b                                 ;
.fill:
    ld (de), a                            ;
    inc de                                ;
    djnz .fill                            ;
    jr rle_unpack                         ;
