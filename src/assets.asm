    ASSERT __SJASMPLUS__ >= 0x011401 ; SjASMPlus 1.20.1
    OPT --syntax=abf
    DEVICE ZXSPECTRUM128,stack_top

; assemble runtime screens bundle to be included in various builds

    include "build/main.exp"
    includelua "lua/incbin_rle.lua"

    PAGE screens_page
    ORG screens_base
    LUA allpass
        sj.add_word(0)
        sj.add_word(_c("menu_scr_gfx")) -- screen_menu_ptr
        sj.add_word(_c("play_scr_gfx")) -- screen_play_ptr
        sj.add_word(_c("help_scr_gfx")) -- screen_help_ptr
        sj.insert_label("menu_scr_gfx", sj.current_address); incbin_rle("res/menu.scr")
        sj.insert_label("play_scr_gfx", sj.current_address); incbin_rle("res/play.scr")
        sj.insert_label("help_scr_gfx", sj.current_address); incbin_rle("res/help.scr")
        sj.parse_line("screens_end equ $")
    ENDLUA

    DISPLAY "GFX @", screens_base, "[", /D,screens_page, "] (", /A,screens_end-screens_base, ")"
    SAVEBIN "main.gfx", screens_base, screens_end-screens_base

; EOF vim: et:ai:ts=4:sw=4:
