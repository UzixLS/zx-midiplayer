settings_magic equ "zxmi"

    STRUCT settings_t
magic       DD
kempston    DB
output      DB
divmmc      DB
zxmmc       DB
zcontroller DB
neogsmmc    DB
divide      DB
nemoide     DB
smuc        DB
extraram    DB
_reserv     BLOCK 256-14, 0
    ENDS
    assert settings_t == settings_block_size


    IFDEF DOS_PLUS3  ; TODO: if both defined?
        DEFINE __MODULE_SETTINGS_IO_IMPLEMENTED__

; OUT -  F - Z on success, NZ on fail
p3_settings_load:
        ld a, (var_disks.boot_n)    ; move it to disk_init? it doesn't change
        ld (_p3_settings_file), a

        ; TODO: common file path, only MODE_, _ACTION and DOS_READ/_WRITE are different
        ld b, PLUS3.FILENO
        ld c, 1 ; MODE_RD
        ld de, 0x0001   ; Open the file, read the header (if any)
        ld hl, _p3_settings_file
        PLUS3CALL PLUS3.DOS_OPEN
        jr nc, _error

        ld b, PLUS3.FILENO
        ld a, (bankm)
        and 0x07
        ld c, a
        ld hl, var_settings
        ld de, settings_t
        PLUS3CALL PLUS3.DOS_READ

_close:
        push af     ; save READ status

        ld b, PLUS3.FILENO
        PLUS3CALL PLUS3.DOS_CLOSE

        pop af      ; restore READ status, ignore CLOSE result
        jr nc, _error

_success:
        ; since we have interrups mode 2, turn off motor right now
        PLUS3CALL PLUS3.DD_L_OFF_MOTOR    ; AF BC DE HL IX corrupt
        xor a   ; ZF=1
        ret
_error:
        ; since we have interrups mode 2, turn off motor right now
        PLUS3CALL PLUS3.DD_L_OFF_MOTOR    ; AF BC DE HL IX corrupt
        or 0xff ; ZF=0
        ret

; OUT -  F - Z on success, NZ on fail
p3_settings_save:
        ld a, (var_disks.boot_n)    ; move it to disk_init? it doesn't change
        ld (_p3_settings_file), a

        ; TODO: common file path, only MODE_, _ACTION and DOS_READ/_WRITE are different
        ld b, PLUS3.FILENO
        ld c, 2 ; MODE_WR
        ld de, 0x0203   ; FIXME:
        ld hl, _p3_settings_file
        PLUS3CALL PLUS3.DOS_OPEN
        jr nc, _error

        ld b, PLUS3.FILENO
        ld a, (bankm)
        and 0x07
        ld c, a
        ld hl, var_settings
        ld de, settings_t
        PLUS3CALL PLUS3.DOS_WRITE
        jr _close

_p3_settings_file:
        defb 'X:zxmidipl.cfg',0xff

settings_load   equ p3_settings_load
settings_save   equ p3_settings_save
    ELSE
        DEFINE __MODULE_SETTINGS_IO_IMPLEMENTED__

; OUT -  F - Z on success, NZ on fail
; OUT - SP[0:sizeof(settings_t)-1] - loaded setting (only when ok)
trdos_settings_load0:
    ld de, (var_settings_sector)                              ; error if var_setting_sector == 0
    ld a, d                                                   ; ...
    or e                                                      ; ...
    jr nz, 1f                                                 ; ...
    or 1                                                      ; ... set NZ flag
    ret                                                       ; ...
1:  ld c, trdos_fun_select_drive                              ; select drive A/B/C/D
    ld a, (var_disks.boot_n)                                  ; ...
    call trdos_exec_fun                                       ; ...
    ret nz                                                    ; ... exit on error
    ld c, trdos_fun_reconfig_floppy                           ; ... init floppy disk parameters
    call trdos_exec_fun                                       ; ...
    ret nz                                                    ; ... exit on error
    pop bc                                                    ; allocate stack
    ld hl, -settings_t                                        ; ...
    add hl, sp                                                ; ...
    ld sp, hl                                                 ; ...
    push bc                                                   ; ...
    ld c, trdos_fun_read_block                                ; read settings
    ld de, (var_settings_sector)                              ; ... src
    ld b, 1                                                   ; ... one sector
    call trdos_exec_fun                                       ; ...
    jp nz, .err                                               ; ... reset settings in case of error
    ld hl, 2                                                  ; compare magic dword
    add hl, sp                                                ; ...
    ld a, (settings_magic >>  0) & 0xff : cpi : jr nz, .err   ; ...
    ld a, (settings_magic >>  8) & 0xff : cpi : jr nz, .err   ; ...
    ld a, (settings_magic >> 16) & 0xff : cpi : jr nz, .err   ; ...
    ld a, (settings_magic >> 24) & 0xff : cpi : jr nz, .err   ; ...
    ret                                                       ;
.err:
    pop de                                                    ; deallocate stack
    ld hl, settings_t                                         ; ...
    add hl, sp                                                ; ...
    ld sp, hl                                                 ; ...
    or 1                                                      ; set NZ flag
    ex de, hl                                                 ;
    jp (hl)                                                   ;


; OUT -  F - Z on success, NZ on fail
trdos_settings_load:
    call trdos_settings_load0                                       ;
    ret nz                                                    ;
    ld hl, 0                                                  ;
    add hl, sp                                                ;
    ld de, var_settings                                       ;
    ld bc, settings_t                                         ;
    ldir                                                      ;
    ld sp, hl                                                 ;
    ret                                                       ;


; OUT -  F - Z on success, NZ on fail
trsdos_settings_save:
    call trdos_settings_load0                                       ; check if user didn't changed floppy disk
    ret nz                                                    ; ...
    ld hl, settings_t                                         ; deallocate stack
    add hl, sp                                                ; ...
    ld sp, hl                                                 ; ...
1:  ld hl, var_settings.magic                                 ; set magic dword
    ld (hl), (settings_magic >>  0) & 0xff : inc hl           ; ...
    ld (hl), (settings_magic >>  8) & 0xff : inc hl           ; ...
    ld (hl), (settings_magic >> 16) & 0xff : inc hl           ; ...
    ld (hl), (settings_magic >> 24) & 0xff                    ; ...
1:  ld c, trdos_fun_write_block                               ; write settings
    ld hl, var_settings                                       ; ... src
    ld de, (var_settings_sector)                              ; ... dst
    ld b, 1                                                   ; ... one sector
    jp trdos_exec_fun                                         ; ...

settings_load   equ trdos_settings_load
settings_save   equ trsdos_settings_save
    ENDIF;DOS_PLUS3

    IFNDEF __MODULE_SETTINGS_IO_IMPLEMENTED__
settings_load:
settings_save:
        or 0xff
        ret
    ELSE    ; internal DEFINE, let's limit its scope
        UNDEFINE __MODULE_SETTINGS_IO_IMPLEMENTED__
    ENDIF ;__MODULE_SETTINGS_IO_IMPLEMENTED__

settings_apply:
    call input_init_kempston                                  ;
    jp disks_init                                             ;


settings_menu_apply_cb:
    call settings_apply                                       ;
    call right_menu_clear                                     ;
    ld iy, main_menu                                          ;
    call menu_draw                                            ;
    jp menu_main_right_toggle                                 ;


settings_menu_save_cb:
    call settings_save               ;
    ld a, LAYOYT_OK_FE               ;
    jr z, 1f                         ;
    ld a, LAYOYT_ERR_FE              ;
1:  out (#fe), a                     ;
    ret                              ;


; IN  - DE - *settings_menuentry_t
settings_menu_val_cb:
    ex de, hl                        ;
    inc hl                           ;
    ld e, (hl)                       ; de = ptr
    inc hl                           ; ...
    ld d, (hl)                       ; ...
    ld a, (de)                       ; a = *ptr
    inc hl                           ;
    add a, a                         ;
    adc a, l                         ;
    ld l, a                          ;
    jr nc, 1f                        ;
    inc h                            ;
1:  ld a, (hl) : ld ixl, a           ;
    inc hl                           ;
    ld a, (hl) : ld ixh, a           ;
    ret                              ;


; IN  - DE - *settings_menuentry_t
settings_menu_cb:
    ex de, hl                        ;
    ld c, (hl)                       ; c = max
    inc hl                           ;
    ld a, (hl)                       ; hl = ptr
    inc hl                           ; ...
    ld h, (hl)                       ; ...
    ld l, a                          ; ...
    ld a, (hl)                       ; a = *ptr
    inc a                            ; a++
    cp c                             ; if (a > max) a = 0
    jr c, 1f                         ; ...
    xor a                            ; ...
1:  ld (hl), a                       ; *ptr = a
    ex de, hl                        ;
    jp menugen_callback_redraw_value ;


settings_menuentry_output:
    DB 5
    DW var_settings.output
    DW str_128std.end
    DW str_ts1.end
    DW str_ts2.end
    DW str_shama.end
    DW str_neogs1053.end
settings_menuentry_divmmc:
    DB 2
    DW var_settings.divmmc
    DW str_off.end
    DW str_on.end
settings_menuentry_zxmmc:
    DB 2
    DW var_settings.zxmmc
    DW str_off.end
    DW str_on.end
settings_menuentry_zcontroller:
    DB 2
    DW var_settings.zcontroller
    DW str_off.end
    DW str_on.end
settings_menuentry_neogsmmc:
    DB 2
    DW var_settings.neogsmmc
    DW str_off.end
    DW str_on.end
settings_menuentry_divide:
    DB 2
    DW var_settings.divide
    DW str_off.end
    DW str_on.end
settings_menuentry_nemoide:
    DB 2
    DW var_settings.nemoide
    DW str_off.end
    DW str_on.end
settings_menuentry_smuc:
    DB 2
    DW var_settings.smuc
    DW str_off.end
    DW str_on.end
settings_menuentry_extraram:
    DB 4
    DW var_settings.extraram
    DW str_off.end
    DW str_pentagon.end
    DW str_scorpion.end
    DW str_profi.end
settings_menuentry_kempston:
    DB 3
    DW var_settings.kempston
    DW str_off.end
    DW str_auto.end
    DW str_on.end

settings_menu_entries:
    menugen_t 11
    menugen_entry_t str_output       settings_menu_val_cb settings_menu_cb settings_menuentry_output
    menugen_entry_t str_kempston     settings_menu_val_cb settings_menu_cb settings_menuentry_kempston
    menugen_entry_t str_divmmc       settings_menu_val_cb settings_menu_cb settings_menuentry_divmmc
    menugen_entry_t str_zxmmc        settings_menu_val_cb settings_menu_cb settings_menuentry_zxmmc
    menugen_entry_t str_zcontroller  settings_menu_val_cb settings_menu_cb settings_menuentry_zcontroller
    menugen_entry_t str_neogsmmc     settings_menu_val_cb settings_menu_cb settings_menuentry_neogsmmc
    menugen_entry_t str_divide       settings_menu_val_cb settings_menu_cb settings_menuentry_divide
    menugen_entry_t str_nemoide      settings_menu_val_cb settings_menu_cb settings_menuentry_nemoide
    menugen_entry_t str_smuc         settings_menu_val_cb settings_menu_cb settings_menuentry_smuc
    ; menugen_entry_t str_extraram     settings_menu_val_cb settings_menu_cb settings_menuentry_extraram
    menugen_entry_t str_save         0 settings_menu_save_cb
    menugen_entry_t str_apply        0 settings_menu_apply_cb
