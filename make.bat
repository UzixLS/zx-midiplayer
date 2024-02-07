@echo This is unsupported build method!
@echo Use "GNU make" tool!
@timeout 5

@PATH=C:\Hwdev\sjasmplus\;%PATH%
sjasmplus --outprefix=build/ --exp=build/main.exp -DVERSION_DEF=\"\" -DVERSIONSHORT_DEF=\"\"  src/main.asm
sjasmplus --outprefix=build/ --msg=err src/build.asm
@pause
