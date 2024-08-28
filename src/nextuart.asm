; MIDI Out for ZX Spectrum Next, using joystick port 2 in UART mode
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - HL - garbage
nextuart_prepare:
    ld bc, #243b                     ; NextReg Register Select port
    xor a                            ; Register 0 (Machine ID)
    out (c), a                       ; Select register
    ld b, #25                        ; NextReg Data port
    in a, (c)                        ; Read register
    and #0f                          ; Select relevant bits
    cp #0a                           ; ZX Spectrum Next machine?
    ret nz                           ; No -> break

    xor a                            ; Opcode for NOP
    ld (nextuart_putc), a            ; Enable UART send routine
    ld b, #24                        ; NextReg Register Select port
    ld a, #0b                        ; Register 11 (Joystick I/O Mode)
    out (c), a                       ; Select register
    ld b, #25                        ; NextReg Data port
    ld a, #b0                        ; I/O mode, UART on Joystick 2
    out (c), a                       ; Write register
    ld b, #15                        ; UART Select port
    ld a, #10                        ; Select UART 0, set 3 highest prescaler bits (always 0 for MIDI)
    out (c), a                       ; Write UART settings
    ld b, #16                        ; UART Frame port
    ld a, #98                        ; Init TX/RX, set 8N1
    out (c), a                       ; Write UART settings
    ld a, #18                        ; set 8N1
    out (c), a                       ; Write UART settings
    ld b, #24                        ; NextReg Register Select port
    ld a, #11                        ; Register 17 (Video timing)
    out (c), a                       ; Select register
    ld b, #25                        ; NextReg Data port
    in a, (c)                        ; Read register
    and #07                          ; Select relevant bits
    cp 0                             ; Video timing 0? (28,0 MHz)
    jr nz, .clock1                   ; No -> Check next timing
    ld hl, 28000000 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock1:
    cp 1                             ; Video timing 1? (28,571429 MHz)
    jr nz, .clock2                   ; No -> Check next timing
    ld hl, 28571429 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock2:
    cp 2                             ; Video timing 2? (29,464286 MHz)
    jr nz, .clock3                   ; No -> Check next timing
    ld hl, 29464286 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock3:
    cp 3                             ; Video timing 3? (30,0 MHz)
    jr nz, .clock4                   ; No -> Check next timing
    ld hl, 30000000 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock4:
    cp 4                             ; Video timing 4? (31,0 MHz)
    jr nz, .clock5                   ; No -> Check next timing
    ld hl, 31000000 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock5:
    cp 5                             ; Video timing 5? (32,0 MHz)
    jr nz, .clock6                   ; No -> Check next timing
    ld hl, 32000000 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock6:
    cp 6                             ; Video timing 6? (33,0 MHz)
    jr nz, .clock7                   ; No -> Video timing 7
    ld hl, 33000000 / 31250          ; Calculate prescaler
    jr .clock9                       ; Set prescaler
.clock7:
    ld hl, 27000000 / 31250          ; Video timing 7 (27,0 MHz)
.clock9:
    rl l                             ; Shift bit 7 from low byte to carry
    rl h                             ; Shift carry to high byte, H contains now upper 7 prescaler bits
    srl l                            ; Restore low byte, L contains now lower 7 prescaler bits
    ld b, #14                        ; UART RX / Set prescaler port
    ld a, h                          ; Prescaler upper 7 bits
    or #80                           ; Set bit 7 (indentifies high byte)
    out (c), a                       ; Write prescaler upper 7 bits
    out (c), l                       ; Write prescaler lower 7 bits
    ret                              ;


; Send byte to MIDI device
; IN  -   A - byte to send
; OUT -  AF - garbage
; OUT -  BC - garbage
; OUT -   E - garbage
nextuart_putc:
    ret                              ; will be replaced by NOP if ZX Next detected
                                     ; (prevents hanging in next part)
    ld e, a                          ; Store the byte to send
    ld bc, #133b                     ; UART TX / Status port
.wait:
    in a, (c)                        ; Read UART status
    and #02                          ; TX buffer full?
    jr nz, .wait                     ; wait
    out (c), e                       ; Send byte to UART TX
    ret                              ;


nextuart_flush_txbuf:
    ret                              ;
