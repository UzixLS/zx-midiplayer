    STRUCT menu_t
generator_fun   WORD ; IN - DE - entry number ; OUT -  F - Z on success, NZ on fail ; OUT - IX - pointer to 0-terminated string
count_fun       WORD ; OUT - DE - total entries count
callback_fun    WORD ; IN - DE - entry number
context         WORD
y_top           BYTE
x_left          BYTE
lines           BYTE
columns         BYTE
_lines_used     BYTE
_cursor_line    BYTE
_top_entry_n    WORD
_bg_attr        BYTE
_cursor_attr    BYTE
    ENDS


; IN  - IY - *menu_t
; OUT - AF - garbage
menu_init:
    xor a                               ;
    ld (iy+menu_t._top_entry_n+0), a    ;
    ld (iy+menu_t._top_entry_n+1), a    ;
    ld (iy+menu_t._cursor_line), a      ;
    ld a, LAYOUT_MENU_BG_ATTR           ;
    ld (iy+menu_t._bg_attr), a          ;
    ld a, LAYOUT_CURSOR_ATTR            ;
    ld (iy+menu_t._cursor_attr), a      ;
    ret                                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_erase_cursor:
    ld a, (iy+menu_t.y_top)             ;
    add a, (iy+menu_t._cursor_line)     ;
    ld h, a                             ;
    ld a, (iy+menu_t._bg_attr)          ;
    jp menu_draw_cursor.common          ;

; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_draw_cursor:
    ld a, (iy+menu_t.y_top)             ;
    add a, (iy+menu_t._cursor_line)     ;
    ld h, a                             ;
    ld a, (iy+menu_t._cursor_attr)      ;
.common:
    ld l, (iy+menu_t.x_left)            ;
    ld b, (iy+menu_t.columns)           ;
    ld c, 1                             ;
    jp fill_attr_at                     ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_draw_attr:
    ld b, (iy+menu_t.columns)           ;
    ld c, (iy+menu_t.lines)             ;
    ld h, (iy+menu_t.y_top)             ;
    ld l, (iy+menu_t.x_left)            ;
    ld a, (iy+menu_t._bg_attr)          ;
    jp fill_attr_at                     ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_draw:
    call menu_draw_attr                 ; prepare target area
    ld b, (iy+menu_t.lines)             ; ...
    ld c, (iy+menu_t.columns)           ; ...
    ld h, (iy+menu_t.y_top)             ; ...
    ld l, (iy+menu_t.x_left)            ; ...
    call clear_screen_area_at           ; ...
    ld b, (iy+menu_t.lines)             ; B = how much lines left
    ld c, (iy+menu_t.y_top)             ; C = line y to print at
    ld e, (iy+menu_t._top_entry_n+0)    ; DE = top_entry_n
    ld d, (iy+menu_t._top_entry_n+1)    ; ...
    xor a                               ; lines_used = 0
    ld (iy+menu_t._lines_used), a       ; ...
.loop:
    push de                             ;
    push bc                             ;
    call menu_call_generator            ; IX = string_pointer
    pop bc                              ;
    jr nz, .exit2                       ;
    ld h, c                             ; print IX
    ld l, (iy+menu_t.x_left)            ; ...
    push bc                             ;
    call print_string0_at               ; ...
    pop bc                              ;
    pop de                              ;
    inc de                              ;
    inc c                               ; y++
    inc (iy+menu_t._lines_used)         ; lines_used++
    djnz .loop                          ; lines_left--
.exit:
    jp menu_draw_cursor                 ;
.exit2:
    pop de                              ;
    jp menu_draw_cursor                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_style_active:
    ld a, LAYOUT_MENU_BG_ATTR           ;
    ld (iy+menu_t._bg_attr), a          ;
    call menu_draw_attr                 ;
    ld a, LAYOUT_CURSOR_ATTR            ;
    ld (iy+menu_t._cursor_attr), a      ;
    jp menu_draw_cursor                 ;

; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_style_inactive:
    ld a, LAYOUT_MENU_BG_INACTIVE_ATTR  ;
    ld (iy+menu_t._bg_attr), a          ;
    call menu_draw_attr                 ;
    ld a, LAYOUT_CURSOR_INACTIVE_ATTR   ;
    ld (iy+menu_t._cursor_attr), a      ;
    jp menu_draw_cursor                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_down:
    ld a, (iy+menu_t._lines_used)       ; exit if menu is empty
    or a                                ; ...
    ret z                               ; ...
    ld a, (iy+menu_t._cursor_line)      ; if cursor on last line - move viewport down
    inc a                               ; ...
    ld b, (iy+menu_t.lines)             ; ...
    cp b                                ; ...
    jr z, .get_next_entry               ; ...
    ld b, (iy+menu_t._lines_used)       ; else if there is not all lines are used - exit
    cp b                                ; ...
    ret z                               ; ...
    call menu_erase_cursor              ; else move cursor down
    inc (iy+menu_t._cursor_line)        ; ...
    jp menu_draw_cursor                 ; ...
.get_next_entry:
    ld e, (iy+menu_t._top_entry_n+0)    ; DE = next entry number
    ld d, (iy+menu_t._top_entry_n+1)    ; ...
    ld l, (iy+menu_t._cursor_line)      ; ...
    ld h, 0                             ; ...
    inc l                               ; ...
    add hl, de                          ; ...
    ex de, hl                           ; ...
    call menu_call_generator            ; IX = string_pointer
    ret nz                              ;
    inc (iy+menu_t._top_entry_n+0)      ; top_entry_n++
    jr nc, .scroll                      ; ...
    inc (iy+menu_t._top_entry_n+1)      ; ...
.scroll:
    push ix                             ;
    push iy                             ;
    ld l, (iy+menu_t.x_left)            ; L = x
    ld c, (iy+menu_t.columns)           ; C = width
    ld b, (iy+menu_t.lines)             ; B = lines count-1
    dec b                               ; ...
    ld d, (iy+menu_t.y_top)             ; D (dst) = y
    ld h, d                             ; H (src) = y + 1
    inc h                               ;
    call vertical_scroll_at             ;
    pop iy                              ;
    pop ix                              ;
    ld l, (iy+menu_t.x_left)            ;
    ld a, (iy+menu_t.y_top)             ;
    add (iy+menu_t._lines_used)         ;
    dec a                               ;
    ld h, a                             ;
    jp print_string0_at                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_up:
    ld a, (iy+menu_t._cursor_line)      ; if cursor on first line - move viewport up
    or a                                ; ...
    jr z, .get_prev_entry               ; ...
    call menu_erase_cursor              ; else move cursor up
    dec (iy+menu_t._cursor_line)        ; ...
    jp menu_draw_cursor                 ; ...
.get_prev_entry:
    ld e, (iy+menu_t._top_entry_n+0)    ; DE = prev entry number
    ld d, (iy+menu_t._top_entry_n+1)    ; ...
    ld a, d                             ;
    or e                                ;
    ret z                               ;
    dec de                              ;
    push de                             ;
    call menu_call_generator            ; IX = string_pointer
    pop de                              ;
    ret nz                              ;
    ld (iy+menu_t._top_entry_n+0), e    ; top_entry_n--
    ld (iy+menu_t._top_entry_n+1), d    ; ...
.scroll:
    ld a, (iy+menu_t.lines)             ; if not all lines are used currently - update counter
    cp (iy+menu_t._lines_used)          ; ...
    jp z, .scroll1                      ; ...
    inc (iy+menu_t._lines_used)         ; ...
.scroll1:
    push ix                             ;
    push iy                             ;
    ld l, (iy+menu_t.x_left)            ; L = x
    ld c, (iy+menu_t.columns)           ; C = width
    ld b, (iy+menu_t.lines)             ; B = lines count-1
    dec b                               ; ...
    ld h, (iy+menu_t.y_top)             ; H (src) = y
    ld d, h                             ; D (dst) = y + 1
    inc d                               ;
    call vertical_scroll_at             ;
    pop iy                              ;
    pop ix                              ;
    ld h, (iy+menu_t.y_top)             ;
    ld l, (iy+menu_t.x_left)            ;
    jp print_string0_at                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_pagedown:
    ld a, (iy+menu_t.lines)             ; if (lines_used < lines) - just move cursor to last line
    cp (iy+menu_t._lines_used)          ; ...
    jp nz, .move_cursor_to_last_line    ; ...
    ld l, (iy+menu_t._top_entry_n+0)    ; top_entry_n = top_entry_n+lines
    ld h, (iy+menu_t._top_entry_n+1)    ; ...
    ld e, a                             ; ...
    ld d, 0                             ; ...
    push hl                             ;
    add hl, de                          ; ...
    ld (iy+menu_t._top_entry_n+0), l    ; ...
    ld (iy+menu_t._top_entry_n+1), h    ; ...
    call menu_draw                      ;
    pop hl                              ;
    ld a, (iy+menu_t._lines_used)       ; if no more lines - restore back top_entry_n and move cursor to last line
    or a                                ; ...
    jr z, .restore                      ; ...
    dec a                               ; if cursor are bellow last line - move cursor to last line
    cp (iy+menu_t._cursor_line)         ; ...
    jr c, .move_cursor_to_last_line     ; ...
    ret                                 ;
.restore:
    ld (iy+menu_t._top_entry_n+0), l    ; ...
    ld (iy+menu_t._top_entry_n+1), h    ; ...
    call menu_draw                      ; ...
.move_cursor_to_last_line:
    call menu_erase_cursor              ;
    ld a, (iy+menu_t._lines_used)       ;
    sub 1                               ;
    jp nc, 1f                           ;
    xor a                               ;
1:  ld (iy+menu_t._cursor_line), a      ;
    jp menu_draw_cursor                 ;


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_pageup:
    ld l, (iy+menu_t._top_entry_n+0)    ;
    ld h, (iy+menu_t._top_entry_n+1)    ;
    ld a, h                             ; if (top_entry_n == 0) just move cursor to the first line
    or l                                ; ...
    jr z, .move_cursor_to_first_line    ; ...
    ld e, (iy+menu_t.lines)             ; top_entry_n = max(0, top_entry_n-lines)
    ld d, 0                             ; ...
    sbc hl, de                          ; ...
    jr nc, 1f                           ; ... if (hl < 0) hl = 0
    jr z, 1f                            ; ...
    ld hl, 0                            ; ...
1:  ld (iy+menu_t._top_entry_n+0), l    ; ...
    ld (iy+menu_t._top_entry_n+1), h    ; ...
    jp menu_draw                        ;
.move_cursor_to_first_line:
    call menu_erase_cursor              ; move cursor to the first line
    xor a                               ; ...
    ld (iy+menu_t._cursor_line), a      ; ...
    jp menu_draw_cursor                 ; ...


; IN  - IY - *menu_t
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
; OUT - IX - garbage
menu_handle_input:
    ld a, (var_input_key)               ; exit if no any key pressed
    or a                                ; ...
    ret z                               ; ...
    cp INPUT_KEY_DOWN                   ;
    jp z, menu_down                     ;
    cp INPUT_KEY_UP                     ;
    jp z, menu_up                       ;
    cp INPUT_KEY_RIGHT                  ;
    jp z, menu_pagedown                 ;
    cp INPUT_KEY_LEFT                   ;
    jp z, menu_pageup                   ;
    cp INPUT_KEY_ACT                    ;
    ret nz                              ;
    ld l, (iy+menu_t._top_entry_n+0)    ; run callback if act key pressed
    ld h, (iy+menu_t._top_entry_n+1)    ; ... DE = top_entry_n_number + cursor_line
    ld d, 0                             ; ...
    ld e, (iy+menu_t._cursor_line)      ; ...
    add hl, de                          ; ...
    ex de, hl                           ; ...
    ld l, (iy+menu_t.callback_fun+0)    ; ... HL = callback_address
    ld h, (iy+menu_t.callback_fun+1)    ; ...
    jp (hl)                             ; ...


; IN  - DE - entry number
; IN  - IY - *menu_t
; OUT -  F - Z on success, NZ on fail
; OUT - IX - pointer to 0-terminated string
; OUT - AF - garbage
; OUT - BC - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menu_call_generator:
    ld l, (iy+menu_t.generator_fun+0)
    ld h, (iy+menu_t.generator_fun+1)
    jp (hl)


menu_dummy_generator:
    xor a                                 ; set Z flag
menu_dummy_callback:
    ret                                   ;


; menu_debug_loop:
;     ld a, #1f
;     ld bc, #7ffd
;     out (c), a
;     ld a, #c0
;     call screen_select
;     ld iy, menu_debug
;     call menu_init
;     call menu_draw
; .loop:
;     ei : halt
;     call input_process
;     call menu_handle_input
;     jp .loop

; menu_debug: menu_t menu_debug_generator menu_debug_count menu_debug_callback 3 3 10 7
; menu_debug_entries EQU 15

; menu_debug_generator:
;     ld hl, menu_debug_entries
;     sbc hl, de
;     jr c, .no_more_entries
;     jr z, .no_more_entries
; .ok:
;     ld ix, .string
;     ld a, e
;     sla a
;     sla a
;     sla a
;     ld b, 0
;     ld c, a
;     add ix, bc
;     xor a
;     ret
; .no_more_entries:
;     or 1
;     ret
; .string:
;     db "test 00",0,"Test 01",0,"test 02",0,"Test 03",0,"test 04",0,"Test 05",0,"test 06",0,"Test 07",0,"test 08",0,"Test 09",0,"test 10",0,"Test 11",0,"test 12",0,"Test 13",0,"test 14",0
;     db "Test 15",0,"test 16",0,"Test 17",0,"test 18",0,"Test 19",0,"test 20",0,"Test 21",0,"test 22",0,"Test 23",0,"test 24",0,"Test 25",0,"test 26",0,"Test 27",0,"test 28",0,"Test 29",0
;     db "test 30",0,"Test 31",0

; menu_debug_count:
;     ld de, menu_debug_entries
;     ret

; menu_debug_callback:
;     ld hl, LAYOUT_DEBUG
;     call get_char_address
;     ld a, e
;     call print_hex
;     ret
