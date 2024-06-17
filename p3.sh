#!/bin/bash

set -x
set -e

if [[ $# -eq 0 ]]; then
    set -- zxmidipl.bin zxmidipl.drv zxmidipl.gfx zxmidipl.ldr
fi

for n in $@; do
    f="build/$n"
    if [[ -f "$f" ]]; then
        cpmrm -f pcw 3dos/zxmidip.dsk "$n"
        cpmcp -f pcw 3dos/zxmidip.dsk "$f" 0:
    fi
done

# EOF vim: et:ai:ts=4:sw=4:
