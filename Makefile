ifneq ($(wildcard .git),)
	VERSION := $(shell git describe --abbrev=6 --long --dirty --always --tags --first-parent | sed s/-/./)
endif

export PATH:=/cygdrive/c/Hwdev/sjasmplus/:/cygdrive/e/Emulation/ZX Spectrum/Utils/fuse-utils/:/cygdrive/e/Emulation/ZX Spectrum/Emuls/Es.Pectrum/:${PATH}

SJOPTS = --fullpath --inc=resources/ -DVERSION=\"${VERSION}\"

.PHONY: all clean .FORCE
.FORCE:

all: build/main.sna

clean:
	rm -rf build/ .tmp/

build/main.sna: src/main.asm .FORCE
	mkdir -p build
	sjasmplus --sld=build/main.sld --lst=build/main.lst --outprefix=build/ ${SJOPTS} $<

%.tzx: %.sna
	snap2tzx -o $@ $<

run: build/main.tzx
	EsPectrum $<

-include Makefile.local
