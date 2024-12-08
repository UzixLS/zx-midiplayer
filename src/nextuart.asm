;

    DEFINE ZXNEXTOS_UART_FLUSH

; MIDI Out for ZX Spectrum Next, using joystick port 2 in UART mode
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - HL - garbage
nextuart_prepare:
    ; see
    ; https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/ports.txt
    ; https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/nextreg.txt
    ; for port/reg details
    IFNDEF ZXNEXTOS ; we don't have Next specific build
    IFDEF ZXNEXTOS_Z80N_CHECK
        ld  a, %10000000
        db  0xED, 0x24, 0x00, 0x00   ; mirror a : nop : nop
        ; at this point on Next A will be 1, otherwise it's 0x80
        dec a
        ret nz      ; we're not on Next
    ELSE;!ZXNEXTOS_Z80N_CHECK
    ld bc, #243B                     ; NextReg Register Select port
    xor a                            ; Register 0 (Machine ID)
    out (c), a                       ; Select register
    inc b ;#253B                     ; BC = NextReg Data port
    in a, (c)                        ; Read register
    and #0f                          ; Select relevant bits
    cp #0a                           ; ZX Spectrum Next machine?
    ret nz                           ; No -> break
    ENDIF;ZXNEXTOS_Z80N_CHECK

    xor a                            ; Opcode for NOP
    ld (nextuart_putc), a            ; Enable UART send routine
    ENDIF ;!ZXNEXTOS

    IFDEF ZXNEXTOS_UART_FLUSH
        ld bc, #243B    ; NEXTREG select port
        ld a, 0x01      ; Core Version MM; bits 7:4 = Major; bits 3:0 = Minor
        out (c), a      ; select NEXTREG 0x01 "Core Version"
        inc b           ; NEXTREG read port
        in h, (c)       ; actually read core version
        dec b           ; NEXTREG select port
        ld a, 0x0e      ; Core Version: sub minor
        out (c), a      ; select NEXTREG 0x0E "Sub Minor Core Version"
        inc b           ; NEXTREG read port
        in l, (c)       ; actually read sub minor core version
        ld de, 0x310a   ; 3.01.10
        xor a           ; make sure CF = 0
        sbc hl, de
        jr c, .uartstup ; core < 3.01.10, leave RET in place
        ; NOTE: A=0 after xor a above
        ;ld a, 0x00     ; NOP opcode, replacing RET
        ld (core_ver_patch), a
.uartstup:
    ENDIF;ZXNEXTOS_UART_FLUSH

    ld bc, #243B                     ; BC = NextReg Register Select port
    ld a, #0b                        ; Register 11 (Joystick I/O Mode)
    out (c), a                       ; Select register
    inc b ;#253b                     ; BC = NextReg Data port
    ld a, %10110000                  ; I/O mode, UART on Joystick 2
    ;      E_MM___P "E"nabled, "M"ode 11 'uart on right joystick port',
    ;               "P"arameter 0 'redirect esp uart0 to joystick'
    ;               (Tx out on pin 7, Rx in from pin 9, ... )
    out (c), a                       ; Write register
    ld b, #15 ;#153B                 ; BC = UART Select port
    ld a, %00010000                  ; Select UART 0, set 3 highest prescaler bits (always 0 for MIDI)
    ;      _s_W_ppp "s"elect 0 'esp UART', "W"rite bits 2:0 to "p"rescaler
    ;               highest prescaler bits 0                                      \/
    out (c), a                       ; Write UART settings
    inc b ;#163B                     ; BC = UART Frame port
    ld a, %10011000                  ; Init TX/RX, set 8N1
    ;      RbfSSpet "R"eset Tx/Rx modules, do not assert "b"reak, no "f"low control,
    ;               "SS" 11 - 8 bits, no "p"arity ("e"ven), 1 s"t"op bit
    out (c), a                       ; Write UART settings
    ld a, %00011000                  ; set 8N1
    ;      rbfSSpet
    out (c), a                       ; Write UART settings
    ld b, #24                        ; NextReg Register Select port
    ld a, #11                        ; Register 17 (Video timing)
    out (c), a                       ; Select register
    inc b;#253B                      ; BC = NextReg Data port
    in a, (c)
    and %00000111                    ; bits 7:3 - reserved, bits 2:0 - Mode
    ld e, a                          ; E = Mode
    xor a                            ;
    ld d, a                          ; now we have Mode in DE
    ld hl, prescaler                 ; prescaler value lookup table
    add hl, de
    add hl, de                       ; HL+=Mode*2, prescaler entries 2 bytes long
    ; prescaler is 17 bits long and written as follows:
    ; lowest 7 bits into #143b (if bit7=0)
    ;   next 7 bits into #143b (if bit7=1)
    ;  upper 3 bits into #153b -- these are always 0 for our case, set above, see /\
    ld b, #14 ;#143B                 ; BC = UART RX port
    ld a, (hl)                       ; lowest byte of prescaler value
    and %01111111                    ; write lower (bit7=0) 7 bits of prescaler
    out (c), a                       ; send prescaler value (partial) to UART
    ld a, (hl)                       ;
    rla                              ; move the 8th bit of prescaler in CF
    inc hl                           ; second byte of prescaler value
    ld a, (hl)                       ;
    rla                              ; shift 8th bit of prescaler into A
    or %10000000                     ; write upper (bit=7) 7 bits of prescaler
    out (c), a                       ; send prescaler value (partial) to UART
    ret                              ;

; VGA 0   1..               ..6 + HDMI (7)
prescaler:  dw 28000000 / 31250, 28571429 / 31250, 29464286 / 31250 ; 0 1 2
            dw 30000000 / 31250, 31000000 / 31250, 32000000 / 31250 ; 3 4 5
            dw 33000000 / 31250, 27000000 / 31250                   ; 6 7

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
    and %00000010                    ; bit 1 = 1 if the Tx buffer is full
    jr nz, .wait                     ; wait until buffer is empty
    out (c), e                       ; Send byte to UART TX
    ret                              ;


nextuart_flush_txbuf:
    IFDEF ZXNEXTOS_UART_FLUSH
core_ver_patch:
        ret             ; SMC placeholder, replaced with 00(NOP) for core >= 3.1.10
    ; flush Tx buffer if core ver >= 0x310a, otherwise bit 4 is not defined
        ld bc, #133B    ; https://wiki.specnext.dev/UART_TX
.flshtx:in a, (c)       ; BC=ZXOS_TX
        and %00010000   ; bit 4 = 1 if the Tx buffer is empty
        jr z, .flshtx   ; There is NO flow control, hence "infinite" loop
        ; without timeout is acceptable. UART will always push bytes out ASAP.
    ENDIF;ZXNEXTOS_UART_FLUSH
    ret                              ;

    ; Next UART @0xA0A0(0x009C)
    DISPLAY "Next UART @",nextuart_prepare,"(",$-nextuart_prepare,")"
    DISPLAY " original @0x....(0x009C)"

; EOF vim: et:ai:ts=4:sw=4:
