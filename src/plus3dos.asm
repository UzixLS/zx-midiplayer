;

    IFNDEF DOS_PLUS3
        ; bypass module compilation
        DEFINE __MODULE_DOS_PLUS3_ASM__
    ENDIF;!DOS_PLUS3

    IFNDEF __MODULE_DOS_PLUS3_ASM__
    DEFINE __MODULE_DOS_PLUS3_ASM__

    IFDEF DOS_TRDOS
    DEFINE __MODULE_DOS_PLUS3_RELOCATE__ 0x7000
    ENDIF;DOS_TRDOS

    MODULE PLUS3

    IFDEF __MODULE_DOS_PLUS3_RELOCATE__
        LUA allpass
            sj.insert_define("__MODULE_DOS_PLUS3_OLDORG__", sj.current_address)
        ENDLUA
        DISPLAY "PLUS3: relocated to ",__MODULE_DOS_PLUS3_RELOCATE__,"(was ",__MODULE_DOS_PLUS3_OLDORG__,")"
        ORG __MODULE_DOS_PLUS3_RELOCATE__
    ENDIF;__MODULE_DOS_PLUS3_RELOCATE__

    IFNDEF PLUS3_STARMID_PATTERN
        DEFINE PLUS3_STARMID_PATTERN "*.mid"
    ENDIF ;PLUS3_STARMID_PATTERN

__MODULE_DOS_PLUS3__BEGIN__ equ $

; https://worldofspectrum.org/ZXSpectrum128+3Manual/chapter8pt25.html
; +3 detection. If 23417 and 23418 contain an ASCII char (A-P or T)

; https://worldofspectrum.org/zxplus3e/commands.html
; "only two partitions can be mapped at any one time"

    ; hacky: we rely on 'plus3api' being the very first code to be compiled
    ; in PLUS3API module:
p3api:
        ld iy, (var_basic_iy)  ; restore IY
        ; execution continues to PLUS3API.plus3api
    INCLUDE "plus3-api.asm"

    MACRO PLUS3CALL api
        call PLUS3.p3api
        dw api
    ENDM

    DEFINE _SMC_W_ 0xdead
    DEFINE _SMC_B_ 0x5A

FILENO  equ 0x07    ; arbitrary number used as file descriptor
; we don't keep file open, so the actual number is irrelevant

; max dir entries can be - 512 (for +3e) -> 6656 bytes
_p3_dir_entry_size  equ (8+3+2)
dir_window_start    dw 0    ; offset of the current catalogue window
dir_window_size     equ 128 ; max number of catalogue entries to load
dir_window_eow      db 0    ; have we reached the end of the catalogue?
dir_stack_ptr       dw disk_buffer
; we keep a stack of "preloaded" catalogue entries, starting with "zeroised"
; one that theoretically allows us to jump back to any previous window, also:
; 1) unless "window" size is smaller than the number of entries in the right
;    menu (20) UI always goes to the previous one
; 2) +3 API does not allow jumping to an arbitrary "upcoming" window, it only
;    capable of loading the next one (following the last entry we have)
; however, we mitigate any of those by always navigating to the "next"/"previous"
; window in _p3_get_dir_entry.
; Anyway, with disk_buffer of 2048 bytes it has 157 directory entries,
; 128 entries per "window" leaves approx. 29 stack slots, thus the theoretical
; maximum catalogue size we can handle is 28*128 = 3584 entries
; The maximum practical catalogue size we observed so far was 512 entries
; See Part 27 Guide to +3DOS for further details
;
; window 0      window 1        window 2
; --------      --------        --------
; Entry 0 <DS   Entry 0         Entry 0
; Entry 1       Entry N <DS     Entry N
;  ...          Entry N+1       Entry Nx2 <DS
; Entry N        ...            Entry Nx2+1
;               Entry Nx2       ...
;                               Entry Nx3

    ; DE - directory entry number
_p3_get_dir_entry:
        ; you normally want to calulate the window index and load it directly
        ; but we rely on the fact that navigation UI is sequential:
        ; moving cursor above the topmost entry switches to the previous window
        ; and moving cursor below the bottom entry switches to the next next one
        ld (.save_de), de
        ld hl, (dir_window_start)
        ex hl, de
        or a    ; CF=0
        sbc hl, de
        jr c, .previous
        push hl ; if it's below dir_window_size, it's our offset
        ld de, dir_window_size
        or a    ; CF=0
        sbc hl, de
        pop hl
        jr nc, .next
        ; 0 <= (HL-dir_window_start) < dir_window_size
        ex hl, de
        jr _p3_dir_entry_ptr
.previous: ; we can optimise this one because we can jump directly to any window "below" the current one
        ; however, as long as the visible number of file names in the UI is larger than
        ; the page size, it's useless, UI will always go +/- 1
        ; for now just move dir_window_offset down 1 entry and load dir again
        ld hl, (dir_stack_ptr)
        ld de, _p3_dir_entry_size
        or a    ; CF=0
        sbc hl, de
        ld (dir_stack_ptr), hl
        ; adjust dir_window_start
        ld hl, (dir_window_start)
        ld de, dir_window_size
        or a    ; CF=0
        sbc hl, de
        ld (dir_window_start), hl
        ; TODO: load
        jr .load_new_window
        ;ret
.next:  ; there is no choice here, we need to load all chunks starting from the current window
        ; copy the last entry to the first
        ; move dir_stack_ptr to the newly added entry
        ld a, (dir_window_eow)
        or a
        ret nz  ; we've reached the end of the catalogue records, use offset in HL as is, it points to NULL terminator
        ld hl, (dir_stack_ptr)
        ld de, _p3_dir_entry_size
        add hl, de  ; next entry, first in the current window
        ld (dir_stack_ptr), hl  ; save new ptr
        ld de, (dir_window_size - 1) * _p3_dir_entry_size
        add hl, de
        ld de, (dir_stack_ptr)
        ld bc, _p3_dir_entry_size
        ldir
        ; adjust dir_window_start
        ld hl, (dir_window_start)
        ld de, dir_window_size
        add hl, de
        ld (dir_window_start), hl
.load_new_window:
        call disk_directory_load
.save_de equ $ + 1
        ld de, _SMC_W_  ; make sure to restore original entry number
        jr _p3_get_dir_entry
        ;ret

;     ; DE - directory entry number
; _p3_dir_entry_offset:   ; DE - directory entry number; OUT: HL - entry offset
;     ; this is essentialy "multiply by 13"
;         ; calculate offset, 8+3+2=13 bytes per record
;         ld h, d
;         ld l, e
;         add hl, hl  ; x2
;         add hl, hl  ; x4
;         push hl
;         add hl, hl  ; x8
;         add hl, de  ; x8+1
;         pop de
;         add hl, de  ; x8+1+x4 = 13
;         ret ; HL = DE x 13

_p3_dir_entry_ptr:
;_p3_dir_entry_name: ; fetch filename into internal buffer
        ; calculate offset, 8+3+2=13 bytes per record
        ld h, d
        ld l, e
        add hl, hl  ; x2
        add hl, hl  ; x4
        push hl
        add hl, hl  ; x8
        add hl, de  ; x8+1
        pop de
        add hl, de  ; x8+1+x4 = 13
        ; now add offset (from HL) to the buffer base ptr
        ld de, (dir_stack_ptr)
        add hl, de
; Entry 0 must be preloaded with the first 'filename.type'
; required. Entry 1 will contain the first matching filename greater
; than the preloaded entry (if any).
; Thus, first entry is the "last to match", i.e. NULL or the last one from the previous fragment
        ld de, _p3_dir_entry_size
        add hl, de
        ; TODO: check for NULL and set/reset CF here?
        ret

    ; extract filename from directory entry for OPEN call
_p3_filename:   ; HL - dir entry
        ld de, _p3_name_buf
        ld bc, 8
        ldir
        ld a, '.'
        ld (de), a
        inc de
        ld c, 3
        ldir
        ; ld a, 0xff  ; not really necessary because we always have 8+3
        ; ld (de), a
        ret

_p3_name_buf:
        defs 8+1+3
        defb 0xff

    ; DE - directory entry number ; A, BC, HL - NOT preserved
    ; see trdos_entry_is_directory
disk_entry_is_directory:    ; ZF=0 - not a directory, A=0
    xor a   ; +3(e) has flat directory structure, no sub-dirs
    ret

    ; DE - directory entry number ; A, BC, DE, HL - NOT preserved
disk_file_load: ; ZF=1 - success, ZF=0 - error
        ld a, d
        ld (var_current_file_number+1), a
        ld a, e
        ld (var_current_file_number+0), a
        ;call _p3_dir_entry_ptr
        call _p3_get_dir_entry
        ld a, (hl)
        or a
        jp z, .noentry      ; 0x00 -- last entry

        call _p3_filename
        ; HL points to the file size (in kilobytes)
        push hl
        ; copy file name to var_current_file_name
        ld hl, _p3_name_buf
        ld de, var_current_file_name
        ld bc, 8+1+3
        ldir
        pop hl
        ; guesstimate file size into DE
        ld a, (hl)
        .2 sla a
        or a      ; FIXME: hack for 63+k files (PLUS3DOS headers resolve that)
        jr nz, 1f
        dec a
1:
        ld d, a
        ld e, 0
        push de ; \DE/ this is expected file size rounded up to nearest Kb
        ld (var_current_file_size), de  ; is it actually used anywhere?

        ld b, FILENO
        ld c, 1 ; _MODE_RD
        ;ld de, 0x0002   ; Open the file, ignore any header. if exists
        ld de, 0x0001   ; Open the file, read the header (if any).
        ld hl, _p3_name_buf
        ; 0106  DOS_OPEN
        ; B - file number (0..15)
        ; C - Access mode: bits 1-rd,2-wr,3-rdwr,5-shared_rdwd
        ; D - Create action
        ; E - Open action
        ; HL - 0xFF terminated file name
        ; A, BC DE HL IX corrupt, all other registers preserved.
        PLUS3CALL DOS_OPEN  ; BC DE HL IX corrupt
        ; CF=1 -- success, A corrupt; CF=0 -- error, A - error code
        ; new file created:     CF=1 ZF=1
        ; existing file opened: CF=1 ZF=0
        pop de  ; /DE\ restore stack before conditional jump
        jr nc, .noentry

        ; now, if we're 128 bytes into the file, it has PLUS3DOS header
        ; and, therefore, has the exact byte length
        push de ; \DE/ save estimated file size
        ld b, FILENO
        ; B = File number
        PLUS3CALL DOS_GET_POSITION  ; BC D IX corrupt
        ; CF=1 - success; A corrupt, E HL = File pointer 000000h...FFFFFFh
        ; CF=0 - error; A = Error code, E HL corrupt
        pop de  ; /DE\ restore estimated file size
        jr nc, .close   ; something went wrong, should not really happen...
        rlc l   ; L could be only 0 or 128, shift it's leftmost bit to CF
        jr nc, .opened  ; CF=0, means bit 7 = 0, no header, no exact byte count
        push de ; \DE/ save estimated file size
        ld b, FILENO
        ; B = File number
        PLUS3CALL DOS_GET_EOF   ; BC D IX corrupt
        ; CF=1 - succes; A corrupt, E HL = File pointer 000000h...FFFFFFh
        ; CF=0 - error; A = Error code, E HL Corrupt
        pop de  ; /DE\ restore estimated file size
        jr nc, .opened  ; ignore any errors here TODO: wise?
        ld de, 128  ; PLUS3DOS header size
        xor a   ; clear CF (it was set after DOS_GET_EOF success)
        sbc hl, de
        ex hl, de   ; DE now has the actual size in bytes
        ld (var_current_file_size), de  ; is it actually used anywhere?

.opened:
        ; FIXME: we assume that file_page_size is at least 256-aligned
        ld hl, 0
.loop:
        ld (.save_hl), hl
        ; HL has to be the current file position
        call file_switch_page
        push de     ; \DE/ save file length
        ld a, high file_page_size
        cp d
        jr nc, .doread
        ld d, a     ; cap current chunk at file_page_size
.doread:
        call .file.read
        pop de      ; /DE\ restore file length/stack
        jr nc, .close   ; error? bail out
        push af ; save READ result
        ld a, d
        sub high file_page_size
        ld d, a
        jr c, .done ; we already have READ result on stack
        jr z, .done ; we already have READ result on stack
        pop af  ; discard read result from stack
.save_hl equ $ + 1
        ld hl, _SMC_W_
        ld a, high file_page_size
        add a, h
        ld h, a
        jr .loop
.close:
        push af ; save READ result
.done:
        ld b, FILENO
        ; 0109  DOS_CLOSE
        ; B - File number (0..15)
        PLUS3CALL DOS_CLOSE ; BC DE HL IX corrupt
        ; CF=1 - success, A corrupt; CF=0 - error, A - error code
        ; since we have interrups mode 2, turn off motor right now
        PLUS3CALL DD_L_OFF_MOTOR
        pop af  ; ignore CLOSE and MOTOR return, check most recent READ result
        jr nc, .noentry
        xor a
        ret
.noentry:
        or 0xff
        ret
.file.read:
        ld hl, file_base_addr
        ld b, FILENO
        ld a, (bankm)
        and 0x07
        ld c, a     ; keep current page config
        ; B - File number (0..15)
        ; C - Page number for 0xC000..0xFFFF
        ; DE - Number of bytes to read, 0 means 64K
        ; HL - Buffer pointer
        PLUS3CALL DOS_READ  ; BC HL IX corrupt
        ; CF=1 - success, A,DE trashed ; CF=0 - error, A - error, DE - unread/remaining bytes
        ret c   ; we're read whatever we wanted, good
        ; hack for partial reads. did we read anything?
        cp 25   ; "End of file" error   ; CF=0 if equals
        jr z, .ok
        xor a   ; clear CF
        ret
.ok:
        ; ; just in case, was there anything?
        ; ld a, e
        ; or d
        ; ret z   ; ZF=1 CF=0, error
        scf     ; we've read something, assuming all went fine
        ret

    ; DE - directory entry or 0xffff (root); A, BC, DE, HL - NOT preserved
    ; see trdos_directory_load
disk_directory_load:    ; ZF=1 - success, ZF=0 - error
    ; +3 has flat structure, no subdirs, so we ignore DE
        ; initial stack ptr setup in _init
        ld de, (dir_stack_ptr)
        ld hl, _p3_star_mid ; filename filter
        ld b, dir_window_size+1 ; disk_buffer_size / (8+3+2)    ; max number of entries
        ld c, 0             ; skip system files
        ; B = n+1, size of buffer in entries, >=2
        ; C = Filter; bit 0 - include system files, bits 1..7 - reserved (0)
        ; DE = Address of buffer (first entry initialised)
        ; HL = Address of filename (wildcards permitted)
        PLUS3CALL DOS_CATALOG   ; C DE HL IX corrupt
        ; CF=1 - success, B = Number of completed entries in buffer, 0...n
        ;       (If B = n, there may be more to come).
        ; CF=0 - error, A = Error code, B corrupt
        push af
        push bc
        ; since we have interrups mode 2, turn off motor right now
        PLUS3CALL DD_L_OFF_MOTOR    ; AF BC DE HL IX corrupt
        pop bc
        pop af
        jr nc, .error
        ; good news: there are no invalid entries, no need to filter file names, too
        ; bad  news: there could be up to 512 entries (+3e, 16Mb partition)
        ; FIXME: what we read 0 entries?
        ld a, dir_window_size+1
        cp b    ; If B = n, there may be more to come
        jr nz, .end_of_directory
        xor a
        ld (dir_window_eow), a
        jr .mark_end
.end_of_directory:
        ld a, 0xff
        ld (dir_window_eow), a
.mark_end:
        ld e, b
        dec e
        ld d, 0
        call _p3_dir_entry_ptr
        xor a
        ld (hl), a  ; make sure there is NULL terminator after last record
        ret
.error:
        or 0xff
        ret

_p3_star_mid:
        defb PLUS3_STARMID_PATTERN, 0xff

    ; DE - directory entry number   ; A, BC, DE, HL - NOT preserved
    ; see trdos_file_menu_generator, much of the code copied
    ; IY MUST be preserved
disk_directory_menu_generator:  ; ZF=1 - success, ZF=0 - error; IX - stringz
        push iy ; silly workaround, update once plus3api is fixed
        call _p3_get_dir_entry
        pop iy
        ld a, (hl)
        or a
        jr z, .noentry      ; 0x00 -- last entry
        ; Bytes 0...7	- Filename (ASCII) left justified, space filled
        ld de, tmp_menu_string+2    ; ICON<SPACE> -> +2
        ld bc, 8
        ldir
        ; now we add delimiter
        ld a, '.'
        ld (de), a
        inc de
        ; Bytes 6...10	- Type (ASCII) left justified, space filled
    push hl ; \HL/ pointer to the file type
        ld c, 3
        ldir
        ; Bytes 11...12	- Size in kilobytes (binary) [allocated sectors/2]
.filesize:
    ld a, ' '                 ;
    ld (de), a                ;
    inc de                    ;
    ld a, '$'                 ;
    ld (de), a                ;
    inc de                    ;
    ;inc hl                    ;
    ld b, 2                   ;
    ; +3 DOS keeps file size in kilobytes
    ; the rest of the code assumes size in 256-sectors (TR-DOS)
    ; so, we use only low byte of the file size and multiply it by 4
1:  ld a, (hl)                ; hi
    .2 sla a                  ; +3 DOS correction
    and #f0                   ; ...
    .4 rra                    ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (de), a                ; ...
    inc de                    ; ...
    ld a, (hl)                ; lo
    .2 sla a                  ; +3 DOS correction
    and #0f                   ; ...
    add a, #90                ; ...
    daa                       ; ...
    adc a, #40                ; ...
    daa                       ; ...
    ld (de), a                ; ...
    inc de                    ; ...
    inc hl;dec hl                    ;
    djnz 1b                   ;
.null:
    xor a                     ; write NULL byte to the end of string
    ld (de), a                ; ...
.icon:
    pop hl  ; /HL\ pointer to the file type
    call disks_get_icon_by_extension ; A = icon
    ld ix, tmp_menu_string    ;
    ld (ix), a                ;
    ld a, ' '                 ; space
    ld (ix+1), a              ;
    xor a
    ret
.noentry:
        or 0xff
        ret

disk_enumerate_volumes:
        PLUS3CALL DOS_VERSION   ; AF BC HL IX corrupt
        ; D=Issue, E=Version (within issue)
; https://worldofspectrum.org/zxplus3e/technical.html
; To check for IDEDOS, execute the standard +3DOS call DOS_VERSION
; and test the sign flag. If IDEDOS is present, the sign flag will be set.
        jp    m, .enumerate_ide
        ; plain old +3 with two drives max
        ld a, 'A'
        call _disk_save_device_name_a
        ld a, 2
        ; 1       5B66h (23398)   FLAGS3  Various flags.
        ; Bit 4 is set if a disk interface is present. Bit 5 is set if drive B: is present.
        ld hl, 0x5b66
        bit 5, (hl)   ; FLAGS3
        jr z, .no_unit_2
        ld a, 'B'
        call _disk_save_device_name_a
.no_unit_2:
        ret
.enumerate_ide:
        ld l, 'A'
.loop:
        call disk_is_device_mapped
        ; A - device ID
        jr nc, .next    ; error, does it make sense to continue?
        jr z, .unmapped
        cp 4    ; RAMdisk -- ignore
        jr z, .next
        ; check if floppy unit 1 is present (bit 5 doesn't work!)
        cp 3    ; floppy unit 1
        jr nz, .save
        call disk_is_unit_1_present
        jr nc, .next
.save:
        call disk_save_device_name
.unmapped:
.next:
        inc l
        ld a, 'P'
        cp l
        jr nc, .loop
        ; NOTE: disk_init stores current volume in boot_n
        ; interrupts are off, no motor timeout
        PLUS3CALL DD_L_OFF_MOTOR    ; turn motor off, now
        ; cleanup var_disk FIXME: duplicated in disk_save_device_name, use sub-routine?
        ld hl, var_disk
        ld de, var_disk+1
        ld bc, disk_t
        xor a
        ld (hl), a
        ldir
        ret
disk_is_device_mapped:
        push hl
        push de
        ld bc, disk_buffer
        ; L=drive letter 'A' to 'P' (uppercase)
        ; BC=address of 18-byte buffer
        PLUS3CALL IDE_DOS_MAPPING   ; AF BC DE HL corrupt
        ; CF=1 - sucess;
        ;   ZF0 - mapped, A=device (unit 0, 1), floppy (2,3), RAM (4); BC=partition #; buffer - text descr
        ;   ZF=1 - NOT mapped
        ; CF=0 - error; A=error code
        pop de
        pop hl
        ret
disk_is_unit_1_present:
        push af
        push bc
        push de
        push hl
        ; no entry conditions
        PLUS3CALL DD_ASK_1  ; A BC DE HL IX corrupt
        ; CF=1 - unit 1 present
        ; CF=0 - NO unit 1
        pop hl
        pop de
        pop bc
        jr c, .present
        pop af
        or a    ; CF=0 - NO unit 1
        ret
.present:
        pop af
        scf     ; CF=1 - unit 1 present
        ret
disk_save_device_name:  ; L - device name (IX+0) - ordinal
        ld a, l
_disk_save_device_name_a:
        push hl
        push de
        push af
        assert disk_t == 16
        ; cleanup var_disk, fill in relevant fields, call disks_save_new
        ld hl, var_disk
        ld de, var_disk+1
        ld bc, disk_t
        xor a
        ld (hl), a
        ldir
        ; fill in relevant details
        ld a, DISK_DRIVER_PLUS3
        ld (var_disk.driver), a
        pop af  ; A - device name, as L at entry
        ld hl, var_disk.label
        ld (hl), a
        ; we use disk_param for "target drive" when switching
        ; and keep label as UI element only
        ld hl, var_disk.disk_param
        ld (hl), a
        push ix
        call disks_save_new
        pop ix
        pop de
        pop hl
        ret

disk_device_change:    ; A - device name (A..P)
        push af
        call _p3_internal_init  ; cleanup all state/buffers
        pop af
        ; A = Drive, ASCII 'A'...'P' (FFh (255) = get default drive)
        PLUS3CALL DOS_SET_DRIVE ; BC DE HL IX corrupt
        ; CF=1 - success; A = Default drive
        ; CF=0 - error; A = Error code
        ret

_p3_internal_init:  ; re-set directory cache
        xor a
        ld (PLUS3.dir_window_eow), a
        ld hl, disk_buffer
        ld (PLUS3.dir_stack_ptr), hl
        ld de, disk_buffer+1
        ld bc, _p3_dir_entry_size-1
        ld (hl), a
        ldir    ; zero out the first directory cache entry
        ret

disk_init:
        ld a, (var_plus3dos_present)
        or a
        ret z
        call _p3_internal_init
        ld a, 0xff  ; FFh (255) = get default drive
        PLUS3CALL PLUS3.DOS_SET_DRIVE   ; BC DE HL IX corrupt
        jr nc, 1f
        ld (var_disks.boot_n), a
1:
        ; disable recoverable error reporting (interactive Retry,Abort,Cancel?)
        xor a   ; A=0, disable error messages
        ; A = Enable (0xff)/disable (0)
        ; HL = Address of ALERT routine (if enabled)
        PLUS3CALL DOS_SET_MESSAGE   ; AF BC DE IX corrupt
        ; HL = address of previous ALERT routine (0 if none)

        ; FIXME: duplicated in plus3-loader
        ld de, 0x1b04   ; cache at bufer 0x1b, size 0x04
        ld hl, 0x2000   ; RAMdisk at buffer 0x20, size 0x00 (OFF)
        ; D = First buffer for cache
        ; E = Number of cache sector buffers
        ; H = First buffer for RAMdisk
        ; L = Number of RAMdisk sector buffers
        ; (Note that E + L <= 128)
        PLUS3CALL DOS_SET_1345  ; BC DE HL IX corrupt
        ; CF=1 - success, A - corrupt
        ; CF=0 - error, A=error code
        ;DEBUG: PLUS3CALL DOS_GET_1345  ; AF BC IX corrupt
        ret

__MODULE_DOS_PLUS3_SIZE__   equ $-__MODULE_DOS_PLUS3__BEGIN__
        DISPLAY "PLUS3: @", __MODULE_DOS_PLUS3__BEGIN__, " size:",__MODULE_DOS_PLUS3_SIZE__

    IFDEF __MODULE_DOS_PLUS3_OLDORG__
        DISPLAY "PLUS3: relocate ends, back to ", __MODULE_DOS_PLUS3_OLDORG__
        ORG __MODULE_DOS_PLUS3_OLDORG__
        UNDEFINE __MODULE_DOS_PLUS3_OLDORG__
    ENDIF;__MODULE_DOS_PLUS3_OLDORG__

    UNDEFINE _SMC_B_
    UNDEFINE _SMC_W_

    ENDMODULE ; PLUS3

    ; it's DEFINE and not EQU because it's easier to check with IFDEF
    IFNDEF settings_block_size
        DEFINE settings_block_size 256
    ELSE
        ASSERT settings_block_size==256
    ENDIF;settings_block_size

plus3_init                  equ PLUS3.disk_init
plus3_scan_disks            equ PLUS3.disk_enumerate_volumes
plus3_entry_is_directory    equ PLUS3.disk_entry_is_directory
plus3_file_load             equ PLUS3.disk_file_load
plus3_directory_load        equ PLUS3.disk_directory_load
plus3_file_menu_generator   equ PLUS3.disk_directory_menu_generator

    ENDIF ;__MODULE_DOS_PLUS3_ASM__

; EOF vim: et:ai:ts=4:sw=4:
