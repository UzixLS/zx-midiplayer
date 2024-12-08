;

    IFNDEF _PLATFORM_
        ; make sure only one target platform is enabled
        IFDEF DOS_TRDOS
            IFDEF DOS_PLUS3
                UNDEFINE DOS_PLUS3
            ENDIF
            IFDEF DOS_ESXDOS
                UNDEFINE DOS_ESXDOS
            ENDIF
            DEFINE _PLATFORM_
        ENDIF;DOS_TRDOS

        IFDEF DOS_PLUS3
            IFDEF DOS_TRDOS
                UNDEFINE DOS_TRDOS
            ENDIF
            IFDEF DOS_ESXDOS
                UNDEFINE DOS_ESXDOS
            ENDIF
            DEFINE _PLATFORM_
        ENDIF;DOS_PLUS3

        IFDEF DOS_ESXDOS
            IFDEF DOS_TRDOS
                UNDEFINE DOS_TRDOS
            ENDIF
            IFDEF DOS_PLUS3
                UNDEFINE DOS_PLUS3
            ENDIF
            DEFINE _PLATFORM_
        ENDIF;DOS_ESXDOS
    ENDIF;!_PLATFORM_

    ; no explicit selection, fall back to TR-DOS
    IFNDEF _PLATFORM_
        DEFINE DOS_TRDOS
        DEFINE _PLATFORM_
    ENDIF;!_PLATFORM_

    IFDEF DOS_TRDOS
        DISPLAY "Platform: *** TR-DOS ***"
    ENDIF
    IFDEF DOS_PLUS3
        DISPLAY "Platform: *** +3 DOS ***"
    ENDIF
    IFDEF DOS_ESXDOS
        DISPLAY "Platform: *** esxDOS ***"
    ENDIF


; EOF vim: et:ai:ts=4:sw=4:syntax=asm:
