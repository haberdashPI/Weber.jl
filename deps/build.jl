using PyCall

downloaddir = Pkg.dir("Weber","deps","downloads")
bindir = Pkg.dir("Weber","deps","usr","lib")

# remove any old build files
for d in [downloaddir,bindir]
  rm(d,recursive=true,force=true)
  mkpath(d)
end

################################################################################
# install SDL2 and plugins

@static if is_windows()
  # do I need install 7z? (does this require julia bin directoy on PATH??)
  # I'm not using WinRPM here, because it doesn't include the SDL extensions
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

  deps = Pkg.dir("Weber","deps","deps.jl")
  open(deps,"w") do s
    for (var,val) in [:SDL2 => SDL2, :SDL2_mixer => SDL2_mixer,:SDL2_ttf => SDL2_ttf]
      println(s,"const _psycho_$var = \"$val\"")
    end
  end
elseif is_apple()
  # since the Homebrew.jl binaries don't work and the SDL website uses a
  # framework, which you can't easily link to via julia, I'm just downloading
  # the binaries I generated in homebrew from my personal website.
  try
    tarfile = joinpath(downloaddir,"SDL2.tgz")
    download("http://haberdashpi.github.io/SDL2-2.0.5_macosx_binaries.tgz",tarfile)
    run(`tar xzf $tarfile --directory=$bindir`)

    SDL2 = joinpath(bindir,"libSDL2-2.0.0.dylib")
    SDL2_mixer = joinpath(bindir,"libSDL2_mixer-2.0.0.dylib")
    SDL2_ttf = joinpath(bindir,"libSDL2_ttf-2.0.0.dylib")
  finally
    rm(downloaddir,recursive=true,force=true)
  end

  deps = Pkg.dir("Weber","deps","deps.jl")
  open(deps,"w") do s
    for (var,val) in [:SDL2 => SDL2, :SDL2_mixer => SDL2_mixer,:SDL2_ttf => SDL2_ttf]
      println(s,"const _psycho_$var = \"$val\"")
    end
  end
elseif is_linux()
  # using BinDeps
  # @BinDeps.setup

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

  # @BinDeps.install [:SDL2 => :SDL2]

  error("I don't have access to an available linux distro to troubleshoot"*
        " this program, so I have left the linux install unimplemented.")
else
  error("Unsupported operating system.")
end

try
  pyimport_conda("pyxid","pyxid","haberdashPI")
catch e
  if isa(e,PyCall.PyError) &&
    pybuiltin("type")(e.val) == pybuiltin("ImportError")
    info("Please restart Julia before using Weber.")
  else
    rethrow(e)
  end
end
