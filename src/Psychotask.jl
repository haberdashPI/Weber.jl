module Psychotask

using Cxx

depsjl = joinpath(dirname(@__FILE__), "..", "deps", "deps.jl")
if isfile(depsjl)
  include(depsjl)
  Libdl.dlopen(_psycho_SDL2)
  Libdl.dlopen(_psycho_SDL2_mixer)
  Libdl.dlopen(_psycho_SDL2_ttf)
  cxxinclude(joinpath(dirname(@__FILE__),"..","deps","usr","include","SDL.h"))
  cxxinclude(joinpath(dirname(@__FILE__),"..","deps","usr","include","SDL_mixer.h"))
  cxxinclude(joinpath(dirname(@__FILE__),"..","deps","usr","include","SDL_ttf.h"))
else
  error("Psychotask not properly installed. "*
        "Please run\nPkg.build(\"Psychotask\")")
end

SDL_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))
Mix_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))
TTF_GetError() = unsafe_string(ccall((:SDL_GetError,_psycho_SDL2),Cstring,()))

include(joinpath(dirname(@__FILE__),"VideoUtil.jl"))
include(joinpath(dirname(@__FILE__),"SoundUtil.jl"))
include(joinpath(dirname(@__FILE__),"Trial.jl"))

end
