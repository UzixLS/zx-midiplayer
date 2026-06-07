    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    OPT --syntax=abf
    DEVICE ZXSPECTRUM128,stack_top

    include "build/main.exp"
    includelua "lua/incbin_pages.lua"
    includelua "lua/incbin_rle.lua"

    include "build.inc"

; === SNA file ===
    lua allpass
        incbin_pages("res/start.scr",  0, nil, 0x4000, {0})
        incbin_pages("build/main.bin", 0, nil, _c("begin"), {0})
        incbin_pages("build/main.gfx", 0, nil, _c("screens_base"), {1})
        incbin_pages("res/test0.mid",  0, nil, 0xC000, {0,4,6,3})
    endlua
    page 0 : savesna "main.sna", main

; === TAP file ===
    emptytap "main.tap"
    page 0 : savetap "main.tap", main

    IFDEF DOS_ESXDOS
        include "build.esxdos.asm"
    ENDIF

    IFDEF DOS_TRDOS
; === TRD file ===
ramtop equ #5fb3
    assert begin > ramtop
    assert ramtop - boot_b_end > 255
    org #5d3b
boot_b:
    dw #0100, boot_b_end-$-4              ; basic line number and length
    db #fd, '0'                           ; CLEAR 0 (ramtop)
    db #0e, #00, #00 : dw ramtop : db #00 ; ...
    db ':'                                ;
    db #f9, #c0, '0'                      ; RANDOMIZE USR 0 (.enter)
    db #0e, #00, #00 : dw .enter : db #00 ; ...
    db ':'                                ;
    db #ea                                ; REM
.enter:
    di                                    ;
    ld a, #10 + screens_page              ; load all screens, they will be unpacked on demand
    ld bc, #7ffd                          ; ...
    ld (bankm), a                         ; ...
    out (c), a                            ; ...
    ld hl, screens_base                   ; ...
    ld b, screen_sectors                  ; ...
    call .sub_load                        ; ...
    ld hl, start_scr_trd                  ; unpack startup screen
    ld de, #4000                          ; ...
    call rle_unpack                       ; ...
    xor a                                 ; set black border
    out (#fe), a                          ; ...
    ld a, #10                             ; code
    ld bc, #7ffd                          ; ... load
    ld (bankm), a                         ; ...
    out (c), a                            ; ...
    ld hl, #c000                          ; ...
    ld b, code_sectors                    ; ...
    call .sub_load                        ; ...
    ld hl, #c000                          ; ... and unpack
    ld de, begin                          ; ...
    call rle_unpack                       ; ...
    ld hl, (#5cf4)                        ; next sector is settings, save for further usage
    ld (var_settings_sector), hl          ; ...
    ld a, 1                               ;
    ld (var_trdos_present), a             ;
    jp main                               ;

; IN - HL - destination address
; IN - B  - sectors count
.sub_load:
    ld de, (#5cf4)                        ;
    ld c, #05                             ;
    jp #3d13                              ;

    include "rle_unpack.asm"

    db #0d                                ; basic line end
boot_b_end:

    page 0
    emptytrd "main.trd", "ZXMIDI"
    savetrd "main.trd", "boot.B", boot_b, boot_b_end-boot_b

    org 0
    lua allpass
        sj.add_word(_c("start_scr_trd"))
        sj.add_word(_c("menu_scr_trd")) -- screen_menu_ptr
        sj.add_word(_c("play_scr_trd")) -- screen_play_ptr
        sj.add_word(_c("help_scr_trd")) -- screen_help_ptr
        sj.insert_label("start_scr_trd", sj.current_address + _c("screens_base")); incbin_rle("res/start.scr")
        sj.insert_label("menu_scr_trd",  sj.current_address + _c("screens_base")); incbin_rle("res/menu.scr")
        sj.insert_label("play_scr_trd",  sj.current_address + _c("screens_base")); incbin_rle("res/play.scr")
        sj.insert_label("help_scr_trd",  sj.current_address + _c("screens_base")); incbin_rle("res/help.scr")
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

    org 0
    dd settings_magic
    block 256-$, 0
    savetrd "main.trd", &"boot.B", 0, $

    lua allpass
        for file_name in io.popen([[ls "res/midi/"]]):lines() do
            _pc("org 0")
            _pc(string.format("incbin \"res/midi/%s\"", file_name))
            _pc(string.format("savetrd \"main.trd\", \"%s\", 0, $", file_name))
        end
    endlua
    ENDIF;DOS_TRDOS
