; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Division

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
    sbc hl,de
.setbit:
    .db $DD, $2C     ; inc ixl, change to inc ix to avoid undocumented
    djnz .loop
    ret
