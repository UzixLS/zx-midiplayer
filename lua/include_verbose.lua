function include_verbose(file_name)
    file_name = file_name:gsub('"', '')
    start = sj.current_address
    _pc(string.format([[include "%s"]], file_name))
    finish = sj.current_address
    _pc(string.format([[display "include file=%s start=0x%X end=0x%X size=%u"]], file_name, start, finish, finish-start))
end
