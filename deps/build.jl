downloaddir = joinpath(dirname(@__FILE__),"downloads")
includedir = joinpath(dirname(@__FILE__),"usr","include")
bindir = joinpath(dirname(@__FILE__),"usr","lib")

for d in [downloaddir,includedir,bindir]
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
      run(`7z x $zipfile -y -o$libdir`)
      cp(joinpath(libdir,libraray*".dll"),joinpath(bindir,library*".dll"))
      joinpath(bindir,library*".dll")
    finally
      rm(libdir,recursive=true,force=true)
      rm(zipfile,force=true)
    end
  end

  function setupinclude(library,incudesub,uri)
    try
      libdir = joinpath(downloaddir,library)
      zipfile = joinpath(downloaddir,library*".zip")
      download(uri,zipfile)
      run(`7z x $zipfile -y -o$downloaddir`)
      headdir = joinapath(libdir,includesub)
      for header in filter(f -> endswith(".h"),readdir(libdir))
        cp(joinpath(headdir,includesub,header),joinpath(includedir,header))
      end
    finally
      rm(libdir,recursive=true,force=true)
      rm(zipfile,force=true)
    end
  end

  try
    SDL2 = setupbin("SDL2","https://www.libsdl.org/release/SDL2-2.0.5-win32-x64.zip")
    SDL2_mixer = setupbin("SDL2_mixer","https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.1-win32-x64.zip")
    SDL2_ttf = setupbin("SDL2_ttf","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14-win32-x64.zip")

    setupinclude("SDL2","include","https://www.libsdl.org/release/SDL2-2.0.5.zip")
    setupinclude("SDL2_mixer",".","https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.1.zip")
    setupinclude("SDL2_ttf",".","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14.zip")
  finally
    rm(downloaddir,recursive=true,force=true)
  end
elseif is_apple()
  function setupinclude(library,includesub,uri)
    libdir = joinpath(downloaddir,library)
    tarfile = joinpath(downloaddir,library*".tar.gz")
    try
      download(uri,tarfile)
      run(`tar xzf $tarfile --directory=$downloaddir`)
      headdir = joinpath(libdir,includesub)
      for header in filter(f -> endswith(f,".h"),readdir(headdir))
        cp(joinpath(libdir,includesub,header),joinpath(includedir,header))
      end
    finally
      rm(libdir,recursive=true,force=true)
      rm(tarfile,force=true)
    end
  end

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

    setupinclude("SDL2-2.0.5","include","https://www.libsdl.org/release/SDL2-2.0.5.tar.gz")
    setupinclude("SDL2_mixer-2.0.1",".","https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.0.1.tar.gz")
    setupinclude("SDL2_ttf-2.0.14",".","https://www.libsdl.org/projects/SDL_ttf/release/SDL2_ttf-2.0.14.tar.gz")
  finally
    rm(downloaddir,recursive=true,force=true)
  end
elseif is_linux()
  # TODO: use BinDeps.jl to install on linux???
  error("I don't have access to an available linux distro to troubleshoot"*
        " installation, so it is left unimplemented.")
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
