CPU_FREQ_3_5_MHZ  equ 0
CPU_FREQ_3_54_MHZ equ 1
CPU_FREQ_7_MHZ    equ 2
CPU_FREQ_14_MHZ   equ 3
CPU_FREQ_28_MHZ   equ 4
var_cpu_freq BYTE CPU_FREQ_3_5_MHZ

INT_50_HZ   equ 0
INT_48_8_HZ equ 1
var_int_type BYTE INT_50_HZ

INPUT_KEY_NONE  equ 0
INPUT_KEY_RIGHT equ 1
INPUT_KEY_LEFT  equ 2
INPUT_KEY_DOWN  equ 4
INPUT_KEY_UP    equ 8
INPUT_KEY_ACT   equ 16
INPUT_KEY_BACK  equ 32
var_input_key BYTE INPUT_KEY_NONE
var_input_key_last: BYTE INPUT_KEY_NONE
var_input_key_hold_timer: BYTE 0

var_int_counter WORD 0
var_smf_file smf_file_t
var_tmp32 BLOCK 32
