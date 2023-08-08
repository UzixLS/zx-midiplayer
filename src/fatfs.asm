; http://elm-chan.org/docs/fat_e.html

BS_JmpBoot       equ 0    ; len 3    Jump instruction to the bootstrap code (x86 instruction) used by OS boot sequence. There are two type of formats for this field and the former format is prefered.
                                   ; 0xEB, 0x??, 0x90 (Short jump + NOP)
                                   ; 0xE9, 0x??, 0x?? (Near jump)
                                   ; ?? is the arbitrary value depends on where to jump is. In case of any format out of these formats, the volume will not be recognized by Windows.
BS_OEMName       equ 3    ; len 8    "MSWIN 4.1" is recommended but also "MSDOS 5.0" is often used. There are many misconceptions about this field. This is only a name. Microsoft's OS does not pay any attention to this field, but some FAT drivers do some reference. This string is recommended because it is considered to minimize compatibility problems. You can set something else, but some FAT drivers may not recognize that volume. This field usually indicates name of the system created the volume.
BPB_BytsPerSec   equ 11   ; len 2    Sector size in unit of byte. Valid values for this field are 512, 1024, 2048 or 4096. Microsoft's OS properly supports these sector sizes, but many FAT drivers assume the sector size is 512 and do not check this field. For this reason, 512 should be used for maximum compatibility. However, you should not misunderstand that it is only related to compatibility. This value must be the same as the sector size of the storage contains the FAT volume.
BPB_SecPerClus   equ 13   ; len 1    Number of sectors per allocation unit. In the FAT file system, the allocation unit is called Cluster. This is a block of one or more consecutive sectors and the data area is managed in this unit. The number of sectors per cluster must be a power of 2. Therefore, valid values are 1, 2, 4,... and 128. However, any value whose cluster size (BPB_BytsPerSec * BPB_SecPerClus) exceeds 32 KB should not be used. Recent systems, such as Windows, supprts cluster size larger than 32 KB, such as 64 KB, 128 KB, and 256 KB, but such volumes will not be recognized correctly by MS-DOS or old disk utilities.
BPB_RsvdSecCnt   equ 14   ; len 2    Number of sectors in reserved area. This field must not be 0 because there is the boot sector itself contains this BPB in the reserved area. To avoid compatibility problems, it should be 1 on FAT12/16 volume. This is because some old FAT drivers ignore this field and assume that the size of reserved area is 1. On the FAT32 volume, it is typically 32. Microsoft's OS properly supports any value of 1 or larger.
BPB_NumFATs      equ 16   ; len 1    Number of FATs. The value of this field should always be 2. Also any value eaual to or greater than 1 is valid but it is strongly recommended not to use values other than 2 to avoid compatibility problem. Microsoft's FAT driver properly supports the values other than 2 but some tools and FAT drivers ignore this field and operate with number of FAT is 2.
                                   ; The standard value for this field 2 is to provide redudancy for the FAT data. The value of FAT entry is typically read from the first FAT and any change to the FAT entry is refrected to each FATs. If a sector in the FAT area is damaged, the data will not be lost because it is duplicated in another FAT. Therefore it can minimize risk of data loss. On the non-disk based storages, such as memory card, such redundancy is a useless feature, so that it may be 1 to save the disk space. But some FAT driver may not recognize such a volume properly.
BPB_RootEntCnt   equ 17   ; len 2    On the FAT12/16 volumes, this field indicates number of 32-byte directory entries in the root directory. The value should be set a value that the size of root directory is aligned to the 2-sector boundary, BPB_RootEntCnt * 32 becomes even multiple of BPB_BytsPerSec. For maximum compatibility, this field should be set to 512 on the FAT16 volume. For FAT32 volumes, this field must be 0.
BPB_TotSec16     equ 19   ; len 2    Total number of sectors of the volume in old 16-bit field. This value is the number of sectors including all four areas of the volume. When the number of sectors of the FAT12/16 volumes is 0x10000 or larger, an invalid value 0 is set in this field, and the true value is set to BPB_TotSec32. For FAT32 volumes, this field must always be 0.
BPB_Media        equ 21   ; len 1    The valid values for this field is 0xF0, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE and 0xFF. 0xF8 is the standard value for non-removable disks and 0xF0 is often used for non partitioned removable disks. Other important point is that the same value must be put in the lower 8-bits of FAT[0]. This comes from the media determination of MS-DOS Ver.1 and not used for any purpose any longer.
BPB_FATSz16      equ 22   ; len 2    Number of sectors occupied by a FAT. This field is used for only FAT12/16 volumes. On the FAT32 volumes, it must be an invalid value 0 and BPB_FATSz32 is used instead. The size of the FAT area becomes BPB_FATSz?? * BPB_NumFATs sectors.
BPB_SecPerTrk    equ 24   ; len 2    Number of sectors per track. This field is relevant only for media that have geometry and used for only disk BIOS of IBM PC.
BPB_NumHeads     equ 26   ; len 2    Number of heads. This field is relevant only for media that have geometry and used for only disk BIOS of IBM PC.
BPB_HiddSec      equ 28   ; len 4    Number of hidden physical sectors preceding the FAT volume. It is generally related to storage accessed by disk BIOS of IBM PC, and what kind of value is set is platform dependent. This field should always be 0 if the volume starts at the beginning of the storage, e.g. non-partitioned disks, such as floppy disk.
BPB_TotSec32     equ 32   ; len 4    Total number of sectors of the FAT volume in new 32-bit field. This value is the number of sectors including all four areas of the volume. When the value on the FAT12/16 volume is less than 0x10000, this field must be invalid value 0 and the true value is set to BPB_TotSec16. On the FAT32 volume, this field is always valid and old field is not used.

; FAT12/16
;  BS_DrvNum        equ 36  ; len 1    Drive number used by disk BIOS of IBM PC. This field is used in MS-DOS bootstrap, 0x00 for floppy disk and 0x80 for fixed disk. Actually it depends on the OS.
;  BS_Reserved      equ 37  ; len 1    Reserved (used by Windows NT). It should be set 0 when create the volume.
;  BS_BootSig       equ 38  ; len 1    Extended boot signature (0x29). This is a signature byte indicates that the following three fields are present.
;  BS_VolID         equ 39  ; len 4    Volume serial number used with BS_VolLab to track a volume on the removable storage. It enables to detect a wrong media change by FAT driver. This value is typically generated with current time and date on formatting.
;  BS_VolLab        equ 43  ; len 11   This field is the 11-byte volume label and it matches volume label recorded in the root directory. FAT driver should update this field when the volume label in the root directory is changed. MS-DOS does it but Windows does not do it. When volume label is not present, "NO NAME " should be set in this field.
;  BS_FilSysType    equ 54  ; len 8    "FAT12   ", "FAT16   " or "FAT     ". Many people think that this string has any effect in determination of the FAT type but it is clearly a misrecognization. From the name of this field, you will find that this is not a part of BPB. Since this string is often incorrect or not set, Microsoft's FAT driver does not use this field to determine the FAT type. However, some old FAT drivers use this string to determine the FAT type, so that it should be set based on the FAT type of the volume to avoid compatibility problems.
;  BS_BootCode      equ 62  ; len 448  Bootstrap program. It is platform dependent and filled with zero when not used.
;  BS_BootSign      equ 510 ; len 2    0xAA55. A boot signature indicating that this is a valid boot sector.
;                      ;512            When the sector size is larger than 512 bytes, rest field in the sector should be filled with zero.

; FAT32
BPB_FATSz32      equ 36   ; len 4    Size of a FAT in unit of sector. The size of the FAT area is BPB_FATSz32 * BPB_NumFATs sector. This is an only field needs to be referred prior to determine the FAT type while this field exists in only FAT32 volume. But this is not a problem because BPB_FATSz16 is always invalid in FAT32 volume.
BPB_ExtFlags     equ 40   ; len 2    Bit3-0: Active FAT starting from 0. Valid when bit7 is 1.
                                   ; Bit6-4: Reserved (0).
                                   ; Bit7: 0 means that each FAT are active and mirrored. 1 means that only one FAT indicated by bit3-0 is active.
                                   ; Bit15-8-4: Reserved (0).
BPB_FSVer        equ 42   ; len 2    FAT32 version. Upper byte is major version number and lower byte is minor version number. This document describes FAT32 version 0.0. This field is for futuer extension of FAT32 volume to manage the filesystem verison. However, FAT32 volume will not be updated any longer.
BPB_RootClus     equ 44   ; len 4    First cluster number of the root directory. It is usually set to 2, the first cluster of the volume, but it does not need to always be 2.
BPB_FSInfo       equ 48   ; len 2    Sector of FSInfo structure in offset from top of the FAT32 volume. It is usually set to 1, next to the boot sector.
BPB_BkBootSec    equ 50   ; len 2    Sector of backup boot sector in offset from top of the FAT32 volume. It is usually set to 6, next to the boot sector but 6 and any other value is not recommended.
BPB_Reserved     equ 52   ; len 12   Reserved (0).
BS_DrvNum        equ 64   ; len 1    Same as the description of FAT12/16 field.
BS_Reserved      equ 65   ; len 1    Same as the description of FAT12/16 field.
BS_BootSig       equ 66   ; len 1    Same as the description of FAT12/16 field.
BS_VolID         equ 67   ; len 4    Same as the description of FAT12/16 field.
BS_VolLab        equ 71   ; len 11   Same as the description of FAT12/16 field.
BS_FilSysType    equ 82   ; len 8    Always "FAT32   " and has not any effect in determination of FAT type.
BS_BootCode32    equ 90   ; len 420  Bootstrap program. It is platform dependent and filled with zero when not used.
BS_BootSign      equ 510  ; len 2    0xAA55. A boot signature indicating that this is a valid boot sector.
                    ;512             When the sector size is larger than 512 bytes, rest field in the sector should be filled with zero.

; Directory entry
DIR_Name         equ 0    ; len 11   Short file name (SFN) of the object.
DIR_Attr         equ 11   ; len 1    File attribute in combination of following flags. Upper 2 bits are reserved and must be zero.
                                   ; 0x01: ATTR_READ_ONLY (Read-only)
                                   ; 0x02: ATTR_HIDDEN (Hidden)
                                   ; 0x04: ATTR_SYSTEM (System)
                                   ; 0x08: ATTR_VOLUME_ID (Volume label)
                                   ; 0x10: ATTR_DIRECTORY (Directory)
                                   ; 0x20: ATTR_ARCHIVE (Archive)
                                   ; 0x0F: ATTR_LONG_FILE_NAME (LFN entry)
DIR_NTRes        equ 12   ; len 1    Optional flags that indicates case information of the SFN.
                                   ; 0x08: Every alphabet in the body is low-case.
                                   ; 0x10: Every alphabet in the extensiton is low-case.
DIR_CrtTimeTenth equ 13   ; len 1    Optional sub-second information corresponds to DIR_CrtTime. The time resolution of DIR_CrtTime is 2 seconds, so that this field gives a count of sub-second and its valid value range is from 0 to 199 in unit of 10 miliseconds. If not supported, set zero and do not change afterwards.
DIR_CrtTime      equ 14   ; len 2    Optional file creation time. If not supported, set zero and do not change afterwards.
DIR_CrtDate      equ 16   ; len 2    Optional file creation date. If not supported, set zero and do not change afterwards.
DIR_LstAccDate   equ 18   ; len 2    Optional last accesse date. There is no time information about last accesse time, so that the resolution of last accesse time is 1 day. If not supported, set zero and do not change afterwards.
DIR_FstClusHI    equ 20   ; len 2    Upeer part of cluster number. Always zero on the FAT12/16 volume. See DIR_FstClusLO.
DIR_WrtTime      equ 22   ; len 2    Last time when any change is made to the file (typically on closeing).
DIR_WrtDate      equ 24   ; len 2    Last data when any change is made to the file (typically on closeing).
DIR_FstClusLO    equ 26   ; len 2    Lower part of cluster number. When the file size is zero, no cluster is assigned and this item must be zero. Always an valid value if it is a directory.
DIR_FileSize     equ 28   ; len 4    Size of the file in unit of byte. Not used when it is a directroy and the value must be always zero.


fat_buffer equ disk_buffer
dir_buffer equ disk_buffer+disk_sector_size

    STRUCT fatfs_disk_t
BPB_SecPerClus           DB
BPB_RootClus             DD
data_lba                 DD
    ENDS

    STRUCT fatfs_state_t
current_dir              DD
dir_window_first_file_n  DW
dir_window_files_cnt     DW
dir_window_cluster_n     DD
dir_window_cluster_pos   DW
dir_window_sector_pos    DB
    ENDS



; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
fatfs_check_sanity:
.BS_FilSysType:
    ld hl, disk_buffer+BS_FilSysType              ; check expected string
    ld a, 'F' : cpi : ret nz                      ; ...
    ld a, 'A' : cpi : ret nz                      ; ...
    ld a, 'T' : cpi : ret nz                      ; ...
    ld a, '3' : cpi : ret nz                      ; ...
    ld a, '2' : cpi : ret nz                      ; ...
.BS_JmpBoot:
    ld a, (disk_buffer+BS_JmpBoot)                ; x86 boot code - should be #EB or #E9 or #E8 on valid fat partition
    cp #eb : jr z, .BPB_BytsPerSec                ; ...
    cp #e9 : jr z, .BPB_BytsPerSec                ; ...
    cp #e8 : jr z, .BPB_BytsPerSec                ; ...
    ret                                           ; ...
.BPB_BytsPerSec:
    ld de, (disk_buffer+BPB_BytsPerSec)           ; sector shoud be 512/1024/2048/4096-bytes size
    ld hl, -512                                   ; ...
    add hl, de                                    ; ...
    ld b, 1                                       ; ... set multiplier for BPB_SecPerClus
    jr z, .BPB_SecPerClus                         ; ...
    ld hl, -1024                                  ; ...
    add hl, de                                    ; ...
    ld b, 2                                       ; ... set multiplier for BPB_SecPerClus
    jr z, .BPB_SecPerClus                         ; ...
    ld hl, -2048                                  ; ...
    add hl, de                                    ; ...
    ld b, 4                                       ; ... set multiplier for BPB_SecPerClus
    jr z, .BPB_SecPerClus                         ; ...
    ld hl, -4096                                  ; ...
    add hl, de                                    ; ...
    ld b, 8                                       ; ... set multiplier for BPB_SecPerClus
    jr z, .BPB_SecPerClus                         ; ...
    ret                                           ; ...
.BPB_SecPerClus:
    assert disk_sector_size == 512
    ld a, (disk_buffer+BPB_SecPerClus)            ; save BPB_SecPerClus * multiplier (as disk sector size is always 512-byte)
1:  add a, a                                      ; ...
    djnz 1b                                       ; ...
    srl a                                         ; ...
    ld (var_disk.fatfs.BPB_SecPerClus), a         ; ...
    ld a, (disk_buffer+BPB_SecPerClus)            ; check sectors per cluster != 0 and is power of 2
    or a                                          ; ...
    jr z, .err                                    ; ...
    ld e, a                                       ; ...
    dec a                                         ; ...
    and e                                         ; ...
    ret nz                                        ; ...
.BPB_RsvdSecCnt:
    ld hl, (disk_buffer+BPB_RsvdSecCnt)           ; check reserved sectors != 0
    ld a, h                                       ; ...
    or l                                          ; ...
    jr z, .err                                    ; ...
.BPB_NumFATs:
    ld a, (disk_buffer+BPB_NumFATs)               ; check number of FATs is 1 or 2
    cp 1 : jr z, .BPB_RootEntCnt                  ; ...
    cp 2 : jr z, .BPB_RootEntCnt                  ; ...
    ret                                           ; ...
.BPB_RootEntCnt:
    ld hl, (disk_buffer+BPB_RootEntCnt)           ; check number of entries in root directory - for FAT32 this should be 0
    ld a, h                                       ; ...
    or l                                          ; ...
    ret nz                                        ; ...
.BPB_TotSec16:
    ld hl, (disk_buffer+BPB_TotSec16)             ; check total number of sectors - for FAT32 this should be 0
    ld a, h                                       ; ...
    or l                                          ; ...
    ret nz                                        ; ...
.BPB_TotSec32:
    ld hl, (disk_buffer+BPB_TotSec32+0)           ; check total number of sectors != 0
    ld a, h                                       ; ...
    or l                                          ; ...
    ld hl, (disk_buffer+BPB_TotSec32+2)           ; ...
    or h                                          ; ...
    or l                                          ; ...
    jr z, .err                                    ; ...
.BPB_FATSz16:
    ld hl, (disk_buffer+BPB_FATSz16)              ; check FAT12/16 size - for FAT32 this should be 0
    ld a, h                                       ; ...
    or l                                          ; ...
    ret nz                                        ; ...
.BPB_FATSz32:
    ld hl, (disk_buffer+BPB_FATSz32+0)            ; check FAT32 size != 0
    ld a, h                                       ; ...
    or l                                          ; ...
    ld hl, (disk_buffer+BPB_FATSz32+2)            ; ...
    or h                                          ; ...
    or l                                          ; ...
    jr z, .err                                    ; ...
.exit_ok:
    xor a                                         ; set Z flag
    ret                                           ;
.err:
    or 1                                          ; set NZ flag
    ret                                           ;


; OUT -  F  - Z on success, NZ on fail
; OUT -  A  - garbage
; OUT - BC  - garbage
; OUT - DE  - garbage
; OUT - HL  - garbage
; OUT - IXL - garbage
fatfs_init:
    ld bc, 0                                      ;
    ld de, 0                                      ;
    ld hl, disk_buffer                            ;
    ld ixl, 1                                     ;
    call disk_read_sectors                        ;
    ret nz                                        ;
.check:
    call fatfs_check_sanity                       ;
    ret nz                                        ;
.get_root_directory_cluster:
    ld hl, (disk_buffer+BPB_RootClus+0)           ;
    ld (var_disk.fatfs.BPB_RootClus+0), hl        ;
    ld (var_fatfs.current_dir+0), hl              ;
    ld hl, (disk_buffer+BPB_RootClus+2)           ;
    ld (var_disk.fatfs.BPB_RootClus+2), hl        ;
    ld (var_fatfs.current_dir+2), hl              ;
.set_disk_rw_base_lba:
    ld de, (disk_buffer+BPB_RsvdSecCnt)           ; base offset of disk = address of first fat table
    ld hl, (var_disk.offset+0)                    ;
    add hl, de                                    ;
    ld (var_disk.offset+0), hl                    ;
    ld de, 0                                      ;
    ld hl, (var_disk.offset+2)                    ;
    adc hl, de                                    ;
    ld (var_disk.offset+2), hl                    ;
.calc_data_lba:
    ld de, (disk_buffer+BPB_FATSz32+0)            ;
    ld hl, (disk_buffer+BPB_FATSz32+2)            ;
    ld a, (disk_buffer+BPB_NumFATs)               ; 2xfat?
    or a                                          ; ...
    jr z, 1f                                      ; ...
    sla e : rl d : rl l : rl h                    ; ...
1:  ld (var_disk.fatfs.data_lba+0), de            ;
    ld (var_disk.fatfs.data_lba+2), hl            ;
.count_of_clusters:
    ld b, h : ld c, l                             ; FAT32 should contain >= 65526 clusters
    ld hl, (disk_buffer+BPB_TotSec32+0)           ; HLDE = BPB_TotSec - DataStartSector - BPB_RsvdSecCnt
    or a : sbc hl, de                             ; ...
    ex de, hl                                     ; ...
    ld hl, (disk_buffer+BPB_TotSec32+2)           ; ...
    sbc hl, bc                                    ; ...
    ld bc, (disk_buffer+BPB_RsvdSecCnt)           ; ...
    ex de, hl                                     ; ...
    or a                                          ; ...
    sbc hl, bc                                    ; ...
    ex de, hl                                     ; ...
    ld bc, 0                                      ; ...
    sbc hl, bc                                    ; ...
    ld a, (var_disk.fatfs.BPB_SecPerClus)         ; HLDE = HLDE / BPB_SecPerClus
1:  srl a                                         ; ...
    jr z, 1f                                      ; ...
    srl h : rr l : rr d : rr e                    ; ... HLDE = HLDE/2
    jr 1b                                         ; ...
1:  ld a, h                                       ; check > 65535
    or l                                          ; ...
    jr nz, .exit_ok                               ; ...
    ex de, hl                                     ; check >= 65526
    ld de, 65526                                  ; ...
    sbc hl, de                                    ; ...
    jr c, .err                                    ; ...
.exit_ok:
    xor a                                         ; set Z flag
    ret                                           ;
.err:
    or 1                                          ; set NZ flag
    ret                                           ;


; IN  - DEBC - cluster n (0x00000002 - 0x0FFFFFF6)
; IN  -   HL - offset in sectors inside cluster
; OUT -    F - Z on success, NZ on fail
; OUT - DEBC - lba (sector address)
; OUT -    A - garbage
; OUT -   HL - garbage
fatfs_get_lba:
    push hl                                    ;
.sub_0x00000002:
    ld l, 0                                    ; DEBC -= 2
    ld a, c : sub 2 : ld c, a                  ; ...
    ld a, b : sbc l : ld b, a                  ; ...
    ld a, e : sbc l : ld e, a                  ; ...
    ld a, d : sbc l : ld d, a                  ; ...
.check_in_range:
              cp #0f     : jr c, .calc_lba     ; check DEBC <= 0x0FFFFFF4
    ld a, e : inc a      : jr nz, .calc_lba    ; ...
    ld a, b : inc a      : jr nz, .calc_lba    ; ...
    ld a, c : cp #f6-2+1 : jr c, .calc_lba     ; ...
    pop hl                                     ;
    or 1                                       ; set NZ flag
    ret                                        ;
.calc_lba:
    ld a, (var_disk.fatfs.BPB_SecPerClus)      ; lba = cluster_n * BPB_SecPerClus
1:  srl a                                      ; ...
    jr z, .add_data_offset                     ; ...
    sla c : rl b : rl e : rl d                 ; ... DEBC = DEBC*2
    jr 1b                                      ; ...
.add_data_offset:
    ld hl, (var_disk.fatfs.data_lba+0)         ; lba += first_data_sector_number
    add hl, bc                                 ; ...
    ld b, h : ld c, l                          ; ...
    ld hl, (var_disk.fatfs.data_lba+2)         ; ...
    adc hl, de                                 ; ...
    ex de, hl                                  ; ...
.add_sector_offset:
    pop hl                                     ; lba += HL (offset in sectors inside cluster)
    add hl, bc                                 ; ...
    ld b, h : ld c, l                          ; ...
    jr nc, .exit                               ; ...
    inc de                                     ; ...
.exit:
    xor a                                      ; set Z flag
    ret                                        ;


; IN  - DEBC - cluster n
; OUT -    F - Z on success, NZ on fail
; OUT - DEBC - next cluster n in chain
; OUT -    A - garbage
; OUT -   HL - garbage
; OUT -  IXL - garbage
fatfs_get_next_cluster_n:
    push bc                                    ;
    assert disk_sector_size == 512
    sla c : ld c, b : ld b, e : ld e, d        ; lba of fat sector = cluster_n * 4 / 512
    ld d, 0 : rl c : rl b : rl e : rl d        ; ...
    ld hl, fat_buffer                          ; get corresponding fat sector
    ld ixl, 1                                  ; ...
    call disk_read_sectors                     ; ...
    pop bc                                     ;
    ret nz                                     ; ...
    ld a, c : and #7f                          ; each 512-byte sector in fat32 contains information about 128 clusters
    ld b, 0                                    ; ... and each entry is 4 byte long
    rla : rl b : rla : rl b                    ; ...
    ld c, a                                    ; ...
    ld hl, fat_buffer                          ; ...
    add hl, bc                                 ; ...
    ld c, (hl) : inc hl : ld b, (hl) : inc hl  ; get info from fat about next cluster in chain
    ld e, (hl) : inc hl : ld d, (hl)           ; ...
    xor a                                      ; set Z flag
    ret                                        ;


; IN  - DEBC - cluster n
; IN  -   HL - clusters count to skip
; OUT -    F - Z on success, NZ on fail
; OUT - DEBC - nth cluster n in chain
; OUT -    A - garbage
; OUT -   HL - garbage
fatfs_get_nth_cluster_n:
    ld a, h : or l                             ;
    ret z                                      ;
    dec hl                                     ;
    push hl                                    ;
    call fatfs_get_next_cluster_n              ;
    pop hl                                     ;
    ret nz                                     ;
    jr fatfs_get_nth_cluster_n                 ;


; IN  - DE - entry number
; OUT -  F - Z on success, NZ on fail
; OUT - HL - pointer to directory entry
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - HL - garbage
fatfs_get_entry:
    push de                                    ;
    ld hl, (var_fatfs.dir_window_first_file_n) ; check de < dir_window_first_file_n
    ex de, hl                                  ; ...
    or a                                       ; ...
    sbc hl, de                                 ; ...
    push hl                                    ; ... HL = entry number from start or window
    jr z, 1f                                   ; ...
    jr c, .entry_before_window                 ; ...
1:  ld de, (var_fatfs.dir_window_files_cnt)    ; check de >= dir_window_first_file_n + dir_window_files_cnt
    or a                                       ; ...
    sbc hl, de                                 ; ...
    jr nc, .entry_after_window                 ; ...
.entry_in_window:
    pop hl                                     ;
    .5 add hl, hl                              ; * 32 (entry size)
    ld de, dir_buffer                          ;
    add hl, de                                 ; HL = src addr
    pop de                                     ;
    xor a                                      ; set Z flag
    ret                                        ;
.entry_before_window:
    call fatfs_directory_load_prev_window      ;
    jr 1f                                      ;
.entry_after_window:
    call fatfs_directory_load_next_window      ;
1:  pop hl                                     ;
    pop de                                     ;
    ret nz                                     ;
    jr fatfs_get_entry                         ;


; IN  - DE - entry number
; OUT -  F - NZ when yes, Z when no
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - HL - garbage
fatfs_entry_is_directory:
    call fatfs_get_entry                       ;
    ret nz                                     ;
    ld bc, DIR_Attr                            ;
    add hl, bc                                 ;
    ld a, (hl)                                 ;
    and #10                                    ;
    ret                                        ;


; IN  - DE - entry number
; OUT -  F - Z on success, NZ on fail
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
fatfs_file_menu_generator:
    call fatfs_get_entry                       ;
    ret nz                                     ;
    ld de, tmp_menu_string+2                   ;
    ld ix, tmp_menu_string                     ;
.name:
    ld bc, 8                                   ; copy file name
    ldir                                       ; ...
.ext:
    push hl                                    ;
    ld a, ' '                                  ; dont print file extension if it doesn't contain printable symbols
    cpi : jr nz, 1f                            ; ...
    cpi : jr nz, 1f                            ; ...
    cpi : jr nz, 1f                            ; ...
    jr 2f                                      ; ...
1:  ld a, '.'                                  ;
2:  ld (de), a : inc de                        ; copy file extension
    ld bc, 3                                   ; ...
    pop hl : push hl                           ; ...
    ldir                                       ; ...
.check_is_directory:
    ld a, (hl)                                 ; check if entry is directory
    and #10                                    ; ...
    jr z, .filesize                            ; ...
    ld a, udg_folder                           ; set appropriate icon
    ld (ix+0), a                               ; ...
    pop hl                                     ;
    jr .no_icon                                ;
.filesize:
    ld a, ' ' : ld (de), a : inc de            ;
    ld a, '$' : ld (de), a : inc de            ;
    ld bc, DIR_FileSize-11+2                   ;
    add hl, bc                                 ;
    ld a, (hl) : inc hl : or (hl)              ; if (file_size > 0xffff) print "$$$$"
    jr z, 1f                                   ; ...
    ld a, '$' : ld (de), a : inc de            ; ...
    ld (de), a : inc de                        ; ...
    ld (de), a : inc de                        ; ...
    ld (de), a : inc de                        ; ...
    jr .icon                                   ; ...
1:  .2 dec hl                                  ;
    ld b, 2                                    ;
1:  ld a, (hl)                                 ; hi
    and #f0                                    ; ...
    .4 rra                                     ; ...
    add a, #90                                 ; ...
    daa                                        ; ...
    adc a, #40                                 ; ...
    daa                                        ; ...
    ld (de), a                                 ; ...
    inc de                                     ; ...
    ld a, (hl)                                 ; lo
    and #0f                                    ; ...
    add a, #90                                 ; ...
    daa                                        ; ...
    adc a, #40                                 ; ...
    daa                                        ; ...
    ld (de), a                                 ; ...
    inc de                                     ; ...
    dec hl                                     ;
    djnz 1b                                    ;
.icon:
    pop hl                                     ;
    call disks_get_icon_by_extension           ; A = icon
    ld (ix), a                                 ;
.no_icon:
1:  ld a, ' '                                  ; space
    ld (ix+1), a                               ;
.null:
    xor a                                      ; write NULL byte to the end of string
    ld (de), a                                 ; ...
    xor a                                      ; set Z flag
    ret                                        ;



; OUT -   F - Z on success, NZ on fail
; OUT -   A - garbage
; OUT -  BC - garbage
; OUT -  DE - garbage
; OUT -  HL - garbage
; OUT - IXL - garbage
; OUT - DE' - garbage
; OUT - HL' - garbage
fatfs_directory_load_next_window:
    exx                                             ;
    ld de, (var_fatfs.dir_window_files_cnt)         ; DE' = files_count_prev
    ld hl, (var_fatfs.dir_window_cluster_pos)       ; HL' = cluster_pos
    exx                                             ;
    ld bc, (var_fatfs.dir_window_cluster_n+0)       ;
    ld de, (var_fatfs.dir_window_cluster_n+2)       ;
    ld hl, (var_fatfs.dir_window_sector_pos)        ; L = sector_pos
    ld a, (var_disk.fatfs.BPB_SecPerClus)           ; if sector_pos is last sector in cluster - get next cluster
    dec a                                           ; ...
    cp l                                            ; ...
    jr z, .next_cluster                             ; ...
.next_sector:
    ld h, 0 : inc l                                 ; sector_pos++
    jr .read                                        ;
.next_cluster:
    exx                                             ; cluster_pos++
    inc hl                                          ; ...
    exx                                             ; ...
    call fatfs_get_next_cluster_n                   ; DEBC = next cluster_n
    ret nz                                          ; ...
    ld hl, 0                                        ; sector_pos = 0
.read:
    call fatfs_directory_load.read                  ;
    ret nz                                          ;
    exx                                             ;
    ld (var_fatfs.dir_window_cluster_pos), hl       ; save cluster_pos
    ld hl, (var_fatfs.dir_window_first_file_n)      ; first_file += files_count_prev
    add hl, de                                      ; ...
    ld (var_fatfs.dir_window_first_file_n), hl      ; ...
    exx                                             ;
    xor a                                           ; set Z flag
    ret                                             ;


; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IXL - garbage
; OUT - HL' - garbage
fatfs_directory_load_prev_window:
    exx                                             ;
    ld hl, (var_fatfs.dir_window_cluster_pos)       ;
    exx                                             ;
    ld hl, (var_fatfs.dir_window_cluster_pos)       ;
    ld a, (var_fatfs.dir_window_sector_pos)         ;
    or a                                            ; if current sector is first sector in cluster - get prev cluster
    jr z, .prev_cluster                             ; ...
.prev_sector:
    dec a                                           ; sector_pos--
    ld h, 0 : ld l, a                               ; ...
    ld bc, (var_fatfs.dir_window_cluster_n+0)       ;
    ld de, (var_fatfs.dir_window_cluster_n+2)       ;
    jr .read                                        ;
.prev_cluster:
    ld a, h : or l                                  ; already on first cluster in chain?
    jr nz, 1f                                       ; ...
    or 1                                            ; ... set NZ flag
    ret                                             ; ...
1:  exx                                             ; cluster_pos--
    dec hl                                          ; ...
    exx                                             ; ...
    dec hl                                          ; get prev cluster n
    ld bc, (var_fatfs.current_dir+0)                ; ...
    ld de, (var_fatfs.current_dir+2)                ; ...
    call fatfs_get_nth_cluster_n                    ; ...
    ret nz                                          ; ...
    ld hl, (var_disk.fatfs.BPB_SecPerClus)          ; sector_pos = last sector in cluster
    dec l                                           ;
    ld h, 0                                         ;
.read:
    call fatfs_directory_load.read                  ;
    ret nz                                          ;
    ld bc, (var_fatfs.dir_window_files_cnt)         ; first_file -= files_count
    ld hl, (var_fatfs.dir_window_first_file_n)      ; ...
    or a                                            ; ...
    sbc hl, bc                                      ; ...
    ld (var_fatfs.dir_window_first_file_n), hl      ; ...
    exx                                             ; save cluster_pos
    ld (var_fatfs.dir_window_cluster_pos), hl       ; ...
    exx                                             ; ...
    xor a                                           ; set Z flag
    ret                                             ;


; IN  - DE - entry number or 0xffff for root directory
; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IXL  - garbage
fatfs_directory_load:
    ld a, #ff                                       ;
    cp d : jr nz, .get_dir_info                     ;
    cp e : jr nz, .get_dir_info                     ;
    jr z, .root_dir                                 ;
.get_dir_info:
    call fatfs_get_entry                            ;
    ret nz                                          ;
    ld de, DIR_FstClusHI                            ;
    add hl, de                                      ;
    ld e, (hl) : inc hl : ld d, (hl)                ;
    ld bc, DIR_FstClusLO-DIR_FstClusHI-1            ;
    add hl, bc                                      ;
    ld c, (hl) : inc hl : ld b, (hl)                ;
    ld a, d : or e : or b : or c                    ; if cluster_n == 0 - root directory
    jr nz, .chdir                                   ; ...
.root_dir:
    ld bc, (var_disk.fatfs.BPB_RootClus+0)          ;
    ld de, (var_disk.fatfs.BPB_RootClus+2)          ;
.chdir:
    ld (var_fatfs.current_dir+0), bc                ;
    ld (var_fatfs.current_dir+2), de                ;
    ld hl, 0                                        ;
    ld (var_fatfs.dir_window_first_file_n), hl      ;
    ld (var_fatfs.dir_window_cluster_pos), hl       ;
.read:
    push de                                         ;
    push bc                                         ;
    push hl                                         ;
    call fatfs_get_lba                              ;
    jr z, 1f                                        ;
    .3 pop hl                                       ;
    ret                                             ;
1:  ld hl, dir_buffer                               ;
    ld ixl, 1                                       ;
    call disk_read_sectors                          ;
    jr z, 1f                                        ;
    .3 pop hl                                       ;
    ret                                             ;
1:  pop hl                                          ;
    ld a, l                                         ;
    ld (var_fatfs.dir_window_sector_pos), a         ;
    pop hl                                          ;
    ld (var_fatfs.dir_window_cluster_n+0), hl       ;
    pop hl                                          ;
    ld (var_fatfs.dir_window_cluster_n+2), hl       ;
    ; jp fatfs_directory_parse                       ;


; OUT -  F - Z=1
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
fatfs_directory_parse:
    ld hl, 0                                   ;
    ld (var_fatfs.dir_window_files_cnt), hl    ;
    ld ix, dir_buffer                          ; src
    ld de, dir_buffer                          ; dst
.loop:
    ld a, (ix+DIR_Name+0)                      ;
    or a                                       ; last entry?
    ret z                                      ; ...
    push ix                                    ;
    cp #e5                                     ; deleted entry?
    jr z, .next                                ; ...
    cp '.'                                     ; skip directory with name '.'
    jr nz, 1f                                  ; ...
    ld a, (ix+DIR_Name+1)                      ; ...
    cp ' '                                     ; ...
    jr nz, 1f                                  ; ...
    ld a, (ix+DIR_Attr)                        ; ...
    and #10                                    ; ...
    jr nz, .next                               ; ...
1:  ld a, (ix+DIR_Attr)                        ; skip hidden, system and volume files
    and #0e                                    ; ...
    jr nz, .next                               ; ...
    pop hl                                     ;
    push hl                                    ;
    ld bc, 32                                  ; save this entry
    ldir                                       ; ...
    ld hl, (var_fatfs.dir_window_files_cnt)    ; cnt++
    inc hl                                     ; ...
    ld (var_fatfs.dir_window_files_cnt), hl    ; ...
.next:
    xor a                                      ; set Z flag
    pop hl                                     ; check ix+32 >= dir_buffer+512 (sector size)
    ld bc, #ffff-disk_sector_size-dir_buffer+32+1 ; ...
    add hl, bc                                 ; ...
    ret c                                      ; ...
    ld bc, 32                                  ;
    add ix, bc                                 ;
    jr .loop                                   ;


; IN  - DE - entry number
; OUT -  F - Z on success, NZ on fail
; OUT -  A - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
fatfs_file_load:
    call fatfs_get_entry                       ;
    ret nz                                     ;
    ld (var_current_file_number), de           ;
.load_file_params:
1:  ld de, var_current_file_name               ; copy file name
    ld bc, 8                                   ; ...
    ldir                                       ; ...
    ld a, '.' : ld (de), a : inc de            ; ... '.'
    ld bc, 3                                   ; ... extension
    ldir                                       ; ...
    ld bc, DIR_FileSize-11                     ; file size in bytes
    add hl, bc                                 ; ...
    ld c, (hl) : inc hl : ld b, (hl)           ; ...
    ld a, b                                    ; ... exit if file_size == 0
    or c                                       ; ...
    jr nz, 1f                                  ; ...
    or 1                                       ; ...
    ret                                        ; ...
1:  ld (var_current_file_size), bc             ; ...
    inc hl                                     ; ... only files <= 64K are supported for now
    ld c, (hl) : inc hl : ld a, (hl)           ; ...
    or c                                       ; ...
    ret nz                                     ; ...
    ld de, -DIR_FileSize+DIR_FstClusHI-3       ; DEBC = cluster_n
    add hl, de                                 ; ...
    ld e, (hl) : inc hl : ld d, (hl)           ; ...
    ld bc, DIR_FstClusLO-DIR_FstClusHI-1       ; ...
    add hl, bc                                 ; ...
    ld c, (hl) : inc hl : ld b, (hl)           ; ...
    push de                                    ;
    push bc                                    ;
    ld hl, 0                                   ; DEBC = lba
    call fatfs_get_lba                         ; ...
    jp nz, .err_pop2                           ; ...
    ld hl, 0                                   ; HL = file_position
    ld a, (var_disk.fatfs.BPB_SecPerClus)      ; IXH = remain_sectors_in_cluster = BPB_SecPerClus
    ld ixh, a                                  ; ...
.loop:
.calc_read_portion:
    ld a, h                                    ; A = page_free_sectors
    and high file_page_size - 1                ; ...
    assert disk_sector_size == 512
    srl a                                      ; ...
    sub file_page_size/disk_sector_size        ; ...
    neg                                        ; ...
    cp ixh                                     ; IXL = read_portion = MIN( remain_sectors_in_cluster, page_free_sectors )
    jr c, 1f                                   ; ...
    ld a, ixh                                  ; ...
1:  ld ixl, a                                  ; ...
.switch_page_if_required:
    ld a, h                                    ; A = page_hi_offset
    and high file_page_size - 1                ; ...
    or a                                       ; if (page_hi_offset == 0) file_switch_page()
    jr nz, .read_from_disk                     ; ...
    push af : push bc                          ; ...
    call file_switch_page                      ; ...
    dec hl                                     ; ...
    pop bc : pop af                            ; ...
.read_from_disk:
    push bc : push de : push hl : push ix      ;
    add high file_base_addr                    ; HL = page_ptr = (page_hi_offset << 8) + PAGE_ADDR
    ld h, a                                    ; ...
    call disk_read_sectors                     ;
    pop ix : pop hl : pop de : pop bc          ;
    jp nz, .err_pop2                           ;
.calc_file_position:
    ld a, ixl                                  ; file_position += read_portion * sector_size (512)
    add a, a                                   ; ...
    add a, h                                   ; ...
    jp c, .exit_pop2                           ; ... overflow?
    ld h, a                                    ; ...
    push de                                    ; check file_position >= file_size
    ex hl, de                                  ; ...
    ld hl, (var_current_file_size)             ; ...
    or a                                       ; ...
    sbc hl, de                                 ; ...
    ex hl, de                                  ; ...
    pop de                                     ; ...
    jp z, .exit_pop2                           ; ...
    jp c, .exit_pop2                           ; ...
.calc_remain_sectors_in_cluster
    ld a, ixh                                  ; IXH -= read_portion
    sub ixl                                    ; ...
    jr z, .remain_sectors_in_cluster_is_zero   ; ...
    ld ixh, a                                  ; ...
.remain_sectors_in_cluster_not_zero:
        ld a, ixl : add c : ld c, a            ; lba += read_portion
        ld a, b : adc 0 : ld b, a              ; ...
        ld a, e : adc 0 : ld e, a              ; ...
        ld a, d : adc 0 : ld d, a              ; ...
        jp .loop                               ;
.remain_sectors_in_cluster_is_zero:
        ld a, (var_disk.fatfs.BPB_SecPerClus)  ; remain_sectors_in_cluster = BPB_SecPerClus
        ld ixh, a                              ; ...
        pop bc                                 ;
        pop de                                 ;
        push hl : push ix                      ;
        call fatfs_get_next_cluster_n          ; DEBC = next cluster_n
        pop ix : pop hl                        ;
        ret nz                                 ; ...
        push de                                ;
        push bc                                ;
        push hl                                ;
        ld hl, 0                               ;
        call fatfs_get_lba                     ; lba = next lba
        pop hl                                 ;
        jp .loop                               ;
.err_pop2:
    .2 pop hl                                  ;
    or 1                                       ; set NZ flag
    ret                                        ;
.exit_pop2:
    .2 pop hl                                  ;
    xor a                                      ; set Z flag
    ret                                        ;


/*
uint16_t PAGE_SIZE = 16384;
uint16_t PAGE_ADDR = 0xC000;
uint8_t  PAGE_SECTORS = PAGE_SIZE/SECTOR_SIZE;
uint16_t SECTOR_SIZE = 512;
uint8_t  SECTORS_PER_CLUSTER = X;
uint16_t FILE_SIZE = X;

uint8_t  remain_sectors_in_cluster = SECTORS_PER_CLUSTER;
uint16_t file_position = 0;
uint32_t cluster_n = get_first_cluster_n();
uint32_t lba = fatfs_get_lba( cluster_n );

while( 1 ) {
    uint8_t page_hi_offset = (file_position >> 8) & ((PAGE_SIZE-1) >> 8);
    uint8_t page_free_sectors = PAGE_SECTORS - page_hi_offset / (SECTOR_SIZE>>8);
    uint8_t read_portion = MIN( page_free_sectors, remain_sectors_in_cluster );
    if( page_hi_offset == 0 ) {
        page_select( file_position );
    }
    uint8_t page_ptr = (page_hi_offset << 8) + PAGE_ADDR;
    disk_read_sectors( lba, page_ptr, read_portion );

    file_position += read_portion * SECTOR_SIZE;
    if( file_position >= FILE_SIZE )
        break;

    remain_sectors_in_cluster -= read_portion;
    if( remain_sectors_in_cluster ) {
        lba += read_portion;
    }
    else {
        remain_sectors_in_cluster = SECTORS_PER_CLUSTER;
        cluster_n = fatfs_get_next_cluster_n();
        lba = fatfs_get_lba( cluster_n );
    }
}
*/
