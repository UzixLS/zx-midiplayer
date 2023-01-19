; https://github.com/breakintoprogram/lib-spectrum/blob/master/lib/output.z80


; Simple clear-screen routine
; IN  -  A - colour to clear attribute block of memory with
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
clear_screen:
    ld hl, 16384        ; start address of screen bitmap
    ld de, 16385        ; address + 1
    ld bc, 6144         ; length of bitmap memory to clear
    ld (hl), 0          ; set the first byte to 0
    ldir                ; copy this byte to the second, and so on
    ld bc, 767          ; length of attribute memory, less one to clear
    ld (hl), a          ; set the first byte to A
    ldir                ; copy this byte to the second, and so on
    ret


; Fill a box of the screen with a solid colour
; IN  -  A - the colour
; IN  - HL - address in the attribute map
; IN  -  C - width
; IN  -  B - height
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
    dec c
    jr nz, .loop_columns
    pop bc
    pop hl
    add hl, de
    djnz .loop_rows
    ret


; Print NULL(0)-terminated string
; IN  - IX - pointer to string
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; OUT -  A - 0
; OUT - IX - pointer to NULL byte
; OUT -  F - garbage
; OUT - DE - garbage
; OUT - HL - garbage
print_string0:
    call get_char_address ; HL = screen address
.loop:
    ld a, (ix)            ; fetch the character to print
    or a                  ; exit if NULL character detected
    ret z                 ; ...
    call print_char       ;
    inc l                 ; go to the next screen address
    inc ix                ; increase IX to the next character
    jr .loop              ; loop back to print next character
    ret

; Print string
; IN  - IX - pointer to string
; IN  -  H - Y character position [0..23]
; IN  -  L - X character position [0..31]
; IN  -  B - string length
; OUT -  A - 0
; OUT - IX - pointer to NULL byte
; OUT -  F - garbage
; OUT - DE - garbage
; OUT - HL - garbage
print_stringl:
    call get_char_address ; HL = screen address
.loop:
    ld a, (ix)            ; fetch the character to print
    push bc               ;
    call print_char       ;
    pop bc                ;
    inc l                 ; go to the next screen address
    inc ix                ; increase IX to the next character
    djnz .loop:           ; loop back to print next character
    ret

; Get screen address
; IN  -  H - Y character position
; IN  -  L - X character position
; OUT - HL - address
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
    or %01000000
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
    or %01000000        ; set base address of screen
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
    ld A, C
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
; IN  - DE - address of character set
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
; IN  - DE - address of character set (if entering at print_char_udg)
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
print_char:
    ld de, 0x3c00       ; address of character set in rom
    push hl
    ld b, 0             ; get index into character set
    ld c, a
    dup 3
    sla c
    rl b
    edup
    ex de, hl
    add hl, bc
    ex de, hl
    call print_udg8
    pop hl
    ret


; Print a UDG (Single Height)
; IN  - DE - character data
; IN  - HL - screen address
; OUT - AF - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT -  H - garbage
print_udg8:
    ld b, 8             ; loop counter
.loop:
    ld a, (de)          ; get the byte from the ROM into A
    ld (hl), a          ; stick A onto the screen
    inc de              ; goto next byte of character
    inc h               ; goto next line on screen
    djnz .loop          ; loop around whilst it is Not Zero (NZ)
    ret
