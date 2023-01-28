screen_size  equ 6912
screen0      equ #C000
screen0_page equ 7
screen1      equ screen0 + screen_size
screen1_page equ 7

    export screen_size
    export screen0
    export screen1
    export screen0_page
    export screen1_page


load_screen0:
    ld a, #10 + screen0_page
    ld bc, #7ffd
    out (c), a
    ld de, #4000
    ld hl, screen0
    ld bc, screen_size
    ldir
    ld a, #10
    ld bc, #7ffd
    out (c), a
    ret

load_screen1:
    ld a, #10 + screen1_page
    ld bc, #7ffd
    out (c), a
    ld de, #4000
    ld hl, screen1
    ld bc, screen_size
    ldir
    ld a, #10
    ld bc, #7ffd
    out (c), a
    ret
