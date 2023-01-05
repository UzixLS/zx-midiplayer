    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    DEVICE ZXSPECTRUM128,stack_top
    OPT --syntax=F
    SLDOPT COMMENT WPMEM, LOGPOINT, ASSERTION

    page 0
    org #4000
    incbin "title.scr"

    org #7777
begin:
int_handler:
    ret

    org #8000
int_im2_vector_table:
    .257 db #77 ; by Z80 user manual int vector is I * 256 + (D & 0xFE)
                ; but by other references and by T80/A-Z80 implementation int vector is I * 256 + D
                ; so we just play safe and use symmetric int handler address and vector table with one extra byte

main:
    di
    ld a, #80      ; set IM2 interrupt table address (#8000-#8100)
    ld i, a        ; ...
    im 2           ; ...
    ld a, #10      ; page BASIC48
    ld bc, #7ffd   ; ...
    out (c), a     ; ...
    ld a, #01      ; set border
    out (#fe), a   ; ...
    call uart_init ;

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
    call player_loop

loop:
    ei
    halt
    jr loop

    include "layout.asm"
    include "uart.asm"
    include "smf.asm"
    include "player.asm"
    include "draw.asm"
    include "strings.asm"
    include "variables.asm"

    display "Program start: ",main
    display "Program end:   ",$

    assert $ < stack_bottom
    org #BF00
stack_bottom:
    org #BFFF
stack_top:

    org #C000
testmid:
    incbin "test0.mid"
    ; incbin "test1.mid"

end:

    SAVESNA "main.sna",main
