; these variables are placed in slow ram

disk_buffer_size equ 8*256
disk_buffer: block disk_buffer_size+1, 0
uart_txbuf: block 128, 0
uart_txbuf_len: byte 0
tmp_menu_string: block 33, 0
