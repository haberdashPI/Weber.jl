using SampledSignals
using DSP
using LibSndFile
using FixedPointNumbers
import SampledSignals: samplerate

export match_lengths, mix, mult, silence, noise, highpass, lowpass, bandpass,
	tone, ramp, harmonic_complex, attenuate, sound, play, pause, stop,
  savesound, duration, setup_sound, current_sound_latency, buffer,
  resume_sounds, pause_sounds

"""
   match_lengths(x,y,...)

Ensure that all sounds have exactly the same length by adding silence
to the end of shorter sounds.
"""
function match_lengths(xs...)
	max_length = maximum(map(x -> size(x,1), xs))

  map(xs) do x
    if size(x,1) < max_length
      vcat(x,SampleBuf(zeros(eltype(x),
                             max_length - size(x,1),size(x,2)),samplerate(x)))
    else
      x
    end
  end
end

"""
    mix(x,y,...)

Mix several sounds together so that they play at the same time.
"""
function mix(xs...)
  xs = match_lengths(xs...)
  reduce(+,xs)
end

"""
    mult(x,y,...)

Mutliply several sounds together. Typically used to apply an amplitude envelope.
"""
function mult(xs...)
	xs = match_lengths(xs...)
	reduce(.*,xs)
end

"""
    silence(length,[sample_rate_Hz=44100])

Creates period of silence of the given length (in seconds).
"""
function silence(length_s;sample_rate_Hz=samplerate(sound_setup_state))
	SampleBuf(zeros(floor(Int,sample_rate_Hz * length_s)),sample_rate_Hz)
end

"""
   noise(length,[sample_rate_Hz=44100])

Creats a period of white noise of the given length (in seconds).
"""
function noise(length_s;sample_rate_Hz=samplerate(sound_setup_state))
	return SampleBuf(1-2rand(floor(Int,length_s*sample_rate_Hz)),sample_rate_Hz)
end

"""
    tone(freq,length,[sample_rate_Hz=44100],[phase=0])

Creats a pure tone of the given frequency and length (in seconds).
"""
function tone(freq_Hz,length_s;sample_rate_Hz=samplerate(sound_setup_state),
              phase=0)
	t = linspace(0,length_s,round(Int,length_s*sample_rate_Hz))
	return SampleBuf(sin(2π*t * freq_Hz + phase),sample_rate_Hz)
end

"""
    harmonic_complex(f0,harmonics,amps,length,
                     [sample_rate_Hz=44100],[phases=zeros(length(harmonics))])

Creates a haromic complex of the given length, with the specified harmonics
at the given amplitudes. This implementation is somewhat superior
to simply summing a number of pure tones generated using `tone`, because
it avoids beating in the sound that may occur due floating point errors.
"""
function harmonic_complex(f0,harmonics,amps,length_s;
						              sample_rate_Hz=samplerate(sound_setup_state),
                          phases=zeros(length(harmonics)))
  @assert 0 .<= phases .< 2π
	n = maximum(harmonics)+1

  # generate single cycle of complex
  unit_length_s = 1/f0
  unit_length = floor(Int,sample_rate_Hz*unit_length_s)
  unit = zeros(unit_length)

	highest_freq = tone(f0,2n*unit_length_s;sample_rate_Hz=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
    wave = highest_freq[(1:unit_length) * (n-harm) + phase_offset]
		unit += amp*wave[1:length(unit)]
	end

  # repeate the cycle as many times as necessary
  full_length = round(Int,length_s*sample_rate_Hz)
  full_sound = zeros(full_length)
  for i0 in 1:unit_length:full_length
    i1 = min(i0+unit_length-1,full_length)
    full_sound[i0:i1] = unit[1:i1-i0+1]
  end

	SampleBuf(full_sound,sample_rate_Hz)
end

"""
   bandpass(x,low,high,[order=5],[sample_rate_Hz=samplerate(x)])

Band-pass filter the sound at the specified frequencies.

Filtering uses a butterworth filter of the given order.
"""
function bandpass(x,low,high;order=5,sample_rate_Hz=samplerate(x))
	ftype = Bandpass(float(low),float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end


"""
   lowpass(x,low,[order=5],[sample_rate_Hz=samplerate(x)])

Low-pass filter the sound at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
function lowpass(x,low;order=5,sample_rate_Hz=samplerate(x))
	ftype = Lowpass(float(low),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end

"""
   highpass(x,high,[order=5],[sample_rate_Hz=samplerate(x)])

High-pass filter the sound at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
function highpass(x,high;order=5,sample_rate_Hz=samplerate(x))
	ftype = Highpass(float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end

"""
   ramp(x,[ramp_s=0.005];[sample_rate_Hz=samplerate(x)])

Applies a half cosine ramp to the sound. Prevents click sounds at the start of
tones.
"""
function ramp(x,ramp_s=0.005;sample_rate_Hz=samplerate(x))
	ramp_len = floor(Int,sample_rate_Hz * ramp_s)
	@assert size(x,1) > 2ramp_len

	ramp_t = (1.0:ramp_len) / ramp_len
	up = -0.5cos(π*ramp_t)+0.5
	down = -0.5cos(π*ramp_t+π)+0.5
	envelope = [up; ones(size(x,1) - 2*ramp_len); down]
	mult(x,envelope)
end

"""
   attenuate(x,atten_dB)

Apply the given decibales of attentuation to the sound relative to a power level
of 1.

This function normalizes the sound to have a root mean squared value of 1 and
then reduces the sound by a factor of ``10^{-a/20}``, where ``a`` = `atten_dB`.
"""
function attenuate(x,atten_dB=20)
	10^(-atten_dB/20) * x/sqrt(mean(x.^2))
end

"""
    sound(x::Array,[sample_rate_Hz=44100])

Creates a sound object from an aribtrary array.

For real numbers, assumes 1 is the loudest and -1 the softest. Assumes 16-bit
PCM for integers. The array should be 1d for mono signals, or an array of size
(N,2) for stereo sounds.
"""
function sound{T <: Number}(x::Array{T};
                            sample_rate_Hz=samplerate(sound_setup_state))
  bounded = max(min(x,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
  sound(SampleBuf(Fixed{Int16,15}.(bounded),sample_rate_Hz))
end

"""
   sound(x::SampleBuff)

Creates a sound object from a `SampleBuf` (from the `SampledSignals` module).
"""
function sound(x::SampleBuf)
  bounded = max(min(x.data,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
  sound(SampleBuf(Fixed{Int16,15}.(bounded),samplerate(x)))
end

immutable MixChunk
  allocated::Cint
  buffer::Ptr{Fixed{Int16,15}}
  byte_length::UInt32
  volume::UInt8
end

immutable Sound
  chunk::MixChunk
  buffer::SampleBuf
  function Sound(c::MixChunk,b::SampleBuf)
    if !isready(sound_setup_state)
      setup_sound()
    end
    new(c,b)
  end
end

function sound(x::SampleBuf{Fixed{Int16,15}})
  Sound(MixChunk(0,pointer(x.data),sizeof(x.data),128),x)
end

"""
   buffer(s::Sound)

Gets the `SampleBuf` associated with this sound.
"""
buffer(x::Sound) = x.buffer

const SDL_INIT_AUDIO = 0x00000010
const AUDIO_S16 = 0x8010

const default_sample_rate = 44100
type SoundSetupState
  samplerate::Int
  buffer_size::Int
end
SoundSetupState() = SoundSetupState(0,256)
function samplerate(s::SoundSetupState)
  if s.samplerate == 0
    default_sample_rate
  else
    s.samplerate
  end
end
isready(s::SoundSetupState) = s.samplerate != 0
const sound_setup_state = SoundSetupState()
samplerate(x::Vector) = samplerate(sound_setup_state)
samplerate(x::Matrix) = samplerate(sound_setup_state)

"""
    current_sound_latency()

Reports the current latency of audio playback. This is the minimum expected
error in playback timing that could possibly be achieved with the given sound
settings. If you wish to have a lower latency you can call `setup_sound` and use
a smaller buffer size. Note however that a buffer size that is too small for
your hardware will corrupt the sound.
"""
function current_sound_latency()
  sound_setup_state.buffer_size / samplerate(sound_setup_state)
end

type SDLAudioSpec
  freq::Cint
  format::UInt16
  channels::UInt8
  silence::UInt8
  buffer_size::UInt16
  size::UInt32
  callback::Ptr{Void}
  user::Ptr{Void}
end

function empty_callback(udata::Ptr{Void},stream::Ptr{UInt8},len::Cint)
  nothing
end

function verify_buffer_size(sample_rate_Hz,buffer_size)
  if buffer_size != nothing
    ec = cfunction(empty_callback,Void,(Ptr{Void},Ptr{UInt8},Cint))
    requested = SDLAudioSpec(sample_rate_Hz,AUDIO_S16,2,0,buffer_size,
                             2buffer_size,ec,C_NULL)
    given = SDLAudioSpec(sample_rate_Hz,AUDIO_S16,2,0,0,0,ec,C_NULL)
    sdl_init = ccall((:SDL_OpenAudio,_psycho_SDL2),Cint,
                     (Ptr{SDLAudioSpec},Ptr{SDLAudioSpec}),
                     Ref(requested),Ref(given))
    if sdl_init < 0
      error("Failed to initialize sound: "*SDL_GetError())
    end
    if requested.buffer_size != given.buffer_size
      ccall((:SDL_CloseAudio,_psycho_SDL2),Void,())
      error("The requested buffer size $buffer_size cannot be provided.")
    else
      info("Using audio buffer size of $buffer_size")
    end
    ccall((:SDL_CloseAudio,_psycho_SDL2),Void,())

    buffer_size
  else
    256
  end
end

"""
    setup_sound([sample_rate_Hz=44100],[buffer_size=256])

Initialize format for audio playback.

This function is called automatically the first time a `Sound` object is created
(normally by using the `sound` function). It need not normally be called
explicitly, unless you wish to change the play-back sample rate or buffer
size. Sample rate determines the maximum playable frequency (max freq is ≈
sample_rate/2). The buffer size determines audio latency, so the shorter this is
the better. However, when this size is too small, audio playback will be
corrupted.

Changing the sample rate from the default 44100 to a new value will also change
the default sample rate sounds will be creataed at, to match this new sample
rate. Upon playback, there is no check to ensure that the sample rate of a given
sound is the same as that setup here, and no resampling of the sound is made.
"""
function setup_sound(;sample_rate_Hz=samplerate(sound_setup_state),
                     buffer_size=nothing)
  global sound_setup_state

  if isready(sound_setup_state)
    ccall((:Mix_CloseAudio,_psycho_SDL2_mixer),Void,())
  else
    init = ccall((:SDL_Init,_psycho_SDL2),Cint,(UInt32,),SDL_INIT_AUDIO)
    if init < 0
      error("Failed to initialize SDL: "*SDL_GetError())
    end
    if !sdl_is_setup[]
      sdl_is_setup[] = true
      atexit(() -> ccall((:SDL_Quit,_psycho_SDL2),Void,()))
    end
  end
  if samplerate(sound_setup_state) != sample_rate_Hz
    warn("The sample rate is being changed from "*
         "$(samplerate(sound_setup_state))Hz to $(sample_rate_Hz)Hz. "*
         "Sounds you've created that do not share this new sample rate will "*
         "not play correctly.")
  end

  sound_setup_state.samplerate = sample_rate_Hz
  buffer_size = sound_setup_state.buffer_size =
    verify_buffer_size(sample_rate_Hz,buffer_size)

  mixer_init = ccall((:Mix_OpenAudio,_psycho_SDL2_mixer),
                     Cint,(Cint,UInt16,Cint,Cint),
                     round(Cint,sample_rate_Hz/2),AUDIO_S16,2,buffer_size)
  if mixer_init < 0
    error("Failed to initialize sound: "*Mix_GetError())
  end
  atexit(() -> ccall((:Mix_CloseAudio,_psycho_SDL2_mixer),Void,()))
end

type PlayingSound
  channel::Int
  start::Float64
  paused::Float64
  sound::Sound
  times::Int
end

function play(x;keys...)
  if experiment_running()
    warn("Sound was not precomputed! To minimize latency, call ",
         "`x = sound(obj)` before running an experiment, then call `play(x)` ",
         "during the experiment.")
  end
  play(sound(x);keys...)
end

"""
    play(x;[wait=false],[times=1])

Plays a sound (created via `sound`).

If `wait` == false, returns an object that can be used to `stop`, or `pause` the
sound. One can also call play(x,wait=true) on this object to wait for the sound
to finish. The sound will normally play only once, but can be repeated
multiple times using `times`.
"""

function play(x::Sound;wait=false,times=1)
  channel = ccall((:Mix_PlayChannelTimed,_psycho_SDL2_mixer),Cint,
                  (Cint,Ref{MixChunk},Cint,Cint),
                  -1,x.chunk,times-1,-1)
  if channel < 0
    error("Failed to play sound: "*Mix_GetError())
  end

  if !wait
    PlayingSound(channel,time(),NaN,x,times)
  else
    sleep(times*duration(x)-0.01)
    while ccall((:Mix_Playing,_psycho_SDL2_mixer),Cint,(Cint,),channel) > 0
    end
    nothing
  end
end

function play(x::PlayingSound;wait=false)
  if !isnan(x.paused)
    ccall((:Mix_Resume,_psycho_SDL2_mixer),Void,(Cint,),x.channel)
    x.start = time() - (x.paused - x.start)
    x.paused = NaN
  end

  if !wait
    x
  else
    sleep(duration(x) - (time() - x.start) - 0.01)
    while ccall((:Mix_Playing,_psycho_SDL2_mixer),Cint,(Cint,),x.channel) > 0
    end
    nothing
  end
end

"""
Pause playback of the sound. Resume by calling `play` on the sound again.
"""
function pause(x::PlayingSound)
  ccall((:Mix_Pause,_psycho_SDL2_mixer),Void,(Cint,),x.channel)
  x.paused = time()
  x
end

"""
     stop(x)

Stop playback of the sound.
"""
function stop(x::PlayingSound)
  ccall((:Mix_HaltChannel,_psycho_SDL2_mixer),Void,(Cint,),x.channel)
  nothing
end

"""
    pause_sounds()

Pause all sounds that are playing.
"""
function pause_sounds()
  ccall((:Mix_Pause,_psycho_SDL2_mixer),Void,(Cint,),-1)
end

"""
    resume_sounds()

Resume all sounds that have been paused.
"""
function resume_sounds()
  ccall((:Mix_Resume,_psycho_SDL2_mixer),Void,(Cint,),-1)
end


"""
    duration(x)

Get the duration of the given sound.
"""
duration(s::Sound) = duration(s.buffer)
duration(s::PlayingSound) = duration(s.sound)*s.times
duration(s::SampleBuf) = length(s) / samplerate(s)
function duration(s::Array{Float64};
                  sample_rate_Hz=samplerate(sound_setup_state))
  length(s) / sample_rate_Hz
end
