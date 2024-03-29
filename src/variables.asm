var_device device_t

INPUT_KEY_NONE  equ 0
INPUT_KEY_RIGHT equ 1
INPUT_KEY_LEFT  equ 2
INPUT_KEY_DOWN  equ 4
INPUT_KEY_UP    equ 8
INPUT_KEY_ACT   equ 16
INPUT_KEY_BACK  equ 32
var_input_key BYTE INPUT_KEY_NONE
var_input_key_last BYTE INPUT_KEY_NONE
var_input_key_hold_timer BYTE 0
var_input_no_beep BYTE 0

var_basic_iy WORD 0
var_int_counter BYTE 0

var_current_screen WORD 0
var_current_menu DB 0
var_current_menu_ptr WORD main_menu

var_player_state player_state_t

PLAYLIST_NEXT equ 1
PLAYLIST_PREV equ 2
var_playlist_flag BYTE 0

var_smf_file smf_file_t

var_vis_state vis_state_t

var_trdos_present DB 0
var_trdos_error DB 0
var_trdos_cleared_screen DB 0

var_disks disks_t
var_disk disk_t
var_fatfs fatfs_state_t
var_current_file_number DW 0
var_current_file_size DW 0
var_current_file_name BLOCK 13, 0

var_settings settings_t
var_settings_sector DW 0
