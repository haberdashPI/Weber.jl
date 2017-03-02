downloaddir = joinpath(dirname(@__FILE__),"downloads")
bindir = joinpath(dirname(@__FILE__),"usr","lib")

# remove any old build files
for d in [downloaddir,bindir]
  rm(d,recursive=true,force=true)
  mkpath(d)
end

################################################################################
# install SDL2 and plugins

SDL2 = "UNKNOWN"
SDL2_ttf = "UNKNOWN"
weber_sound = "UNKNOWN"
portaudio = "UNKNOWN"

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
    SDL2_ttf = setupbin("SDL2_ttf","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14-win32-x64.zip")
  finally
    rm(downloaddir,recursive=true,force=true)
  end

  weber_build = joinpath(dirname(@__FILE__),"build","libweber-sound.0.dll")
  weber_sound = joinpath(bindir,"libweber-sound.0.dll")
  portaudio_build = joinpath(dirname(@__FILE__),"lib","portaudio_x64.dll")
  portaudio = joinpath(bindir,"portaudio_x64.dll")
  if isfile(weber_build)
    mv(weber_build,weber_sound)
    mv(portaudio_build,portaudio)
  else
    download("http://haberdashpi.github.io/libweber-sound.0.dll",weber_sound)
    download("http://haberdashpi.github.io/portaudio_x64.dll",portaudio)
  end

  weber_sound = replace(weber_sound,"\\","\\\\")
  portaudio = replace(portaudio,"\\","\\\\")
elseif is_apple()
  using Homebrew

  Homebrew.add("sdl2")
  Homebrew.add("sdl2_ttf")
  Homebrew.add("portaudio")

  prefix = joinpath(Homebrew.prefix(),"lib")
  SDL2 = joinpath(prefix,"libSDL2-2.0.0.dylib")
  SDL2_ttf = joinpath(prefix,"libSDL2_ttf-2.0.0.dylib")
  portaudio = joinpath(prefix,"libportaudio.2.dylib")

  weber_build = joinpath(dirname(@__FILE__),"build","libweber-sound.0.dylib")
  weber_sound = joinpath(bindir,"libweber-sound.0.dylib")
  if isfile(weber_build)
    cp(weber_build,weber_sound)
  else
    original_path = "/usr/local/opt/portaudio/lib/libportaudio.2.dylib"
    download("http://haberdashpi.github.io/libweber-sound.0.dylib",weber_sound)
    run(`install_name_tool -change $original_path $portaudio $weber_sound`)
  end
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
@assert portaudio != "UNKNOWN"
@assert weber_sound != "UNKNOWN"

deps = joinpath(dirname(@__FILE__),"deps.jl")
open(deps,"w") do s
  for (var,val) in [:weber_SDL2 => SDL2,
                    :weber_portaudio => portaudio,
                    :weber_sound => weber_sound,
                    :weber_SDL2_ttf => SDL2_ttf]
    println(s,"const $var = \"$val\"")
  end
end
