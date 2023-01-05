; OUT -  A - garbage
; OUT - BC - garbage
uart_init:
    ld bc, #fffd       ;
    ld a, #07          ;
    out (c), a         ; Select register 7 - Mixer.
    ld b, #bf          ;
    ld a, #f8          ;
    out (c), a         ; Enable port A output.
    ret


; Send Byte to MIDI Device
; ------------------------
; This routine sends a byte to the MIDI port. MIDI devices communicate at 31250 baud,
; although this routine actually generates a baud rate of 31388, which is within the 1%
; tolerance supported by MIDI devices.
; IN  -   A - byte to send
; OUT -  AF - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
; OUT - IXL - garbage
uart_putc:
    ld ixl, a          ; Store the byte to send.
    ld bc, #fffd       ;
    ld a, #0e          ;
    out (c), a         ; Select register 14 - I/O port.

.put_start_bit:
    ld bc, #bffd       ;
    ld a, #fa          ; Set RS232 'RXD' transmit line to 0. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; Send out the START bit.
.delay_after_start_bit:
    ld e, #03          ; (7) Introduce delays such that the next bit is output 113 T-states from now.
.delay1:
    dec e              ; (4)
    jr nz, .delay1     ; (12/7)
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)
    nop                ; (4)

.send_bits:
    ld a, ixl          ; (4) Retrieve the byte to send.
    ld d, #08          ; (7) There are 8 bits to send.
.loop:
    rra                ; (4) Rotate the next bit to send into the carry.
    ld ixl, a          ; (4) Store the remaining bits.
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
    ld e, #02          ; (7) Introduce delays such that the next data bit is output 113 T-states from now.
.delay2:
    dec e              ; (4)
    jr nz, .delay2     ; (12/7)
    nop                ; (4)
    add a, #00         ; (7)

    ld a, ixl          ; (4) Retrieve the remaining bits to send.
    dec d              ; (4) Decrement the bit counter.
    jr nz, .loop       ; (12/7) Jump back if there are further bits to send.

.delay_before_stop_bit:
    nop                ; (4) Introduce delays such that the stop bit is output 113 T-states from now.
    nop                ; (4)
    add a, #00         ; (7)
    nop                ; (4)
    nop                ; (4)
.put_stop_bit:
    ld a, #fe          ; (7) Set RS232 'RXD' transmit line to 0. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11) Send out the STOP bit.
.delay_after_stop_bit:
    ld e, #06          ; (7) Delay for 101 T-states (28.5us).
.delay3:
    dec e              ; (4)
    jr nz, .delay3     ; (12/7)

    ret                ; (10)
