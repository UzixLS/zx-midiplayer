export PATH:=/cygdrive/c/Hwdev/sjasmplus/:/cygdrive/e/Emulation/ZX Spectrum/Utils/fuse-utils/:/cygdrive/e/Emulation/ZX Spectrum/Emuls/Es.Pectrum/:${PATH}

SJOPTS = --fullpath

.PHONY: all clean .FORCE
.FORCE:

all: main.sna main.tzx

clean:
	rm -f *.bin *.mem *.hex *.map *.sna *.z80 *.tzx *.tap *.trd

%.bin %.sna: %.asm .FORCE
	sjasmplus --sld=$(basename $<).sld ${SJOPTS} $<

%.tzx: %.sna
	snap2tzx $<

run: main.tzx
	EsPectrum $<

-include Makefile.local
