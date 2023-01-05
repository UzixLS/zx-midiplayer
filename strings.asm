    MACRO DEFSTR _string
    DB _string,0
@.end:
    ENDM

string_title: DEFSTR "Title: "
