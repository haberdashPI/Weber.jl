__precompile__()

module Weber
try
  old = pwd()
  cd(dirname(@__FILE__))
  global const version = convert(VersionNumber,
                                 readstring(`git describe --tags`))
  cd(old)
catch
  global const version = Pkg.installed("Weber")
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
# more all that much, so they're the only calls I've wrapped).
SDL_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))
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

include(joinpath(dirname(@__FILE__),"video.jl"))
include(joinpath(dirname(@__FILE__),"sound.jl"))
include(joinpath(dirname(@__FILE__),"event.jl"))
include(joinpath(dirname(@__FILE__),"trial.jl"))
include(joinpath(dirname(@__FILE__),"primitives.jl"))
include(joinpath(dirname(@__FILE__),"helpers.jl"))

include(joinpath(dirname(@__FILE__),"precompile.jl"))

function __init__()
  _precompile_()
  init_events()
end

end
