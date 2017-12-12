__precompile__()

module Weber
using TimedSound
using Unitful
using Juno
using Base.Iterators
using MacroTools
using Lazy: @>, @>>, @_
export resize_cache!, @>, @>>, @_

export sound, tone, noise, silence, harmonic_complex, irn, audible, highpass,
  lowpass, bandpass, bandstop, ramp, rampon, rampoff, fadeto, attenuate, mix,
  mult, envelope, duration, nchannels, nsamples, audiofn, leftright, left,
  right, play, setup_sound , playable, resample, stop, samplerate,
  current_sound_latency, pause_sounds, resume_sounds, ..,
  ms, s, kHz, Hz, samples

try
  @assert Sys.WORD_SIZE == 64
catch
  error("Weber can only be run as a 64-bit program. Please use a 64-bit ",
        "implementation of Julia.")
end

old = pwd()
try
  cd(Pkg.dir("Weber"))

  suffix = (success(`git diff-index HEAD --quiet`) ? "" : "-dirty")
  if !isempty(suffix)
    warn("Source files in $(Pkg.dir("Weber")) have been modified "*
                  "without being committed to git. Your experiment will not "*
                  "be reproduceable.")
  end
  global const version =
    convert(VersionNumber,chomp(readstring(`git describe --match 'v*' --tags`))*suffix)
catch
  try
    global const version = Pkg.installed("Weber")
    if !isempty(version.build)
      warn("Source files do not correspond to an official release "*
                    "of Weber. Your experiment will not be reproducable. "*
                    "Consider installing git and adding it to your PATH to "*
                    "record a more precise version number.")
    end
  catch
    warn("The Weber version number could not be determined. "*
         "Your experiment will not be reproducable. "*
         "It is recommended that you install Weber via Pkg.add(\"Weber\").")
  end
finally
  cd(old)
end

# load binary library dependencies
depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depsjl)
  include(depsjl)
else
  error("Weber not properly installed. "*
        "Please run\nPkg.build(\"Weber\")")
end

# setup error reporting functions (these are the only calls to SDL that occur
# all that often, so they're the only calls I've wrapped directly).
SDL_GetError() = unsafe_string(ccall((:SDL_GetError,weber_SDL2),Cstring,()))
Mix_GetError = SDL_GetError
TTF_GetError = SDL_GetError

# this is a simple function for accessing aribtrary offsets in memory as any
# bitstype you want... this is used to read from a c union by determining the
# offset of various fields in the data using offsetof(struct,field) in c and
# then using that offset to access the memory in julia. SDL's
# core event type (SDL_Event) is a c union.
function at{T}(x::Ptr{Void},::Type{T},offset)
  unsafe_wrap(Array,reinterpret(Ptr{T},x + offset),1)[1]
end

import FileIO: load, save
export load, save

const sdl_is_setup = Array{Bool}()
sdl_is_setup[] = false

include(joinpath(@__DIR__,"timing.jl"))
include(joinpath(@__DIR__,"video.jl"))

function resize_cache!(size)
  resize!(image_cache,size)
  resize!(convert_cache,size)
end

include(joinpath(@__DIR__,"types.jl"))
include(joinpath(@__DIR__,"sound_hooks.jl"))
include(joinpath(@__DIR__,"event.jl"))
include(joinpath(@__DIR__,"trial.jl"))
include(joinpath(@__DIR__,"experiment.jl"))

include(joinpath(@__DIR__,"primitives.jl"))
include(joinpath(@__DIR__,"helpers.jl"))
include(joinpath(@__DIR__,"adaptive.jl"))

include(joinpath(@__DIR__,"precompile.jl"))

include(joinpath(@__DIR__,"extension_macro.jl"))
include(joinpath(@__DIR__,"extensions.jl"))

const localunits = Unitful.basefactors
const localpromotion = Unitful.promotion
function __init__()
  _precompile_()
  merge!(Unitful.basefactors,localunits)
  merge!(Unitful.promotion, localpromotion)
end

end
