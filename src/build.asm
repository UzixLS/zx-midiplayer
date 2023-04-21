    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    OPT --syntax=abf
    DEVICE ZXSPECTRUM128,stack_top

    include "build/main.exp"
    includelua "lua/incbin_pages.lua"
    includelua "lua/incbin_rle.lua"


; === SNA file ===
    lua allpass
        incbin_pages("res/start.scr",  0, nil, 0x4000, {0})
        incbin_pages("res/menu.scr",   0, nil, 0xC000, {7})
        incbin_pages("res/play.scr",   0, nil, 0xC000+6912, {7})
        incbin_pages("build/main.bin", 0, nil, _c("begin"), {0})
        incbin_pages("res/test0.mid",  0, nil, 0xC000, {0,4,6,3})
    endlua
    page 0 : savesna "main.sna", main


; === TAP file ===
    emptytap "main.tap"
    page 0 : savetap "main.tap", main


; === TRD file ===
    org #5d3b
boot_b:
    dw #0100, .end-$-4, #30fd,#000e,#b300,#005f,#f93a,#30c0,#000e,#5300,#005d,#ea3a
.enter:
    di                                ;

    ld hl, #8000                      ;
    ld b, screen_sectors              ;
    call .sub_load                    ;
    ld hl, #8000                      ;
    ld de, #4000                      ; screen_start
    call .sub_unpack                  ;
    xor a                             ; set black border
    out (#fe), a                      ; ...
    ld a, #10 + screen0_page          ; screen_menu
    ld bc, #7ffd                      ;
    out (c), a                        ;
    ld de, screen0                    ;
    call .sub_unpack                  ;
    call .sub_unpack                  ; screen_play

    ld a, #10                         ; code
    ld bc, #7ffd                      ;
    out (c), a                        ;
    ld hl, #c000                      ;
    ld b, code_sectors                ;
    call .sub_load                    ;
    ld hl, #c000                      ;
    ld de, begin                      ;
    call .sub_unpack                  ;

    jp main                           ;

; IN - HL - destination address
; IN - B  - sectors count
.sub_load:
    ld de, (#5cf4)          ;
    ld c, #05               ;
    jp #3d13                ;

; IN  - DE - destination
; IN  - HL - source
; OUT - DE - pointer to next untouched byte at dest
; OUT - HL - pointer to next byte after unpacked block
.sub_unpack:
    ld b, 1                 ;
    ld a, (hl)              ;
    inc hl                  ;
    cp (hl)                 ;
    jr nz, .fill            ;
    inc hl                  ;
    ld b, (hl)              ;
    inc hl                  ;
    inc b                   ;
    ret z                   ;
    inc b                   ;
.fill:
    ld (de), a              ;
    inc de                  ;
    djnz .fill              ;
    jp .sub_unpack          ;

    db #0d
.end:

    page 0
    emptytrd "main.trd", "ZXMIDI"
    savetrd "main.trd", "boot.B", boot_b, boot_b.end-boot_b

    org 0
    lua allpass
        incbin_rle("res/start.scr")
        incbin_rle("res/menu.scr")
        incbin_rle("res/play.scr")
        sj.insert_label("screen_sectors", math.ceil(sj.current_address/256))
    endlua
    assert $ < #4000
    savetrd "main.trd", &"boot.B", 0, $

    org 0
    lua allpass
        incbin_rle("build/main.bin")
        sj.insert_label("code_sectors", math.ceil(sj.current_address/256))
    endlua
    assert $ < #4000
    savetrd "main.trd", &"boot.B", 0, $

    lua allpass
        for file_name in io.popen([[ls "res/midi/"]]):lines() do
            _pc("org 0")
            _pc(string.format("incbin \"res/midi/%s\"", file_name))
            _pc(string.format("savetrd \"main.trd\", \"%s\", 0, $", file_name))
        end
    endlua
