device_detect_cpu_int:
    ld ix, int_handler.A                      ;
.enter:
    ld bc, 0                                  ; counter = 0
    ei : halt                                 ;
    ld hl, var_int_counter                    ;
    ld a, (hl)                                ; A = int_counter+1
    inc a                                     ; ...
    ei : halt                                 ;
.counter_loop:                                ; 23 T-states
    inc bc                                    ; (6) counter++
    cp (hl)                                   ; (7) if (int_counter != int_counter_last) then stop loop
    jp z, .counter_loop                       ; (10)
.check_int_too_long:
    xor a                                     ; if (counter < 0x100) - assume int problem
    or b                                      ; ...
    jr nz, .int_ok                            ; ...
    ld (ix+2), #c9                            ; trying to fix it - insert additional nops // #c9 - ret
    ld (ix+1), #fb                            ; ... ei
    ld (ix+0), #00                            ; ... nop
    inc ix                                    ;
    jr .enter                                 ;
.int_ok:
    push ix                                   ;
    ld ix, .table-device_t                    ; foreach entry in table
    ld de, device_t                           ;
.table_loop:
    add ix, de                                ;
    ld l, (ix+device_t.counter+0)             ;
    ld h, (ix+device_t.counter+1)             ;
    sbc hl, bc                                ; compare counter
    jr c, .table_loop                         ; ...
.match:
    ld (var_device.counter), bc               ;
    push ix : pop hl                          ;
    inc hl : inc hl                           ;
    ld de, var_device+2                       ;
    ld bc, device_t-2                         ;
    ldir                                      ;
.extend_int_in_turbo:
    pop ix                                    ;
    ld a, (var_device.cpu_freq)               ; if (freq != CPU_3_5_MHZ && freq != CPU_3_54_MHZ) ...
    or 1                                      ; ...
    cp 1                                      ; ...
    jr z, .debug                              ; ...
    ld (ix+2), #c9                            ; ... then insert one additional nop just for safety // #c9 - ret
    ld (ix+1), #fb                            ; ... ei
    ld (ix+0), #00                            ; ... nop
.debug:
    ; LD_SCREEN_ADDRESS hl, LAYOUT_DEBUG
    ; ld a, (var_device.counter+1)
    ; call print_hex
    ; ld a, (var_device.counter+0)
    ; call print_hex
    ; ld a, (var_device.cpu_freq)
    ; call print_hex
    ; ld a, (var_device.int_type)
    ; call print_hex
    ; jp device_detect_cpu_int
    ret

.table:
CPU_3_5_MHZ  equ 0
CPU_3_54_MHZ equ 1
CPU_7_MHZ    equ 2
CPU_14_MHZ   equ 3
CPU_28_MHZ   equ 4
INT_50_HZ    equ 0
INT_49_HZ    equ 1
INT_48_HZ    equ 2
    STRUCT device_t
counter             word
cpu_freq            byte
int_type            byte
us_per_int          word
tstates_per_line    word
lines_before_screen byte
horizontal_align    word
    ENDS
                                                                 ; Timings  Freq   T-states Int-freq  Comment
    device_t #0bde+10 CPU_3_5_MHZ  INT_50_HZ 19968 224  64 141   ; 48K      3.5    69888    50.08     -
    device_t #0c0a+10 CPU_3_54_MHZ INT_50_HZ 19992 228  63 141   ; 128K     3.5469 70908    50.02     real 128k
    device_t #0c2c+10 CPU_3_5_MHZ  INT_48_HZ 20480 224  80 210   ; Pentagon 3.5    71680    48.828125 -
    device_t #17bd+10 CPU_7_MHZ    INT_50_HZ 19968 448  64 302   ; 48K      7      139776   50.08     turbo modes detected correctly only when there is no wait states
    device_t #1815+10 CPU_7_MHZ    INT_49_HZ 20259 456  63 302   ; 128K     7      141816   49.36     all known machines with turbo and 128K timings are 3.5x-based
    device_t #1859+10 CPU_7_MHZ    INT_48_HZ 20480 448  80 440   ; Pentagon 7      143360   48.828125 -
    device_t #2f7a+10 CPU_14_MHZ   INT_50_HZ 19968 896  64 624   ; 48K      14     279552   50.08     -
    device_t #302b+10 CPU_14_MHZ   INT_49_HZ 20259 912  63 624   ; 128K     14     283632   49.36     all known machines with turbo and 128K timings are 3.5x-based
    device_t #30b2+10 CPU_14_MHZ   INT_48_HZ 20480 896  80 900   ; Pentagon 14     286720   48.828125 -
    device_t #5ef4+10 CPU_28_MHZ   INT_50_HZ 19968 1792 64 1448  ; 48K      28     559104   50.08     -
    device_t #6057+10 CPU_28_MHZ   INT_49_HZ 20259 1824 63 1448  ; 128K     28     567264   49.36     all known machines with turbo and 128K timings are 3.5x-based
    device_t #6164+10 CPU_28_MHZ   INT_48_HZ 20480 1792 80 2000  ; Pentagon 28     573440   48.828125 -
    device_t #ffff    CPU_28_MHZ   INT_48_HZ 20480 1792 80 2000  ; fallback entry
