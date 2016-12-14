downloaddir = joinpath(dirname(@__FILE__),"downloads")
bindir = joinpath(dirname(@__FILE__),"usr","lib")

for d in [downloaddir,bindir]
  rm(d,recursive=true,force=true)
  mkpath(d)
end

# NOTE: I'm not using BinDeps.jl here because I have found that
# the binaries from the various julia package managers can be
# corrupt, leading to weird runtime errors (e.g. playing sound just plays random
# chunks of memory).

SDL2 = "unknown"
SDL2_mixer = "unknown"
SDL2_ttf = "unknown"

if is_windows()
  function setupbin(library,uri)
    libdir = joinpath(downloaddir,library)
    zipfile = joinpath(downloaddir,library*".zip")
    try
      download(uri,zipfile)
      run(`powershell -nologo -noprofile -command "& { Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('$zipfile', '$libdir'); }"`)
      cp(joinpath(libdir,libraray*".dll"),joinpath(bindir,library*".dll"))
      joinpath(bindir,library*".dll")
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
elseif is_apple()
  # since the Homebrew.jl binaries don't work and the SDL website uses a
  # framework, which you can't easily link to via julia, I'm just downloading
  # the binaries I generated using homebrew from my personal website.
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
elseif is_linux()
  # TODO: use BinDeps.jl to install on linux???
  error("I don't have access to an available linux distro to troubleshoot"*
       " installation, so I have left it unimplemented.")
else
  error("Unsupported operating system.")
end

@assert SDL2 != "unknown"
@assert SDL2_mixer != "unknown"
@assert SDL2_ttf != "unknown"

deps = joinpath(dirname(@__FILE__),"deps.jl")
open("deps.jl","w") do s
  for (var,val) in [:SDL2 => SDL2, :SDL2_mixer => SDL2_mixer,:SDL2_ttf => SDL2_ttf]
    println(s,"const _psycho_$var = \"$val\"")
  end
end
