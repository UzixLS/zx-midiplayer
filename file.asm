; Page         128  +3
; 0 000
; 1 001        slow
; 2 010 0x8000
; 3 011        slow
; 4 100             slow
; 5 101 0x4000 slow slow
; 6 110             slow
; 7 111 altscr slow slow

file_pages:
    db #10, #14, #16, #13

file_base_addr = 0xC000


; IN  - HL - file position
; OUT -  A - data
; OUT - HL - next file position
file_get_next_byte:
    push bc                                                          ;
    push hl                                                          ;
    ld a, h                                                          ; compare requested page with current page
    and #c0                                                          ; ...
.pg:cp #00                                                           ; ... self modifying code! see bellow
    jp z, .get                                                       ; ...
.switch_page:
    ld (.pg+1), a                                                    ; self modifying code! save new page selector
    ld bc, #7ffd                                                     ;
    or a   : jp nz, 1f : ld a, (file_pages+0) : out (c), a : jp .get ;
1:  cp #40 : jp nz, 1f : ld a, (file_pages+1) : out (c), a : jp .get ;
1:  cp #80 : jp nz, 1f : ld a, (file_pages+2) : out (c), a : jp .get ;
1:                       ld a, (file_pages+3) : out (c), a : jp .get ;
.get:
    ld a, h                                                          ; position = position[5:0]
    and #3f                                                          ; ...
    ld h, a                                                          ; ...
    ld bc, file_base_addr                                            ; A  = *(base_addr + position)
    add hl, bc                                                       ; ...
    ld a, (hl)                                                       ; ...
    pop hl                                                           ;
    inc hl                                                           ; position++
    pop bc                                                           ;
    ret
