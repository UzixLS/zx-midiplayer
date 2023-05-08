; OUT -  A - garbage
; OUT - BC - garbage
; OUT - HL - garbage
uart_init:
    ld bc, #fffd                     ;
    ld a, #07                        ;
    out (c), a                       ; Select register 7 - Mixer.
    ld b, #bf                        ;
    ld a, #fc                        ;
    out (c), a                       ; Enable port A output.
    ld a, (var_cpu_freq)             ; if (cpu frequency != 3.5MHz) then patch code for it
    cp CPU_FREQ_28_MHZ               ;
    jp z, uart_patch_for_cpu_28mhz   ;
    cp CPU_FREQ_14_MHZ               ;
    jp z, uart_patch_for_cpu_14mhz   ;
    cp CPU_FREQ_7_MHZ                ;
    jp z, uart_patch_for_cpu_7mhz    ;
    cp CPU_FREQ_3_54_MHZ             ;
    jp z, uart_patch_for_cpu_3_54mhz ;
    ret                              ; ...

uart_patch_for_cpu_3_54mhz:
    xor a                            ; 0x00 = nop (4 T-states). Next byte at destination is 0x00 too.
    ld (uart_putc.A), a              ; ... so we're replacing "ld a,0" (7) with "nop : nop" (8)
    ld (uart_putc.B), a              ; ...
    ret                              ;
uart_patch_for_cpu_7mhz
    ld a, 12                         ; ld e, 12
    ld (uart_putc.E+1), a            ;
    ld a, 11                         ; ld a, 11
    ld (uart_putc.C+1), a            ; ...
    ld a, 9                          ; ld a, 9
    ld (uart_putc.D+1), a            ; ...
    ret                              ;
uart_patch_for_cpu_14mhz
    ld a, 24                         ; ld e, 24
    ld (uart_putc.E+1), a            ;
    ld a, 27                         ; ld a, 27
    ld (uart_putc.C+1), a            ; ...
    ld a, 25                         ; ld a, 25
    ld (uart_putc.D+1), a            ; ...
    ret                              ;
uart_patch_for_cpu_28mhz
    ld a, 48                         ; ld e, 48
    ld (uart_putc.E+1), a            ;
    ld a, 59                         ; ld a, 59
    ld (uart_putc.C+1), a            ; ...
    ld a, 57                         ; ld a, 57
    ld (uart_putc.D+1), a            ; ...
    ret                              ;


; Send byte to MIDI device
; Baudrate 31250 for 3.5MHz CPU or 31388 for 3.5469MHz CPU
; IN  -   A - byte to send
; OUT -  AF - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
uart_putc:
    ld e, a            ; Store the byte to send.
    ld bc, #fffd       ;
    ld a, #0e          ;
    out (c), a         ; Select register 14 - I/O port.

.put_start_bit:
    ld bc, #bffd       ;
    ld a, #fa          ; Set RS232 'RXD' transmit line to 0. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; Send out the START bit.
.delay_after_start_bit:
.A: ld a, 0            ; (7) Introduce delays such that the next bit is output 112 T-states from now. Self modifying code! See uart_patch_for_cpu_3_54mhz
    ld a, r            ; (9)
.C: ld a, 3            ; (7) Self modifying code! See uart_patch_for_cpu_*. Patched for 112/224/448/896 T-states total
1:  dec a              ; (4*3) or (4*11) or (4*27) or (4*59)
    jp nz, 1b          ; (10*3) or (10*11) or (10*27) or (10*59)

.send_bits:
    ld a, e            ; (4) Retrieve the byte to send.
    ld d, 8            ; (7) There are 8 bits to send.
.loop:
    rra                ; (4) Rotate the next bit to send into the carry.
    ld e, a            ; (4) Store the remaining bits.
    jp nc, .put_0      ; (10) Jump if it is a 0 bit.
.put_1:
    ld a, #fe          ; (7) Set RS232 'RXD' transmit line to 1. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11)
    jr .delay_next_bit ; (12) Jump forward to process the next bit.
.put_0:
    ld a, #fa          ; (7) Set RS232 'RXD' transmit line to 0. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11)
    jr .delay_next_bit ; (12) Jump forward to process the next bit.
.delay_next_bit:
.B: ld a, 0            ; (7) Introduce delays such that the next data bit is output 112 T-states from now. Self modifying code! See uart_patch_for_cpu_3_54mhz
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)
.D: ld a, 1            ; (7) Self modifying code! See uart_patch_for_cpu_*. Patched for 112/224/448/896 T-states total
1:  dec a              ; (4*1) or (4*9) or (4*25) or (4*57)
    jp nz, 1b          ; (10*1) or (10*9) or (10*25) or (10*57)
.check_for_loop:
    ld a, e            ; (4) Retrieve the remaining bits to send.
    dec d              ; (4) Decrement the bit counter.
    jr nz, .loop       ; (12/7) Jump back if there are further bits to send.

.delay_before_stop_bit:
    ld a, 0            ; (7) Introduce delays such that the stop bit is output 112 T-states from now.
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)
.put_stop_bit:
    ld a, #fe          ; (7) Set RS232 'RXD' transmit line to 1. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11) Send out the STOP bit.
.delay_after_stop_bit:
.E: ld e, 6            ; (7) Delay for 101 T-states (28.5us). Self modifying code! See uart_patch_for_cpu_*
1:  dec e              ; (4)
    jr nz, 1b          ; (12/7)
    ret                ; (10)


; IN  -  A - byte to put into tx buffer
; OUT -  F - garbage
; OUT - BC - garbage
; OUT - DE - garbage
uart_putc_txbuf:
    push hl                     ;
    ld hl, uart_txbuf_len       ;
    ld c, (hl)                  ;
    inc (hl)                    ; txbuf_len++
    jp p, .put                  ; if (txbuf_len > 127) flush txbuf
.overflow:
    ld (hl), 1                  ;
    push af                     ;
    push ix                     ;
    ld ixl, 127                 ;
    call uart_flush_txbuf.enter ;
    pop ix                      ;
    pop af                      ;
    ld c, 0                     ;
.put:
    ld b, 0                     ;
    ld hl, uart_txbuf           ;
    add hl, bc                  ;
    ld (hl), a                  ; txbuf[txbuf_len_initial] = A
    pop hl                      ;
    ret                         ;


; OUT - AF  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
; OUT - IXL - garbage
uart_flush_txbuf:
    ld a, (uart_txbuf_len)   ;
    or a                     ;
    ret z                    ;
    ld ixl, a                ;
    xor a                    ;
    ld (uart_txbuf_len), a   ;
.enter:
    ld hl, uart_txbuf        ;
.loop:                       ;
    ld a, (hl)               ;
    di : call uart_putc : ei ;
    inc hl                   ;
    dec ixl                  ;
    jp nz, .loop             ;
    ret                      ;
