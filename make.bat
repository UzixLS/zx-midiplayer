@echo This is unsupported build method!
@echo Use "GNU make" tool!
@timeout 5

@PATH=C:\Hwdev\sjasmplus\;%PATH%
sjasmplus --outprefix=build/ --inc=resources/ src/main.asm
@pause
