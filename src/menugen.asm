    STRUCT menugen_t
elements      DB
    ENDS

    STRUCT menugen_entry_t
name          DW
value_cb      DW
cb            DW
ctx           DW
    ENDS


; IN  - IY - *menu_t
; OUT - DE - entries count
menugen_count:
    ld h, (iy+menu_t.context+1)           ;
    ld l, (iy+menu_t.context+0)           ;
    ld e, (hl)                            ;
    ld d, 0                               ;
    ret                                   ;


; IN  - DE - entry number
; IN  - IY - *menu_t
; OUT -  F - NZ when ok, Z when not ok
; OUT - IX - pointer to 0-terminated string
; OUT -  A - garbage
; OUT -  B - garbage
; OUT - DE - garbage
; OUT - HL - garbage
menugen_generator:
    xor a                                 ; if (entry_number > 255) - return not ok
    or d                                  ; ...
    jr nz, .no_entry                      ; ...
    ld h, (iy+menu_t.context+1)           ;
    ld l, (iy+menu_t.context+0)           ;
    ld a, (hl)                            ; if (entry_number >= elements) - return not ok
    cp e                                  ; ...
    jr c, .no_entry                       ; ...
    jr z, .no_entry                       ; ...
    assert menugen_entry_t == 8           ;
    sla e : rl d                          ;
    sla e : rl d                          ;
    sla e : rl d                          ;
    add hl, de                            ;
    ld de, menugen_t                      ;
    add hl, de                            ;
.name:
    ld a, (hl) : ld ixl, a : inc hl       ;
    ld a, (hl) : ld ixh, a : inc hl       ;
.value:
    ld e, (hl) : inc hl : ld d, (hl)      ; DE = value_cb
    ld a, e : or d : jr z, .done          ;
    push de                               ;
    ld de, tmp_menu_string                ;
    ld b, (iy+menu_t.columns)             ;
.save_tmp_string1:
    ld a, (ix)                            ; strcpy(tmp_menu_string, ix)
    or a                                  ; ...
    jr z, .fill_tail_with_spaces          ; ...
    ld (de), a                            ; ...
    inc ix                                ; ...
    inc de                                ; ...
    dec b                                 ; ...
    jr nz, .save_tmp_string1              ; ...
.fill_tail_with_spaces:
    xor a                                 ; fill tail with ' '
    or b                                  ; ...
    jr z, .get_value                      ; ...
    ld a, ' '                             ; ...
1:  ld (de), a                            ; ...
    inc de                                ; ...
    djnz 1b                               ; ...
.get_value:
    .3 inc hl                             ; DE = ctx
    ld e, (hl) : inc hl : ld d, (hl)      ; ...
    pop hl                                ;
    call .jp_hl                           ; IX = &string[last byte]
    ld a, (iy+menu_t.columns)             ;
    ld de, tmp_menu_string                ;
    add a, e                              ;
    ld e, a                               ;
    jr nc, .save_tmp_string2              ;
    inc d                                 ;
.save_tmp_string2:
    dec de                                ; strcpy(tmp_menu_string, ix)
    ld a, (ix)                            ; ...
    or a                                  ; ...
    jr z, 1f                              ; ...
    ld (de), a                            ; ...
    dec ix                                ; ...
    jr .save_tmp_string2                  ; ...
1:  ld ix, tmp_menu_string                ;
.done:
    or 1                                  ; set NZ flag
    ret                                   ;
.no_entry:
    xor a                                 ; set Z flag
    ret                                   ;
.jp_hl:
    jp (hl)                               ;


; IN  - DE - entry number
; IN  - IY - *menu_t
menugen_callback:
    xor a                                 ; if (entry_number > 255) - return not ok
    or d                                  ; ...
    ret nz                                ; ...
    ld h, (iy+menu_t.context+1)           ;
    ld l, (iy+menu_t.context+0)           ;
    ld a, (hl)                            ; if (entry_number >= elements) - return not ok
    cp e                                  ; ...
    ret c                                 ; ...
    ret z                                 ; ...
    assert menugen_entry_t == 8           ;
    sla e : rl d                          ;
    sla e : rl d                          ;
    sla e : rl d                          ;
    add hl, de                            ;
    ld de, menugen_t + menugen_entry_t.cb ;
    add hl, de                            ;
    ld e, (hl) : inc hl                   ; place cb to stack
    ld d, (hl) : inc hl                   ; ...
    push de                               ; ...
    ld e, (hl) : inc hl                   ; DE = ctx
    ld d, (hl)                            ; ...
    ret                                   ;


; IN  - IY - *menu_t
; IN  - HL - pointer to menu_entry_t.ctx+1 (as it in menugen_callback() before ret)
menugen_callback_redraw_value:
    ld d, (hl) : dec hl : ld e, (hl)      ; DE = ctx
    .3 dec hl                             ;
    ld a, (hl) : dec hl : ld l, (hl)      ; DE = value_cb
    ld h, a                               ;
    call .jp_hl                           ;
    ld l, (iy+menu_t.x_left)              ; HL = YX
    ld a, (iy+menu_t.columns)             ; ...
    dec a                                 ; ...
    add a, l                              ; ...
    ld l, a                               ; ...
    ld h, (iy+menu_t._cursor_line)        ; ...
    ld a, (iy+menu_t.y_top)               ; ...
    add a, h                              ; ...
    ld h, a                               ; ...
    jp print_string0_rev_at               ;
.jp_hl:
    jp (hl)                               ;
