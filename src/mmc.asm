; IN  -  A - driver | card number
; OUT -  F - Z on success, NZ on fail
; OUT - AF - garbage
; OUT -  B - garbage
mmc_driver_select:
    ld b, a                       ;
    srl a                         ;
    cp DISK_DRIVER_DIVMMC>>1      ;
    jr z, .divmmc                 ;
    cp DISK_DRIVER_ZXMMC>>1       ;
    jr z, .zxmmc                  ;
    cp DISK_DRIVER_ZCONTROLLER>>1 ;
    jr z, .zcontroller            ;
    ret                           ;
.divmmc:
    ld a, #fe                     ; 1st card
    bit 0, b                      ;
    jr z, 1f                      ;
    ld a, #fd                     ; 2nd card
1:  ld (mmcdrv_cs_on.V+1), a      ;
    ld a, #ff                     ; cs off
    ld (mmcdrv_cs_off.V+1), a     ;
    ld a, #e7                     ; control port
    ld (mmcdrv_cs_on.P+1), a      ;
    ld (mmcdrv_cs_off.P+1), a     ;
    ld a, #eb                     ; spi port
    ld (mmcdrv_tx.P+1), a         ;
    ld (mmcdrv_rx.P+1), a         ;
    ld (mmc_cmd.P+1), a           ;
    ld (mmc_read_block.P+1), a    ;
    xor a                         ; set Z flag
    ret                           ;
.zxmmc:
    ld a, #fe                     ; 1st card (0xfa)
    bit 0, b                      ;
    jr z, 1f                      ;
    ld a, #f9                     ; 2nd card
1:  ld (mmcdrv_cs_on.V+1), a      ;
    ld a, #fb                     ; cs off
    ld (mmcdrv_cs_off.V+1), a     ;
    ld a, #1f                     ; control port
    ld (mmcdrv_cs_on.P+1), a      ;
    ld (mmcdrv_cs_off.P+1), a     ;
    ld a, #3f                     ; spi port
    ld (mmcdrv_tx.P+1), a         ;
    ld (mmcdrv_rx.P+1), a         ;
    ld (mmc_cmd.P+1), a           ;
    ld (mmc_read_block.P+1), a    ;
    xor a                         ; set Z flag
    ret                           ;
.zcontroller:
    bit 0, b                      ;
    ret nz                        ; only one card
    ld a, #01                     ; 1st card
    ld (mmcdrv_cs_on.V+1), a      ;
    ld a, #03                     ; cs off
    ld (mmcdrv_cs_off.V+1), a     ;
    ld a, #77                     ; control port
    ld (mmcdrv_cs_on.P+1), a      ;
    ld (mmcdrv_cs_off.P+1), a     ;
    ld a, #57                     ; spi port
    ld (mmcdrv_tx.P+1), a         ;
    ld (mmcdrv_rx.P+1), a         ;
    ld (mmc_cmd.P+1), a           ;
    ld (mmc_read_block.P+1), a    ;
    xor a                         ; set Z flag
    ret                           ;

mmcdrv_cs_on:
.V  ld a, #ff    ;
.P  out (#ff), a ;
    ret          ;
mmcdrv_cs_off:
.V  ld a, #ff    ;
.P  out (#ff), a ;
    ret          ;
mmcdrv_tx:
.P  out (#ff), a ;
    ret          ;
mmcdrv_rx:
.P  in a, (#ff)  ;
    ret          ;


CARDTYPE_NONE equ 0
CARDTYPE_MMC  equ 1
CARDTYPE_SD   equ 2
CARDTYPE_SDHC equ 3


; Command:
; |76543210|76543210|76543210|76543210|76543210|76543210|
; |01IIIIII|AAAAAAAA|AAAAAAAA|AAAAAAAA|AAAAAAAA|CCCCCCC1|
; I - command index
; A - command arguments
; C - checksum - CRC7 - x7+x3+x0
;
; Reponse R1
; |76543210|
; |0PASCIEi|
; P - Parameter error
; A - Address error
; S - Erase sequence error
; C - Com crc error
; I - Illegal command
; E - Erase reset
; i - In idle state
;
; Response R3
; |76543210|76543210|76543210|76543210|76543210|
; |RRRRRRRR|PCU....V|VVVVVVVV|V.......|........|
; R - R1 response
; P - Card power up status bit (busy) - This bit is set to LOW if the card has not finished the power up routine.
; C - Card Capacity Status (CCS) - is bit is valid only when the card power up status bit is set.
; U - UHS-II card status
; V - Supported voltage
;
; Response R7
; |76543210|76543210|76543210|76543210|76543210|
; |RRRRRRRR|CCCC....|........|....VVVV|EEEEEEEE|
; R - R1 response
; C - Command version
; V - Voltage accepted
; E - Echo-back - Check pattern
;
; Command    | Argument               | Response | Data | Abbreviation             | Description
; CMD0       | None(0)                | R1       | No   | GO_IDLE_STATE            | Software reset.
; CMD1       | None(0)                | R1       | No   | SEND_OP_COND             | Initiate initialization process.
; ACMD41(*1) | *2                     | R1       | No   | APP_SEND_OP_COND         | For only SDC. Initiate initialization process.
; CMD8       | *3                     | R7       | No   | SEND_IF_COND             | For only SDC V2. Check voltage range.
; CMD9       | None(0)                | R1       | Yes  | SEND_CSD                 | Read CSD register.
; CMD10      | None(0)                | R1       | Yes  | SEND_CID                 | Read CID register.
; CMD12      | None(0)                | R1b      | No   | STOP_TRANSMISSION        | Stop to read data.
; CMD16      | Block length[31:0]     | R1       | No   | SET_BLOCKLEN             | Change R/W block size.
; CMD17      | Address[31:0]          | R1       | Yes  | READ_SINGLE_BLOCK        | Read a block.
; CMD18      | Address[31:0]          | R1       | Yes  | READ_MULTIPLE_BLOCK      | Read multiple blocks.
; CMD23      | Number of blocks[15:0] | R1       | No   | SET_BLOCK_COUNT          | For only MMC. Define number of blocks to transfer with next multi-block read/write command.
; ACMD23(*1) | Number of blocks[22:0] | R1       | No   | SET_WR_BLOCK_ERASE_COUNT | For only SDC. Define number of blocks to pre-erase with next multi-block write command.
; CMD24      | Address[31:0]          | R1       | Yes  | WRITE_BLOCK              | Write a block.
; CMD25      | Address[31:0]          | R1       | Yes  | WRITE_MULTIPLE_BLOCK     | Write multiple blocks.
; CMD55(*1)  | None(0)                | R1       | No   | APP_CMD                  | Leading command of ACMD<n> command.
; CMD58      | None(0)                | R3       | No   | READ_OCR                 | Read OCR.
; *1:ACMD<n> means a command sequense of CMD55-CMD<n>.
; *2: Rsv(0)[31], HCS[30], Rsv(0)[29:0]
; *3: Rsv(0)[31:12], Supply Voltage(1)[11:8], Check Pattern(0xAA)[7:0]
;


; IN -  HL - pointer to 6-byte array
; OUT -  F - Z on success, NZ on fail
; OUT -  A - R1
; OUT - BC - garbage
; OUT - HL - 0
mmc_cmd:
    call mmc_wait_not_busy             ;
    ld a, #ff                          ;
    ret nz                             ; zesarux fails there
.P  ld c, #ff                          ;
    ld b, 6                            ;
    otir                               ;
    ; jp mmc_wait_r1                     ;


; OUT - F - Z on success, NZ on fail
; OUT - A - R1
; OUT - B - garbage
mmc_wait_r1:
    ld b, 32                           ; Ncr = 0..8 (SD) / 1..8 (MMC)
1:  call mmcdrv_rx                     ;
    bit 7, a                           ;
    ret z                              ;
    djnz 1b                            ;
    ret                                ;


; OUT - F - Z on success, NZ on fail
; OUT - A - #ff
; OUT - B - garbage
mmc_wait_not_busy:
    ld b, 0                            ;
1:  call mmcdrv_rx                     ;
    cp #ff                             ;
    ret z                              ;
    djnz 1b                            ;
    ret                                ;


; OUT - F  - Z on success, NZ on fail
; OUT - E  - card type
; OUT - A  - garbage
; OUT - BC - garbage
; OUT - D  - garbage
; OUT - HL - garbage
mmc_init:
    ld a, (var_int_counter)            ;
    add a, MMC_INIT_TIMEOUT            ;
    ld d, a                            ;
    ld e, CARDTYPE_NONE                ;
    call mmcdrv_cs_on                  ;
    call mmcdrv_cs_off                 ;
    ld b, 10                           ; send >= 74 clock pulses
    ld a, #ff                          ; ...
1:  call mmcdrv_tx                     ; ...
    djnz 1b                            ; ...
    call mmcdrv_cs_on                  ;
.send_cmd0:
    ld hl, .cmd0                       ;
    call mmc_cmd                       ; send CMD0, A=R1
    cp #01                             ;
    call nz, .err                      ;
.send_cmd8:
    ld hl, .cmd8                       ;
    call mmc_cmd                       ; send CMD8, A=R1
    cp #01                             ;
    jr nz, .send_acmd41_00             ;
    .3 call mmcdrv_rx                  ; check lower bits in R7
    cp #01                             ; ...
    call nz, .err                      ; ... unexpected value, exit
    call mmcdrv_rx                     ; ...
    cp #aa                             ; ...
    call nz, .err                      ; ... unexpected value, exit
.send_acmd41_40:
    ld hl, .cmd55                      ;
    call mmc_cmd                       ; send CMD55, A=R1
    and #fe                            ;
    or a                               ;
    call nz, .err                      ;
    ld hl, .acmd41_40                  ;
    call mmc_cmd                       ; send ACMD41(0x40000000), A=R1
    cp #01                             ; not busy?
    jr nz, 1f                          ; ...
    ld a, (var_int_counter)            ; timeout expired?
    cp d                               ; ...
    call z, .err                       ; ...
    jr .send_acmd41_40                 ; ...
1:  or a                               ; 0 - init done
    call nz, .err                      ;
.send_cmd58:
    ld hl, .cmd58                      ;
    call mmc_cmd                       ; send CMD58(0x00000000), A=R1
    or a                               ;
    call nz, .err                      ;
    call mmcdrv_rx                     ;
    push af                            ;
    .3 call mmcdrv_rx                  ;
    pop af                             ;
    and #40                            ; check CCS bit
    ld e, CARDTYPE_SD                  ;
    jr z, .send_cmd16                  ;
    ld e, CARDTYPE_SDHC                ;
    jr .exit                           ;
.send_acmd41_00:
    ld hl, .cmd55                      ;
    call mmc_cmd                       ; send CMD55, A=R1
    and #fe                            ;
    or a                               ;
    jr nz, .send_cmd1                  ;
    ld hl, .acmd41_00                  ;
    call mmc_cmd                       ; send ACMD41(0x00000000), A=R1
    cp #01                             ; not busy?
    jr nz, 1f                          ; ...
    ld a, (var_int_counter)            ; timeout expired?
    cp d                               ; ...
    call z, .err                       ; ...
    jr .send_acmd41_00                 ; ...
1:  or a                               ; 0 - init done
    ld e, CARDTYPE_SD                  ;
    jr z, .send_cmd16                  ; ...
    call .err                          ;
.send_cmd1:
    ld e, CARDTYPE_MMC                 ;
    ld hl, .cmd1                       ;
    call mmc_cmd                       ; send CMD1(0x00000000), A=R1
    cp #01                             ; not busy?
    jr nz, 1f                          ; ...
    ld a, (var_int_counter)            ; timeout expired?
    cp d                               ; ...
    call z, .err                       ; ...
    jr .send_cmd1                      ; ...
1:  or a                               ; 0 - init done
    jr z, .send_cmd16                  ; ...
    call .err                          ;
.send_cmd16:
    ld hl, .cmd16                      ;
    call mmc_cmd                       ; send CMD16(0x00000200), A=R1
.exit:
    xor a                              ; set Z flag
    jp mmcdrv_cs_off                   ;
.err:
    ; push de                            ;
    ; LD_SCREEN_ADDRESS hl, LAYOUT_DEBUG ;
    ; call print_hex                     ; print A (response) content
    ; ld a, ' '                          ;
    ; call print_char                    ;
    ; inc l                              ;
    ; pop de                             ;
    ; ld a, e                            ;
    ; call print_hex                     ;
    ; ld a, ' '                          ;
    ; call print_char                    ;
    ; inc l                              ;
    ; pop de                             ; print caller address
    ; push de                            ; ...
    ; ld a, d                            ; ...
    ; call print_hex                     ; ...
    ; pop de                             ; ...
    ; ld a, e                            ; ...
    ; call print_hex                     ; ...
    ; jr $                               ;
    pop de                             ;
    or 1                               ; set NZ flag
    jp mmcdrv_cs_off                   ;
.cmd0:      DB #40,#00,#00,#00,#00,#95
.cmd8:      DB #48,#00,#00,#01,#aa,#86
.cmd55:     DB #77,#00,#00,#00,#00,#65
.acmd41_40: DB #69,#40,#00,#00,#00,#77
.cmd58:     DB #7A,#00,#00,#00,#00,#fd
.acmd41_00: DB #69,#00,#00,#00,#00,#65
.cmd1:      DB #41,#00,#00,#00,#00,#F9
.cmd16:     DB #50,#00,#00,#02,#00,#15


; IN  - DEBC - src lba
; IN  - HL   - dst address of 512-byte buffer
; IN  - A    - card type
; OUT - F    - Z on success, NZ on fail
; OUT - HL   - next untouched dst address
; OUT - A    - garbage
; OUT - BC   - garbage
; OUT - DE   - garbage
mmc_read_block:
    cp CARDTYPE_SDHC                   ; SD/MMC require byte address, not lba
    jr z, 1f                           ; ...
    ld d, e : ld e, b                  ; ... addr = addr * 512
    ld b, c : ld c, 0                  ; ...
    sla b : rl e : rl d                ; ...
1:  ld a, d : ld (.cmd17+1), a         ;
    ld a, e : ld (.cmd17+2), a         ;
    ld a, b : ld (.cmd17+3), a         ;
    ld a, c : ld (.cmd17+4), a         ;
    push hl                            ;
    call mmcdrv_cs_on                  ;
    ld hl, .cmd17                      ;
    call mmc_cmd                       ;
    pop hl                             ;
    or a                               ;
    jp nz, .err                        ;
.wait_for_data_token:
    ld a, (var_int_counter)            ;
    add a, MMC_READ_TIMEOUT            ;
    ld d, a                            ;
    ld b, 0                            ;
1:  call mmcdrv_rx                     ;
    cp #fe                             ;
    jr z, .read_data                   ;
    ld a, (var_int_counter)            ; timeout expired?
    cp d                               ; ...
    jr z, .err                         ; ...
    djnz 1b                            ;
.read_data:
.P  ld c, #ff                          ;
    ld b, 0                            ;
    inir                               ;
    inir                               ;
    .2 in a, (c)                       ; crc
.exit:
    xor a                              ; set Z flag
    jp mmcdrv_cs_off                   ;
.err:
    or 1                               ; set NZ flag
    jp mmcdrv_cs_off                   ;
.cmd17: DB #51,#00,#00,#00,#00,#ff
