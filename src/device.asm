device_detect_cpu_int:
    ld ix, int_handler.A
.enter:
    ld bc, 0                       ; counter = 0
    ei : halt                      ;
    ld a, (var_int_counter+1)      ; D = int_counter+1
    inc a                          ; ...
    ld d, a                        ; ...
    ei : halt                      ;
.loop:                             ; 33 T-states
    inc bc                         ; (6) counter++
    ld a, (var_int_counter+1)      ; (13) if (int_counter != int_counter_last) then stop loop
    cp d                           ; (4)
    jp z, .loop                    ; (10)
.check_int_too_long:
    xor a                          ; if (counter < 0x100) - assume int problem
    or b                           ; ...
    jr nz, .int_ok                 ; ...
    ld (ix+0), #00                 ; trying to fix it - insert additional nops
    ld (ix+1), #fb                 ; ... ei
    ld (ix+2), #c9                 ; ... ret
    inc ix                         ;
    jr .enter                      ;
.int_ok:
    call .sub                      ; D = cpu_freq, E = int_type
    ld a, d : ld (var_cpu_freq), a ; save
    ld a, e : ld (var_int_type), a ; ...
.debug:
    ; push de
    ; push bc
    ; ld hl, LAYOUT_DEBUG
    ; call get_char_address
    ; ld a, b
    ; call print_hex
    ; pop bc
    ; ld a, c
    ; call print_hex
    ; pop de
    ; push de
    ; ld a, d
    ; call print_hex
    ; pop de
    ; ld a, e
    ; call print_hex
    ; jp device_detect_cpu_int
    ret

.sub:
    ; timings    CPU-freq T-states Int-freq   Counter  Comment
    ; 48K        3.5      69888    50.08      0845
    ; 128K       3.5469   70908    50.02      0864     real 128k
    ; Pentagon   3.5      71680    48.828125  087c
    ; 48K        7        139776   50.08      108b     turbo modes detected correctly only when there is no wait states
    ; 128K       7        141816   49.36      10c9     all known machines with turbo and 128K timings are 3.5x-based
    ; Pentagon   7        143360   48.828125  10f8
    ; 48K        14       279552   50.08      2117
    ; 128K       14       283632   49.36      2192     all known machines with turbo and 128K timings are 3.5x-based
    ; Pentagon   14       286720   48.828125  21f0
1:  ld hl,#0845+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_3_5_MHZ  << 8) | INT_50_HZ   : ret
1:  ld hl,#0864+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_3_54_MHZ << 8) | INT_50_HZ   : ret
1:  ld hl,#087c+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_3_5_MHZ  << 8) | INT_48_8_HZ : ret
1:  ld hl,#108b+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_7_MHZ    << 8) | INT_50_HZ   : ret
1:  ld hl,#10c9+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_7_MHZ    << 8) | INT_50_HZ   : ret
1:  ld hl,#10f8+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_7_MHZ    << 8) | INT_48_8_HZ : ret
1:  ld hl,#2117+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_14_MHZ   << 8) | INT_50_HZ   : ret
1:  ld hl,#2192+10 : sbc hl,bc : jr c,1f :   ld de, (CPU_FREQ_14_MHZ   << 8) | INT_50_HZ   : ret
1:/*ld hl,#21f0+10 : sbc hl,bc : jr c,1f :*/ ld de, (CPU_FREQ_14_MHZ   << 8) | INT_48_8_HZ : ret
