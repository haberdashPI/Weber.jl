__precompile__()

module Weber
using Juno
export resize_cache!

# helper function for clean info and warn output
function cleanstr(strs...;width=70)
  nlines = 0
  ncolumns = 0
  words = (w for str in strs for w in split(str,r"\s+"))
  result = IOBuffer()
  print(result,first(words))
  for word in drop(words,1)
    if ncolumns + length(word) > width
      ncolumns = 0
      nlines += 1
      print(result,"\n")
    else
      ncolumns += length(word) + 1
      print(result," ")
    end

    print(result,word)
  end
  takebuf_string(result)
end

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
    warn(cleanstr("Source files in $(Pkg.dir("Weber")) have been modified",
                  "without being committed to git. Your experiment will not",
                  "be reproduceable."))
  end
  global const version =
    convert(VersionNumber,chomp(readstring(`git describe --match v* --tags`))*suffix)
catch
  try
    global const version = Pkg.installed("Weber")
    if !isempty(version.build)
      warn(cleanstr("Source files do not correspond to an official release ",
                    "of Weber. Your experiment will not be reproducable. ",
                    "Consider installing git and adding it to your PATH to ",
                    "record a more precise version number."))
    end
  catch
    warn(cleanstr("The Weber version number could not be determined.",
         "Your experiment will not be reproducable.",
         "It is recommended that you install Weber via Pkg.add(\"Weber\")."))
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

const weber_sound_is_setup = Array{Bool}()
weber_sound_is_setup[] = false

include(joinpath(dirname(@__FILE__),"timing.jl"))
include(joinpath(dirname(@__FILE__),"video.jl"))
include(joinpath(dirname(@__FILE__),"audio.jl"))

function resize_cache!(size)
  resize!(sound_cache,size)
  resize!(image_cache,size)
  resize!(convert_cache,size)
end

include(joinpath(dirname(@__FILE__),"types.jl"))
include(joinpath(dirname(@__FILE__),"event.jl"))
include(joinpath(dirname(@__FILE__),"trial.jl"))
include(joinpath(dirname(@__FILE__),"experiment.jl"))

include(joinpath(dirname(@__FILE__),"primitives.jl"))
include(joinpath(dirname(@__FILE__),"helpers.jl"))
include(joinpath(dirname(@__FILE__),"adaptive.jl"))

include(joinpath(dirname(@__FILE__),"precompile.jl"))

const localunits = Unitful.basefactors
const localpromotion = Unitful.promotion
function __init__()
  _precompile_()
  merge!(Unitful.basefactors,localunits)
  merge!(Unitful.promotion, localpromotion)
end

end
