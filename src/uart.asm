; OUT -  A - garbage
; OUT - BC - garbage
; OUT - HL - garbage
uart_init:
    ld a, (var_device.cpu_freq)      ; if (cpu frequency != 3.5MHz) then patch code for it
    cp CPU_28_MHZ                    ;
    jr z, .patch_for_cpu_28mhz       ;
    cp CPU_14_MHZ                    ;
    jr z, .patch_for_cpu_14mhz       ;
    cp CPU_7_MHZ                     ;
    jr z, .patch_for_cpu_7mhz        ;
    cp CPU_3_54_MHZ                  ;
    jr z, .patch_for_cpu_3_54mhz     ;
    ret                              ;
.patch_for_cpu_3_54mhz:
    xor a                            ; 0x00 = nop (4 T-states). Next byte at destination is 0x00 too
    ld (uart_putc.A), a              ; ... so we're replacing "ld a,0" (7) with "nop : nop" (8)
    ret                              ;
.patch_for_cpu_7mhz:
    ld a, 12                         ; ld e, 12
    ld (uart_putc.C+1), a            ;
    ld a, 10                         ; ld a, 10
    ld (uart_putc.B+1), a            ; ...
    ret                              ;
.patch_for_cpu_14mhz:
    ld a, 24                         ; ld e, 24
    ld (uart_putc.C+1), a            ;
    ld a, 26                         ; ld a, 26
    ld (uart_putc.B+1), a            ; ...
    ret                              ;
.patch_for_cpu_28mhz:
    ld a, 48                         ; ld e, 48
    ld (uart_putc.C+1), a            ;
    ld a, 58                         ; ld a, 58
    ld (uart_putc.B+1), a            ; ...
    ret                              ;


uart_prepare:
    xor a                            ;
    ld (uart_txbuf_len), a           ;
.turbosound_chip_select:
    ld bc, #fffd                     ;
    ld a, (var_settings.output)      ; 0 - don't change, 1 - TS chip #1, 2 - TS chip #2
    or a                             ;
    jr z, .port_a_configure          ;
    add #fe - 1                      ; #FF - select chip #1, #FE - select chip #2
    xor 1                            ; ...
    out (c), a                       ; ...
.port_a_configure:
    ld a, #07                        ; Select register 7 - Mixer
    out (c), a                       ; ...
    ld b, #bf                        ;
    ld a, #fc                        ; Enable port A output
    out (c), a                       ; ...
    ret                              ;


; Send byte to MIDI device
; Baudrate 31250 for 3.5MHz CPU or 31388 for 3.5469MHz CPU
; IN  -   A - byte to send
; OUT -  AF - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
uart_putc:
    di                 ;
    ld e, a            ; Store the byte to send
    ld bc, #fffd       ;
    ld a, #0e          ;
    out (c), a         ; Select register 14 - I/O port
    ld b, #bf          ;
    ld d, 1+8+1        ; There are START+DATA+STOP bits to send
    scf                ; Put STOP bit into carry flag
    jr .put_0          ; Send out the START bit
.loop:
    rr e               ; (8) Rotate the next bit to send into the carry
    jp nc, .put_0      ; (10) Jump if it is a 0 bit
.put_1:
    ld a, #fe          ; (7) Set RS232 'RXD' transmit line to 1. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11)
    jr .next_bit       ; (12) Jump forward to process the next bit
.put_0:
    ld a, #fa          ; (7) Set RS232 'RXD' transmit line to 0. (Keep KEYPAD 'CTS' output line low to prevent the keypad resetting)
    out (c), a         ; (11)
    jr .next_bit       ; (12) Jump forward to process the next bit
.next_bit:
.A: ld a, 0            ; (7) Self modifying code! See uart_init.patch_for_cpu_3_54mhz. Patched for 113 T-states total
.B: ld a, 2            ; (7) Self modifying code! See uart_init.patch_for_cpu_*. Patched for 112/224/448/896 T-states total
1:  dec a              ; (4*2) or (4*10) or (4*26) or (4*58)
    jp nz, 1b          ; (10*2) or (10*10) or (10*26) or (10*58)
    .2 nop             ; (4*2)
    dec d              ; (4) Decrement the bit counter
    jp nz, .loop       ; (10) Jump back if there are further bits to send
.delay_after_stop_bit:
.C: ld e, 6            ; (7) Delay for 101 T-states (28.5us). Self modifying code! See uart_init.patch_for_cpu_*
1:  dec e              ; (4)
    jr nz, 1b          ; (12/7)
    ei                 ;
    ret                ;


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
    call uart_putc           ;
    inc hl                   ;
    dec ixl                  ;
    jp nz, .loop             ;
    ret                      ;
