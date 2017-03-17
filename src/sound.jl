using SampledSignals
using DSP
using LibSndFile
using FixedPointNumbers
using FileIO
using LRUCache
using Lazy
import FileIO: load, save
import SampledSignals: samplerate
import Base: show, length, start, done, next

export match_lengths, mix, mult, silence, noise, highpass, lowpass, bandpass,
	tone, ramp, harmonic_complex, attenuate, sound, asstream, play, stream, stop,
  duration, setup_sound, current_sound_latency, buffer,
  resume_sounds, pause_sounds, load, save, samplerate, length, channel,
  rampon, rampoff, stream_unit

const weber_sound_version = 2

let
  version_in_file =
    match(r"libweber-sound\.([0-9]+)\.(dylib|dll)",weber_sound).captures[1]
  if parse(Int,version_in_file) != weber_sound_version
    error("Versions for weber sound driver do not match. Please run ",
          "Pkg.build(\"Weber\").")
  end
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
function with_cache(fn,usecache,x)
  if usecache
    get!(fn,sound_cache,x)
  else
    fn()
  end
end

"""
    sound(x::Array,[cache=true];[sample_rate_Hz=44100])

Creates a sound object from an arbitrary array.

For real numbers, assumes 1 is the loudest and -1 the softest. Assumes 16-bit
PCM for integers. The array should be 1d for mono signals, or an array of size
(N,2) for stereo sounds.

When cache is set to true, sound will cache its results thus avoiding repeatedly
creating a new sound for the same object.

!!! note "Called Implicitly"

    This function is normally called implicitly in a call to
    `play(x)`, where x is an arbitrary array, so it need not normally
    be called.
"""
function sound{T <: Number}(x::Array{T},cache=true;
                            sample_rate_Hz=samplerate(sound_setup_state))
  with_cache(cache,x) do
    bounded = max(min(x,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
    if ndims(x) == 1
      bounded = hcat(bounded,bounded)
    end
    sound(SampleBuf(Fixed{Int16,15}.(bounded),sample_rate_Hz))
  end
end

"""
    sound(x::SampleBuff,[cache=true])

Creates a sound object from a `SampleBuf` (from the `SampledSignals` module).
"""
function sound(x::SampleBuf,cache=true)
  with_cache(cache,x) do
    bounded = max(min(x.data,typemax(Fixed{Int16,15})),typemin(Fixed{Int16,15}))
    if ndims(x) == 1
      bounded = hcat(bounded,bounded)
    end
    sound(SampleBuf(Fixed{Int16,15}.(bounded),samplerate(x)))
  end
end

function sound(x::SampleBuf{Fixed{Int16,15},1},cache=true)
  with_cache(cache,x) do
    sound(hcat(x,x))
  end
end

function sound(x::SampleBuf{Fixed{Int16,15},2})
  Sound(WS_Sound(pointer(x.data),size(x.data,1)),x)
end

save(f::File,sound::Sound) = save(f,sound.buffer)

"""
    buffer(s::Sound)

Gets the `SampleBuf` associated with this sound (c.f. `SampledSignals` package).
"""
buffer(x::Sound) = x.buffer

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

immutable OpStream
  streams::Tuple
  op::Function
end
immutable OpState
  streams::Tuple
  states::Tuple
end
immutable OpPassState
  stream
  state
end

start(ms::OpStream) = OpState(ms.streams,map(start,ms.streams))
done(ms::OpStream,state::OpState) = all(map(done,state.streams,state.states))
done(ms::OpStream,state::OpPassState) = done(state.stream,state.state)
@inline function next(ms::OpStream,state::OpPassState)
  obj, pass_state = next(state.stream,state.state)
  obj, OpPassState(state.stream,pass_state)
end
function next(ms::OpStream,state::OpState)
  undone = find(map((stream,state) -> !done(stream,state),state.streams,state.states))
  streams = state.streams[undone]
  states = state.states[undone]

  nexts = map(next,streams,states)
  sounds = map(x -> x[1],nexts)
  states = map(x -> x[2],nexts)

  if length(undone) > 1
    reduce(ms.op,sounds), OpState(streams,states)
  else
    sounds[1], OpPassState(streams[1],states[1])
  end
end

"""
    mix(x,y,...)

Mix several sounds (or streams) together so that they play at the same time.
"""
function mix(xs::Union{SampleBuf,Array}...)
  xs = match_lengths(xs...)
  reduce(+,xs)
end
mix(itrs...) = OpStream(itrs,+)

"""
    mult(x,y,...)

Mutliply several sounds (or streams) together. Typically used to apply an
amplitude envelope.
"""
function mult(xs::Union{SampleBuf,Array}...)
  xs = match_lengths(xs...)
  reduce(.*,xs)
end
mult(itrs...) = OpStream(itrs,.*)

"""
    silence(length,[sample_rate_Hz=44100])

Creates period of silence of the given length (in seconds).
"""
function silence(length_s;sample_rate_Hz=samplerate(sound_setup_state))
	SampleBuf(zeros(floor(Int,sample_rate_Hz * length_s)),sample_rate_Hz)
end


immutable NoiseStream
  rng::RandomDevice
  length::Int
  samplerate::Int
end
show(io::IO,as::NoiseStream) = write(io,"NoiseStream()")
start(ns::NoiseStream) = nothing
done(ns::NoiseStream,::Void) = false

"""
    noise(length,[sample_rate_Hz=44100])

Creates a period of white noise of the given length (in seconds).

You can create an infinite stream of noise (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function noise(length_s=Inf;sample_rate_Hz=samplerate(sound_setup_state))
  if length_s < Inf
	  SampleBuf(1-2rand(floor(Int,length_s*sample_rate_Hz)),sample_rate_Hz)
  else
    NoiseStream(RandomDevice(),stream_unit(),sample_rate_Hz)
  end
end

function next(ns::NoiseStream,::Void)
  SampleBuf(1-2rand(ns.rng,ns.length),ns.samplerate), nothing
end

tone_helper(t,freq,phase) = sin(2π*t * freq + phase)


immutable ToneStream
  freq::Float64
  phase::Float64
  length::Int
  samplerate::Int
end
show(io::IO,as::ToneStream) = write(io,"ToneStream($(freq)Hz)")
start(ts::ToneStream) = 1
done(ts::ToneStream,i::Int) = false

"""
    tone(freq,length,[sample_rate_Hz=44100],[phase=0])

Creates a pure tone of the given frequency and length (in seconds).

You can create an infinitely long tone (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function tone(freq_Hz,length_s=Inf;sample_rate_Hz=samplerate(sound_setup_state),
              phase=0)
  if length_s < Inf
	  t = linspace(0,length_s,round(Int,length_s*sample_rate_Hz))
	  SampleBuf(tone_helper(t,freq_Hz,phase),sample_rate_Hz)
  else
    ToneStream(freq_Hz,phase,stream_unit(),sample_rate_Hz)
  end
end

function next(ts::ToneStream,i::Int)
  t = (ts.length*(i-1):ts.length*i-1) ./ ts.samplerate
  SampleBuf(tone_helper(t,ts.freq,ts.phase),ts.samplerate), i+1
end

function complex_cycle(f0,harmonics,amps,sample_rate_Hz,phases)
  @assert all(0 .<= phases) && all(phases .< 2π)
	n = maximum(harmonics)+1

  # generate single cycle of complex
  cycle_length_s = 1/f0
  cycle_length = floor(Int,sample_rate_Hz*cycle_length_s)
  cycle = zeros(cycle_length)

	highest_freq = tone(f0,2n*cycle_length_s;sample_rate_Hz=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
    wave = highest_freq[(1:cycle_length) * (n-harm) + phase_offset]
		cycle += amp*wave[1:length(cycle)]
	end

  cycle
end

immutable ComplexStream
  cycle::SampleBuf
  length::Int
  samplerate::Int
end
show(io::IO,as::ComplexStream) = write(io,"ComplexStream(...)")
start(cs::ComplexStream) = 0
done(cs::ComplexStream,i::Int) = false

"""
    harmonic_complex(f0,harmonics,amps,length,
                     [sample_rate_Hz=44100],[phases=zeros(length(harmonics))])

Creates a harmonic complex of the given length, with the specified harmonics
at the given amplitudes. This implementation is somewhat superior
to simply summing a number of pure tones generated using `tone`, because
it avoids beating in the sound that may occur due floating point errors.

You can create an infinitely long complex (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function harmonic_complex(f0,harmonics,amps,length_s=Inf;
						              sample_rate_Hz=samplerate(sound_setup_state),
                          phases=zeros(length(harmonics)))
  cycle = complex_cycle(f0,harmonics,amps,sample_rate_Hz,phases)

  if length_s < Inf
    full_length = round(Int,length_s*sample_rate_Hz)
    cycle[(0:full_length-1) .% length(cycle) + 1]
  else
    ComplexStream(cycle,stream_unit(),sample_rate_Hz)
  end
end

function next(cs::ComplexStream,i::Int)
  sound = cs.cycle[(i:i+cs.length-1) .% length(cs.cycle) + 1]
  sound, i+cs.length
end

immutable FilterStream{T}
  filt
  stream::T
  samplerate::Int
end
show(io::IO,filt::FilterStream) = write(io,"FilterStream($filt,$stream)")
start(fs::FilterStream) = DF2TFilter(fs.filt), start(fs.stream)
done{T,S}(fs::FilterStream{T},x::Tuple{DF2TFilter,S}) = done(fs.stream,x[2])
function next{T,S}(fs::FilterStream{T},x::Tuple{DF2TFilter,S})
  filt_state, state = x
  new_filt_state = deepcopy(filt_state)
  sound, state = next(fs.stream,state)
  SampleBuf(filt(new_filt_state,sound),fs.samplerate), (new_filt_state, state)
end

# TODO: after basic streaming is working
# figure out how to stream these filters
"""
    bandpass(x,low,high,[order=5],[sample_rate_Hz=samplerate(x)])

Band-pass filter the sound (or stream) at the specified frequencies.

Filtering uses a butterworth filter of the given order.
"""
bandpass(x::Sound,low,high;keys...) = sound(bandpass_helper(x.buffer,low,high;keys...))
bandpass(x::Array,low,high;keys...) = bandpass_helper(x,low,high;keys...)
bandpass(x::SampleBuf,low,high;keys...) = bandpass_helper(x,low,high;keys...)
function bandpass_helper(x,low,high;order=5,sample_rate_Hz=samplerate(x))
	ftype = Bandpass(float(low),float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end

function bandpass(itr,low,high;order=5,sample_rate_Hz=samplerate(first(itr)))
	ftype = Bandpass(float(low),float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
  FilterStream(f,itr,Int(sample_rate_Hz))
end

"""
    lowpass(x,low,[order=5],[sample_rate_Hz=samplerate(x)])

Low-pass filter the sound (or stream) at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
lowpass(x::Sound,low;keys...) = sound(lowpass_helper(x.buffer,low;keys...))
lowpass(x::Array,low;keys...) = lowpass_helper(x,low;keys...)
lowpass(x::SampleBuf,low;keys...) = lowpass_helper(x,low;keys...)
function lowpass_helper(x,low;order=5,sample_rate_Hz=samplerate(x))
	ftype = Lowpass(float(low),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end

function lowpass(itr,low;order=5,sample_rate_Hz=samplerate(first(itr)))
  ftype = Lowpass(float(low),fs=sample_rate_Hz)
  f = digitalfilter(ftype,Butterworth(order))
	FilterStream(f,itr,Int(sample_rate_Hz))
end

# TODO: implement high and band pass streaming filters

"""
    highpass(x,high,[order=5],[sample_rate_Hz=samplerate(x)])

High-pass filter the sound (or stream) at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
highpass(x::Sound,high;keys...) = sound(highpass_helper(x.buffer,high;keys...))
highpass(x::Array,high;keys...) = highpass_helper(x,high;keys...)
highpass(x::SampleBuf,high;keys...) = highpass_helper(x,high;keys...)
function highpass_helper(x,high;order=5,sample_rate_Hz=samplerate(x))
	ftype = Highpass(float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),sample_rate_Hz)
end

function highpass(itr,high;order=5,sample_rate_Hz=samplerate(first(itr)))
  ftype = Highpass(float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
  FilterStream(f,itr,Int(sample_rate_Hz))
end

# TODO: after basic streaming is working
# figure out how to apply ramps for some period of the stream
"""
    ramp(x,[ramp_s=0.005];[sample_rate_Hz=samplerate(x)])

Applies a half cosine ramp to start and end of the sound.

Ramps prevent clicks at the start and end of sounds.
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

immutable FnStream
  fn::Function
  length::Int
  samplerate::Int
end
start(fs::FnStream) = 1
done(fs::FnStream,i::Int) = false
function next(fs::FnStream,i::Int)
  t = (fs.length*(i-1):fs.length*i-1) ./ fs.samplerate
  SampleBuf(fs.fn.(t),fs.samplerate), i+1
end

"""
    asstream(fn;[sample_rate_Hz=44100])

Converts the function `fn` into a sound stream.

The function `fn` should take a single argument--the time in seconds from the
start of the stream--and should return a number between -1 and 1.
"""
function asstream(fn;sample_rate_Hz=samplerate(sound_setup_state))
  FnStream(fn,stream_unit(),sample_rate_Hz)
end

"""
    rampon(stream,[ramp_s=0.005])

Applies a half consine ramp to start of the stream.
"""
function rampon(stream,ramp_s=0.005)
  sample_rate_Hz = samplerate(first(stream))
  ramp = asstream(sample_rate_Hz=sample_rate_Hz) do t
    t < ramp_s ? -0.5cos(π*(t/ramp_s))+0.5 : 1
  end
  len = size(first(stream),1)
  num_units = ceil(Int,ramp_s*sample_rate_Hz / len)
  mult(stream,take(ramp,num_units))
end

"""
    rampoff(stream,[ramp_s=0.005],[after=0])

Applies a half consine ramp to the stream after `after` seconds, ending the
stream at that point.
"""
function rampoff(itr,ramp_s=0.005,after=0)
  sample_rate_Hz=samplerate(first(itr))
  len = size(first(itr),1)
  ramp = asstream(sample_rate_Hz=sample_rate_Hz) do t
    if t < after
      1
    elseif after <= t < after+ramp_s
      -0.5cos(π*(t - after)/ramp_s + π)+0.5
    else
      0
    end
  end
  num_units = ceil(Int,(after+ramp_s)*sample_rate_Hz / len)
  take(mult(itr,ramp),num_units)
end

# TODO: after basic streaming is working
# figure out how to attenuate the stream
"""
    attenuate(x,atten_dB)

Apply the given decibels of attenuation to the sound (or stream) relative to a
power level of 1.

This function normalizes the sound to have a root mean squared value of 1 and
then reduces the sound by a factor of ``10^{-a/20}``, where ``a`` = `atten_dB`.

If `x` is a stream, attenuate takes an additional keyword argument
`time_constant`. This determines the time across which the sound is
normalized to power 1, which defaults to 1 second.
"""
attenuate(x::Array,atten=20) = attenuate_helper(x,atten)
attenuate(x::SampleBuf,atten=20) = attenuate_helper(x,atten)
attenuate(x::Sound,atten=20) = sound(attenuate_helper(x.buffer,atten))
function attenuate_helper(x,atten_dB)
	10^(-atten_dB/20) * x/sqrt(mean(x.^2))
end

immutable AttenStream{T}
  itr::T
  atten_dB::Float64
  decay::Float64
end

immutable AttenState{T}
  itr_state::T
  μ²::Float64
  N::Float64
end
show(io::IO,as::AttenStream) = write(io,"AttenStream(...,$(as.atten_dB),$(as.decay))")
start{T}(as::AttenStream{T}) = AttenState(start(as.itr),1.0,1.0)
done(as::AttenStream,s::AttenState) = done(as.itr,s.itr_state)
function next{T,S}(as::AttenStream{T},s::AttenState{S})
  xs, itr_state = next(as.itr,s.itr_state)
  ys = similar(xs)
  for i in 1:size(xs,1)
    ys[i,:] = 10^(-as.atten_dB/20) * xs[i,:] ./ sqrt(s.μ² ./ s.N)
    s = AttenState(itr_state,as.decay*s.μ² + mean(xs[i,:])^2,as.decay*s.N + 1)
  end

  ys, s
end

function attenuate(itr,atten_dB=20;time_constant=1)
  sr = samplerate(first(itr))
  AttenStream(itr,float(atten_dB),1 - 1 / (time_constant*sr))
end

const default_sample_rate = 44100
type SoundSetupState
  samplerate::Int
  playing::Dict{Sound,Float64}
  state::Ptr{Void}
  num_channels::Int
  queue_size::Int
  stream_unit::Int
end
const default_stream_unit = 2^10
const sound_setup_state = SoundSetupState(0,Dict(),C_NULL,0,0,default_stream_unit)
isready(s::SoundSetupState) = s.samplerate != 0

"""
    stream_unit()

Report the length in samples of each unit that all sound streams should generate.
"""
stream_unit(s::SoundSetupState=sound_setup_state) = s.stream_unit

"""
    samplerate([sound])

Report the sampling rate of the sound or of any object
that can be turned into a sound.

If no sound is passed, the curent playback sampling rate is reported (as
determiend by [`setup_sound`](@ref)).  The sampling rate of object determines
how many samples per second are used to represent the sound. Objects that can be
converted to sounds assume the sampling rate of the current hardware settings as
defined by [`setup_sound`](@ref).
"""
samplerate(x::Vector) = samplerate(sound_setup_state)
samplerate(x::Matrix) = samplerate(sound_setup_state)
function samplerate(s::SoundSetupState=sound_setup_state)
  if s.samplerate == 0
    default_sample_rate
  else
    s.samplerate
  end
end

# Give some time after the sound stops playing to clean it up.
# This ensures that even when there is some latency
# the sound will not be GC'ed until it is done playing.
const sound_cleanup_wait = 2

# register_sound: ensures that sounds are not GC'ed while they are
# playing. Whenever a new sound is registered it removes sounds that are no
# longer playing. This is called internally by all methods that send requests to
# play sounds to the weber-sound library (implemented in weber_sound.c)
function register_sound(current::Sound,done_at::Float64)
  setstate = sound_setup_state
  setstate.playing[current] = done_at
  for s in keys(setstate.playing)
    done_at = setstate.playing[s]
    if done_at > Weber.tick() + sound_cleanup_wait
      delete!(setstate.playing,s)
    end
  end
end

function ws_if_error(msg)
  if sound_setup_state.state != C_NULL
    str = unsafe_string(ccall((:ws_error_str,weber_sound),Cstring,
                              (Ptr{Void},),sound_setup_state.state))
    if !isempty(str) error(msg*" - "*str) end

    str = unsafe_string(ccall((:ws_warn_str,weber_sound),Cstring,
                              (Ptr{Void},),sound_setup_state.state))
    if !isempty(str) warn(msg*" - "*str) end
  end
end

"""
    setup_sound([sample_rate_Hz=44100],[num_channels=8],[queue_size=8],
                [stream_unit=2^10])

Initialize format and capacity of audio playback.

This function is called automatically (using the default settings) the first
time a `Sound` object is created (normally during [`play`](@ref) or
[`stream`](@ref)).  It need not normally be called explicitly, unless you wish
to change one of the default settings.

# Sample Rate

Sample rate determines the maximum playable frequency (max freq is ≈
sample_rate/2). Changing the sample rate from the default 44100 to a new value
will also change the default sample rate sounds will be created at, to match
this new sample rate.

!!! warning "There is no check for sampling rate"

    Upon playback, there is no check to ensure that the sample rate of a given
    sound is the same as that setup here, and no resampling of the sound is
    made, so it will play incorrectly if the sample rates differ.
    This minimizes the latency of audio playback.

# Channel Number

The number of channels determines the number of sounds and streams that can be
played concurrently. Note that discrete sounds and streams use a distinct set of
channels.

# Queue Size

Sounds can be queued to play ahead of time (using the `time` parameter of
[`play`](@ref)). When you request that a sound be played it may be queued to
play on a channel where a sound is already playing. The number of sounds that
can be queued to play at once is determined by queue size. The number of
channels times the queue size determines the number of sounds that you can queue
up to play ahead of time.

# Stream Unit

The stream unit determines the number of samples that are streamed at one time.
Iterators to be used as streams should generate this many samples at a time.  If
this value is two small for your hardware, streams will sound jumpy. However the
latency for changing from one stream to another will increase as the stream unit
increases.

"""
function setup_sound(;sample_rate_Hz=samplerate(sound_setup_state),
                     buffer_size=nothing,queue_size=8,num_channels=8,
                     stream_unit=default_stream_unit)
  if isready(sound_setup_state)
    ccall((:ws_close,weber_sound),Void,(Ptr{Void},),sound_setup_state.state)
    ws_if_error("While closing old audio stream during setup")
  else

    if !weber_sound_is_setup[]
      weber_sound_is_setup[] = true
      atexit() do
        sleep(0.1)
        ccall((:ws_close,weber_sound),Void,
              (Ptr{Void},),sound_setup_state.state)
        ws_if_error("While closing audio stream at exit.")
        ccall((:ws_free,weber_sound),Void,
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
  sound_setup_state.state = ccall((:ws_setup,weber_sound),Ptr{Void},
                                  (Cint,Cint,Cint,),sample_rate_Hz,
                                  num_channels,queue_size)
  sound_setup_state.num_channels = num_channels
  sound_setup_state.queue_size = queue_size
  sound_setup_state.stream_unit = stream_unit
  ws_if_error("While trying to initialize sound")
end

function play(x;time=0.0,channel=0)
  if in_experiment() && !experiment_running()
    error("You cannot call `play` during experiment `setup`. During `setup`",
          " you should add play to a trial (e.g. ",
          "`addtrial(moment(play,my_sound))`).")
  end
  warn("Calling play outside of an experiment.")
  _play(x,time,channel)
end

function _play(x,time=0.0,channel=0)
  play(sound(x),time,channel)
end

"""
    current_sound_latency()

Reports the current, minimum latency of audio playback.

The current latency depends on your hardware and software drivers. This
estimate does not include the time it takes for a sound to travel from
your sound card to speakers or headphones. This latency estimate is used
internally by [`play`](@ref) to present sounds at accurate times.
"""
function current_sound_latency()
  ccall((:ws_cur_latency,weber_sound),Cdouble,
        (Ptr{Void},),sound_setup_state.state)
end

"""
    play(x;[time=0.0],[channel=0])

Plays a sound (created via `sound`).

For convenience, play can also can be called on any object that can be turned
into a sound (via `sound`).

This function returns immediately with the channel the sound is playing on. You
may provide a specific channel that the sound plays on: only one sound can be
played per channel. Normally it is unecessary to specify a channel, because an
appriate channel is selected for you. However, pausing and resuming of
sounds occurs on a per channel basis, so if you plan to pause a specific
sound, you can do so by specifiying its channel.

If `time > 0`, the sound plays at the given time (in seconds from epoch, or
seconds from experiment start if an experiment is running), otherwise the sound
plays as close to right now as is possible.
"""
function play(x::Sound,time::Float64=0.0,channel::Int=0)
  @assert 1 <= channel <= sound_setup_state.num_channels || channel <= 0
  # first, verify the sound can be played when we want to
  if time > 0.0
    latency = current_sound_latency()
    now = Weber.tick()
    if now + latency > time
      if latency > 0
        warn("Requested timing of sound cannot be achieved. ",
             "With your hardware you cannot request the playback of a sound ",
             "< $(round(1000*latency,2))ms before it begins.")
      else
        warn("Requested timing of sound cannot be achieved. ",
             "Give more time for the sound to be played.")
      end
      if experiment_running()
        record("high_latency",value=(now + latency) - time)
      end
    end
  elseif experiment_running()
    warn("On trial $(Weber.trial()), offset $(Weber.offset()): Cannot guarntee",
         " the timing of a sound. Add a delay to the sound if precise timing",
         " is required.")
  end

  # play the sound
  channel = ccall((:ws_play,weber_sound),Cint,
                  (Cdouble,Cdouble,Cint,Ref{WS_Sound},Ptr{Void}),
                  Weber.tick(),time,channel-1,x.chunk,
                  sound_setup_state.state) + 1
  ws_if_error("While playing sound")
  register_sound(x,(time > 0.0 ? time : Weber.tick()) + duration(x))

  channel
end

type Streamer
  next_stream::Float64
  channel::Int
  itr_state
  itr
end
show(stream::IO,streamer::Streamer) =
  write(stream,"<Streamer channel: $(streamer.channel)>")

function setup_streamers()
  streamers[-1] = Streamer(0.0,0,nothing,nothing)
  Timer(1/60,1/60) do timer
    for streamer in values(streamers)
      if streamer.itr != nothing
        process(streamer)
      end
    end
  end
end

const num_channels = 8
const streamers = Dict{Int,Streamer}()
"""
    stream([itr | fn],channel=1)

Plays sounds continuously on a given channel by reading from the iterator `itr`
whenever more data is required. The iterator should return objects that can be
turned into sounds (via [`sound`](@ref)). The number of available streaming
channels is determined by [`setup_sound`](@ref). The size, in samples, of each
sound returned by this iterator should be equal to [`stream_unit`](@ref).

Alternatively a `fn` can be streamed: this transforms a previously streamed itr
into a new iterator by calling `fn(itr)`. If no stream already exists on the
given channel, `fn` is passed the result of `countfrom()`.

A stream stops playing if the iterator is finished. There can only be one stream
per channel.  Streaming a new iterator on the same channel as another stream
stops the older stream. The channels for `stream` are separate from the channels
for `play`. That is, `play(mysound,channel=1)` plays a sound on a channel
separate from `stream(mystream,1)`.

Returns the time at which the stream will start playing.

!!! warning "Streaming delays the start of a moment."

    When stream is called as a moment, (e.g. `moment(stream,itr,channel)`) it
    will delay the start of the moment so that it begins at the start of the
    stream. The amount of delay depends on how long any currently playing unit
    of an older stream takes to finish playing on the given channel. This delay
    ensures that subsequent moments are synchronized to the start of the stream,
    allowing all events to be well timed with respect to streaming events.

    In general the latency of changing from one stream to another depends
    on how long each sound returned by the iterator is. Streams cannot
    be stopped in the middle of playing back a given unit returned by
    the iterator. This in turn is normally determined by the stream_unit
    value set during the initial call to [`setup_sound`](@ref), which can
    be retrieved using [`stream_unit`](@ref).

"""

function stream(itr,channel::Int=1)
  !isready(sound_setup_state) ? setup_sound() : nothing
  @assert 1 <= channel <= sound_setup_state.num_channels
  itr_state = start(itr)
  obj, itr_state = next(itr,itr_state)
  x = sound(obj,false)
  done_at = -1.0
  stop(channel)

  while (done_at = ccall((:ws_play_next,weber_sound),Cdouble,
                         (Cdouble,Cint,Ref{WS_Sound},Ptr{Void}),
                         tick(),channel-1,x.chunk,sound_setup_state.state)) < 0
    sleep(0.001);
  end
  ws_if_error("While playing sound")
  register_sound(x,done_at)

  if in_experiment()
    data(get_experiment()).streamers[channel] =
      Streamer(done_at - 0.95duration(x),channel,itr_state,itr)
  else
    if isempty(streamers)
      setup_streamers()
    end
    streamers[channel] =
      Streamer(done_at - 0.95duration(x),channel,itr_state,itr)
  end

  (done_at - duration(x))
end

function stream(fn::Function,channel::Int)
  @assert 1 <= channel <= sound_setup_state.num_channels
  dict = in_experiment() ? data(get_experiment()).streamers : streamers
  itr = if channel in keys(dict)
    streamer = dict[channel]
    delete!(dict,channel)
    rest(streamer.itr,streamer.itr_state)
  else
    countfrom()
  end

  stream(fn(itr),channel)
end

"""
    stop(channel)

Stop the stream that is playing on the given channel.
"""
function stop(channel::Int)
  @assert 1 <= channel <= sound_setup_state.num_channels
  if in_experiment()
    delete!(data(get_experiment()).streamers,channel)
  else
    delete!(streamers,channel)
  end
  nothing
end

function process(streamer::Streamer)
  if !done(streamer.itr,streamer.itr_state)
    obj, next_state = next(streamer.itr,streamer.itr_state)
    x = sound(obj,false)
    done_at = -1.0

    done_at = ccall((:ws_play_next,weber_sound),Cdouble,
                    (Cdouble,Cint,Ref{WS_Sound},Ptr{Void}),
                    tick(),streamer.channel-1,x.chunk,
                    sound_setup_state.state)
    ws_if_error("While playing sound")
    if done_at < 0
      # sound not ready to be queued for playing, wait a bit and try again
      streamer.next_stream += 0.05duration(x)
    else
      # sound was queued to play, wait until this queued sound actually
      # starts playing to queue the next stream unit
      register_sound(x,done_at)
      streamer.next_stream += 0.75duration(x)
      streamer.itr_state = next_state
    end
  else stop(streamer.channel) end
end

"""
    play(fn::Function)

Play the sound that's returned by calling `fn`.
"""
function play(fn::Function;keys...)
  play(fn();keys...)
end

"""
    pause_sounds([channel],[isstream])

Pause all sounds (or a stream) playing on a given channel.

If no channel is specified, then all sounds are paused.
"""
function pause_sounds(channel=-1,isstream=false)
  if isready(sound_setup_state)
    @assert 1 <= channel <= sound_setup_state.num_channels || channel <= 0
    ccall((:ws_pause,weber_sound),Void,(Ptr{Void},Cint,Cint,Cint),
          sound_setup_state.state,channel-1,isstream,true)
    ws_if_error("While pausing sounds")
  end
end

"""
    resume_sounds([channel],[isstream])

Resume all sounds (or a stream) playing on a given channel.

If no channel is specified, then all sounds are resumed.
"""
function resume_sounds(channel=-1,isstream=false)
  if isready(sound_setup_state)
    @assert 1 <= channel <= sound_setup_state.num_channels || channel <= 0
    ccall((:ws_pause,weber_sound),Void,(Ptr{Void},Cint,Cint,Cint),
        sound_setup_state.state,channel-1,isstream,false)
    ws_if_error("While resuming audio playback")
  end
end

"""
    duration(x)

Get the duration of the given sound.
"""
duration(s::Sound) = duration(s.buffer)
duration(s::SampleBuf) = size(s,1) / samplerate(s)
function duration(s::Array{Float64};
                  sample_rate_Hz=samplerate(sound_setup_state))
  length(s) / sample_rate_Hz
end
