using DSP
using Lazy
using Unitful

include(joinpath(dirname(@__FILE__),"sound.jl"))
include(joinpath(dirname(@__FILE__),"stream.jl"))
include(joinpath(dirname(@__FILE__),"playback.jl"))

export mix, mult, silence, envelope, noise, highpass, lowpass, bandpass,
  bandstop, tone, ramp, harmonic_complex, attenuate, asstream,
  rampon, rampoff, fadeto, irn

"""
    mix(x,y,...)

mix several sounds (or streams) together so that they play at the same time.

Unlike normal addition, this acts as if each sound is padded with
zeros at the end so that the lengths of all sounds match.
"""
mix{R}(xs::Union{Audible{R},Array}...) = soundop((x,y) -> x .+ y,xs...)

"""
    mult(x,y,...)

Mutliply several sounds (or streams) together. Typically used to apply an
amplitude envelope.

Unlike normal multiplication, this acts as if each sound is padded with
ones at the end so that the lengths of all sounds match.
"""
mult{R}(xs::Union{Audible{R},Array}...) = soundop((x,y) -> x .* y,xs...)

"""
    silence(length;[sample_rate=samplerate()])

Creates period of silence of the given length (in seconds).
"""
function silence(length;sample_rate=samplerate())
  audible(t -> zeros(t),length,false,sample_rate=sample_rate)
end

"""
    envelope(mult,length;[sample_rate_Hz=44100])

creates an envelope of a given multiplier and length (in seconds).

If mult = 0 this is the same as calling [`silence`](@ref). This function
is useful in conjunction with [`fadeto`](@ref) and [`mult`](@ref)
when defining an envelope that changes in level. For example,
the following will play a 1kHz tone for 1 second, which changes
in volume halfway through to a softer level.

    mult(tone(1000,1),fadeto(envelope(1,0.5),envelope(0.1,0.5)))

"""
function envelope(mult,length;sample_rate=samplerate())
  audible(t -> mult*ones(t),length,sample_rate=sample_rate)
end

"""
    noise(length=Inf;[sample_rate_Hz=44100],[rng=RandomDevice()])

Creates a period of white noise of the given length (in seconds).

You can create an infinite stream of noise by passing a length of Inf, or
leaving out the length entirely.
"""
function noise(len=Inf;sample_rate=samplerate(),rng=RandomDevice())
  audible((i::UnitRange{Int}) -> 1.0-2.0rand(rng,length(i)),len,
          false,sample_rate=sample_rate)
end

"""
    tone(freq,length;[sample_rate=samplerate()],[phase=0])

Creates a pure tone of the given frequency and length (in seconds).

You can create an infinitely long tone by passing a length of Inf, or leaving
out the length entirely.
"""
function tone(freq,len=Inf;sample_rate=samplerate(),phase=0.0)
  freq_Hz = ustrip(inHz(freq))
  audible(t -> sin.(2π*t * freq_Hz + phase),len,
          sample_rate=sample_rate)
end

function complex_cycle(f0,harmonics,amps,sample_rate_Hz,phases)
  @assert all(0 .<= phases) && all(phases .< 2π)
	n = maximum(harmonics)+1

  # generate single cycle of complex
  cycle = silence((1/f0),sample_rate=sample_rate_Hz)

	highest_freq = tone(f0,2n*length(cycle)*samples;sample_rate=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
    wave = highest_freq[(1:length(cycle)) * (n-harm) + phase_offset]
		cycle += amp*wave[1:length(cycle)]
	end

  cycle
end

"""
    harmonic_complex(f0,harmonics,amps,length,
                     [sample_rate=samplerate()],[phases=zeros(length(harmonics))])

Creates a harmonic complex of the given length, with the specified harmonics
at the given amplitudes. This implementation is somewhat superior
to simply summing a number of pure tones generated using `tone`, because
it avoids beating in the sound that may occur due floating point errors.

You can create an infinitely long complex by passing a length of Inf, or leaving
out the length entirely.
"""
function harmonic_complex(f0,harmonics,amps,len=Inf;
						              sample_rate=samplerate(),
                          phases=zeros(length(harmonics)))
  cycle = complex_cycle(inHz(f0),harmonics,amps,
                        inHz(Int,sample_rate),phases)
  N = size(cycle,1)
  audible((i::UnitRange{Int}) -> cycle[(i.-1) .% N + 1],len,false,sample_rate=sample_rate)
end

"""
    irn(n,λ,[length=Inf];[g=1],[sample_rate=samplerate()],
                         [rng=Base.GLOBAL_RNG()])

Creates an iterated ripple ``y_n(t)`` for a noise ``y_0(t)`` according to
the following formula.

``
y_n(t) = y_{n-1}(t) + g⋅y_{n-1}(t-d)

You can create an infinitely long IRN by passing a length of Inf, or leaving
out the length entirely.

!!! note "RNG must be reproduceable"

    For the streaming implementation, the noise's RNG is copied to generate the
    iterations, so copying this RNG must reliabley reproduce the same sequence
    of noise.  This means you cannot use `RandomDevice`.
``
"""
function irn(n,λ,length=Inf;g=1,sample_rate=samplerate(),rng=Base.GLOBAL_RNG)
  irn_helper(noise(length,sample_rate=sample_rate,rng=rng),n,λ,g,rng)
end

function irn_helper(source,n,λ,g,rng)
  if n == 0
    source
  else
    irn_helper(mix(source,[silence(λ); g * source_again(source,rng)]),n-1,λ,g,rng)
  end
end

source_again(source::Sound,rng) = source
source_again(source::Stream,rng) = noise(rng=deepcopy(rng))

"""
    bandpass(x,low,high;[order=5])

Band-pass filter the sound (or stream) at the specified frequencies.

Filtering uses a butterworth filter of the given order.
"""
bandpass(x,low,high;order=5) = filter_helper(x,low,high,Bandpass,order)

"""
    bandstop(x,low,high,[order=5],[sample_rate_Hz=samplerate(x)])

Band-stop filter of the sound (or stream) at the specified frequencies.

Filtering uses a butterworth filter of the given order.
"""
bandstop(x,low,high;order=5) = filter_helper(x,low,high,Bandstop,order)

"""
    lowpass(x,low,[order=5],[sample_rate_Hz=samplerate(x)])

Low-pass filter the sound (or stream) at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
lowpass(x,low;order=5) = filter_helper(x,low,0,Lowpass,order)

"""
    highpass(x,high,[order=5],[sample_rate_Hz=samplerate(x)])

High-pass filter the sound (or stream) at the specified frequency.

Filtering uses a butterworth filter of the given order.
"""
highpass(x,high;order=5) = filter_helper(x,0,high,Highpass,order)

function buildfilt(samplerate,low,high,kind)
  if kind == Bandpass
	  Bandpass(float(ustrip(inHz(low))),float(ustrip(inHz(high))),fs=samplerate)
  elseif kind == Lowpass
    Lowpass(float(ustrip(inHz(low))),fs=samplerate)
  elseif kind == Highpass
    Highpass(float(ustrip(inHz(high))),fs=samplerate)
  elseif kind == Bandstop
    Bandstop(float(ustrip(inHz(low))),float(ustrip(inHz(high))),fs=samplerate)
  end
end

function filter_helper(audible,low,high,kind,order)
  ftype = buildfilt(ustrip(samplerate(audible)),low,high,kind)
	f = digitalfilter(ftype,Butterworth(order))
  audiofn(x -> filt(f,x),audible)
end

"""
    ramp(x,[length=5ms])

Applies a half cosine ramp to start and end of the sound.

Ramps prevent clicks at the start and end of sounds.
"""
function ramp{R}(x::Sound{R},len=5ms)
  ramp_n = insamples(len,R*Hz)
	if nsamples(x) < 2ramp_n
    error("Cannot apply two $(rounded_time(len,R)) ramps to ",
          "$(rounded_time(duration(x),R)) sound.")
  end

  n = nsamples(x)
	r = audible(duration(x),false,sample_rate=R*Hz) do t
    ifelse.(t .< ramp_n,
      -0.5.*cos.(π.*t./ramp_n).+0.5,
    ifelse.(t .< n .- ramp_n,
      1,
      -0.5.*cos.(π.*(t .- n .+ ramp_n)./ramp_n.+π).+0.5))
	end
	mult(x,r)
end

"""
    rampon(stream,[len=5ms])

Applies a half consine ramp to start of the sound or stream.
"""
function rampon{R}(x::Audible{R},len=5ms)
  ramp_n = insamples(len,R*Hz)
	if nsamples(x) < ramp_n
    error("Cannot apply a $(rounded_time(len,R)) ramp to ",
          "$(rounded_time(duration(x),R)) sound.")
  end

	r = audible(ramp_n*samples,false,sample_rate=R*Hz) do t
    -0.5.*cos.(π.*t./ramp_n).+0.5
	end
	mult(x,r)
end

"""
    rampoff(stream,[len=5ms],[after=0s])

Applies a half consine ramp to the end sound, or to a stream.

For streams, you may specify how many seconds after the call to
rampff the stream should end.
"""

function rampoff{R}(x::Sound{R},len=5ms)
  rampoff_helper(x,insamples(len,R*Hz),nsamples(x))
end

function rampoff{R}(x::AbstractStream{R},len=5ms,after=0ms)
  rampoff_helper(x,insamples(len,R*Hz),insamples(after,R*Hz))
end

function rampoff_helper{R}(x::Audible{R},len::Int,after::Int)
	if !(0 < after <= nsamples(x))
    if len > nsamples(x)
      error("Cannot apply $(rounded_time(len/R,R)) ramp to",
            " $(rounded_time(duration(x),R)) of audio.")
    else
      error("Cannot apply $(rounded_time(len/R,R)) ramp after ",
            "$(rounded_time(after/R - len/R,R)) to",
            " $(rounded_time(duration(x),R)) of audio.")
    end
  end

  rampstart = (after - len)
	r = audible(after*samples,false) do t
    ifelse.(t .< rampstart,1,-0.5.*cos.(π.*(t.-rampstart)./len.+π).+0.5)
	end
	mult(limit(x,after),r)
end

"""
    fadeto(stream,channel=1,transition=50ms)

A smooth transition from the currently playing stream to another stream.
"""
function fadeto(new::AbstractStream,channel::Int=1,transition=50ms)
  old = streamon(channel)
  if isnull(old)
    rampon(new,transition)
  else
    mix(rampoff(get(old),transition),rampon(new,transition))
  end
end

"""
    fadeto(sound1,sound2,overlap=50ms)

A smooth transition from sound1 to sound2, overlapping the end of sound1
and the start of sound2 by `overlap` (in seconds).
"""
function fadeto{R}(a::Sound{R},b::Sound{R},overlap=50ms)
  mix(rampoff(a,overlap),
      [silence(duration(a) - overlap); rampon(b,overlap)])
end

"""
    attenuate(x,atten_dB;[time_constant])

Apply the given decibels of attenuation to the sound (or stream) relative to a
power level of 1.

This function normalizes the sound to have a root mean squared value of 1 and
then reduces the sound by a factor of ``10^{-a/20}``, where ``a`` = `atten_dB`.

The keyword argument `time_constant` determines the time across which the sound
is normalized to power 1, which, for sounds, defaults to the entire sound and,
for streams, defaults to 1 second.
"""
# TODO: allow a time constant for Sound's using braodcast operator
function attenuate(x::Sound,atten_dB)
	similar(x) .= 10^(-atten_dB/20) .* x ./ rms(x)
end
function attenuate(x::AbstractStream,atten_dB;time_constant=1s)
	audiofn(soundop((x,y) -> x ./ y,x,rms(x,time_constant))) do x
    10^(-atten_dB/20) .* x
  end
end

rms(x::Sound) = sqrt(mean(x.^2))
function rms{R}(audio::Audible{R},len)
  decay = 1 - 1 / (ustrip(inseconds(len,R))*R)
  let μ² = 1.0, N = 1.0
    audiofn(audio) do xs
      ys = similar(xs,size(xs,1))
      for i in 1:size(xs,1)
        ys[i] = sqrt(μ² ./ N)
        μ² = decay*μ² + mean(xs[i,:])^2
        N = decay*N + 1
      end
      ys
    end
  end
end
