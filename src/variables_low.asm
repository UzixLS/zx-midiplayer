; these variables are placed in slow ram

file_buffer_size equ 8*256
file_buffer: block file_buffer_size+1, 0
uart_txbuf: block 128, 0
uart_txbuf_len: byte 0
tmp_menu_string: block 33, 0
