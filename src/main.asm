    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    DEVICE ZXSPECTRUM128,stack_top
    OPT --syntax=F
    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

    page 0
    org #7f74
begin:
    db "Code begin",0
int_handler:
    push af
    ld a, (var_int_counter+1)
    inc a
    ld (var_int_counter+1), a
    pop af
.A: ei                        ; (1 byte) self modifying code! see device_detect_cpu_int
    ret                       ; (1 byte) ...

    assert $ < 0x8000
    org #8000
int_im2_vector_table:
    assert int_handler == 0x7f7f
    .257 db #7f ; by Z80 user manual int vector is I * 256 + (D & 0xFE)
                ; but by other references and by T80/A-Z80 implementation int vector is I * 256 + D
                ; so we just play safe and use symmetric int handler address and vector table with one extra byte

main:
    di               ;
    ld sp, stack_top ;
    ld a, #80        ; set IM2 interrupt table address (#8000-#8100)
    ld i, a          ; ...
    im 2             ; ...
    ld a, #10        ; page BASIC48
    ld bc, #7ffd     ; ...
    out (c), a       ; ...
    ld a, #01        ; set blue border
    out (#fe), a     ; ...
    call device_detect_cpu_int ;
    call uart_init   ;

    ; call #3d21    ; init
    ; ld a, 0       ; drive = a
    ; ld c, 1       ; function = select drive
    ; call #3d13    ; ...
    ; ld a, (#5cf6)
    ; ld (#5cf9), a
    ; ld a, 2       ; dst = screen
    ; ld c, 7       ; function = list files
    ; call #3d13

    ld hl, LAYOUT_TITLE_STR
    ld ix, string_title
    call print_string0

    ld ix, testmid
    call smf_parse
    jr nz, loop
    call player_loop
loop:
    ld a, #02      ; set red border
    out (#fe), a   ; ...
    ei
    halt
    jr loop

    include "layout.asm"
    include "file.asm"
    include "uart.asm"
    include "math.asm"
    include "smf.asm"
    include "player.asm"
    include "draw.asm"
    include "device.asm"
    include "strings.asm"
    include "variables.asm"

buildversion:
    ifdef VERSION
    db VERSION, 0
    else
    db 0
    endif
builddate:
    db __DATE__, " ", __TIME__, 0
    db "Code end",0
end:
    display "Program start: ",main
    display "Program end:   ",$

    assert $ < stack_bottom
    org #BF00
stack_bottom:
    org #BFFF
stack_top:



; === SNA file ===
    org #4000   : incbin "play.scr"
    org #C000,7 : incbin "files.scr"

    org #C000,0
testmid:
    ; incbin "test0.mid",0 ; <= 16 Kb
    ; incbin "test0.mid",0,#4000 : org #C000,4 : incbin "test0.mid",#4000 ; <= 32 Kb
    ; incbin "test0.mid",0,#4000 : org #C000,4 : incbin "test0.mid",#4000,#4000 : org #C000,6 : incbin "test0.mid",#8000 ; <= 48 Kb
    incbin "test0.mid",0,#4000 : org #C000,4 : incbin "test0.mid",#4000,#4000 : org #C000,6 : incbin "test0.mid",#8000,#4000 : org #C000,3 : incbin "test0.mid",#C000 ; <= 64 Kb

    page 0 : savesna "main.sna", main


; === TRD file ===
    org #5d3b
boot_b:
    dw #0100, .end-$-4, #30fd,#000e,#b300,#005f,#f93a,#30c0,#000e,#5300,#005d,#ea3a
.enter:
    di

    ld hl, #4000                      ;
    ld b, 6912/256                    ;
    call .sub_load                    ;

    ld a, #17                         ;
    ld bc, #7ffd                      ;
    out (c), a                        ;
    ld hl, #c000                      ;
    ld b, 6912/256                    ;
    call .sub_load                    ;

    ld hl, begin                      ;
    ld b, (end-begin)/256+1           ;
    call .sub_load                    ;

    ld a, #10                         ;
    ld bc, #7ffd                      ;
    out (c), a                        ;
    ld hl, #c000                      ;
    ld b, test1_mid_len/256+1         ; TODO correct len
    call .sub_load                    ;

    jp main                           ;

; IN - HL - destination address
; IN - B  - sectors count
.sub_load:
    ld de, (#5cf4)          ;
    ld c, #05               ;
    jp #3d13                ;

    db #0d
.end:

    emptytrd "main.trd", "ZXMIDI"
    page 0 : savetrd "main.trd", "boot.B", boot_b, boot_b.end-boot_b
    page 0 : savetrd "main.trd", &"boot.B", #4000, 6912
    page 7 : savetrd "main.trd", &"boot.B", #C000, 6912
    page 0 : savetrd "main.trd", &"boot.B", begin, end-begin

    org 0 : incbin "test1.mid"
test1_mid_len = $
    savetrd "main.trd", &"boot.B", 0, test1_mid_len
