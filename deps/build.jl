downloaddir = joinpath(dirname(@__FILE__),"downloads")
bindir = joinpath(dirname(@__FILE__),"usr","lib")

const weber_sound_version = 3

# remove any old build files
for d in [downloaddir,bindir]
  rm(d,recursive=true,force=true)
  mkpath(d)
end

################################################################################
# install SDL2 and plugins

SDL2 = "UNKNOWN"
SDL2_ttf = "UNKNOWN"

@static if is_windows()
  # WinRPM lacks SDL2_ttf and SDL2_mixer binaries, so I'm just directly
  # downloading them from the SDL website.
  function setupbin(library,uri)
    libdir = joinpath(downloaddir,library)
    zipfile = joinpath(downloaddir,library*".zip")
    try
      download(uri,zipfile)
      run(`$(joinpath(JULIA_HOME, "7z.exe")) x $zipfile -y -o$libdir`)
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
    SDL2_ttf = setupbin("SDL2_ttf","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14-win32-x64.zip")
  finally
    rm(downloaddir,recursive=true,force=true)
  end
elseif is_apple()
  using Homebrew

  Homebrew.add("sdl2")
  Homebrew.add("sdl2_ttf")

  prefix = joinpath(Homebrew.prefix(),"lib")
  SDL2 = joinpath(prefix,"libSDL2-2.0.0.dylib")
  SDL2_ttf = joinpath(prefix,"libSDL2_ttf-2.0.0.dylib")
elseif is_linux()
    error("Weber does not support Linux. You can try manually installing ",
          "SDL2, SDL2_ttf and portaudio and then creating an appropriate ",
          "deps.jl file in $(dirname(@__FILE__)). Be warned however that ",
          "I have encountered strange llvm runtime errors with the linux ",
          "implementation, possibly related to SDL2 problems.")
  # function getdir(lib)
  #   dir = readlines(`dpkg -L $lib-0`)
  #   libs = filter(x -> ismatch(Regex(lowercase(lib)*".so"),lowercase(x)),dir)
  #   chomp(last(libs))
  # end
  # SDL2 = getdir("libsdl2-2.0")
  # SDL2_mixer = getdir("libsdl2-mixer-2.0")
  # SDL2_ttf = getdir("libsdl2-ttf-2.0")
else
  error("Unsupported operating system.")
end

@assert SDL2 != "UNKNOWN"
@assert SDL2_ttf != "UNKNOWN"

deps = joinpath(dirname(@__FILE__),"deps.jl")
open(deps,"w") do s
  for (var,val) in [:weber_SDL2 => SDL2,
                    :weber_SDL2_ttf => SDL2_ttf]
    println(s,"const $var = \"$val\"")
  end
end
