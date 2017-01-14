using PyCall

downloaddir = joinpath(dirname(@__FILE__),"downloads")
bindir = joinpath(dirname(@__FILE__),"usr","lib")

# remove any old build files
for d in [downloaddir,bindir]
  rm(d,recursive=true,force=true)
  mkpath(d)
end

################################################################################
# install SDL2 and plugins

@static if is_windows()
  # WinRPM lacks SDL2_ttf and SDL2_mixer binaries, so I'm just directly
  # downloading them from the SDL website.
  function setupbin(library,uri)
    libdir = joinpath(downloaddir,library)
    zipfile = joinpath(downloaddir,library*".zip")
    try
      download(uri,zipfile)
      run(`7z x $zipfile -y -o$libdir`)
      for lib in filter(s -> endswith(s,".dll"),readdir(libdir))
        cp(joinpath(libdir,lib),joinpath(bindir,lib))
      end
      replace(joinpath(bindir,library*".dll"),"\\","\\\\")
    finally
      rm(libdir,recursive=true,force=true)
      rm(zipfile,force=true)
    end
  end
  try
    SDL2 = setupbin("SDL2","https://www.libsdl.org/release/SDL2-2.0.5-win32-x64.zip")
    SDL2_mixer = setupbin("SDL2_mixer","https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.1-win32-x64.zip")
    SDL2_ttf = setupbin("SDL2_ttf","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14-win32-x64.zip")
  finally
    rm(downloaddir,recursive=true,force=true)
  end

  deps = joinpath(dirname(@__FILE__),"deps.jl")
  open(deps,"w") do s
    for (var,val) in [:SDL2 => SDL2, :SDL2_mixer => SDL2_mixer,:SDL2_ttf => SDL2_ttf]
      println(s,"const _psycho_$var = \"$val\"")
    end
  end
elseif is_apple()
  using Homebrew

  Homebrew.add("sdl2")
  Homebrew.add("sdl2_mixer")
  Homebrew.add("sdl2_ttf")

  prefix = joinpath(Homebrew.prefix(),"lib")
  SDL2 = joinpath(prefix,"libSDL2-2.0.0.dylib")
  SDL2_mixer = joinpath(prefix,"libSDL2_mixer-2.0.0.dylib")
  SDL2_ttf = joinpath(prefix,"libSDL2_ttf-2.0.0.dylib")

  deps = joinpath(dirname(@__FILE__),"deps.jl")
  open(deps,"w") do s
    for (var,val) in [:SDL2 => SDL2, :SDL2_mixer => SDL2_mixer,:SDL2_ttf => SDL2_ttf]
      println(s,"const _psycho_$var = \"$val\"")
    end
  end
elseif is_linux()
  # SDL2 = library_dependency("libSDL", aliases = ["libSDL", "SDL"])
  # SDL2_mixer = library_dependency("libSDL_mixer", aliases = ["libSDL_mixer"], depends = [libSDL], os = :Unix)
  # SDL2_ttf = library_dependency("libSDL_ttf", aliases = ["libSDL_ttf"], depends = [libSDL], os = :Unix)

  # provides(AptGet,
	#     	{"libsdl1.2-dev" => libSDL,
	#     	 "libsdl-mixer1.2-dev" => SDLmixer,
	#     	 "libsdl-ttf2.0-dev" => SDLttf})

  # provides(Yum,
  #   		   {"SDL-devel" => libSDL,
  #   		    "SDL_mixer-devel" => SDLmixer,
  #   		    "SDL_ttf-devel" => SDLttf})

  # @BinDeps.install [:SDL2 => :SDL2,
  #                   :SDL2_mixer => :SDL2_mixer,
  #                   :SDL2_ttf => :SDL2_ttf]

  error("I don't have access to an available linux distro to troubleshoot"*
        " this program, so I have left the linux install unimplemented.")
else
  error("Unsupported operating system.")
end

Conda.add_channel("haberdashPI")
Conda.add("pyxid")
