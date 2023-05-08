; https://github.com/breakintoprogram/lib-spectrum/blob/master/lib/output.z80


; IN  - A  = #40 - use screen at #4000, A = #C0 - use screen at #C000
; OUT - AF - garbage
screen_select:
    ld (get_char_address.A+1), a  ;
    ld (clear_screen.A+2), a      ;
    ld (clear_screen.B+2), a      ;
    ld (get_pixel_address.A+1), a ;
    add #18                       ;
    ld (get_attr_address.A+1), a  ;
    ret                           ;


; Simple clear-screen routine
; IN  -  A - colour to clear attribute block of memory with
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
clear_screen:
.A: ld hl, 0x4000       ; self modifying code! see screen_select
.B: ld de, 0x4001       ; self modifying code! see screen_select
    ld bc, 6144         ;
    ld (hl), 0          ;
    ldir                ;
    ld bc, 767          ;
    ld (hl), a          ;
    ldir                ;
    ret                 ;


; Clear screen pixel area routine
; IN  - B   - lines count [0..23]
; IN  - C   - width columns [1..31]
; IN  - H   - Y [0..23]
; IN  - L   - X [0..31]
; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
clear_screen_area_at:
    rlc b : rlc b : rlc b
    rlc h : rlc h : rlc h
    rlc l : rlc l : rlc l
    ; fall through to clear_screen_area ...

; Clear screen pixel area routine
; IN  - B   - lines count [0..191]
; IN  - C   - width columns [1..31]
; IN  - H   - Y [0..191]
; IN  - L   - X [0..255]
; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
clear_screen_area:
    ld a, c                 ;
    dec a                   ;
    jr z, .onebytewidth     ; we cant use ldir when width=1
    ld (.A+1), a            ;
    push bc                 ;
    ld b, h : ld c, l       ; HL = screen address
    call get_pixel_address  ; ...
    jp .first_line          ;
.next_line:
    push bc                 ;
    call pixel_address_down ;
.first_line:
    push hl                 ;
.A: ld bc, 0                ; clear line. self modifying code! see above
    ld d, h : ld e, l       ; ...
    inc de                  ; ...
    ld (hl), b              ; ...
    ldir                    ; ... do { *(DE++) = *(HL++) } while(--BC) // columns--
    pop hl                  ;
    pop bc                  ;
    djnz .next_line         ;
    ret                     ;
.onebytewidth:
    push bc                 ;
    ld b, h : ld c, l       ; HL = screen address
    call get_pixel_address  ; ...
    pop bc                  ;
    dec c                   ;
.next_line_1:
    ld (hl), c              ;
    call pixel_address_down ;
    djnz .next_line_1       ;
    ret                     ;


; Fill a box of the screen with a solid colour
; IN  -  A - the colour
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; IN  -  B - width
; IN  -  C - height
; OUT - AF - garbage
; OUT - DE - garbage
; OUT - HL - garbage
fill_attr_at:
    push af
    call get_attr_address
    pop af
    ; fall through to fill_attr ...

; Fill a box of the screen with a solid colour
; IN  -  A - the colour
; IN  - HL - address in the attribute map
; IN  -  B - width
; IN  -  C - height
; OUT -  F - garbage
; OUT - DE - garbage
; OUT - HL - garbage
fill_attr:
    ld de, 32
.loop_rows:
    push hl
    push bc
.loop_columns:
    ld (hl), a
    inc l
    djnz .loop_columns
    pop bc
    pop hl
    add hl, de
    dec c
    jp nz, .loop_rows
    ret


; Vertical scroll screen area
; IN  -  B - lines count [0..23]
; IN  -  C - width columns [2..31]
; IN  -  H - source Y [0..23]
; IN  -  L - X [0..31]
; IN  -  D - dest Y [0..23]
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
vertical_scroll_at:
    rlc b : rlc b : rlc b
    rlc h : rlc h : rlc h
    rlc l : rlc l : rlc l
    rlc d : rlc d : rlc d
    ; fall through to vertical_scroll ...


; Vertical scroll screen area
; IN  -  B - lines count [0..191]
; IN  -  C - width columns [2..31]
; IN  -  H - source Y [0..191]
; IN  -  L - X [0..255]
; IN  -  D - dest Y [0..191]
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
; OUT - IY - garbage
vertical_scroll:
    push hl : pop ix       ; IXH=Y_source IXL=X
    ld iyh, d : ld iyl, b  ; IYH=Y_dest   IYL=lines
    ld a, c                ; set width for ldir
    ld (.A+1), a           ; ...
    dec a                  ; ...
    ld (.B+1), a           ; ...
    ld a, h                ; if src == dst - exit
    sub d                  ; ... A = src-dst
    ret z                  ; ...
    jp c, .down            ;
.up:
    ld (.E+1), a           ; set how much lines to clear
    ld a, #24              ; inc ixh/iyh opcode
    ld (.C+1), a           ; ...
    ld (.D+1), a           ; ...
    jp .first_line         ;
.down:
    neg                    ; set how much lines to clear
    ld (.E+1), a           ; ...
    dec b                  ;
    ld a, h                ; source_y += (lines-1)
    add b                  ; ...
    ld ixh, a              ; ...
    ld a, d                ; dest_y += (lines-1)
    add b                  ; ...
    ld iyh, a              ; ...
    ld a, #25              ; dec ixh/iyh opcode
    ld (.C+1), a           ; ...
    ld (.D+1), a           ; ...
    jp .first_line         ;
.next_line:
.C: inc ixh                ; source_y++ // self modifying code! see above
.D: inc iyh                ; dest_y++   // self modifying code! see above
.first_line:
    ld b, iyh : ld c, ixl  ; DE = dest address
    call get_pixel_address ; ...
    ex de, hl              ; ...
    ld b, ixh : ld c, ixl  ; HL = source address
    call get_pixel_address ; ...
    push hl                ;
.A: ld bc, 0               ; copy line. self modifying code! see above
    ldir                   ; ... do { *(DE++) = *(HL++) } while(--BC) // columns--
    pop hl                 ;
.E: ld a, 0                ; check if we should clear line. self modifying code! see above
    cp iyl                 ; ...
    jr nc, .clear_line     ; iyl <= a
    dec iyl                ;
    jp nz, .next_line      ; lines--
.clear_line:
    ld d, h : ld e, l      ;
    inc de                 ;
.B: ld bc, 0               ; self modifying code! see above
    ld (hl), b             ;
    ldir                   ;
    dec iyl                ;
    jp nz, .next_line      ; lines--
    ret                    ;


; Get screen address
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; OUT - HL - address (attribute area)
; OUT - AF - garbage
get_attr_address: ; IN:000yyyyy 000xxxxx OUT: 010110yy yyyxxxxx
    ld a, h
    and %00000111
    rrca
    rrca
    rrca
    or l
    ld l, a
    ld a, h
    and %00011000
    rrca
    rrca
    rrca
.A: or #58   ; self modifying code! see screen_select
    ld h, a
    ret


; Get screen address
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; OUT - HL - address (pixel area)
; OUT - AF - garbage
get_char_address:
    ld a, h
    and %00000111
    rra
    rra
    rra
    rra
    or l
    ld l, a
    ld a, h
    and %00011000
.A: or #40        ; self modifying code! see screen_select
    ld h, a
    ret


; Move HL down one character line
; IN  - HL - address
; OUT - HL - address
; OUT - AF - garbage
char_address_down:
    ld a, l
    add a, 32
    ld l, a
    ret nc
    ld a, h
    add a, 8
    ld h, a
    ret


; Get screen address
; IN  -  B - Y pixel position
; IN  -  C - X pixel position
; OUT -  A - pixel position within character in A
; OUT - HL - address
; OUT -  F - garbage
get_pixel_address:
    ld a, b             ; calculate Y2, Y1, Y0
    and %00000111       ; mask out unwanted bits
.A: or #40              ; set base address of screen. Self modifying code! see screen_select
    ld h, a             ; store in H
    ld a, b             ; calculate Y7, Y6
    rra                 ; shift to position
    rra
    rra
    and %00011000       ; mask out unwanted bits
    or h                ; OR with Y2, Y1, Y0
    ld h, a             ; store in H
    ld a, b             ; calculate Y5, Y4, Y3
    rla                 ; shift to position
    rla
    and %11100000       ; mask out unwanted bits
    ld l, a             ; store in L
    ld a, c             ; calculate X4, X3, X2, X1, X0
    rra                 ; shift into position
    rra
    rra
    and %00011111       ; mask out unwanted bits
    or l                ; OR with Y5, Y4, Y3
    ld l, a             ; store in L
    ld a, c
    and 7
    ret


; Move HL down one pixel line
; IN  - HL - address
; OUT - HL - address
; OUT - AF - garbage
pixel_address_down:
    inc h               ; go down onto the next pixel line
    ld a, h             ; check if we have gone onto next character boundary
    and 7
    ret nz              ; no, so skip the next bit
    ld a, l             ; go onto the next character line
    add a, 32
    ld l, a
    ret c               ; check if we have gone onto next third of screen
    ld a, h             ; yes, so go onto next third
    sub 8
    ld h, a
    ret


; Move HL up one pixel line
; IN  - HL - address
; OUT - HL - address
; OUT - AF - garbage
pixel_address_up:
    dec h               ; go up onto the next pixel line
    ld a, h             ; check if we have gone onto the next character boundary
    and 7
    cp 7
    ret nz
    ld a, l
    sub 32
    ld l, a
    ret c
    ld a, h
    add a, 8
    ld h, a
    ret


; Print NULL(0)-terminated string
; IN  - IX - pointer to string
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; OUT -  A - 0
; OUT - IX - pointer to NULL byte
; OUT - HL - screen address of last printed character
; OUT -  F - garbage
; OUT - BC - garbage
; OUT - DE - garbage
print_string0_at:
    call get_char_address ; HL = screen address
print_string0:
.loop:
    ld a, (ix)            ; fetch the character to print
    or a                  ; exit if NULL character detected
    ret z                 ; ...
    call print_char       ;
    inc l                 ; go to the next screen address
    inc ix                ; increase IX to the next character
    jr .loop              ; loop back to print next character
    ret                   ;

; Print string
; IN  - IX - pointer to string
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; IN  -  B - string length
; OUT -  A - 0
; OUT - IX - pointer to NULL byte
; OUT - HL - screen address of last printed character
; OUT -  F - garbage
; OUT - DE - garbage
print_stringl_at:
    call get_char_address ; HL = screen address
print_stringl:
.loop:
    ld a, (ix)            ; fetch the character to print
    push bc               ;
    call print_char       ;
    pop bc                ;
    inc l                 ; go to the next screen address
    inc ix                ; increase IX to the next character
    djnz .loop            ; loop back to print next character
    ret                   ;


; Print a HEX/BCD value
; IN  - IX - pointer to HEX/BCD value
print_hex_8     ld a, (ix) : inc ix: call print_hex
print_hex_6     ld a, (ix) : inc ix: call print_hex
print_hex_4     ld a, (ix) : inc ix: call print_hex
print_hex_2     ld a, (ix) : inc ix
    ; fall through to print_hex ...

; Print a single HEX/BCD value
; IN  -  A - character to print
; IN  - HL - screen address to print character at
; OUT - HL - next screen address
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
print_hex:
    push af             ; store the value
    and 0xf0            ; get the top nibble
    rra                 ; shift into bottom nibble
    rra
    rra
    rra
    cp 10               ; if a >= 10 - handle as HEX
    jp c, 1f            ; ...
    add a, 'A'-10       ; add to ASCII 'A'
    call print_char     ; print the character
    jp 2f
1:  add a, '0'          ; add to ASCII '0'
    call print_char     ; print the character
2:  inc l               ; move right one space
    pop af
    and 0x0f            ; get the bottom nibble
    cp 10               ; if a >= 10 - handle as HEX
    jp c, 1f            ; ...
    add a, 'A'-10       ; add to ASCII 'A'
    call print_char     ; print the character
    inc l               ; move right one space
    ret
1:  add a, '0'          ; add to ASCII '0'
    call print_char     ; print
    inc l               ; move right one space
    ret


; Print a single character out to an X/Y position
; IN  -  A - character to print
; IN  -  C - X character position [0..31]
; IN  -  B - Y character position [0..23]
; OUT - HL - screen address
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
print_char_at:
    push af
    call get_char_address  ; HL = screen address
    pop af
    ; fall through to print_char ...

; Print a single character out to a screen address
; IN  -  A - character to print
; IN  - HL - screen address to print character at
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
print_char:
    ld de, 0x3c00       ; address of character set in rom
    cp 128              ; use UDG character set if character >= 128
    jp c, 1f            ; ...
    ld de, udg-128*8    ; ...
1:  push hl
    ld b, 0             ; get index into character set
    ld c, a
    sla c : rl b        ; address = character_set_address + character_code * 8
    sla c : rl b        ; ...
    sla c : rl b        ; ...
    ex de, hl           ; ...
    add hl, bc          ; ...
.print_udg8:
    ld b, 8             ; loop counter
.loop:
    ld a, (hl)          ; get the byte from the ROM into A
    ld (de), a          ; stick A onto the screen
    inc hl              ; goto next byte of character
    inc d               ; goto next line on screen
    djnz .loop          ; loop around whilst it is Not Zero (NZ)
    pop hl
    ret
