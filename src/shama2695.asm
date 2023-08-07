; Driver for MIDI SAM2695 addon by ShamaZX
; #A0CF - control port
; #A1CF - data port


shama2695_prepare:
.reset_to_defined_state:
    ld bc, #a1cf ; if chip is already in parallel mode then sending 0x3F would switch it to serial mode.
    ld a, #ff    ; as we don't know initial chip state, we're just forcing it into serial mode by sending 0xFF command.
    out (c), a   ; after that we can safely use 0x3F command to get parallel mode.
    ld b, 20     ; see SAM2695 datasheet pages 13,19 for details
    djnz $       ;
.switch_to_parallel_mode:
    ld bc, #a1cf ;
    ld a, #3f    ;
    out (c), a   ;
    ld b, 20     ;
    djnz $       ;
    ld b, #a0    ; we should read answer from data register otherwise parallel mode would be deactivated after 1ms
    in a, (c)    ; see SAM2695 datasheet page 8 for details
    ret          ;


shama2695_tx:
    ld e, a      ;
    ld bc, #a1cf ;
.wait:
    in a, (c)    ;
    and #40      ; check "receiver full" bit
    jr nz, .wait ; we can hang there forever...
.tx:
    ld b, #a0    ;
    out (c), e   ;
    .2 nop       ; minimum time between two consecutive writes must be 3.5 μs
    ret          ;


shama2695_flush_txbuf:
    ret          ;
