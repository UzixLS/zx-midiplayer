    MACRO DEFSTR _string
    DB _string,0
@.end equ $-2
    ENDM

str_head:        DEFSTR "ZX MIDI player by Eugene Lozovoy"
str_version:     DEFSTR VERSIONSHORT_DEF
str_3_5_mhz:     DEFSTR "3.5MHz"
str_3_54_mhz:    DEFSTR "3.54MHz"
str_7_mhz:       DEFSTR "7MHz"
str_14_mhz:      DEFSTR "14MHz"
str_28_mhz:      DEFSTR "28MHz"
str_50_hz:       DEFSTR "50Hz"
str_49_hz:       DEFSTR "49Hz"
str_48_hz:       DEFSTR "48Hz"

str_untitled:    DEFSTR "Untitled MIDI melody"
str_unnamed:     DEFSTR "untitled.mid"
str_zerotimer:   DEFSTR "00:00.0"

str_help:        DEFSTR "Help"
str_settings:    DEFSTR "Settings"
str_exit:        DEFSTR "Exit"

str_output:      DEFSTR "Output"
str_128:         DEFSTR "128 Std"
str_shama:       DEFSTR "ShamaZX"
str_divmmc:      DEFSTR "DivMMC"
str_zxmmc:       DEFSTR "ZXMMC"
str_zcontroller: DEFSTR "Z-Controller"
str_on:          DEFSTR " ON"
str_off:         DEFSTR "     OFF"
str_extraram:    DEFSTR "Extra RAM"
str_pentagon:    DEFSTR "Pentagon"
str_scorpion:    DEFSTR "Scorpion"
str_profi:       DEFSTR "   Profi"
str_save:        DEFSTR "Save"
str_ok:          DEFSTR "OK"
