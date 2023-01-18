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
    cp CPU_FREQ_7_MHZ                ;
    jp z, uart_patch_for_cpu_7mhz    ;
    cp CPU_FREQ_3_54_MHZ             ;
    jp z, uart_patch_for_cpu_3_54mhz ;
    ret                              ; ...

uart_patch_for_cpu_3_54mhz:
    xor a                       ; 0x00 = nop (4 T-states). Next byte at destination is 0x00 too.
    ld (uart_putc.A), a         ; ... so we're replacing "ld a,0" (7) with "nop : nop" (8)
    ld (uart_putc.B), a         ; ...
    ret                         ;

uart_patch_for_cpu_7mhz
    ld a, 12                    ; ld e, 12
    ld (uart_putc.E+1), a       ;
    xor a                       ; jr $+2
    ld (uart_putc.C+1), a       ; ...
    ld (uart_putc.D+1), a       ; ...
    ret                         ;


; Send Byte to MIDI Device
; ------------------------
; This routine sends a byte to the MIDI port. MIDI devices communicate at 31250 baud,
; although this routine actually generates a baud rate of 31388, which is within the 1%
; tolerance supported by MIDI devices.
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
    ld a, 0            ; (7)
    ld a, (ix)         ; (19)
    bit 0, (ix)        ; (20)
.C: jr .send_bits      ; (12) Self modifying code! See uart_patch_for_cpu_7mhz
    ld a, 0            ; (7) Additional delay for 7MHz CPU. 224 T-states total
    ld a, 7            ; (7)
1:  dec a              ; (4*7)
    jp nz, 1b          ; (10*7)

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
    nop                ; (4) Introduce delays such that the next data bit is output 112 T-states from now.
.B: ld a, 0            ; (7) Self modifying code! See uart_patch_for_cpu_3_54mhz
    ld a, 0            ; (7)
    ld a, 0            ; (7)
    ld a, 0            ; (7)
.D: jr .check_for_loop ; (12) Self modifying code! See uart_patch_for_cpu_7mhz
    ld a, 0            ; (7) Additional delay for 7MHz CPU. 224 T-states total
    ld a, 7            ; (7)
1:  dec a              ; (4*7)
    jp nz, 1b          ; (10*7)
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
.E: ld e, 6            ; (7) Delay for 101 T-states (28.5us). Self modifying code! See uart_patch_for_cpu_7mhz
1:  dec e              ; (4)
    jr nz, 1b          ; (12/7)

    ret                ; (10)
