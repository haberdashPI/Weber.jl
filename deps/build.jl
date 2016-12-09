# modified from: https://github.com/rennis250/SDL.jl/blob/ef125ec/deps/build.jl
using BinDeps

# TODO: remove BinDeps, and just do a straigtforward download and install
# from the SDL website.

@BinDeps.setup

libSDL2 = library_dependency("libSDL2", aliases = ["libSDL2", "SDL"])
libSDL2_image = library_dependency("libSDL2_image", aliases = ["libSDL2_image"], depends = [libSDL2])
libSDL2_mixer = library_dependency("libSDL2_mixer", aliases = ["libSDL2_mixer"], depends = [libSDL2])
libSDL2_ttf = library_dependency("libSDL2_ttf", aliases = ["libSDL2_ttf"], depends = [libSDL2])

@static if is_windows()
  # TODO: create a function to download and install binaries
  # from sdl website
  if Pkg.installed("WinRPM") === nothing
    error("WinRPM package not installed, pluse run Pkg.add(\"WinRPM\")")
  end
	using WinRPM
	provides(WinRPM.RPM, "SDL2", libSDL2, os = :Windows)
	provides(WinRPM.RPM, "SDL2_image", libSDL2_image, os = :Windows)
	provides(WinRPM.RPM, "SDL2_mixer", libSDL2_mixer, os = :Windows)
	provides(WinRPM.RPM, "SDL2_ttf", libSDL2_ttf, os = :Windows)
elseif is_apple()
  # TODO: create function to install mac os x DMG fiels

	if Pkg.installed("Homebrew") === nothing
		error("Hombrew package not installed, please run Pkg.add(\"Homebrew\")")
	end
	using Homebrew
	provides(Homebrew.HB, "sdl2", libSDL2, os = :Darwin)
	provides(Homebrew.HB, "sdl2_image", libSDL2_image, os = :Darwin)
	provides(Homebrew.HB, "sdl2_mixer", libSDL2_mixer, os = :Darwin)
	provides(Homebrew.HB, "sdl2_ttf", libSDL2_ttf, os = :Darwin)
elseif is_linux()
  # TODO: create a function to download and install binaries
  # from sdl website
    provides(AptGet,
	    	     Dict("libsdl2-2.0-0" => libSDL2,
	    	          "libsdl2-image-2.0-0" => libSDL2_image,
	    	          "libsdl2-mixer-2.0-0" => libSDL2_mixer,
	    	          "libsdl2-ttf-2.0-0" => libSDL2_ttf))
else
  error("Unsupported operating system.")
end

@BinDeps.install Dict(:libSDL2 => :_psycho_SDL,
                      :libSDL2_mixer => :_psycho_SDLmixer,
                      :libSDL2_ttf => :_psycho_SDLttf)

# install headers for SDL 2.0 and SDL_mixer 2.0
downloaddir = joinpath(dirname(@__FILE__),"downloads")
includedir = joinpath(dirname(@__FILE__),"usr","include")

rm(includedir,force=true,recursive=true)
mkpath(includedir)
mkpath(downloaddir)

function addheaders(source,header_location,uri)
  tar_file = joinpath(downloaddir,source*".tar.gz")
  download(uri*source*".tar.gz",tar_file)
  success(BinDeps.unpack_cmd(tar_file,downloaddir,".tar",".gz"))
  headers = filter(s -> endswith(s,".h"),
                   readdir(joinpath(downloaddir,source,header_location)))
  for header in headers
    mv(joinpath(downloaddir,source,header_location,header),
       joinpath(includedir,header))
  end
end

addheaders("SDL2-2.0.5","include","https://www.libsdl.org/release/")
addheaders("SDL2_mixer-2.0.1",".","https://www.libsdl.org/projects/SDL_mixer/release/")

rm(downloaddir,force=true,recursive=true)
