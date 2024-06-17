#!/bin/bash

# NOTE: this requries libdsk-tools and cpmtools

set -e

DSK=build/zxmidipl.dsk
CPMCP='cpmcp -f pcw'

# yep, it's confusing, pcw180 here and pcw anywhere else
dskform -type dsk -format pcw180 "$DSK"

# the order is not arbitrary, it reflects loading sequence
# BAS - SCR - LDR - GFX - DRV (if present) - BIN

$CPMCP "$DSK" \
    res/zxmidipl.bas 0:disk
$CPMCP "$DSK" \
    res/zxmidipl.scr 0:
$CPMCP "$DSK" \
    build/zxmidipl.ldr build/zxmidipl.gfx 0:
if [[ -s build/zxmidipl.drv ]]; then # optional
    cpmcp -f pcw "$DSK" \
        build/zxmidipl.drv 0:
fi
$CPMCP "$DSK" \
    build/zxmidipl.bin 0:

# sample files

$CPMCP "$DSK" \
    res/test0.mid res/midi/DoomE1M1.mid res/midi/Monkey.mid 0:
$CPMCP "$DSK" \
    res/midi/FurElise.rmi 0:FurElise.mid

# EOF vim: et:ai:ts=4:sw=4:
