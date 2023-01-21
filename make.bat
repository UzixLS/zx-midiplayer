@echo This is unsupported build method!
@echo Use "GNU make" tool!
@timeout 5

@PATH=C:\Hwdev\sjasmplus\;%PATH%
sjasmplus --outprefix=build/ --exp=build/main.exp src/main.asm
sjasmplus --outprefix=build/ src/build.asm
@pause
