--[[
    Lua function providing "incbin" replacement which can arrange file into multiple pages
    for SjASMPlus (https://github.com/z00m128/sjasmplus)
    Author: Eugene Lozovoy

    Parameters:
    1 file_name: name of file to open
    2 offset: positive value (optional)
    3 length: positive value (optional)
    4 baseaddr: destination address
    5 pages: which pages will be used
    6 pagesize: default 16Kb
]]
function incbin_pages(file_name, offset, length, baseaddr, pages, pagesize)
    pagesize = pagesize or 16*1024
    local f = io.open(file_name, "rb")
    if not f then
        sj.error("[incbin_pages]: cannot open file", file_name)
        return
    end
    filelength = f:seek("end")
    f:close()
    offset = offset or 0
    length = length or (filelength - offset)
    if (offset > filelength) or (length > filelength) or (offset+length > filelength) then
        sj.error("[incbin_rle]: file is too small", file_name)
        return
    end
    filepages = math.ceil(filelength / pagesize)
    if filepages > #pages then
        sj.error("[incbin_pages]: cannot fit file", file_name)
        return
    end
    local offsetend = offset + length
    for i = 1, filepages do
        local portion = math.min(pagesize, offsetend - offset)
        _pc(string.format("org 0x%x" ,baseaddr))
        _pc(string.format("page %u", pages[i]))
        _pc(string.format("incbin \"%s\",0x%x,0x%x", file_name, offset, portion))
        offset = offset + portion
    end
end
