; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Division
; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Multiplication

; IN  - ACIX - dividend
; IN  - DE   - divisor
; OUT - ACIX - quotient
; OUT - DE   - divisor
; OUT - HL   - remainder
; OUT - B    - 0
div32by16:
    ld hl, 0
    ld b, 32
.loop:
    add ix, ix
    rl c
    rla
    adc hl, hl
    jr c, .overflow
    sbc hl, de
    jr nc, .setbit
    add hl, de
    djnz .loop
    ret
.overflow:
    or a
    sbc hl, de
.setbit:
    .db $DD, $2C     ; inc ixl, change to inc ix to avoid undocumented
    djnz .loop
    ret


; IN  - DE
; IN  - BC
; OUT - DEHL
; OUT - AF   - garbage
mult_de_bc:
   ld hl, 0
   sla e       ; optimised 1st iteration
   rl d
   jr nc, $+4
   ld h, b
   ld l, c
   ld a, 15
.loop:
   add hl, hl
   rl e
   rl d
   jr nc, $+6
   add hl, bc
   jr nc, $+3
   inc de
   dec a
   jr nz, .loop
   ret
