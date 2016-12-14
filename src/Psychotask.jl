module Psychotask

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depsjl)
  include(depsjl)
else
  error("Psychotask not properly installed. "*
        "Please run\nPkg.build(\"Psychotask\")")
end

SDL_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))
Mix_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))
TTF_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))

# this is a simple function for accessing aribtrary offsets in memory as any
# bitstype you want... this is used to read from a c union by determining the
# offset of various fields in the data using offsetof(struct,field) in c and
# then using that offset to access the memory in julia.
function at{T}(x::Ptr{Void},::Type{T},offset)
  unsafe_wrap(Array,reinterpret(Ptr{T},x + offset),1)[1]
end

include(joinpath(dirname(@__FILE__),"VideoUtil.jl"))
include(joinpath(dirname(@__FILE__),"SoundUtil.jl"))
include(joinpath(dirname(@__FILE__),"Trial.jl"))

end
