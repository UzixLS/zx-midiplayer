    MACRO DEFSTR _string
    DB _string,0
@.end:
    ENDM

str_head: DEFSTR "ZX MIDI player by Eugene Lozovoy"

str_3_5_mhz:     DEFSTR "3.5MHz"
str_3_54_mhz:    DEFSTR "3.54MHz"
str_7_mhz:       DEFSTR "7MHz"
str_14_mhz:      DEFSTR "14MHz"
str_28_mhz:      DEFSTR "28MHz"
str_50_hz:       DEFSTR "50Hz"
str_49_hz:       DEFSTR "49Hz"
str_48_hz:       DEFSTR "48Hz"
str_drive_a:     DEFSTR "A:"
str_drive_b:     DEFSTR "B:"
str_drive_c:     DEFSTR "C:"
str_drive_d:     DEFSTR "D:"
str_divmmc:      DEFSTR "Scan DivMMC"
str_zxmmc:       DEFSTR "Scan ZXMMC"
str_zcontroller: DEFSTR "Scan ZC"
str_help:        DEFSTR "Help"
str_exit:        DEFSTR "Exit"
str_untitled:    DEFSTR "Untitled MIDI melody"
str_unnamed:     DEFSTR "untitled.mid"
str_zerotimer:   DEFSTR "00:00:0"
