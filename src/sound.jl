using FixedPointNumbers
using LRUCache
using FileIO
using Lazy: @>, @>>
using IntervalSets

import FileIO: save
import DSP: resample
import LibSndFile
import SampledSignals: samplerate
import SampledSignals
import Distributions: nsamples
import Base: show, length, start, done, next, getindex, size,
  setindex!, vcat, similar, convert, .*, .+, *, minimum, maximum
importall IntervalSets # I just need .., but there's a syntax parsing bug

export sound, playable, duration, nchannels, nsamples, save, samplerate, length,
  samples, vcat, leftright, similar, left, right,
  audiofn, limit, .., ends

immutable Sound{R,T,N} <: AbstractArray{T,N}
  data::Array{T,N}
  function Sound{R,T,N}(a::Array{T,N}) where {R,T,N}
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
rtype{R}(x::Sound{R}) = R

length(x::Sound) = length(x.data)

asstereo{R,T}(x::Sound{R,T,1}) = hcat(x.data,x.data)
asstereo{R,T}(x::Sound{R,T,2}) = size(x,2) == 1 ? hcat(x.data,x.data) : x.data
asmono{R,T}(x::Sound{R,T,1}) = x.data
asmono{R,T}(x::Sound{R,T,2}) = squeeze(x.data,2)

vcat{R,T}(xs::Sound{R,T,1}...) = Sound{R,T,1}(vcat(map(x -> x.data,xs)...))
function vcat{R,T}(xs::Sound{R,T}...)
  if any(x -> nchannels(x) == 2,xs)
    Sound{R,T,2}(vcat(map(asstereo,xs)...))
  else
    Sound{R,T,1}(vcat(map(asmono,xs)...))
  end
end

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
Base.IndexStyle(::Type{Sound}) = IndexLinear()

# adapted from:
# https://github.com/JuliaAudio/SampledSignals.jl/blob/0a31806c3f7d382c9aa6db901a83e1edbfac62df/src/SampleBuf.jl#L109-L139
rounded_time(x,R) = round(ustrip(inseconds(x,R)),ceil(Int,log(10,R)))*s
function show{R}(io::IO, x::Sound{R})
  seconds = rounded_time(duration(x),R)
  typ = if eltype(x) == Q0f15
    "16 bit PCM"
  elseif eltype(x) <: AbstractFloat
    "$(sizeof(eltype(x))*8) bit floating-point"
  else
    eltype(x)
  end

  channel = size(x.data,2) == 1 ? "mono" : "stereo"

  println(io, "$seconds $typ $channel sound")
  print(io, "Sampled at $(R*Hz)")
  nsamples(x) > 0 && showchannels(io, x)
end
show(io::IO, ::MIME"text/plain", x::Sound) = show(io,x)

const ticks = ['_','▁','▂','▃','▄','▅','▆','▇']
function showchannels(io::IO, x::Sound, widthchars=80)
  # number of samples per block
  blockwidth = round(Int, nsamples(x)/widthchars, RoundUp)
  nblocks = round(Int, nsamples(x)/blockwidth, RoundUp)
  blocks = Array{Char}(nblocks, nchannels(x))
  for blk in 1:nblocks
    i = (blk-1)*blockwidth + 1
    n = min(blockwidth, nsamples(x)-i+1)
    peaks = sqrt.(mean(float(x[(1:n)+i-1,:]).^2,1))
    # clamp to -60dB, 0dB
    peaks = clamp.(20log10.(peaks), -60.0, 0.0)
    idxs = trunc.(Int, (peaks+60)/60 * (length(ticks)-1)) + 1
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

Extract the left channel a stereo sound or stream.
"""
function left{R,T,N}(sound::Sound{R,T,N})
  if size(sound.data,2) == 1
    error("Expected stereo sound.")
  else
    sound[:,1]
  end
end

"""
    right(sound::Sound)

Extract the right channel of a stereo sound or stream.
"""
function right{R,T,N}(sound::Sound{R,T,N})
  if size(sound.data,2) == 1
    error("Expected stereo sound.")
  else
    sound[:,2]
  end
end

immutable EndSecs
end
const ends = EndSecs()

immutable ClosedIntervalEnd{N}
  from::Time{N}
end
minimum(x::ClosedIntervalEnd) = x.from

..(x::Time,::EndSecs) = ClosedIntervalEnd(x)

function checktime(time)
  if time < 0s
    throw(BoundsError("Unexpected negative time."))
  end
end

@inline @Base.propagate_inbounds function getindex(x::Sound,ixs,js::Symbol)
  if js == :left
    getindex(x,ixs,1)
  elseif js == :right
    getindex(x,ixs,2)
  else
    throw(BoundsError(x,js))
  end
end
@inline @Base.propagate_inbounds function setindex!(x::Sound,vals,ixs,js::Symbol)
  if js == :left
    setindex!(x,vals,ixs,1)
  elseif js == :right
    setindex!(x,vals,ixs,2)
  else
    throw(BoundsError(x,js))
  end
end

########################################
# getindex
const Index = Union{Integer,Range,AbstractVector,Colon}
@inline function getindex{R,T,I <: Index}(
  x::Sound{R,T},ixs::ClosedIntervalEnd,js::I)
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  @boundscheck checkbounds(x.data,from,js)
  @inbounds return Sound{R,T,2}(x.data[from:end,js])
end

@inline function getindex{R,T,I <: Index,N,TM <: Time}(
  x::Sound{R,T,N},ixs::ClosedInterval{TM},js::I)
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  to = insamples(maximum(ixs),R*Hz)-1
  @boundscheck checkbounds(x.data,from:to,js)
  @inbounds result = x.data[from:to,js]
  return Sound{R,T,ndims(result)}(result)
end

@inline function getindex{R,T}(
  x::Sound{R,T},ixs::ClosedIntervalEnd)

  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  if size(x,2) == 1
    @boundscheck checkbounds(x.data,from)
    @inbounds return Sound{R,T,1}(x.data[from:end])
  else
    @boundscheck checkbounds(x.data,from,:)
    @inbounds return Sound{R,T,2}(x.data[from:end,:])
  end
end

@inline function getindex{R,T,TM <: Time}(
  x::Sound{R,T},ixs::ClosedInterval{TM})
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  to = insamples(maximum(ixs),R*Hz)-1
  if size(x,2) == 1
    @boundscheck checkbounds(x.data,from)
    @boundscheck checkbounds(x.data,to)
    @inbounds return Sound{R,T,1}(x.data[from:to])
  else
    @boundscheck checkbounds(x.data,from,:)
    @boundscheck checkbounds(x.data,to,:)
    @inbounds return Sound{R,T,2}(x.data[from:to,:])
  end
end

########################################
# setindex

@inline function setindex!{R,T,I}(
  x::Sound{R,T},vals::AbstractArray,ixs::ClosedIntervalEnd,js::I)
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  @boundscheck checkbounds(x.data,from,js)
  @inbounds x.data[from:end,js] = vals
  vals
end

@inline function setindex!{R,T,I,TM <: Time}(
  x::Sound{R,T},vals::AbstractArray,ixs::ClosedInterval{TM},js::I)
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  to = insamples(maximum(ixs),R*Hz)-1
  @boundscheck checkbounds(x.data,from,js)
  @boundscheck checkbounds(x.data,to,js)
  @inbounds x.data[from:to,js] = vals
  vals
end

@inline function setindex!{R,T}(
  x::Sound{R,T},vals::AbstractArray,ixs::ClosedIntervalEnd)
    @boundscheck checktime(minimum(ixs))
    from = max(1,insamples(minimum(ixs),R*Hz))
    if size(x,2) == 1
      @boundscheck checkbounds(x.data,from)
      @inbounds x.data[from:end] = vals
    else
      @boundscheck checkbounds(x.data,from,:)
      @inbounds x.data[from:end,:] = vals
    end
    vals

end

@inline function setindex!{R,T,TM <: Time}(
  x::Sound{R,T},vals::AbstractArray,ixs::ClosedInterval{TM})
  @boundscheck checktime(minimum(ixs))
  from = max(1,insamples(minimum(ixs),R*Hz))
  to = insamples(maximum(ixs),R*Hz)-1
  if size(x,2) == 1
    @boundscheck checkbounds(x.data,from:to)
    @inbounds x.data[from:to] = vals
  else
    @boundscheck checkbounds(x.data,from:to,:)
    @inbounds x.data[from:to,:] = vals
  end
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

const sound_cache = LRU{Tuple{UInt,Int,Function},Sound}(256)
function with_cache(fn,usecache,x,sr)
  if usecache
    get!(fn,sound_cache,(object_id(x),ustrip(inHz(Int,sr)),fn))
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

    This function is normally called implicitly in a call to `play(x)`, so it
    need not normally be called directly.

"""
function sound{T <: Number,N}(x::Array{T,N},cache=true;
                              sample_rate=samplerate())
  if N ∉ [1,2]
    error("Array must have 1 or 2 dimensions to be converted to a sound.")
  end

  with_cache(cache,x,sample_rate) do
    R = ustrip(inHz(sample_rate))
    Sound{R,T,N}(x)
  end
end

function sound(x::SampledSignals.SampleBuf,cache=true;
               sample_rate=samplerate(x)*Hz)
  if ustrip(sample_rate) != samplerate(x)
    error("Unexpected sample rate $sample_rate. Use `playable` or `resample`",
          " to change the sampling rate.")
  end

  with_cache(cache,x,sample_rate) do
    R,T = ustrip(inHz(Int,samplerate(x)*Hz)),eltype(x.data)
    Sound{R,T,ndims(x)}(x.data)
  end
end

function sound{R}(x::Sound{R},cache=true;sample_rate=R*Hz)
  if ustrip(sample_rate) != R
    error("Unexpected sample rate $sample_rate. Use `playable` or `resample`",
          " to change the sampling rate.")
  end
  x
end

"""
    playable(x,[cache=true],[sample_rate=samplerate()])

Prepare a sound or stream to be played.

A call to `playable` will ensure the sound is in the format required by
[`play`](@ref).  This automatically calls [`sound`](@ref) on `x` if it not
already appear to be a sound or a stream.

!!! note "Called Implicitly"

    This need not be called explicitly, as play will call it for you, if need be.
"""

function playable(x,cache=true,sample_rate=samplerate())
  with_cache(cache,x,sample_rate) do
    playable(sound(x,sample_rate=sample_rate),false,sample_rate)
  end
end

function playable{R,T,N}(x::Sound{R,T,N},cache=true,sample_rate=samplerate())
  with_cache(cache,x,sample_rate) do
    bounded = clamp.(x.data,typemin(Q0f15),typemax(Q0f15))
    T2 = Q0f15
    playable(Sound{R,T2,N}(Q0f15.(bounded)),false,sample_rate)
  end
end

function playable{R}(x::Sound{R,Q0f15},cache=true,sample_rate=samplerate())
  if size(x.data,2) == 2
    if R == ustrip(sample_rate)
      x
    else
      with_cache(cache,x,sample_rate) do
        warn("Reampling sound")
        resample(Sound{R,Q0f15,2}(x.data),sample_rate)
      end
    end
  else
    with_cache(cache,x,sample_rate) do
      data = hcat(x.data,x.data)
      if R == ustrip(sample_rate)
        Sound{R,Q0f15,2}(data)
      else
        warn("Reampling sound")
        resample(Sound{R,Q0f15,2}(data),sample_rate)
      end
    end
  end
end

"""
    sound(file,[cahce=true];[sample_rate=samplerate(file)])

Load a specified file (e.g. by filename or stream) as a sound.
"""
sound(file::File,cache=true;keys...) = sound(load(file),cache;keys...)
sound(file::String,cache=true;keys...) = sound(load(file),cache;keys...)
function sound(stream::IOStream,cache=false;keys...)
  if cache
    error("Cannot cache a sound from an IOStream. Please use the filename.")
  end
  sound(load(stream),cache;keys...)
end

"""
    leftright(left,right)

Create a stereo sound from two vectors or two monaural sounds.

For vectors, one can specify a sample_rate other than the default,
if desired.
"""
function leftright{R,T}(x::Sound{R,T},y::Sound{R,T},sample_rate=R*Hz)
  if sample_rate != R*Hz
    error("Unexpected sampling rate $sample_rate. ",
          "Use `playable` or `resample` to change the sampling rate.")
  end
  if size(x.data,2) == size(y.data,2) == 1
    Sound{R,T,2}(hcat(x.data,y.data))
  else
    error("Expected two monaural sounds.")
  end
end

function leftright{T}(x::Array{T},y::Array{T};sample_rate=samplerate())
  if size(x,2) == size(y,2) == 1 && 1 <= ndims(x) <= 2 && 1 <= ndims(y) <= 2
    Sound{ustrip(sample_rate),T,2}(hcat(x,y))
  else
    error("Expected two vectors.")
  end
end

limit{R}(sound::Sound{R},len::Time) = limit(sound,insamples(len,R*Hz))
limit{R,T}(sound::Sound{R,T,1},len::Int) = sound[1:len]
limit{R,T}(sound::Sound{R,T,2},len::Int) = sound[1:len,:]

"""
    audiofn(fn,x)

Apply `fn` to x for both sounds and streams.

For a sound this is the same as calling `fn(x)`.
"""
audiofn{R}(fn::Function,x::Sound{R}) = sound(fn(x),sample_rate=R*Hz)

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
          @inbounds y[i,:] .= xs[j][i,:]
        else
          @inbounds y[i,:] .= op(y[i,:],xs[j][i,:])
        end
      end
    end
  end

  y
end
