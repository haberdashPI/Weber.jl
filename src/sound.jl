using FixedPointNumbers
using LRUCache
using Unitful
using FileIO

import Unitful: ms, s, kHz, Hz

import FileIO: save
import DSP: resample
import LibSndFile
import SampledSignals: samplerate
import SampledSignals
import Distributions: nsamples
import Base: show, length, start, done, next, linearindexing, size, getindex,
  setindex!, vcat, similar, convert, .*, .+

export sound, duration, nchannels, nsamples, save, samplerate, length,
  ms, s, kHz, Hz, vcat, leftright, similar, .., between, left, right

immutable Sound{R,T,N} <: AbstractArray{T,N}
  data::Array{T,N}
  function Sound(a::Array{T,N})
    if T <: Integer
      error("Cannot use integer arrays for a sound. ",
            "Use FixedPointNumbers instead.")
    end

    if N == 1
      new(a)
    elseif N == 2
      new(a)
    else
      error("Unexpected dimension count $N for sound array, should be 1",
            " (for mono) or 2 (for mono or stereo).")
    end
  end
end
convert{R,T,N}(::Type{Sound{R,T,N}},x) = Sound{R,T,N}(convert(Array{T,N},x))
function convert{R,T,S,N}(::Type{Sound{R,T,N}},x::Sound{R,S,N})
  Sound{R,T,N}(convert(Array{T,N},x.data))
end
function convert{R,Q,T,S}(::Type{Sound{R,T}},x::Sound{Q,S})
  error("Cannot convert a sound with sampling rate $(Q*Hz) to a sound with ",
        "sampling rate $(R*Hz). Use `resample` to change the sampling rate.")
end
typealias TimeDim Unitful.Dimensions{(Unitful.Dimension{:Time}(1//1),)}
typealias FreqDim Unitful.Dimensions{(Unitful.Dimension{:Time}(-1//1),)}
typealias Time{N} Quantity{N,TimeDim}
typealias Freq{N} Quantity{N,FreqDim}


"""
    samplerate([sound])

Report the sampling rate of the sound or of any object
that can be turned into a sound.

The sampling rate of an object determines how many samples per second are used
to represent the sound. Objects that can be converted to sounds are assumed to
be at the sampling rate of the current hardware settings as defined by
[`setup_sound`](@ref).
"""
samplerate(x::Vector) = samplerate()
samplerate(x::Matrix) = samplerate()
samplerate{R}(x::Sound{R}) = R*Hz

length(x::Sound) = length(x.data)

"""
    duration(x)

Get the duration of the given sound in seconds.
"""
duration{R}(x::Sound{R}) = uconvert(s,nsamples(x) / (R*Hz))
nchannels(x::Sound) = size(x.data,2)

"""
    nsamples(x::Sound)

Returns the number of samples in the sound.
"""
nsamples(x::Sound) = size(x.data,1)
size(x::Sound) = size(x.data)
linearindexing(t::Type{Sound}) = Base.LinearSlow()

# adapted from:
# https://github.com/JuliaAudio/SampledSignals.jl/blob/0a31806c3f7d382c9aa6db901a83e1edbfac62df/src/SampleBuf.jl#L109-L139
function show{R}(io::IO, x::Sound{R})
  seconds = round(ustrip(duration(x)),ceil(Int,log(10,R)))
  typ = if eltype(x) == Q0f15
    "16 bit PCM"
  elseif eltype(x) <: AbstractFloat
    "$(sizeof(eltype(x))*8) bit floating-point"
  else
    eltype(x)
  end

  channel = size(x.data,2) == 1 ? "mono" : "stereo"

  println(io, "$seconds s $typ $channel sound")
  print(io, "Sampled at $(R*Hz)")
  nsamples(x) > 0 && showchannels(io, x)
end
show(io::IO, ::MIME"text/plain", x::Sound) = show(io,x)

const ticks = ['_','▁','▂','▃','▄','▅','▆','▇']
function showchannels(io::IO, x::Sound, widthchars=80)
  # number of samples per block
  blockwidth = round(Int, nsamples(x)/widthchars, RoundUp)
  nblocks = round(Int, nsamples(x)/blockwidth, RoundUp)
  blocks = Array(Char, nblocks, nchannels(x))
  for blk in 1:nblocks
    i = (blk-1)*blockwidth + 1
    n = min(blockwidth, nsamples(x)-i+1)
    peaks = sqrt.(mean(float(x[(1:n)+i-1,:]).^2,1))
    # clamp to -60dB, 0dB
    peaks = clamp(20log10(peaks), -60.0, 0.0)
    idxs = trunc(Int, (peaks+60)/60 * (length(ticks)-1)) + 1
    blocks[blk, :] = ticks[idxs]
  end
  for ch in 1:nchannels(x)
    println(io)
    print(io, convert(String, blocks[:, ch]))
  end
end


@inline function getindex(x::Sound,i::Int)
  @boundscheck checkbounds(x.data,i)
  @inbounds return x.data[i]
end

@inline function setindex!{R,T,S}(x::Sound{R,T},v::S,i::Int)
  @boundscheck checkbounds(x.data,i)
  @inbounds return x.data[i] = convert(T,v)
end


@inline function getindex(x::Sound,i::Int,j::Int)
  @boundscheck checkbounds(x.data,i,j)
  @inbounds return x.data[i,j]
end

@inline function setindex!{R,T,S}(x::Sound{R,T},v::S,i::Int,j::Int)
  @boundscheck checkbounds(x.data,i,j)
  @inbounds return x.data[i,j] = convert(T,v)
end

"""
    left(sound::Sound)

Extract the left channel a sound.

For a single channel (mono) sound, this transforms the sound into a stereo sound
with the given samples as the left channel, and a silent right channel. For a
double channel (stereo) sound, this transforms the sound into a stereo
sound with a silenced right channel.
"""
function left{R,T,N}(sound::Sound{R,T,N})
  channel = if size(sound.data,2) == 1
    sound.data
  else
    sound.data[:,1]
  end
  Sound{R,T,N}(hcat(channel,(zereos(T,size(sound,1)))))
end

"""
    right(sound::Sound)

Extract the right channel of a sound.

For a single channel (mono) sound, this transforms the sound into a stereo sound
with the given samples as the right channel, and a silent left channel. For a
double channel (stereo) sound, this transforms the sound into a stereo
sound with a silenced left channel.
"""
function right{R,T,N}(sound::Sound{R,T,N})
  channel = if size(sound.data,2) == 1
    sound.data
  else
    sound.data[:,2]
  end
  Sound{R,T,N}(hcat((zereos(T,size(sound,1))),channel))
end

immutable SampleRange{N,M}
  from::Time{N}
  to::Time{M}
end

immutable SampleEndRange{N}
  from::Time{N}
  possible_end::Int
end

"""
   between(a::Quantity,b::Quantity)
   a .. b

Specifies the range of sound samples in the range [a,b): inclusive of the sound
sample preciesly at time a, all samples between a and b, but excusive of the
sample at time b.

While a and b must normally both be specified as time quantities, a special
exception is made for the use of end, e.g. sound[2s .. end], can be used to
specify all samples occuring from 2 seconds or later.
"""
between{N,M}(from::Time{N},to::Time{M}) = SampleRange(from,to)
between{N}(from::Time{N},to::Int) = SampleEndRange(from,to)
const .. = between

insamples(time,rate) = floor(Int,ustrip(inseconds(time)*inHz(rate)))
function insamples{N,M}(time::Time{N},rate::Freq{M})
  floor(Int,ustrip(uconvert(s,time)*uconvert(Hz,rate)))
end

function checktime(time)
  if time < 0s
    throw(BoundsError("Unexpected negative time."))
  end
end

const Left = typeof(left)
const Right = typeof(right)
@inline @Base.propagate_inbounds function getindex(x::Sound,ixs,js::Left)
  getindex(x,ixs,1)
end
@inline @Base.propagate_inbounds function setindex!(x::Sound,vals,ixs,js::Left)
  setindex!(x,vals,ixs,1)
end
@inline @Base.propagate_inbounds function getindex(x::Sound,ixs,js::Right)
  getindex(x,ixs,2)
end
@inline @Base.propagate_inbounds function setindex!(x::Sound,vals,ixs,js::Right)
  setindex!(x,vals,ixs,2)
end

@inline function getindex{R,T,I,N}(x::Sound{R,T,N},ixs::SampleEndRange,js::I)
  if nsamples(x) == ixs.possible_end
    @boundscheck checktime(ixs.from)
    from = max(1,insamples(ixs.from,R*Hz))
    @boundscheck checkbounds(x.data,from,js)
    @inbounds return Sound{R,T,N}(x.data[from:end,js])
  else
    error("Cannot specify range of samples using a mixture of times and ",
          "integers. Use only integers or only times (but `end` works in ",
          "either context).")
  end
end

@inline function getindex{R,T,I,N}(x::Sound{R,T,N},ixs::SampleRange,js::I)
  @boundscheck checktime(ixs.from)
  from = max(1,insamples(ixs.from,R*Hz))
  to = insamples(ixs.to,R*Hz)-1
  @boundscheck checkbounds(x.data,from,js)
  @boundscheck checkbounds(x.data,to,js)
  @inbounds return Sound{R,T,N}(x.data[from:to,js])
end

@inline function setindex!{R,T,I}(x::Sound{R,T},vals::AbstractVector,
                                  ixs::SampleEndRange,js::I)
  if nsamples(x) == ixs.possible_end
    @boundscheck checktime(ixs.from)
    from = max(1,insamples(ixs.from,R*Hz))
    @boundscheck checkbounds(x.data,from,js)
    @inbounds x.data[from:end,js] = vals
    vals
  else
    error("Cannot specify range of samples using a mixture of times and ",
          "integers. Use only integers or only times (but `end` works in ",
          "either context).")
  end
end

@inline function setindex!{R,T,I}(x::Sound{R,T},vals::AbstractVector,
                                  ixs::SampleRange,js::I)
  @boundscheck checktime(ixs.from)
  from = max(1,insamples(ixs.from,R*Hz))
  to = insamples(ixs.to,R*Hz)-1
  @boundscheck checkbounds(x.data,from,js)
  @boundscheck checkbounds(x.data,to,js)
  @inbounds x.data[from:to,js] = vals
  vals
end

function similar{R,T,S,N,M}(x::Sound{R,T,N},::Type{S},dims::NTuple{M,Int})
  if M ∉ [1,2] || (M == 2 && dims[2] ∉ [1,2])
    similar(x.data,S,dims)
  else
    Sound{R,S,M}(similar(x.data,S,dims))
  end
end

save(file::Union{AbstractString,IO},sound::Sound) = save(file,assampled(sound))
assampled{R}(x::Sound{R}) = SampledSignals.SampleBuf(x.data,float(R))

"""
    resample(x::Sound,samplerate)

Returns a new sound representing the sound `x` at the given sampling rate.

You will loose all frequencies in the sound above samplerate/2. Resampling
occurs automatically when you call [`sound`](@ref)---which is called inside
[`play`](@ref))---anytime the sampling rate of the sound and the current audio
playback settings (determined by [`setup_sound`](@ref)) are not the same.

To avoid automatic resampling you can either create sounds at the appropriate
sampling rate, as determined by [`samplerate`](@ref) (recommended), or change
the sampling rate initialized during [`setup_sound`](@ref) (not recommended).
"""
function resample{R,T,N}(x::Sound{R,T,N},new_sample_rate)
  new_rate = floor(Int,ustrip(inHz(new_sample_rate)))
  if new_rate < R
    warn("The function `resample` reduced the sample rate, high freqeuncy",
         " information above $(new_rate/2) Hz will be lost ",
         reduce(*,"",map(x -> string(x)*"\n",stacktrace())))
  end
  Sound{new_rate,T,N}(resample(x.data,new_rate // R))
end

function duration(x::Array{Float64};sample_rate_Hz=samplerate())
  uconvert(s,nsamples(x) / inHz(sample_rate_Hz))
end

inHz(x::Quantity) = uconvert(Hz,x)
function inHz(x::Number)
  warn("Unitless value, assuming Hz. Append Hz or kHz to avoid this warning",
       " (e.g. tone(1kHz))",
       reduce(*,"",map(x -> string(x)*"\n",stacktrace())))
  x*Hz
end
inHz{N <: Number,T}(typ::Type{N},x::T) = floor(N,ustrip(inHz(x)))*Hz
inHz{N <: Number}(typ::Type{N},x::N) = inHz(x)
inHz{N <: Number}(typ::Type{N},x::Freq{N}) = inHz(x)

inseconds(x::Quantity) = uconvert(s,x)
function inseconds(x::Number)
  warn("Unitless value, assuming seconds. Append s or ms to avoid this warning",
       " (e.g. silence(500ms))",
       stacktrace())
  x*s
end

const sound_cache = LRU{Any,Sound}(256)
function with_cache(fn,usecache,x)
  if usecache
    get!(fn,sound_cache,x)
  else
    fn()
  end
end

"""
    sound(x::Array,[cache=true];[sample_rate=samplerate()])

Creates a sound object from an arbitrary array.

Assumes 1 is the loudest and -1 the softest. The array should be 1d for mono
signals, or an array of size (N,2) for stereo sounds.

When cache is set to true, sound will cache its results thus avoiding repeatedly
creating a new sound for the same object.

!!! note "Called Implicitly"

    This function is normally called implicitly in a call to
    `play(x)`, where x is an arbitrary array, so it need not normally
    be called directly.
"""
function sound{T <: Number,N}(x::Array{T,N},cache=true;
                              sample_rate=samplerate())
  if N ∉ [1,2]
    error("Array must have 1 or 2 dimensinos to be converted to a sound.")
  end

  with_cache(cache,x) do
    bounded = max(min(x,typemax(Q0f15)),typemin(Q0f15))
    if size(x,2) == 1
      bounded = hcat(bounded,bounded)
    end
    R = ustrip(inHz(sample_rate))
    Sound{R,Q0f15,N}(Q0f15.(bounded))
  end
end

function sound(x::SampledSignals.SampleBuf,cache=true)
  with_cache(cache,x) do
    R,T = ustrip(inHz(Int,samplerate(x)*Hz)),eltype(x.data)
    sound(Sound{R,T,ndims(x)}(x.data),false)
  end
end

"""
    sound(x::Sound,[cache=true],sample_rate=samplerate())

Regularize the format of a sound.

This will ensure the sound is represented at a given sample rate.
"""

function sound{R,T,N}(x::Sound{R,T,N},cache=true)
  sample_rate=samplerate()
  with_cache(cache,x) do
    bounded = max(min(x.data,typemax(Q0f15)),typemin(Q0f15))
    T2 = Q0f15
    sound(Sound{R,T2,N}(Q0f15.(bounded)),false,sample_rate)
  end
end

function sound{R,N}(x::Sound{R,Q0f15,N},cache=true,sample_rate=samplerate())
  if size(x.data,2) == 2
    if R == ustrip(sample_rate)
      x
    else
      resample(Sound{R,Q0f15,N}(x.data),sample_rate)
    end
  else
    data = hcat(x.data,x.data)
    if R == ustrip(sample_rate)
      Sound{R,Q0f15,N}(data)
    else
      resample(Sound{R,Q0f15,N}(data),sample_rate)
    end
  end
end

"""
    sound(file,[cahce=true])

Load a specified file (e.g. by filename or stream) as a sound.
"""
sound(file::File,cache=true) = sound(load(file),cache)
sound(file::String,cache=true) = sound(load(file),cache)
sound(stream::IOStream) = sound(load(stream),false)


"""
    leftright(left,right;[sample_rate=samplerate()])

Create a stereo sound from two vectors or two monaural sounds.

For vectors, one can specify a sample_rate other than the default,
if desired.
"""
function leftright{R,T,N}(x::Sound{R,T,N},y::Sound{R,T,N})
  if size(x.data,2) == size(y.data,2) == 1
    Sound{R,T,2}(hcat(x.data,y.data))
  else
    error("Expected two monaural sounds.")
  end
end

function leftright{T}(x::Vector{T},y::Vector{T};sample_rate=samplerate())
  Sound{ustrip(sample_rate),T,2}(hcat(x,y))
end
