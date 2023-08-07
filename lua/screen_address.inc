    includelua "lua/screen_address.lua"

    MACRO LD_SCREEN_ADDRESS _reg, _yyxx
        lua allpass
            _pc("ld _reg, " .. screen_address_pixel((_c("_yyxx")&0xff)*8, (_c("_yyxx")>>8)*8))
        endlua
    ENDM

    MACRO LD_ATTR_ADDRESS _reg, _yyxx
        lua allpass
            _pc("ld _reg, " .. screen_address_attr((_c("_yyxx")&0xff)*8, (_c("_yyxx")>>8)*8))
        endlua
    ENDM
