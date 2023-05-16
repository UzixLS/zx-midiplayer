device_detect_cpu_int:
    ld ix, int_handler.A                      ;
.enter:
    ld bc, 0                                  ; counter = 0
    ei : halt                                 ;
    ld a, (var_int_counter)                   ; D = int_counter+1
    inc a                                     ; ...
    ld d, a                                   ; ...
    ei : halt                                 ;
.counter_loop                                 ; 33 T-states
    inc bc                                    ; (6) counter++
    ld a, (var_int_counter)                   ; (13) if (int_counter != int_counter_last) then stop loop
    cp d                                      ; (4)
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
    ld ix, .table-11                          ; foreach entry in table
    ld de, 11                                 ;
.table_loop:
    add ix, de                                ;
    ld l, (ix+0)                              ;
    ld h, (ix+1)                              ;
    sbc hl, bc                                ; compare counter
    jr c, .table_loop                         ;
.match:
    ld a, (ix+2)                              ;
    ld (var_cpu_freq), a                      ;
    ld a, (ix+3)                              ;
    ld (var_int_type), a                      ;
    ld a, (ix+4)                              ;
    ld (var_tstates_per_line+0), a            ;
    ld a, (ix+5)                              ;
    ld (var_tstates_per_line+1), a            ;
    ld a, (ix+6)                              ;
    ld (var_lines_after_int_before_screen), a ;
    ld a, (ix+7)                              ;
    ld (var_horizontal_align+0), a            ;
    ld a, (ix+8)                              ;
    ld (var_horizontal_align+1), a            ;
    ld a, (ix+9)                              ;
    ld (var_us_per_int+0), a                  ;
    ld a, (ix+10)                             ;
    ld (var_us_per_int+1), a                  ;
.debug:
    ; ld d, (ix+2)
    ; ld e, (ix+3)
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

.table:
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
    ; 48K        28       559104   50.08      422e
    ; 128K       28       567264   49.36      4324     all known machines with turbo and 128K timings are 3.5x-based
    ; Pentagon   28       573440   48.828125  43e0
    ; counter     cpu                int             tstates_per_line lines_before_screen horizontal_align us_per_int
    dw #0845+10 : db CPU_3_5_MHZ   : db INT_50_HZ  : dw 224         : db 64             : dw 141         : dw 19968
    dw #0864+10 : db CPU_3_54_MHZ  : db INT_50_HZ  : dw 228         : db 63             : dw 141         : dw 19992
    dw #087c+10 : db CPU_3_5_MHZ   : db INT_48_HZ  : dw 224         : db 80             : dw 210         : dw 20480
    dw #108b+10 : db CPU_7_MHZ     : db INT_50_HZ  : dw 448         : db 64             : dw 302         : dw 19968
    dw #10c9+10 : db CPU_7_MHZ     : db INT_49_HZ  : dw 456         : db 63             : dw 302         : dw 20259
    dw #10f8+10 : db CPU_7_MHZ     : db INT_48_HZ  : dw 448         : db 80             : dw 440         : dw 20480
    dw #2117+10 : db CPU_14_MHZ    : db INT_50_HZ  : dw 896         : db 64             : dw 624         : dw 19968
    dw #2192+10 : db CPU_14_MHZ    : db INT_49_HZ  : dw 912         : db 63             : dw 624         : dw 20259
    dw #21f0+10 : db CPU_14_MHZ    : db INT_48_HZ  : dw 896         : db 80             : dw 900         : dw 20480
    dw #422e+10 : db CPU_28_MHZ    : db INT_50_HZ  : dw 1792        : db 64             : dw 1448        : dw 19968
    dw #4324+10 : db CPU_28_MHZ    : db INT_49_HZ  : dw 1824        : db 63             : dw 1448        : dw 20259
    dw #43e0+10 : db CPU_28_MHZ    : db INT_48_HZ  : dw 1792        : db 80             : dw 2000        : dw 20480
    dw #ffff    : db CPU_28_MHZ    : db INT_48_HZ  : dw 1792        : db 80             : dw 2000        : dw 20480  ; fallback entry
