MAJOR_VERSION = 0
MINOR_VERSION = 0.2

UNAME := $(shell uname)
# TODO: find header files for portaudio
ifeq ($(UNAME), Darwin)
	COMMAND = clang -dynamiclib -std=gnu99 ../src/weber_sound.c -current_version $(MINOR_VERSION) -fvisibility=hidden -o build/libweber-sound.$(MAJOR_VERSION).dylib -L /usr/local/lib -I /usr/local/include -lportaudio -framework CoreAudio -framework AudioToolbox -framework AudioUnit -framework CoreServices -framework Carbon -g
endif

# TODO: find header files and dll for portaudio
ifeq ($(UNAME), Windows_NT)
	COMMAND = gcc -shared -o build/libweber-sound.$(MAJOR_VERSION).dll -c ../src/weber_sound.c -lportaudio
endif

weber_sound: build
	$(COMMAND)

build:
	mkdir build

clean:
	rm weber_sound.o
