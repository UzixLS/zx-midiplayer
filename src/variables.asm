CPU_FREQ_3_5_MHZ  = 0
CPU_FREQ_3_54_MHZ = 1
CPU_FREQ_7_MHZ    = 2
CPU_FREQ_14_MHZ   = 3
var_cpu_freq BYTE CPU_FREQ_3_5_MHZ

INT_50_HZ   = 0
INT_48_8_HZ = 1
var_int_type BYTE INT_50_HZ

var_int_counter WORD 0
var_smf_file smf_file_t
var_tmp32 BLOCK 32
