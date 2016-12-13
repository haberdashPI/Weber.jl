using Colors
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

function window(width=1024,height=768;fullscreen=true,title="Experiment")
  if icxx"SDL_Init(SDL_INIT_VIDEO);" < 0
    error("Failed to initialize SDL: "*SDL_GetError())
  end

  if icxx"!SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY,\"1\");"
    warn("Linear texture filtering not enabled.")
  end

  if @cxx(TTF_Init()) == -1
    error("Failed to initialize SDL_ttf: "*TTF_GetError())
  end

  x = y = icxx"SDL_WINDOWPOS_CENTERED;"
  flags = if fullscreen
    icxx"SDL_WINDOW_FULLSCREEN_DESKTOP | SDL_WINDOW_INPUT_GRABBED;"
  else
    icxx"SDL_WINDOW_INPUT_GRABBED;"
  end

  win = @cxx(SDL_CreateWindow(pointer(title),x,y,width,height,flags))
  if win == C_NULL
    error("Failed to create a window: "*SDL_GetError())
  end

  flags = icxx"""
    SDL_RENDERER_ACCELERATED |
    SDL_RENDERER_PRESENTVSYNC |
    SDL_RENDERER_TARGETTEXTURE;
  """

  fallback_flags = icxx"""
    SDL_RENDERER_SOFTWARE;
  """
  rend = @cxx(SDL_CreateRenderer(win,-1,flags))
  if rend == C_NULL
    accel_error = SDL_GetError()
    rend = @cxx(SDL_CreateRenderer(win,-1,fallback_flags))
    if rend == C_NULL
      error("Failed to create a renderer: "*SDL_GetError())
    end
    warn("Failed to create accelerated graphics renderer: "*accel_error)
  end

  wh = Array{Cint}(2)
  @cxx SDL_GetWindowSize(win,pointer(wh,1),pointer(wh,2))

  @cxx SDL_ShowCursor(0)

  x = SDLWindow(win,rend,wh[1],wh[2],false)
  finalizer(x,x -> (x.closed ? nothing : close(x)))

  x
end

function close(win::SDLWindow)
  icxx"SDL_DestroyRenderer((SDL_Renderer*)$:(win.renderer::Ptr{Void}));"
  icxx"SDL_DestroyWindow((SDL_Window*)$:(win.data::Ptr{Void}));"
  win.closed = true
end


function clear(color=colorant"black")
  clear(get_experiment().win,color)
end

function clear(window::SDLWindow,color::Color)
  clear_helper(window,convert(RGB{U8},color))
end

function clear(window::SDLWindow,color::RGB{U8}=colorant"black")
  r::UInt8 = reinterpret(UInt8,red(color))
  g::UInt8 = reinterpret(UInt8,green(color))
  b::UInt8 = reinterpret(UInt8,blue(color))
  icxx"
  SDL_SetRenderDrawColor((SDL_Renderer*)$:(window.renderer::Ptr{Void}),
    $:(r::UInt8),$:(g::UInt8),$:(b::UInt8),255);
  SDL_RenderClear((SDL_Renderer*)$:(window.renderer::Ptr{Void}));
  1;"
  nothing
end


type SDLFont
  data::Ptr{Void}
  color::RGBA{U8}
end

function font(name::String,size;dirs=font_dirs,color=colorant"white")
  file = find_font(name,dirs)
  font = @cxx TTF_OpenFont(pointer(file),size)
  if font == C_NULL
    error("Failed to load the font $file: "*TTF_GetError())
  end

  x = SDLFont(font,color)
  finalizer(x,x -> icxx"TTF_CloseFont((TTF_Font*)$:(x.data::Ptr{Void}));")
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

function render(window::SDLWindow,font::SDLFont,color::RGB{U8},str::String,
                max_width::UInt32)
  surface = ccall((:TTF_RenderUTF8_Blended_Wrapped,_psycho_SDL2_ttf),Ptr{Void},
                  (Ptr{Void},Cstring,RGBA{U8},UInt32),
                  font.data,pointer(str),color,max_width)
  if surface == C_NULL
    error("Failed to render text: "*TTF_GetError())
  end

  texture = icxx"SDL_CreateTextureFromSurface(
    (SDL_Renderer*)$:(window.renderer::Ptr{Void}),
    (SDL_Surface*)$:(surface::Ptr{Void}));"
  if texture == C_NULL
    error("Failed to create texture for render text: "*SDL_GetError())
  end

  w = icxx"((SDL_Surface*)$:(surface::Ptr{Void}))->w;"
  h = icxx"((SDL_Surface*)$:(surface::Ptr{Void}))->h;"
  x = SDLText(texture,w,h,color)
  finalizer(x,x ->
            icxx"SDL_DestroyTexture((SDL_Texture*)$:(x.data::Ptr{Void}));")
  icxx"SDL_FreeSurface((SDL_Surface*)$:(surface::Ptr{Void}));"

  x
end

function draw(text::SDLText,x::Real=0,y::Real=0)
  draw(get_experiment().win,text,x,y)
end

function draw(window::SDLWindow,text::SDLText,x::Real=0,y::Real=0)
  xint = round(Cint,window.w/2 + x*window.w/4 - text.w / 2)
  yint = round(Cint,window.h/2 + y*window.h/4 - text.h / 2)

  icxx"""
  SDL_Rect rect = {$:(xint::Cint),$:(yint::Cint),
                   $:(text.w::Cint),$:(text.h::Cint)};
  SDL_RenderCopy((SDL_Renderer*)$:(window.renderer),
                 (SDL_Texture*)$:(text.data),NULL,&rect);
  """
  nothing
end

function display()
  display(get_experiment().win)
end

function display(window::SDLWindow)
  icxx"SDL_RenderPresent((SDL_Renderer*)$:(window.renderer::Ptr{Void}));"
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
