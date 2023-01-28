; these variables are placed in slow ram

file_buffer_size equ 8*256
file_buffer: block file_buffer_size, 0
file_menu_string: block 32, 0
