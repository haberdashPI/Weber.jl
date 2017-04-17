using DSP
using Lazy
using Unitful

# TODO: define streaming and sounds with same code that
# makes call to general function which takes a standard interface
# for defining elements of the sound

include(joinpath(dirname(@__FILE__),"sound.jl"))
include(joinpath(dirname(@__FILE__),"playback.jl"))

export mix, mult, silence, envelope, noise, highpass, lowpass, bandpass,
  bandstop, tone, ramp, harmonic_complex, attenuate, asstream,
  rampon, rampoff, fadeto

# TODO: I will probably reimplement streams using a different
# interface, to allow said interface to request how much
# of the stream to present, rather than fixing that value,
# this means I probably shouldn't bother troubleshooting
# the streaming functions, since they'll change quickly anyways
# (might be worth commenting them out....)

function soundop{R}(op,xs::Union{Sound{R},Array}...)
  len = maximum(map(x -> size(x,1),xs))
  channels = maximum(map(x -> size(x,2),xs))
  y = similar(xs[1],(len,channels))

  for i in 1:size(y,1)
    used = false
    for j in 1:length(xs)
      if i <= size(xs[j],1)
        if !used
          used = true
          @inbounds y[i,:] = xs[j][i,:]
        else
          @inbounds y[i,:] = op(y[i,:],xs[j][i,:])
        end
      end
    end
  end

  y
end

# immutable OpStream
#   streams::Tuple
#   op::Function
# end
# immutable OpState
#   streams::Tuple
#   states::Tuple
# end
# immutable OpPassState
#   stream
#   state
# end

# start(ms::OpStream) = OpState(ms.streams,map(start,ms.streams))
# done(ms::OpStream,state::OpState) = all(map(done,state.streams,state.states))
# done(ms::OpStream,state::OpPassState) = done(state.stream,state.state)
# @inline
# function next(ms::OpStream,state::OpPassState)
#   obj, pass_state = next(state.stream,state.state)
#   obj, OpPassState(state.stream,pass_state)
# end
# function next(ms::OpStream,state::OpState)
#   undone = find(map((stream,state) -> !done(stream,state),state.streams,state.states))
#   streams = state.streams[undone]
#   states = state.states[undone]

#   nexts = map(next,streams,states)
#   sounds = map(x -> x[1],nexts)
#   states = map(x -> x[2],nexts)

#   if length(undone) > 1
#     reduce(ms.op,sounds), OpState(streams,states)
#   else
#     sounds[1], OpPassState(streams[1],states[1])
#   end
# end

"""
    mix(x,y,...)

Mix several sounds (or streams) together so that they play at the same time.

Unlike normal addition, this acts as if each sound is padded with
zeros at the end so that the lengths of all sounds match.
"""
mix{R}(xs::Union{Sound{R},Array}...) = soundop(.+,xs...)
# mix(itrs...) = OpStream(itrs,+)

"""
    mult(x,y,...)

Mutliply several sounds (or streams) together. Typically used to apply an
amplitude envelope.

Unlike normal multiplication, this acts as if each sound is padded with
ones at the end so that the lengths of all sounds match.
"""
mult{R}(xs::Union{Sound{R},Array}...) = soundop(.*,xs...)
# mult(itrs...) = OpStream(itrs,.*)

"""
    silence(length,stereo=true;[sample_rate=samplerate()])

Creates period of silence of the given length (in seconds).
"""
function silence(length,stereo=true;sample_rate=samplerate())
  len = insamples(length,sample_rate)
  N = stereo? 2 : 1
  Sound{ustrip(inHz(Int,sample_rate)),Float64,N}(zeros(len,N))
end

"""
    envelope(mult,length,stereo=true;[sample_rate_Hz=44100])

Creates an evelope of a given multiplier and length (in seconds).

If mult = 0 this is the same as calling silence. This function
is useful in conjunction with [`fadeto`](@ref) and [`mult`](@ref)
when defining an envelope that changes in level. For example,
the following will play a 1kHz tone for 1 second, which changes
in volume halfway through to a softer level.

    mult(tone(1000,1),fadeto(envelope(1,0.5),envelope(0.1,0.5)))

"""
function envelope(mult,length,stereo=true;sample_rate=samplerate())
  N = stereo? 2 : 1
  vals = ones(insample(length,sample_rate),N)
  Sound{ustrip(inHz(Int,sample_rate))}(vals,N)
end


# TODO: implement these functions for streams

# immutable NoiseStream{R,N}
#   rng::RandomDevice
#   length::Int
# end
# show(io::IO,as::NoiseStream) = write(io,"NoiseStream()")
# start(ns::NoiseStream) = nothing
# done(ns::NoiseStream,::Void) = false

"""
    noise(length=Inf,stereo=true;[sample_rate_Hz=44100],[rng=global RNG])

Creates a period of white noise of the given length (in seconds).

You can create an infinite stream of noise (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function noise(length=Inf,stereo=true;
               sample_rate=samplerate(),rng=Base.GLOBAL_RNG)
  R = ustrip(inHz(Int,sample_rate))
  N = stereo? 2 : 1
  if ustrip(length) < Inf
    len = insamples(length,sample_rate)
    if stereo
	    Sound{R,Float64,N}(hcat(1-2rand(rng,len),1-2rand(rng,len)))
    else
      Sound{R,Float64,N}(hcat(1-2rand(rng,len)))
    end
  else
    nothing # NoiseStream{R,stereo? 2 : 1}(RandomDevice(),stream_unit())
  end
end

# function next{R}(ns::NoiseStream{R,1},::Void)
#   Sound{R}(1-2rand(ns.rng,ns.length)), nothing
# end

# function next{R}(ns::NoiseStream{R,2},::Void)
#   Sound{R}(hcat(1-2rand(ns.rng,ns.length),1-2rand(ns.rng,ns.length))), nothing
# end

function tone_helper(t,freq,phase,stereo)
  x = sin(2π*t * freq + phase)
  if stereo
    hcat(x,x)
  else
    x
  end
end

# immutable ToneStream{R,N}
#   freq::Freq{Float64}
#   phase::Float64
#   length::Int
# end
# show(io::IO,as::ToneStream) = write(io,"ToneStream($freq)")
# start(ts::ToneStream) = 1
# done(ts::ToneStream,i::Int) = false

"""
    tone(freq,length;[sample_rate=samplerate()],[phase=0])

Creates a pure tone of the given frequency and length (in seconds).

You can create an infinitely long tone (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function tone(freq,len=Inf,stereo=true;sample_rate=samplerate(),phase=0)
  sample_rate_Hz = inHz(Int,sample_rate)
  R = ustrip(sample_rate_Hz)
  N = stereo? 2 : 1
  if ustrip(len) < Inf
    length_s = inseconds(len)
	  t = linspace(0,ustrip(length_s),ustrip(insamples(length_s,sample_rate_Hz)))
    x = tone_helper(t,ustrip(inHz(freq)),phase,stereo)
    T = eltype(x)
	  Sound{R,T,N}(x)
  else
    nothing # ToneStream{R,N}(inHz(freq_Hz),phase,stream_unit())
  end
end

# function next{R,N}(ts::ToneStream{R,N},i::Int)
#   t = (ts.length*(i-1):ts.length*i-1) ./ R
#   Sound{R}(tone_helper(t,ustrip(ts.freq),ts.phase,N == 2)), i+1
# end

function complex_cycle(f0,harmonics,stereo,amps,sample_rate_Hz,phases)
  @assert all(0 .<= phases) && all(phases .< 2π)
	n = maximum(harmonics)+1

  # generate single cycle of complex
  cycle_length_s = 1/f0
  cycle = zeros(insamples(cycle_length_s,sample_rate_Hz))

	highest_freq = tone(f0,2n*cycle_length_s;sample_rate=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
    wave = highest_freq[(1:length(cycle)) * (n-harm) + phase_offset]
		cycle += amp*wave[1:length(cycle)]
	end

  if stereo
    hcat(cycle,cycle)
  else
    cycle
  end
end

# immutable ComplexStream{R,N}
#   cycle::Sound
#   length::Int
#   stereo::Bool
# end
# show(io::IO,as::ComplexStream) = write(io,"ComplexStream(...)")
# start(cs::ComplexStream) = 0
# done(cs::ComplexStream,i::Int) = false

"""
    harmonic_complex(f0,harmonics,amps,length,stereo=false,
                     [sample_rate=samplerate()],[phases=zeros(length(harmonics))])

Creates a harmonic complex of the given length, with the specified harmonics
at the given amplitudes. This implementation is somewhat superior
to simply summing a number of pure tones generated using `tone`, because
it avoids beating in the sound that may occur due floating point errors.

You can create an infinitely long complex (playable with [`stream`](@ref)) by
passing a length of Inf, or leaving out the length entirely.
"""
function harmonic_complex(f0,harmonics,amps,len=Inf,stereo=true;
						              sample_rate=samplerate(),
                          phases=zeros(length(harmonics)))
  sample_rate_Hz = inHz(Int,sample_rate)
  cycle = complex_cycle(inHz(f0),harmonics,stereo,amps,sample_rate_Hz,phases)
  R = ustrip(sample_rate_Hz)
  N = stereo? 2 : 1
  if ustrip(len) < Inf
    n = insamples(len,sample_rate)
    if stereo
      Sound{R,Float64,N}(cycle[(0:n-1) .% size(cycle,1) + 1,:])
    else
      Sound{R,Float64,N}(cycle[(0:n-1) .% size(cycle,1) + 1])
    end
  else
    nothing # ComplexStream{R}(cycle,stream_unit(),stereo)
  end
end

# function next{R}(cs::ComplexStream{R,1},i::Int)
#   Sound{R}(cs.cycle[(i:i+cs.length-1) .% length(cs.cycle) + 1]), i+cs.length
# end

# function next{R}(cs::ComplexStream{R,2},i::Int)
#   Sound{R}(cs.cycle[(i:i+cs.length-1) .% length(cs.cycle) + 1,:]), i+cs.length
# end

# immutable FilterStream{R,T,N,I}
#   filt
#   stream::I
# end
# show(io::IO,filt::FilterStream) = write(io,"FilterStream($filt,$stream)")
# start(fs::FilterStream) = DF2TFilter(fs.filt), start(fs.stream)
# done{T,S}(fs::FilterStream{T},x::Tuple{DF2TFilter,S}) = done(fs.stream,x[2])
# function next{R,T,N,I,J}(fs::FilterStream{R,T,N,I},x::Tuple{DF2TFilter,J})
#   filt_state, state = x
#   new_filt_state = deepcopy(filt_state)
#   sound, state = next(fs.stream,state)

#   Sound{R,T,N}(filt(new_filt_state,sound.data)), (new_filt_state, state)
# end

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

function filter_helper{R,T,N}(x::Sound{R,T,N},low,high,kind,order)
  ftype = buildfilt(R,low,high,kind)
	f = digitalfilter(ftype,Butterworth(order))
  Sound{R,T,N}(mapslices(slice -> filt(f,slice),x.data,1))
end

# function filter_helper(itr,low,hihg,kind;order=5)
#   first_x = first(itr)
#   R = ustrip(samplerate(first_x))
#   T = eltype(first_x)
#   N = ndims(first_x)

#   ftype = buildfilt{R}(low,high,kind)
# 	f = digitalfilter(ftype,Butterworth(order))
#   FilterStream{R,T,N}(f,itr)
# end

"""
    ramp(x,[length=5ms])

Applies a half cosine ramp to start and end of the sound.

Ramps prevent clicks at the start and end of sounds.
"""
function ramp{R}(x::Sound{R},len=5ms)
	ramp_len = insamples(len,R*Hz)
	@assert nsamples(x) > 2ramp_len

	ramp_t = (1.0:ramp_len) / ramp_len
	up = -0.5cos(π*ramp_t)+0.5
	down = -0.5cos(π*ramp_t+π)+0.5
	envelope = [up; ones(size(x,1) - 2*ramp_len); down]
	mult(x,envelope)
end

# immutable FnStream{R}
#   fn::Function
#   length::Int
# end
# start(fs::FnStream) = 1
# done(fs::FnStream,i::Int) = false
# function next{R}(fs::FnStream{R,1},i::Int)
#   t = (fs.length*(i-1):fs.length*i-1) ./ fs.samplerate
#   MonoSound{R}(fs.fn.(t)), i+1
# end

# """
#     asstream(fn;[sample_rate_Hz=44100])

# Converts the function `fn` into a sound stream.

# The function `fn` should take a single argument--the time in seconds from the
# start of the stream--and should return a number between -1 and 1.
# """
# function asstream(fn;sample_rate=samplerate())
#   R = ustrip(inHz(Int,sample_rate))
#   FnStream{R}(fn,stream_unit())
# end

# """
#     rampon(stream,[len=5ms])

# Applies a half consine ramp to start of the sound or stream.
# """
# function rampon(stream,len=5ms)
#   sample_rate = samplerate(first(stream))
#   ramp_len = inseconds(len)
#   ramp = asstream(sample_rate=sample_rate) do t
#     t < ramp_len ? -0.5cos(π*(t/ustrip(ramp_len)))+0.5 : 1
#   end
#   stream_len = size(first(stream),1)
#   num_units = ceil(Int,insamples(ramp_len,sample_rate) / stream_len)
#   mult(stream,take(ramp,num_units))
# end


function rampon{R}(x::Sound{R},len=5ms)
  ramp_len = insamples(len,R*Hz)
	@assert size(x,1) > ramp_len

	ramp_t = (1.0:ramp_len) / ramp_len
	up = -0.5cos(π*ramp_t)+0.5
	envelope = [up; ones(size(x,1) - ramp_len)]
	mult(x,envelope)
end


# """
#     rampoff(stream,[len=5ms],[after=0s])

# Applies a half consine ramp to the end of the sound.

# For streams, you may specify that the ramp off occur some number of seconds
# after the start of the stream.
# """
# function rampoff(itr,len=5ms,after=0s)
#   sample_rate=samplerate(first(itr))
#   stream_len = size(first(itr),1)
#   ramp = asstream(sample_rate=sample_rate) do t
#     if t < after
#       1
#     elseif after <= t < after+len
#       -0.5cos(π*(t - after)/ustrip(len) + π)+0.5)
#     else
#       0
#     end
#   end
#   num_units = ceil(Int,insamples(after+len,sample_rate) / stream_len)
#   take(mult(itr,ramp),num_units)
# end

function rampoff{R}(x::Sound{R},len=5ms)
  ramp_len = insamples(len,R*Hz)
  @assert size(x,1) > ramp_len

  ramp_t = (1.0:ramp_len) / ramp_len
	down = -0.5cos(π*ramp_t+π)+0.5
  envelope = [ones(size(x,1) - ramp_len); down]
  mult(x,envelope)
end


# """
#     fadeto(stream,channel=1,transition=0.05)

# Smoothly transition from the currently playing stream to another stream.
# """
# function fadeto(new,channel::Int=1,transition=0.05)
#   stream(channel) do old
#     if isa(first(old),Number)
#       rampon(new,transition)
#     else
#       mix(rampoff(old,transition),rampon(new,transition))
#     end
#   end
# end

"""
    fadeto(sound1,sound2,overlap=0.05)

A smooth transition from sound1 to sound2, overlapping the end of sound1
and the start of sound2 by `overlap` (in seconds).
"""
function fadeto{R}(a::Sound{R},b::Sound{R},overlap=50ms)
  mix(rampoff(a,overlap),
      [silence(duration(a) - overlap); rampon(b,overlap)])
end

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
function attenuate(x::Sound,atten_dB)
	10^(-atten_dB/20) * x/sqrt(mean(x.^2))
end

# immutable AttenStream{T}
#   itr::T
#   atten_dB::Float64
#   decay::Float64
# end

# immutable AttenState{T}
#   itr_state::T
#   μ²::Float64
#   N::Float64
# end
# show(io::IO,as::AttenStream) = write(io,"AttenStream(...,$(as.atten_dB),$(as.decay))")
# start{T}(as::AttenStream{T}) = AttenState(start(as.itr),1.0,1.0)
# done(as::AttenStream,s::AttenState) = done(as.itr,s.itr_state)
# function next{T,S}(as::AttenStream{T},s::AttenState{S})
#   xs, itr_state = next(as.itr,s.itr_state)
#   ys = similar(xs)
#   for i in 1:size(xs,1)
#     ys[i,:] = 10^(-as.atten_dB/20) * xs[i,:] ./ sqrt(s.μ² ./ s.N)
#     s = AttenState(itr_state,as.decay*s.μ² + mean(xs[i,:])^2,as.decay*s.N + 1)
#   end

#   ys, s
# end

# function attenuate(itr,atten_dB=20;time_constant=1)
#   sr = samplerate(first(itr))
#   AttenStream(itr,float(atten_dB),1 - 1 / (time_constant*sr))
# end
