using SampledSignals
using DSP
using LibSndFile
using FixedPointNumbers
using FileIO
using LRUCache
import FileIO: load, save
import SampledSignals: samplerate
import Base: length

export match_lengths, mix, mult, silence, noise, highpass, lowpass, bandpass,
	tone, ramp, harmonic_complex, attenuate, sound, play, pause, stop,
  savesound, duration, setup_sound, current_sound_latency, buffer,
  resume_sounds, pause_sounds, load, save, samplerate, length

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

Creates a period of white noise of the given length (in seconds).
"""
function noise(length_s;sample_rate_Hz=samplerate(sound_setup_state))
	return SampleBuf(1-2rand(floor(Int,length_s*sample_rate_Hz)),sample_rate_Hz)
end

"""
    tone(freq,length,[sample_rate_Hz=44100],[phase=0])

Creates a pure tone of the given frequency and length (in seconds).
"""
function tone(freq_Hz,length_s;sample_rate_Hz=samplerate(sound_setup_state),
              phase=0)
	t = linspace(0,length_s,round(Int,length_s*sample_rate_Hz))
	return SampleBuf(sin(2π*t * freq_Hz + phase),sample_rate_Hz)
end

"""
    harmonic_complex(f0,harmonics,amps,length,
                     [sample_rate_Hz=44100],[phases=zeros(length(harmonics))])

Creates a harmonic complex of the given length, with the specified harmonics
at the given amplitudes. This implementation is somewhat superior
to simply summing a number of pure tones generated using `tone`, because
it avoids beating in the sound that may occur due floating point errors.
"""
function harmonic_complex(f0,harmonics,amps,length_s;
						              sample_rate_Hz=samplerate(sound_setup_state),
                          phases=zeros(length(harmonics)))
  @assert all(0 .<= phases) && all(phases .< 2π)
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

Apply the given decibels of attenuation to the sound relative to a power level
of 1.

This function normalizes the sound to have a root mean squared value of 1 and
then reduces the sound by a factor of ``10^{-a/20}``, where ``a`` = `atten_dB`.
"""
function attenuate(x,atten_dB=20)
	10^(-atten_dB/20) * x/sqrt(mean(x.^2))
end

immutable WS_Sound
  buffer::Ptr{Fixed{Int16,15}}
  len::Cint
end

immutable Sound
  chunk::WS_Sound
  buffer::SampleBuf
  function Sound(c::WS_Sound,b::SampleBuf)
    if !isready(sound_setup_state)
      setup_sound()
    end
    new(c,b)
  end
end
sound(x::Sound) = x
samplerate(x::Sound) = samplerate(x.buffer)
length(x::Sound) = length(x.buffer)

const sound_cache = LRU{Union{SampleBuf,Array},Sound}(256)

"""
    sound(x::Array,[sample_rate_Hz=44100])

Creates a sound object from an arbitrary array.

For real numbers, assumes 1 is the loudest and -1 the softest. Assumes 16-bit
PCM for integers. The array should be 1d for mono signals, or an array of size
(N,2) for stereo sounds.

!!! note "Called Implicitly"

    This function is normally called implicitly in a call to
    `play(x)`, where x is an arbitrary array, so it need not normally
    be called.
"""
function sound{T <: Number}(x::Array{T};
                            sample_rate_Hz=samplerate(sound_setup_state))
  get!(sound_cache,x) do
    bounded = max(min(x,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
    if ndims(x) == 1
      bounded = hcat(bounded,bounded)
    end
    sound(SampleBuf(Fixed{Int16,15}.(bounded),sample_rate_Hz))
  end
end

"""
    sound(x::SampleBuff)

Creates a sound object from a `SampleBuf` (from the `SampledSignals` module).
"""
function sound(x::SampleBuf)
  get!(sound_cache,x) do
    bounded = max(min(x.data,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
    if ndims(x) == 1
      bounded = hcat(bounded,bounded)
    end
    sound(SampleBuf(Fixed{Int16,15}.(bounded),samplerate(x)))
  end
end

save(f::File,sound::Sound) = save(f,sound.buffer)

# load(f::File{format"WAV"}) = load_helper(f)
# load(f::File{format"AIFF"}) = load_helper(f)
# load(f::File{format"RIFF"}) = load_helper(f)
# load(f::File{format"OGG"}) = load_helper(f)
# load(f::File{format"VOC"}) = load_helper(f)
# function load_helper(f::File)
#   if !isready(sound_setup_state)
#     setup_sound()
#   end

#   rw = ccall((:SDL_RWFromFile,_psycho_SDL2),Ptr{Void},(Cstring,Cstring),
#               filename(f), "rb")
#   if rw == C_NULL
#     error("Failed to open file $(filename(f)): "*SDL_GetError())
#   end

#   pchunk = ccall((:Mix_LoadWAV_RW,_psycho_SDL2_mixer),Ptr{MixChunk},
#                  (Ptr{Void},Cint),rw,1)
#   if pchunk == C_NULL
#     error("Failed to load WAV $(filename(f)): "*SDL_GetError())
#   end
#   chunk = unsafe_load(pchunk)
#   SampleBuf(unsafe_wrap(Array,chunk.buffer,chunk.byte_length >> 1,true),
#             samplerate(sound_setup_state))
# end

function sound(x::SampleBuf{Fixed{Int16,15},1})
  get!(sound_cache,x) do
    sound(hcat(x,x))
  end
end

function sound(x::SampleBuf{Fixed{Int16,15},2})
  Sound(WS_Sound(pointer(x.data),size(x.data,1)),x)
end

"""
    buffer(s::Sound)

Gets the `SampleBuf` associated with this sound (c.f. `SampledSignals` package).
"""
buffer(x::Sound) = x.buffer

const default_sample_rate = 44100
type SoundSetupState
  samplerate::Int
  playing::Nullable{Sound}
  state::Ptr{Void}
end
SoundSetupState() = SoundSetupState(0,Nullable(),C_NULL)
function samplerate(s::SoundSetupState)
  if s.samplerate == 0
    default_sample_rate
  else
    s.samplerate
  end
end
isready(s::SoundSetupState) = s.samplerate != 0
samplerate(x::Vector) = samplerate(sound_setup_state)
samplerate(x::Matrix) = samplerate(sound_setup_state)

const sound_setup_state = SoundSetupState()

function register_sound(current::Sound,play_from=0)
  sound_setup_state.playing = Nullable(current)
end

function unregister_sound(current::Sound)
  sound_setup_state.playing = Nullable()
end

function ws_if_error(msg)
  if sound_setup_state.state != C_NULL
    if ccall((:ws_is_error,__weber_sound),Cint,
             (Ptr{Void},),sound_setup_state.state) == true
      error(msg*": "*unsafe_string(ccall((:ws_error_str,__weber_sound),Cstring,
                                         (Ptr{Void},),sound_setup_state.state)))
    end
  end
end

function isplaying()
  ccall((:ws_isplaying,__weber_sound),Cint,
        (Ptr{Void},),sound_setup_state.state) == true
end

function isplaying(sound::Sound)
  isplaying() && !isnull(sound_setup_state.playing) &&
    get(sound_setup_state.playing) == sound
end
"""
    setup_sound([sample_rate_Hz=44100])

Initialize format for audio playback.

This function is called automatically the first time a `Sound` object is created
(normally by using the `sound` function). It need not normally be called
explicitly, unless you wish to change the play-back sample rate. Sample rate
determines the maximum playable frequency (max freq is ≈ sample_rate/2).

Changing the sample rate from the default 44100 to a new value will also change
the default sample rate sounds will be created at, to match this new sample
rate. Upon playback, there is no check to ensure that the sample rate of a given
sound is the same as that setup here, and no resampling of the sound is made.
"""
function setup_sound(;sample_rate_Hz=samplerate(sound_setup_state),
                     buffer_size=nothing)
  if isready(sound_setup_state)
    ccall((:ws_close,__weber_sound),Void,(Ptr{Void},),sound_setup_state.state)
    ws_if_error("Error closing old audio stream during setup")
  else

    if !weber_sound_is_setup[]
      weber_sound_is_setup[] = true
      atexit() do
        ccall((:ws_close,__weber_sound),Void,
              (Ptr{Void},),sound_setup_state.state)
        ws_if_error("Error closing audio stream at exit.")
        ccall((:ws_free,__weber_sound),Void,
              (Ptr{Void},),sound_setup_state.state)
      end
    end
  end
  if samplerate(sound_setup_state) != sample_rate_Hz
    warn(cleanstr("The sample rate is being changed from "*
         "$(samplerate(sound_setup_state))Hz to $(sample_rate_Hz)Hz. "*
         "Sounds you've created that do not share this new sample rate will "*
         "not play correctly."))
  end

  sound_setup_state.samplerate = sample_rate_Hz
  sound_setup_state.state = ccall((:ws_setup,__weber_sound),Ptr{Void},
                                  (Cint,),sample_rate_Hz)
  ws_if_error("Failed to initialize sound")
end

type PlayingSound
  sound::Sound
  offset::Cint
end

function play(x;wait=false,time=0.0)
  if in_experiment() && !experiment_running()
    error("You cannot call `play` during experiment `setup`. During `setup`",
          " you should add play to a trial (e.g. ",
          "`addtrial(moment(play,my_sound))`).")
  end
  warn("Calling play outside of an experiment.")
  _play(x,wait,time)
end

function _play(x,wait=false,time=0.0)
  play(sound(x),wait,time)
end

"""
    play(x,[wait=false],[time=0.0])

Plays a sound (created via `sound`).

If `wait == false`, returns an object that can be used to `stop`, or `pause` the
sound. One can also call play(x,wait=true) on this object to wait for the sound
to finish. The sound will normally play only once, but can be repeated
multiple times using `times`.

If `time > 0`, plays the sound at the given time (in seconds from epoch).

For convenience, play can also can be called on any object that can be turned
into a sound (via `sound`).

!!! info "Playing Multiple Sounds"

    If one sound is already playing this function will block until the sound
    has finished playing before starting the next sound. If you want
    to play multiple sounds over one another, create a single mixture
    of those sounds--using [`mix`](@ref)--and call play on the mixture.

"""
function play(x::Sound,wait::Bool=false,time::Float64=0.0)

  # verify the sound can be played when we want to
  if time > 0.0
    size = ccall((:ws_cur_buffer_size,__weber_sound),UInt64,
                 (Ptr{Void},),sound_setup_state.state)
    min_dist = (2*size)/samplerate(sound_setup_state)
    now = Weber.tick()
    if now + min_dist > time
      warn("Sounds are placed too close to one another. ",
           "Latency will not be reliable. If you want to play sounds ",
           "closer than $(round(1000*min_dist,2))ms to each other, ",
           "fuse them into one sound, and then play the single, ",
           "longer sound.")
    end
  end

  ccall((:ws_play,__weber_sound),Void,
        (Cdouble,Cdouble,Ref{WS_Sound},Ptr{Void}),
        Weber.tick(),time,x.chunk,sound_setup_state.state)
  ws_if_error("Error playing sound")

  if !wait
    register_sound(x)
    PlayingSound(x,0)
  else
    sleep(duration(x)-0.01)
    while isplaying() end
    nothing
  end
end

"""
    play(fn::Function)

Play the sound that's returned by calling `fn`.
"""
function play(fn::Function;keys...)
  play(fn();keys...)
end

function play(x::PlayingSound;wait=false)
  if isplaying() && !isplaying(x.sound)

  end

  ccall((:ws_play_from,__weber_sound),Void,
        (Cint,Ref{WS_Sound},Ptr{Void}),
        x.offset,x.sound.chunk,sound_setup_state.state)
  ws_if_error("Failed to resume playing sound")

  if !wait
    register_sound(x.sound)
    x
  else
    sleep(duration(x.sound) - (x.offset / samplerate(sound_setup_state))-0.01)
    while ccall((:ws_isplaying,__weber_sound),Cint,
                (Ptr{Void},),sound_setup_state.state)
    end
    nothing
  end
end

"""
    pause(x)

Pause playback of the sound. Resume by calling `play` on the sound again.
"""
function pause(x::PlayingSound)
  if (isnull(sound_setup_state.playing) ||
      get(sound_setup_state.playing) != x.sound)
    return x
  end

  x.offset = ccall((:ws_stop,__weber_sound),Cint,
                   (Ptr{Void},),sound_setup_state.state)
  ws_if_error("Failed to pause sound")
  x
end

"""
    stop(x)

Stop playback of the sound.
"""
function stop(x::PlayingSound)
  unregister_sound(x.sound)
  ccall((:ws_stop,__weber_sound),Cint,(Ptr{Void},),sound_setup_state.state)
  ws_if_error("Failed to stop sound")

  nothing
end

"""
    pause_sounds()

Pause all sounds that are playing.
"""
function pause_sounds()
  ccall((:ws_stop,__weber_sound),Cint,(Ptr{Void},),sound_setup_state.state)
  ws_if_error("Failed to pause sounds")
end

"""
    resume_sounds()

Resume all sounds that have been paused.
"""
function resume_sounds()
  ccall((:ws_resume,__weber_sound),Void,(Ptr{Void},),sound_setup_state.state)
  ws_if_error("Failed to resume playing sounds")
end


"""
    duration(x)

Get the duration of the given sound.
"""
duration(s::Sound) = duration(s.buffer)
duration(s::PlayingSound) = duration(s.sound)
duration(s::SampleBuf) = length(s) / samplerate(s)
function duration(s::Array{Float64};
                  sample_rate_Hz=samplerate(sound_setup_state))
  length(s) / sample_rate_Hz
end
