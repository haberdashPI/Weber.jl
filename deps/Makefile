MAJOR_VERSION = 1
MINOR_VERSION = 0.0

UNAME := $(shell uname)
$(info [${UNAME}])

# On mac osx, run "brew install portaudio", or some other means of installing
# portaudio
# On windows you will either need to download portaudio, as specified below
# or compile it, according to the directions on the portaudio website.
# I had the best luck using visual studio express to compile portaudio.
ifeq ($(UNAME), Darwin)
	COMPILE = clang -dynamiclib -std=gnu99 -DMACOS \
		../src/weber_sound.c -current_version $(MINOR_VERSION) \
		-fvisibility=hidden -o build/libweber-sound.$(MAJOR_VERSION).dylib \
		-L/usr/local/lib -Iinclude -lportaudio \
		-framework CoreAudio -framework AudioToolbox \
		-framework AudioUnit -framework CoreServices \
		-framework Carbon -g
	WGET = ''
	MVLIB = ''
else
	COMPILE = gcc -shared ../src/weber_sound.c \
		-o build/libweber-sound.$(MAJOR_VERSION).dll \
		-lportaudio -Iinclude -Llib -DWINDOWS
	WGET = wget "https://github.com/haberdashPI/haberdashPI.github.io/raw/master/portaudio_x64.dll"
	MVLIB = mv portaudio_x64.dll lib/portaudio_x64.dll
endif

weber_sound: build lib
	$(COMPILE)

build:
	mkdir build

lib:
	mkdir lib
	$(WGET)
	$(MVLIB)
