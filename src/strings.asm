    MACRO DEFSTR _string
    DB _string,0
@.end:
    ENDM

str_head: DEFSTR "ZX MIDI player by Eugene Lozovoy"

str_3_5_mhz:  DEFSTR "3.5MHz"
str_3_54_mhz: DEFSTR "3.54MHz"
str_7_mhz:    DEFSTR "7MHz"
str_14_mhz:   DEFSTR "14MHz"
str_28_mhz:   DEFSTR "28MHz"
str_50_hz     DEFSTR "50Hz"
str_48_hz     DEFSTR "48Hz"
