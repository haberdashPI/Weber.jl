using Colors
using Reactive

import Base: display, close

export render, window, font, clear, display, draw, close

@static if is_windows()
  const font_dirs = [".",joinpath(ENV["WINDIR"],"fonts")]
elseif is_apple()
  const font_dirs = [".","/Library/Fonts"]
elseif is_linux()
  const font_dirs = [".","/usr/share/fonts","/usr/local/share/fonts"]
end

function find_font(name,dirs)
  reg = Regex(lowercase(name)*"\\.ttf\$")
  for d in dirs
    for file in readdir(d)
      if ismatch(reg,lowercase(file))
        return joinpath(d,file)
      end
    end
  end
  error("No font matching the name \"$name\" in the directories "*
        join(dirs,", "," and ")*".")
end

type SDLWindow
  data::Ptr{Void}
  renderer::Ptr{Void}
  w::Cint
  h::Cint
  closed::Bool
end

const SDL_INIT_VIDEO = 0x00000020
const SDL_WINDOWPOS_CENTERED = 0x2fff0000
const SDL_WINDOW_FULLSCREEN_DESKTOP = 0x00001001
const SDL_WINDOW_INPUT_GRABBED = 0x00000100
const SDL_RENDERER_SOFTWARE = 0x00000001
const SDL_RENDERER_ACCELERATED = 0x00000002
const SDL_RENDERER_PRESENTVSYNC = 0x00000004
const SDL_RENDERER_TARGETTEXTURE = 0x00000008

function window(width=1024,height=768;fullscreen=true,title="Experiment",accel=true)
  if !ccall((:SDL_SetHint,_psycho_SDL2),Bool,(Cstring,Cstring),
            "SDL_RENDER_SCALE_QUALITY","1")
    warn("Linear texture filtering not enabled.")
  end

  if ccall((:TTF_Init,_psycho_SDL2_ttf),Cint,()) == -1
    error("Failed to initialize SDL_ttf: "*TTF_GetError())
  end

  x = y = SDL_WINDOWPOS_CENTERED
  flags = (fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : UInt32(0)) |
    SDL_WINDOW_INPUT_GRABBED

  win = ccall((:SDL_CreateWindow,_psycho_SDL2),Ptr{Void},
              (Cstring,Cint,Cint,Cint,Cint,UInt32),
              pointer(title),x,y,width,height,flags)
  if win == C_NULL
    error("Failed to create a window: "*SDL_GetError())
  end

  flags = SDL_RENDERER_ACCELERATED |
    SDL_RENDERER_PRESENTVSYNC |
    SDL_RENDERER_TARGETTEXTURE

  fallback_flags = SDL_RENDERER_SOFTWARE

  rend = ccall((:SDL_CreateRenderer,_psycho_SDL2),Ptr{Void},
               (Ptr{Void},Cint,UInt32),win,-1,(accel ? flags : fallback_flags))
  if rend == C_NULL
    accel_error = SDL_GetError()
    if accel
      rend = ccall((:SDL_CreateRenderer,_psycho_SDL2),Ptr{Void},
                   (Ptr{Void},Cint,UInt32),win,-1,fallback_flags)
      if rend == C_NULL
        error("Failed to create a renderer: "*SDL_GetError())
      end
      warn("Failed to create accelerated graphics renderer: "*accel_error)
    else
      error("Failed to create a renderer: "*accel_error())
    end
  end

  wh = Array{Cint}(2)
  ccall((:SDL_GetWindowSize,_psycho_SDL2),Void,
        (Ptr{Void},Ptr{Cint},Ptr{Cint}),win,pointer(wh,1),pointer(wh,2))
  ccall((:SDL_ShowCursor,_psycho_SDL2),Void,(Cint,),0)

  x = SDLWindow(win,rend,wh[1],wh[2],false)
  finalizer(x,x -> (x.closed ? nothing : close(x)))

  x
end

function close(win::SDLWindow)
  ccall((:SDL_DestroyRenderer,_psycho_SDL2),Void,(Ptr{Void},),win.renderer)
  ccall((:SDL_DestroyWindow,_psycho_SDL2),Void,(Ptr{Void},),win.data)
  win.closed = true
end


function clear(color=colorant"black")
  clear(get_experiment().win,color)
end

function clear(window::SDLWindow,color::Color)
  clear_helper(window,convert(RGB{U8},color))
end

function clear(window::SDLWindow,color::RGB{U8}=colorant"black")
  ccall((:SDL_SetRenderDrawColor,_psycho_SDL2),Void,
        (Ptr{Void},UInt8,UInt8,UInt8),window.renderer,
        red(color),green(color),blue(color))
  ccall((:SDL_RenderClear,_psycho_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end


type SDLFont
  data::Ptr{Void}
  color::RGBA{U8}
end

function font(name::String,size;dirs=font_dirs,color=colorant"white")
  file = find_font(name,dirs)
  font = ccall((:TTF_OpenFont,_psycho_SDL2_ttf),Ptr{Void},(Cstring,Cint),
               pointer(file),size)
  if font == C_NULL
    error("Failed to load the font $file: "*TTF_GetError())
  end

  x = SDLFont(font,color)
  finalizer(x,x -> ccall((:TTF_CloseFont,_psycho_SDL2_ttf),Void,
                         (Ptr{Void},),x.data))
  x
end

type SDLText
  data::Ptr{Void}
  w::Cint
  h::Cint
  color::Color
end

function render(str::String;keys...)
  render(get_experiment().win,str;keys...)
end

fonts = Dict{Tuple{String,Int},SDLFont}()
function render(window::SDLWindow,str::String;
                font_name="arial",size=32,color::RGB{U8}=colorant"white",
                max_width=0.8,clean_whitespace=true)
  if (font_name,size) ∉ keys(fonts)
    fonts[(font_name,size)] = font(font_name,size)
  end
  if clean_whitespace
    str = replace(str,r"^\s+","")
    str = replace(str,r"\s+"," ")
  end
  render(window,fonts[(font_name,size)],color,str,
         round(UInt32,window.w*max_width))
end

const w_ptr = 0x0000000000000010 # icxx"offsetof(SDL_Surface,w);"
const h_ptr = 0x0000000000000014 # icxx"offsetof(SDL_Surface,h);"

function render(window::SDLWindow,font::SDLFont,color::RGB{U8},str::String,
                max_width::UInt32)
  surface = ccall((:TTF_RenderUTF8_Blended_Wrapped,_psycho_SDL2_ttf),Ptr{Void},
                  (Ptr{Void},Cstring,RGBA{U8},UInt32),
                  font.data,pointer(str),color,max_width)
  if surface == C_NULL
    error("Failed to render text: "*TTF_GetError())
  end

  texture = ccall((:SDL_CreateTextureFromSurface,_psycho_SDL2),Ptr{Void},
                  (Ptr{Void},Ptr{Void}),window.renderer,surface)
  if texture == C_NULL
    error("Failed to create texture for render text: "*SDL_GetError())
  end

  w = at(surface,Cint,w_ptr)
  h = at(surface,Cint,h_ptr)
  x = SDLText(texture,w,h,color)
  finalizer(x,x ->
            ccall((:SDL_DestroyTexture,_psycho_SDL2),Void,(Ptr{Void},),x.data))
  ccall((:SDL_FreeSurface,_psycho_SDL2),Void,(Ptr{Void},),surface)

  x
end

function draw(text::SDLText,x::Real=0,y::Real=0)
  draw(get_experiment().win,text,x,y)
end

immutable SDLRect
  x::Cint
  y::Cint
  w::Cint
  h::Cint
end

function draw(window::SDLWindow,text::SDLText,x::Real=0,y::Real=0)
  xint = round(Cint,window.w/2 + x*window.w/4 - text.w / 2)
  yint = round(Cint,window.h/2 + y*window.h/4 - text.h / 2)

  rect = [SDLRect(xint,yint,text.w,text.h)]
  ccall((:SDL_RenderCopy,_psycho_SDL2),Void,
        (Ptr{Void},Ptr{Void},Ptr{Void},Ptr{SDLRect}),
        window.renderer,text.data,C_NULL,pointer(rect))
  nothing
end

function display()
  display(get_experiment().win)
end

function display(window::SDLWindow)
  ccall((:SDL_RenderPresent,_psycho_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end

function display(text::SDLText)
  display(get_experiment().win,text)
end

function display(window::SDLWindow,text::SDLText)
  clear(window)
  draw(window,text)
  display(window)
end

function focus(window::SDLWindow)
  ccall((:SDL_RaiseWindow,_psycho_SDL2),Void,(Ptr{Void},),window.data)
end
