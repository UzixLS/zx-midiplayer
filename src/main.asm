    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    DEVICE ZXSPECTRUM128,stack_top
    OPT --syntax=abf
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

    ld ix, #c000
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
    display "Code entrypoint=", main, " start=", begin, " end=",end, " len=", /d, end-begin

    assert $ < stack_bottom
    org #BF00
stack_bottom:
    org #BFFF
stack_top:


    export begin
    export end
    export main
    savebin "main.bin", begin, end-begin
