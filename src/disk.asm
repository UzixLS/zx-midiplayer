; Page         128  +3
; 0 000
; 1 001        slow
; 2 010 0x8000
; 3 011        slow
; 4 100             slow
; 5 101 0x4000 slow slow
; 6 110             slow
; 7 111 altscr slow slow

    align 8
file_pages: db #10, #14, #16, #13

file_base_addr equ #c000
file_page_size equ #4000



; IN  - HL - file position
; OUT - HL - HL + 1
; OUT - AF - garbage
; OUT - BC - garbage
file_switch_page:
    ld a, #ff                        ; force page switch
    ld (file_get_next_byte.pg+1), a  ; ...

; IN  - HL - file position
; OUT -  A - data
; OUT - HL - next file position
; OUT -  F - garbage
; OUT - BC - garbage
file_get_next_byte:
    ld a, h                          ; compare requested page with current page
    and #c0                          ; ... page_number = position[7:6]
.pg:cp #ff                           ; ... self modifying code! see bellow and file_switch_page
    jp z, .get                       ; ...
.switch_page:
    ld (.pg+1), a                    ;
    ld bc, file_pages                ; A = *(file_pages + (page_number >> 6))
    rlca : rlca                      ; ...
    add a, c                         ; ...
    ld c, a                          ; ...
    ld a, (bc)                       ; ...
    ld bc, #7ffd                     ;
    out (c), a                       ;
.get:
    ld a, h                          ; position = position[5:0]
    and #3f                          ; ...
    add a, high file_base_addr       ; A = *(base_addr + position)
    ld b, a                          ; ...
    ld c, l                          ; ...
    ld a, (bc)                       ; ...
    inc hl                           ; position++
    ret                              ;


disk_sector_size equ 512

DISK_DRIVER_DIVMMC      equ #10
DISK_DRIVER_ZXMMC       equ #20
DISK_DRIVER_ZCONTROLLER equ #30
DISK_DRIVER_NEOGS       equ #40
DISK_DRIVER_DIVIDE      equ #50 | #80
DISK_DRIVER_NEMOIDE     equ #60 | #80
DISK_DRIVER_SMUC        equ #70 | #80
    STRUCT disk_t
driver         DB
offset         DD
disk_param     DB
fatfs          fatfs_disk_t
_reserv        BLOCK 1, 0
    ENDS
    STRUCT disks_t
boot_n         DB
current_n      DB
current_ptr    DW
count          DB
all            BLOCK disk_t*DISKS_MAX_COUNT
    ENDS



; OUT - IXH - IXH+1 on success
; OUT -  AF - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
; OUT -  HL - garbage
disks_save_new:
    ld a, (var_disks.count)            ;
    cp DISKS_MAX_COUNT                 ;
    ret z                              ;
    ld hl, var_disks.count             ; count_next++
    inc (hl)                           ; ...
    assert disk_t == 16
    ld h, 0 : ld l, a                  ; de = &disks.all[count]
    .4 add hl, hl                      ; ...
    ld de, var_disks.all               ; ...
    add hl, de                         ; ...
    ex de, hl                          ; ...
    ld hl, var_disk                    ; memcpy(&disks.all[count],var_disk,sizeof(disk_t))
    ld bc, disk_t                      ; ...
    ldir                               ; ...
    inc ixh                            ;
    ret                                ;


; OUT - IXH - number of disks added
; OUT -   F - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
; OUT -  HL - garbage
; OUT - IXL - garbage
disks_scan_filesystems:
    ld ixh, 0                          ;
    ld bc, 0                           ;
    ld de, 0                           ;
    ld (var_disk.offset+0), bc         ;
    ld (var_disk.offset+2), de         ;
    ld hl, disk_buffer                 ;
    ld ixl, 1                          ;
    call disk_read_sectors             ;
    ret nz                             ;
.fatfs_without_mbr:
    call fatfs_init.check              ; disk may be formatted to fat without mbr
    jp z, disks_save_new               ;
.mbr:
    ld hl, disk_buffer+#1fe            ; check mbr signature
    ld a, #55 : cp (hl) : ret nz       ; ...
    inc hl                             ; ...
    ld a, #aa:  cp (hl):  ret nz       ; ...
    ld b, 0                            ; entries = 0
    ld hl, disk_buffer+#1ee            ;
    call .check_partition_entry        ;
    ld hl, disk_buffer+#1de            ;
    call .check_partition_entry        ;
    ld hl, disk_buffer+#1ce            ;
    call .check_partition_entry        ;
    ld hl, disk_buffer+#1be            ;
    call .check_partition_entry        ;
    ld ixh, 0                          ;
    ld a, b                            ;
    or a                               ;
    ret z                              ;
.check_partition_filesystem:
    pop hl                             ;
    ld (var_disk.offset+2), hl         ;
    pop hl                             ;
    ld (var_disk.offset+0), hl         ;
    push bc                            ;
    call fatfs_init                    ;
    call z, disks_save_new             ;
    pop bc                             ;
    djnz .check_partition_filesystem   ;
    ret                                ;
.check_partition_entry:
    ld a, (hl)                         ; valid PT_BootID is 0x00 or 0x80
    and #7f                            ; ...
    ret nz                             ; ...
    .4 inc hl                          ; check PT_System is not Blank
    ld a, (hl)                         ; ...
    or a                               ; ...
    ret z                              ; ...
    .4 inc hl                          ; check PT_LbaOfs != 0
    ld d, h : ld e, l                  ;
    xor a                              ; ...
    or (hl) : inc hl                   ; ...
    or (hl) : inc hl                   ; ...
    or (hl) : inc hl                   ; ...
    or (hl)                            ; ...
    ret z                              ; ...
    pop ix                             ; return address
1:  ex de, hl                          ; save PT_LbaOfs
    ld e, (hl) : inc hl                ; ...
    ld d, (hl) : inc hl                ; ...
    push de                            ; ...
    ld e, (hl) : inc hl                ; ...
    ld d, (hl) : inc hl                ; ...
    push de                            ; ...
    inc b                              ; entries++
    jp (ix)                            ; ret


; IN  -  A - driver | disk_number
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
disks_scan_mmc:
    ld (var_disk.driver), a            ;
    call mmc_driver_select             ;
    call mmc_init                      ;
    ret nz                             ;
    ld a, e                            ;
    ld (var_disk.disk_param), a        ;
    call disks_scan_filesystems        ;
    xor a : or ixh                     ; if there is no filesystems on disk - add it anyway, but deny any access to it
    ret nz                             ;
    ld a, #01                          ; ...
    ld (var_disk.driver), a            ; ...
    jp disks_save_new                  ; ...


; IN  -  A - driver | disk_number
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
disks_scan_ide:
    ld (var_disk.driver), a            ;
    call ide_driver_select             ;
    call ide_init                      ;
    ld a, 0                            ; nemoide may affect #fe port
    out (#fe), a                       ; ...
    ret nz                             ;
    call disks_scan_filesystems        ;
    xor a : or ixh                     ; if there is no filesystems on disk - add it anyway, but deny any access to it
    ret nz                             ;
    ld a, #81                          ; ...
    ld (var_disk.driver), a            ; ...
    jp disks_save_new                  ; ...


; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
disks_init:
    xor a                              ;
    ld (var_disks.count), a            ;
    ld (var_disks.current_ptr+0), a    ;
    ld (var_disks.current_ptr+1), a    ;
.scan_trdos:
    ld a, (var_trdos_present)          ;
    or a                               ;
    jr z, .scan_divide                 ;
    ld a, trdos_disks                  ;
    ld (var_disks.count), a            ;
.scan_divide:
    ld a, (var_settings.divide)        ;
    or a                               ;
    jr z, .scan_nemoide                ;
    ld a, DISK_DRIVER_DIVIDE | #00     ;
    call disks_scan_ide                ;
    ld a, DISK_DRIVER_DIVIDE | #01     ;
    call disks_scan_ide                ;
.scan_nemoide:
    ld a, (var_settings.nemoide)       ;
    or a                               ;
    jr z, .scan_smuc                   ;
    ld a, DISK_DRIVER_NEMOIDE | #00    ;
    call disks_scan_ide                ;
    ld a, DISK_DRIVER_NEMOIDE | #01    ;
    call disks_scan_ide                ;
.scan_smuc:
    ld a, (var_settings.smuc)          ;
    or a                               ;
    jr z, .scan_divmmc                 ;
    ld a, DISK_DRIVER_SMUC | #00       ;
    call disks_scan_ide                ;
    ld a, DISK_DRIVER_SMUC | #01       ;
    call disks_scan_ide                ;
.scan_divmmc:
    ld a, (var_settings.divmmc)        ;
    or a                               ;
    jr z, .scan_zxmmc                  ;
    ld a, DISK_DRIVER_DIVMMC | #00     ;
    call disks_scan_mmc                ;
    ld a, DISK_DRIVER_DIVMMC | #01     ;
    call disks_scan_mmc                ;
.scan_zxmmc:
    ld a, (var_settings.zxmmc)         ;
    or a                               ;
    jr z, .scan_zcontroller            ;
    ld a, DISK_DRIVER_ZXMMC | #00      ;
    call disks_scan_mmc                ;
    ld a, DISK_DRIVER_ZXMMC | #01      ;
    call disks_scan_mmc                ;
.scan_zcontroller:
    ld a, (var_settings.zcontroller)   ;
    or a                               ;
    jr z, .scan_neogs                  ;
    ld a, DISK_DRIVER_ZCONTROLLER      ;
    call disks_scan_mmc                ;
.scan_neogs:
    ld a, (var_settings.neogsmmc)      ;
    or a                               ;
    ret z                              ;
    ld a, DISK_DRIVER_NEOGS            ;
    jp disks_scan_mmc                  ;


; IN  - DEBC - src lba
; IN  - HL   - dst address of IXL*512-byte buffer
; IN  - IXL  - sectors count
; OUT - F    - Z on success, NZ on fail
; OUT - HL   - next untouched dst address
; OUT - A    - garbage
; OUT - BC   - garbage
; OUT - DE   - garbage
; OUT - IXL  - garbage
disk_read_sectors:
    push hl                          ;
    ld hl, (var_disk.offset+0)       ; lba = lba + partition offset
    add hl, bc                       ; ...
    ld b, h : ld c, l                ; ...
    ld hl, (var_disk.offset+2)       ; ...
    adc hl, de                       ; ...
    ex de, hl                        ; ...
    pop hl                           ;
.loop:
    push de                          ;
    push bc                          ;
    push ix                          ;
    call .driver_read_block          ;
    pop ix                           ;
    pop bc                           ;
    pop de                           ;
    ret nz                           ;
    inc c : jr nz, 1f                ;
    inc b : jr nz, 1f                ;
    inc e : jr nz, 1f                ;
    inc d                            ;
1:  dec ixl                          ;
    jr nz, .loop                     ;
    ret                              ;
.driver_read_block:
    ld a, (var_disk.driver)          ; if 7th bit is set - ide driver, else mmc
    bit 7, a                         ; ...
    ld a, (var_disk.disk_param)      ;
    jp nz, ide_read_block            ;
    jp mmc_read_block                ;


; IN  - DE - entry number
; OUT -  F - NZ when yes, Z when no
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - HL - garbage
disk_entry_is_directory:
    jp 0

; IN  - DE - entry number
; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
disk_file_load:
    jp 0

; IN  - DE - entry number or 0xffff for root directory
; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
disk_directory_load:
    jp 0

; IN  - DE - entry number
; OUT -  F - Z on success, NZ on fail
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
disk_directory_menu_generator:
    jp 0


; IN  -  E - disk number
; OUT -  F - Z on success, NZ on fail
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
disk_change:
    push de                                  ;
.save_old_cur_disk:
    ld de, (var_disks.current_ptr)           ;
    ld a, d                                  ;
    or e                                     ;
    jr z, .change_to_new_disk                ;
    ld hl, var_disk                          ; memcpy(&disks.all[count],var_disk,sizeof(disk_t))
    ld bc, disk_t                            ;
    ldir                                     ;
.change_to_new_disk:
    pop de                                   ;
    ld a, e                                  ;
    ld (var_disks.current_n), a              ;
    ld h, 0 : ld l, e                        ; hl = &disks.all[count]
    assert disk_t == 16
    .4 add hl, hl                            ; ...
    ld de, var_disks.all                     ; ...
    add hl, de                               ; ...
    ld (var_disks.current_ptr), hl           ;
    ld de, var_disk                          ; memcpy(var_disk,&disks.all[count],sizeof(disk_t))
    ld bc, disk_t                            ; ...
    ldir                                     ; ...
    ld a, (var_disk.driver)                  ; determine driver type
    or a                                     ; ...
    jr z, .trd                               ; ...
.fat:
    ld hl, fatfs_entry_is_directory          ;
    ld (disk_entry_is_directory+1), hl       ;
    ld hl, fatfs_file_load                   ;
    ld (disk_file_load+1), hl                ;
    ld hl, fatfs_directory_load              ;
    ld (disk_directory_load+1), hl           ;
    ld hl, fatfs_file_menu_generator         ;
    ld (disk_directory_menu_generator+1), hl ;
.ide:
    jp m, ide_driver_select                  ; ... check bit 7
.mmc:
    jp mmc_driver_select                     ; ...
.trd:
    ld hl, trdos_entry_is_directory          ;
    ld (disk_entry_is_directory+1), hl       ;
    ld hl, trdos_file_load                   ;
    ld (disk_file_load+1), hl                ;
    ld hl, trdos_directory_load              ;
    ld (disk_directory_load+1), hl           ;
    ld hl, trdos_file_menu_generator         ;
    ld (disk_directory_menu_generator+1), hl ;
    ld hl, 0                                 ;
    ld (var_disks.current_ptr), hl           ;
    xor a                                    ; set Z flag
    ret                                      ;



; IN  - HL - pointer to file extension
; OUT -  A - icon
; OUT -  F - garbage
; OUT - DE - garbage
disks_get_icon_by_extension:
    ld d, h : ld e, l                    ;
.check_mid_extension:
    ld a, (de) : inc de                  ; if extension is "mid" - set appropriate icon
    cp 'm' : jr z, 1f                    ;
    cp 'M' : jr nz, .check_rmi_extension ;
1:  ld a, (de) : inc de                  ;
    cp 'i' : jr z, 1f                    ;
    cp 'I' : jr nz, .check_rmi_extension ;
1:  ld a, (de) : inc de                  ;
    cp 'd' : jr z, .melody_icon          ;
    cp 'D' : jr z, .melody_icon          ;
.check_rmi_extension:
    ld d, h : ld e, l                    ;
    ld a, (de) : inc de                  ; if extension is "rmi" - set appropriate icon
    cp 'r' : jr z, 1f                    ;
    cp 'R' : jr nz, .no_icon             ;
1:  ld a, (de) : inc de                  ;
    cp 'm' : jr z, 1f                    ;
    cp 'M' : jr nz, .no_icon             ;
1:  ld a, (de) : inc de                  ;
    cp 'i' : jr z, .melody_icon          ;
    cp 'I' : jr z, .melody_icon          ;
.no_icon:
    ld a, ' '                            ; if extension isn't recognized - set empty icon (space)
    ret                                  ;
.melody_icon:
    ld a, udg_melody                     ;
    ret                                  ;


; IN  -  E - entry number
; OUT -  F - Z on success, NZ on fail
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT - DE - garbage
; OUT - HL - garbage
disks_menu_generator:
    ld ix, tmp_menu_string              ;
    ld a, 'A'                           ;
    add a, e                            ;
    ld (ix+1), a                        ;
    ld (ix+2), ':'                      ;
    ld (ix+3), 0                        ;
.icon:
    assert disk_t == 16
    ld h, 0 : ld l, e                   ; de = &disks.all[count]
    .4 add hl, hl                       ; ...
    ld de, var_disks.all                ; ...
    add hl, de                          ; ...
    ld a, (hl)                          ; determine driver type
    or a                                ; ...
    jr z, .trd                          ; ...
    jp m, .ide                          ; ...
.mmc:
    ld (ix+0), udg_mmc                  ;
    xor a                               ; set Z flag
    ret                                 ;
.ide:
    ld (ix+0), udg_ide                  ;
    xor a                               ; set Z flag
    ret                                 ;
.trd:
    ld (ix+0), udg_floppy               ;
    xor a                               ; set Z flag
    ret                                 ;
