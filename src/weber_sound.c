#include <portaudio.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#define TRUE 1
#define FALSE 0

#ifdef MACOS
#define EXPORT __attribute__((visibility("default")))
#define Int16 __int_16_t
#endif
#ifdef WINDOWS
#define EXPORT __declspec(dllexport)
#define Int16 int16_t
#endif

// TODO: os specific, change for windows

typedef struct{
  Int16* buffer;
  int len;
}Sound;

typedef struct{
  int locked;
  Int16* buffer;
  PaTime start;
  int offset;
  int len;
  unsigned long last_buffer_size;
  double samplerate;
  double samplelen; // redundant, but reduces calculations in callback
}TimedSound;

typedef struct{
  PaError errcode;
  int started;
  TimedSound* sound;
  PaStream* stream;
}WsState;

static int ws_callback(const void* in,void* out,unsigned long len,
                       const PaStreamCallbackTimeInfo* time_info,
                       PaStreamCallbackFlags status_flags,void* user_data){
  // lockless multi-threading: we copy the state of the sound
  // checking the length last. If the sound changes in the middle of a copy
  // len will be 0 (since this is the first field set), so we won't play
  // any of the sound in this case.
  TimedSound* sound = (TimedSound*)user_data;
  Int16* output_buffer = (Int16*)out;
  Int16* sound_buffer = sound->buffer;
  PaTime start = sound->start;
  int offset = sound->offset;
  int sound_len = sound->len;

  PaTime buffer_start = time_info->outputBufferDacTime;
  int i=0;
  int zero_padding = 0;
  int copylen;
  int should_start = FALSE;
  int new_offset = 0;

  sound->last_buffer_size = len;

  // if the sound has yet to start...
  if(offset == 0){
    // if the sound should start in this callback...
    if(buffer_start + sound->samplelen * len > start){
      zero_padding = (int)floor((start - buffer_start)*sound->samplerate);
      should_start = TRUE;
    }

    // printf("padding: %d\n",zero_padding);
    if(zero_padding > 0){
      for(i=0;i<zero_padding;i++){
        output_buffer[(i<<1)] = 0;
        output_buffer[(i<<1)+1] = 0;
      }
    }else zero_padding = 0;
  }
  // copy samples as needed
  if((offset > 0 || should_start) && offset < sound_len){
    copylen = len-zero_padding;
    for(;i<copylen && i < sound_len - offset;i++){
      output_buffer[(i<<1)] = sound_buffer[i+offset];
      output_buffer[(i<<1)+1] = sound_buffer[i+sound_len+offset];
    }
    sound->offset = copylen + offset;
    // lockless multithreading: if the sound length has changed to zero
    // (meaning new buffer is about to be specified), don't update the offset
    if(sound->len == 0) sound->offset = 0;
  }

  // pad the remaing buffer (possibly everything) with zeros
  for(;i<len;i++){
    output_buffer[(i<<1)] = 0;
    output_buffer[(i<<1)+1] = 0;
  }

  return 0;
}

EXPORT
const char* ws_error_str(WsState* state){
  return Pa_GetErrorText(state->errcode);
}

EXPORT
int ws_is_error(WsState* state){
  return state->errcode != 0;
}

EXPORT
WsState* ws_setup(int samplerate){
  WsState* state = (WsState*) malloc(sizeof(WsState));
  state->errcode = Pa_Initialize();
  if(state->errcode != paNoError){
    state->sound = 0;
    state->stream = 0;
    return state;
  }

  state->started = 0;
  state->sound = (TimedSound*)malloc(sizeof(TimedSound));
  state->sound->offset = 0;
  state->sound->len = 0;
  state->sound->locked = FALSE;
  state->sound->samplerate = samplerate;
  state->sound->samplelen = 1.0/samplerate;

  state->errcode = Pa_OpenDefaultStream(&state->stream,0,2,paInt16,samplerate,
                                        paFramesPerBufferUnspecified,ws_callback,
                                        state->sound);
  if(state->errcode != paNoError){
    free(state->sound);
    state->stream = 0;
    state->sound = 0;
    return state;
  }

  return state;
}

EXPORT
void ws_close(WsState* state){
  if(paNoError != (state->errcode = Pa_CloseStream(state->stream))) return;
  if(state->sound != 0){
    free(state->sound);
    state->sound = 0;
  }
  state->errcode = Pa_Terminate();
}

EXPORT
void ws_free(WsState* state){
  free(state);
}

EXPORT
void ws_play(double now,double playat,Sound* toplay,WsState* state){
  TimedSound* sound = state->sound;
  PaTime pa_now = Pa_GetStreamTime(state->stream);
  long int sleep_amount;

  // wait for the last sound to stop playing
  if(state->started && state->sound->offset < state->sound->len){
    sleep_amount = 1000*(sound->len - sound->offset)*sound->samplelen - 20;
    if(sleep_amount > 20) Pa_Sleep(sleep_amount);
    while(state->sound->offset < state->sound->len){
      // waiting...
    }
  }

  // lockless multi-threading: setting len to 0 first means if the callback is
  // in the middle copying sound the last thing it will do is set len to 0
  // (since this is the last field copied), and so no sound will be played.
  sound->len = 0;
  sound->buffer = toplay->buffer;
  sound->offset = 0;
  sound->start = (pa_now - now) + playat;

  sound->len = toplay->len;
  if(!state->started){
    state->started=TRUE;
    if(paNoError != (state->errcode = Pa_StartStream(state->stream))) return;
  }
}

EXPORT
void ws_play_from(int offset,Sound* toplay,WsState* state){
  TimedSound* sound = state->sound;

  // wait for the last sound to stop playing
  if(state->started && state->sound->offset < state->sound->len){
    Pa_Sleep(1000*(sound->len - sound->offset)*sound->samplelen-10);
    while(state->started && state->sound->offset < state->sound->len){
      Pa_Sleep(1);
    }
  }

  // lockless multi-threading: setting len to 0 first means if the callback is
  // in the middle copying sound the last thing it will do is set len to 0
  // (since this is the last field copied), and so no sound will be played.
  sound->len = 0;
  sound->buffer = toplay->buffer;
  sound->len = toplay->len;
  sound->offset = offset; // offset may be cleared, so set it last

  sound->len = toplay->len;
  if(!state->started){
    state->started = TRUE;
    if(paNoError != (state->errcode = Pa_StartStream(state->stream))) return;
  }
}

EXPORT
int ws_stop(WsState* state){
  if(state->started){
    if(paNoError != (state->errcode = Pa_StopStream(state->stream))) return 0;
    state->started = FALSE;
  }
  return state->sound->offset;
}

EXPORT
void ws_resume(WsState* state){
  if(state->started == FALSE){
    state->started = TRUE;
    if(paNoError != (state->errcode = Pa_StartStream(state->stream))) return;
  }
}

EXPORT
unsigned long ws_cur_buffer_size(WsState* state){
  return state->sound->last_buffer_size;
}

EXPORT
int ws_isplaying(WsState* state){
  return state->started && state->sound->offset < state->sound->len;
}
