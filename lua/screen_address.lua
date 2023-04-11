function screen_address_pixel(x, y, baseaddr)
    baseaddr = baseaddr or 0x4000
    if (not (x >= 0 and x < 256 and y >= 0 and y < 192)) then
        sj.error("[screen_address_pixel]: invalid argument x=" .. x .. " y=" .. y)
        return 0
    end
    return baseaddr + (x/8) + ((y&0x7)<<8) + ((y&0x38)<<2) + ((y&0xC0)<<5)
end

function screen_address_attr(x, y, baseaddr)
    baseaddr = baseaddr or 0x4000
    if (not (x >= 0 and x < 256 and y >= 0 and y < 192)) then
        sj.error("[screen_address_attr]: invalid argument x=" .. x .. " y=" .. y)
        return 0
    end
    return baseaddr + 6144 + (x/8) + ((y/8)<<5)
end
