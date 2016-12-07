# modified from: https://github.com/rennis250/SDL.jl/blob/ef125ec/deps/build.jl
using BinDeps

@BinDeps.setup

libSDL = library_dependency("libSDL", aliases = ["libSDL", "SDL"])
libSDL_image = library_dependency("libSDL_image", aliases = ["libSDL_image"], depends = [libSDL])
libSDL_mixer = library_dependency("libSDL_mixer", aliases = ["libSDL_mixer"], depends = [libSDL])
libSDL_ttf = library_dependency("libSDL_ttf", aliases = ["libSDL_ttf"], depends = [libSDL])

@static if is_windows()
  if Pkg.installed("WinRPM") === nothing
    error("WinRPM package not installed, pluse run Pkg.add(\"WinRPM\")")
  end
	using WinRPM
	provides(WinRPM.RPM, "libSDL", libSDL, os = :Windows)
	provides(WinRPM.RPM, "libSDL_image", libSDL_image, os = :Windows)
	provides(WinRPM.RPM, "libSDL_mixer", libSDL_mixer, os = :Windows)
	provides(WinRPM.RPM, "libSDL_ttf", libSDL_ttf, os = :Windows)
elseif is_apple()
	if Pkg.installed("Homebrew") === nothing
		error("Hombrew package not installed, please run Pkg.add(\"Homebrew\")")
	end
	using Homebrew
	provides(Homebrew.HB, "sdl", libSDL, os = :Darwin)
	provides(Homebrew.HB, "sdl_image", libSDL_image, os = :Darwin)
	provides(Homebrew.HB, "sdl_mixer", libSDL_mixer, os = :Darwin)
	provides(Homebrew.HB, "sdl_ttf", libSDL_ttf, os = :Darwin)
elseif is_linux()
    provides(AptGet,
	    	     Dict("libsdl1.2-dev" => libSDL,
	    	          "libsdl-image1.2-dev" => libSDL_image,
	    	          "libsdl-mixer1.2-dev" => libSDL_mixer,
	    	          "libsdl-ttf2.0-dev" => libSDL_ttf))

  provides(Yum,
    		   Dict("SDL-devel" => libSDL,
    		        "SDL_image-devel" => libSDL_image,
    		        "SDL_mixer-devel" => libSDL_mixer,
    		        "SDL_ttf-devel" => libSDL_ttf))
else
  error("Unsupported operating system.")
end

#download()

@BinDeps.install Dict(:libSDL => :_psycho_SDL, :libSDL_mixer => :_psycho_SDLmixer)
