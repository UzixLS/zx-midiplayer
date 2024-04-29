GSDAT            equ #B3 ; read-write, data transfer register for NGS
GSCOM            equ #BB ; write-only, command for NGS

GSSTAT           equ #BB ; read-only, command and data bits (positions given immediately below)
B_CBIT           equ 0   ; Command
M_CBIT           equ #01 ; Command
B_DBIT           equ 7   ; Data
M_DBIT           equ #80 ; Data

GSCTR            equ #33 ; write-only, control register for NGS: constants available given immediately below
C_GRST           equ #80 ; reset
C_GNMI           equ #40 ; NMI
C_GLED           equ #20 ; LED toggle

GSCFG0           equ #0F ; read-write, GS ConFiG port 0: acts as memory cell, reads previously written value. Bits and fields follow:
B_NOROM          equ 0   ; =0 - there is ROM everywhere except 4000-7FFF, =1 - the RAM is all around
M_NOROM          equ #01
B_RAMRO          equ 1   ; =1 - ram absolute addresses 0000-7FFF (zeroth big page) are write-protected
M_RAMRO          equ #02
B_8CHANS         equ 2   ; =1 - 8 channels mode
M_8CHANS         equ #04
B_EXPAG          equ 3   ; =1 - extended paging: both MPAG and MPAGEX are used to switch two memory windows
M_EXPAG          equ #08
B_CKSEL0         equ 4   ;these bits should be set according to the C_**MHZ constants below
M_CKSEL0         equ #10
B_CKSEL1         equ 5
M_CKSEL1         equ #20
C_10MHZ          equ #30
C_12MHZ          equ #10
C_20MHZ          equ #20
C_24MHZ          equ #00
B_PAN4CH         equ 6   ; =1 - 4 channels, panning (every channel is on left and right with two volumes)
M_PAN4CH         equ #40

SCTRL            equ #11 ; Serial ConTRoL: read-write, read: current state of below bits, write - see GS_info
B_SETNCLR        equ 7
M_SETNCLR        equ #80
M_SDNCS          equ #01
B_SDNCS          equ 0
B_MCNCS          equ 1
M_MCNCS          equ #02
B_MPXRS          equ 2
M_MPXRS          equ #04
B_MCSPD0         equ 3
M_MCSPD0         equ #08
B_MDHLF          equ 4
M_MDHLF          equ #10
B_MCSPD1         equ 5
M_MCSPD1         equ #20

SSTAT            equ #12 ; Serial STATus: read-only, reads state of below bits
B_MDDRQ          equ 0
M_MDDRQ          equ #01
B_SDDET          equ 1
M_SDDET          equ #02
B_SDWP           equ 2
M_SDWP           equ #04
B_MCRDY          equ 3
M_MCRDY          equ #08

SD_SEND          equ #13 ; SD card SEND, write-only, when written, byte transfer starts with written byte
SD_READ          equ #13 ; SD card READ, read-only, reads byte received in previous byte transfer
SD_RSTR          equ #14 ; SD card Read and STaRt, read-only, reads previously received byte and starts new byte transfer with #FF
MD_SEND          equ #14 ; Mp3 Data SEND, write-only, sends byte to the mp3 data interface
MC_SEND          equ #15 ; Mp3 Control SEND, write-only, sends byte to the mp3 control interface
MC_READ          equ #15 ; Mp3 Control READ, read-only, reads byte that was received during previous sending of byte


    MACRO WC
    in a, (GSCOM) ;
    rrca          ;
    jr c, $-3     ;
    ENDM

    MACRO WD
    in a, (GSCOM) ;
    rlca          ;
    jr c, $-3     ;
    ENDM

    MACRO WN
    in a, (GSCOM) ;
    rlca          ;
    jr nc, $-3    ;
    ENDM

; IN -  A  - port value
; IN  - C  - port number
; OUT - AF - garbage
neogs_out:
    push af                                       ;
    ld a, c                                       ;
    out (GSDAT), a                                ;
    ld a, #10                                     ;
    out (GSCOM), a                                ;
    WC                                            ;
    pop af                                        ;
    out (GSDAT), a                                ;
    WD                                            ;
    ret                                           ;

; IN  - C  - port number
; OUT - A  - port value
; OUT - F  - garbage
neogs_in:
    ld a, c                                       ;
    out (GSDAT), a                                ;
    ld a, #11                                     ;
    out (GSCOM), a                                ;
    WC                                            ;
    WN                                            ;
    in a, (GSDAT)                                 ;
    ret                                           ;

; OUT - AF - garbage
neogs_reset_once:
.A  ld a, #c9                                     ; self modifying code!
    ld (.A), a                                    ; ... ret
    ld a, C_GRST                                  ;
    out (GSCTR), a                                ;
    ret                                           ;

