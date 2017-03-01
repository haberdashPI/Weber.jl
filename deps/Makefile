MAJOR_VERSION = 0
MINOR_VERSION = 0.3

UNAME := $(shell uname)
$(info [${UNAME}])

ifeq ($(UNAME), Darwin)
	COMMAND = clang -dynamiclib -std=gnu99 -DMACOS \
		../src/weber_sound.c -current_version $(MINOR_VERSION) \
		-fvisibility=hidden -o build/libweber-sound.$(MAJOR_VERSION).dylib \
		-L /usr/local/lib -I /usr/local/include -lportaudio \
		-framework CoreAudio -framework AudioToolbox \
		-framework AudioUnit -framework CoreServices \
		-framework Carbon -g
else
	COMMAND = gcc -shared ../src/weber_sound.c \
		-o build/libweber-sound.$(MAJOR_VERSION).dll \
		-lportaudio -Iinclude -Llib -DWINDOWS
endif

weber_sound: build lib
	$(COMMAND)

build:
	mkdir build

lib:
	mkdir lib
	wget "https://github.com/haberdashPI/haberdashPI.github.io/raw/master/portaudio_x64.dll"
	mv portaudio_x64.dll lib/portaudio_x64.dll

