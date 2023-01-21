--[[
    Lua function providing "incbin" replacement with RLE compression
    for SjASMPlus (https://github.com/z00m128/sjasmplus)
    Author: Eugene Lozovoy
    Original idea and Z80 code: cngsoft (https://www.cpcwiki.eu/forum/programming/realtime-rle-decoding-and-encoding/)

    Z80 code:

    ; ENCODER: HL=^SOURCE,DE=^TARGET,IX=FULL_LENGTH; HL+=FULL_LENGTH,DE+=PAKD_LENGTH,IX=0,B=0,ACF!
    rle2pack_init ld b,0
    rle2pack_loop ld c,(hl)
    rle2pack_find ld a,xh
    or xl
    jr z,rle2pack_exit
    dec ix
    inc hl
    inc b
    jr z,rle2pack_over
    ld a,(hl)
    cp c
    jr z,rle2pack_find
    rle2pack_over call rle2pack_fill
    jr rle2pack_loop
    rle2pack_exit cp b
    call nz,rle2pack_fill
    ; generate the end marker from the last byte!
    dec hl
    ld a,(hl)
    inc hl
    cpl
    jr rle2pack_exit_
    rle2pack_fill dec b
    ld a,c
    jr z,rle2pack_fill_
    rle2pack_exit_ ld (de),a
    inc de
    ld (de),a
    inc de
    dec b
    ld a,b
    rle2pack_fill_ ld (de),a
    inc de
    ld b,0
    ret

    ; DECODER: HL=^SOURCE,DE=^TARGET; HL+=PAKD_LENGTH,DE+=FULL_LENGTH,B!,AF!
    rle2upak_init ld b,1
    ld a,(hl)
    inc hl
    cp (hl)
    jr nz,rle2upak_fill
    inc hl
    ld b,(hl)
    inc hl
    inc b
    ret z
    inc b
    rle2upak_fill ld (de),a
    inc de
    djnz $-2
    jr rle2upak_init

    The encoder is 49 bytes long and does almost 32 kB/s on average; the decoder fits in 19 bytes and runs twice as fast.
    Both support zero-length blocks thanks to the end marker, that also means that the decoder doesn't need to know the
    stream's length (packed or not) in advance.
    By turning all INC HL, DEC HL and INC DE into DEC HL, INC HL and DEC DE streams will be encoded and decoded in reverse.

    The format itself is as follows: single bytes are encoded as themselves, double bytes as themselves plus a $00,
    and strings of three or more identical bytes (up to 256) become the first two bytes plus the length minus 2;
    the end-of-stream marker is a couple of identical bytes plus a $FF, and avoids clashing with previous single bytes
    (i.e. XX, XX XX $FF won't be misread as XX XX XX, $FF).

    Best-case compression (all memory is made of strings of 256 identical bytes) is 3*length/256+3;
    worst-case compression (all memory is made of different couples of identical bytes, i.e. XX XX YY YY XX XX YY YY...) is 3*length/2+3.

    Parameters:
    1 file_name: name of file to open
    2 offset: positive value (optional)
    3 length: positive value (optional)
]]
function incbin_rle(file_name, offset, length)
    local f = io.open(file_name, "rb")
    if not f then
        sj.error("[incbin_rle]: cannot open file", file_name)
        return
    end
    offset = offset or 0
    filelength = f:seek("end")
    length = (length or filelength-offset)
    if (offset > filelength) or (length > filelength) or (offset+length > filelength) then
        sj.error("[incbin_rle]: file is too small", file_name)
        return
    end

    _pl(";; incbin_rle ;; file \"" .. file_name .. "\", offset \"" .. offset .. "\", length " .. length)
    f:seek("set", offset)
    local compressed = 0
    local prevbyte = nil
    local repeat_len = 0
    for i = 1, length do
        local char = f:read(1)
        local byte = string.byte(char)
        if byte == prevbyte and repeat_len == 0 then
            sj.add_byte(byte)
            compressed = compressed + 1
            repeat_len = 1
        elseif byte == prevbyte and repeat_len < 255 then
            repeat_len = repeat_len + 1
        elseif repeat_len > 0 then
            sj.add_byte(repeat_len-1)
            sj.add_byte(byte)
            compressed = compressed + 2
            repeat_len = 0
        else
            sj.add_byte(byte)
            compressed = compressed + 1
        end
        prevbyte = byte
    end
    if repeat_len > 0 then
        sj.add_byte(repeat_len-1)
        compressed = compressed + 1
    end
    sj.add_byte(255)
    sj.add_byte(255)
    sj.add_byte(255)
    compressed = compressed + 3
    f:close()
    _pl(";; incbin_rle ;; end of file \"" .. file_name .. "\"")
    -- if _c("__PASS__") == 3 then
    --     io.write(string.format("include data (rle): name=%s (%u bytes) Offset=%u Len=%u CompressedLen=%u\n",
    --         file_name, filelength, offset, length, compressed))
    -- end
end
