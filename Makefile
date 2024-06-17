ifneq ($(wildcard .git),)
	VERSION      := $(shell git describe --abbrev=6 --long --dirty --always --tags --first-parent | sed s/-/./)
	VERSIONSHORT := $(shell echo v${VERSION} | sed 's/-g[0-9a-f]*//; s/-dirty/D/')
endif

export PATH:=/cygdrive/c/Hwdev/sjasmplus/:/cygdrive/e/Emulation/ZX Spectrum/Emuls/Es.Pectrum/:${PATH}

SJOPTS = --nologo --fullpath --outprefix=build/ -DVERSION_DEF=\"${VERSION}\" -DVERSIONSHORT_DEF=\"${VERSIONSHORT}\" $(OPTS) -DPLUS3_STARMID_PATTERN=\"*.*\"

.PHONY: all clean run

all:
	@mkdir -p build
	sjasmplus --msg=war --lst=build/main.lst --exp=build/main.exp --sld=build/main.sld ${SJOPTS} src/main.asm
	sjasmplus --msg=err --lst=build/build.lst ${SJOPTS} src/build.asm

clean:
	rm -rf build/ .tmp/

run:
	EsPectrum build/main.trd

-include Makefile.local
