using Colors
using Reactive
using DataStructures
using Lazy: @>>

import Base: display, close
import Base: +
import Colors: @colorant_str, RGB # importing solely to allow their use in user code

export render, window, font, display, close, @colorant_str, RGB

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

function clear(window::SDLWindow,color::Color)
  clear(window,convert(RGB{U8},color))
end

function clear(window::SDLWindow,color::RGB{U8}=colorant"gray")
  ccall((:SDL_SetRenderDrawColor,_psycho_SDL2),Void,
        (Ptr{Void},UInt8,UInt8,UInt8),window.renderer,
        reinterpret(UInt8,red(color)),
        reinterpret(UInt8,green(color)),
        reinterpret(UInt8,blue(color)))
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

const forever = -1

"""
Duration determines how long an object will be displayed.  If the duration
of the object is 0, the object will display until a new object is
displayed. If the duration is Inf the object will be displayed forever.
"""
function display_duration
end

"""
Objects are displayed according to their priority (drawing lower valued
prioritys first, and higher values last). Objects with the same priority show in
the order they were displayed.
"""
function display_priority
end

"""
`SDLRendered` objects are those that can be displayed in an SDLWindow
"""
abstract SDLRendered
abstract SDLSimpleRendered <: SDLRendered

function draw(r::SDLRendered)
  draw(get_experiment().window,r)
end

type SDLClear <: SDLSimpleRendered
  color::Color
  duration::Float64
  priority::Float64
end
display_duration(clear::SDLClear) = clear.duration
display_priority(clear::SDLClear) = clear.priority
render(color::Color;keys...) = render(get_experiment().win,color;keys...)
draw(window::SDLWindow,cl::SDLClear) = clear(window,cl.color)

function render(window::SDLWindow,color::Color;duration=0,priority=0)
  SDLClear(color,duration,priority)
end

immutable SDLRect
  x::Cint
  y::Cint
  w::Cint
  h::Cint
end

type SDLText <: SDLSimpleRendered
  data::Ptr{Void}
  rect::SDLRect
  duration::Float64
  priority::Float64
  color::Color
end

display_duration(text::SDLText) = text.duration
display_priority(text::SDLText) = text.priority

"""
render(str::String, [font_name="arial"], [size=32], [color=colorant"white"],
       [max_width=0.8],[clean_whitespace=true],[x=0],[y=0],[duration=0],
       [priority=0])

Render the given string as an image that can be displayed.

* font_name: name of font to use
* size: font size
* color: color to draw the text in
* max_width: the maximum width as a proportion of the screen the text can
*   take up before wrapping
* clean_whitespace: replace all whitespace characters with a single space?
* x: horizontal position (0 is center of screen, 1 far right, -1 far left)
* y: vertical position (0 is center of screen, 1 topmost, -1 bottommost)
* duration: how long the text should display for, 0 displays until call to
*   display
* priority: display priority, higher priority objects display in front of lower
*   priority ones.
"""
function render(str::String;keys...)
  render(get_experiment().win,str;keys...)
end

fonts = Dict{Tuple{String,Int},SDLFont}()
function render(window::SDLWindow,str::String;
                font_name="arial",size=32,color::RGB{U8}=colorant"white",
                max_width=0.8,clean_whitespace=true,x=0,y=0,
                duration=0,priority=0)
  if (font_name,size) ∉ keys(fonts)
    fonts[(font_name,size)] = font(font_name,size)
  end
  if clean_whitespace
    str = replace(str,r"^\s+","")
    str = replace(str,r"\s+"," ")
  end
  render(window,x,y,fonts[(font_name,size)],color,
         round(UInt32,window.w*max_width),str,duration,priority)
end

const w_ptr = 0x0000000000000010 # icxx"offsetof(SDL_Surface,w);"
const h_ptr = 0x0000000000000014 # icxx"offsetof(SDL_Surface,h);"

function render(window::SDLWindow,x::Real,y::Real,font::SDLFont,color::RGB{U8},
                max_width::UInt32,str::String,duration=0,priority=0)
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

  xint = max(0,min(window.w,round(Cint,window.w/2 + x*window.w/4 - w / 2)))
  yint = max(0,min(window.h,round(Cint,window.h/2 - y*window.h/4 - h / 2)))

  result = SDLText(texture,SDLRect(xint,yint,w,h),duration,priority,color)
  finalizer(result,x ->
            ccall((:SDL_DestroyTexture,_psycho_SDL2),Void,(Ptr{Void},),x.data))
  ccall((:SDL_FreeSurface,_psycho_SDL2),Void,(Ptr{Void},),surface)

  result
end

function draw(window::SDLWindow,text::SDLText)
  ccall((:SDL_RenderCopy,_psycho_SDL2),Void,
        (Ptr{Void},Ptr{Void},Ptr{Void},Ptr{SDLRect}),
        window.renderer,text.data,C_NULL,Ref(text.rect))
  nothing
end

function show_drawn(window::SDLWindow)
  ccall((:SDL_RenderPresent,_psycho_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end

# called in __init__() to create display_stacks global variable
const SDL_INIT_VIDEO = 0x00000020
function setup_display()
  global display_signals = Dict{SDLWindow,Signal{SDLRendered}}()
  global display_stacks = Dict{SDLWindow,Signal{OrderedSet{SDLRendered}}}()

  init = ccall((:SDL_Init,_psycho_SDL2),Cint,(UInt32,),SDL_INIT_VIDEO)
  if init < 0
    error("Failed to initialize SDL: "*SDL_GetError())
  end
end

function display(r::SDLRendered)
  display(get_experiment().win,r)
end

type EmptyRendered <: SDLRendered; end
update_stack_helper(window,stack,r::EmptyRendered) = stack

type DeleteRendered <: SDLRendered
  x::SDLRendered
end
update_stack_helper(window,stack,r::DeleteRendered) = delete!(stack,r.x)

"""
display(win::SDLWindow,r::SDLRendered)

When called on an `SDLWindow`, display will display the `SDLRendered` object for
its `display_duration`.
"""
function display(window::SDLWindow,r::SDLRendered)
  global display_stacks
  global display_signals

  if window ∉ keys(display_stacks)
    signal = display_signals[window] = Signal(SDLRendered,EmptyRendered())
    display_stacks[window] = @>> signal begin
      foldp(update_stack(window),OrderedSet{SDLRendered}())
      map(display_stack(window))
    end
  else
    signal = display_signals[window]
  end

  push!(signal,r)
  handle_remove(signal,r)
end

function handle_remove(signal,r::SDLRendered)
  if display_duration(r) > 0.0 && !isinf(display_duration(r))
    Timer(t -> push!(signal,DeleteRendered(r)),display_duration(r))
  end
end

update_stack(window::SDLWindow) = (s,r) -> update_stack_helper(window,s,r)
function update_stack_helper(window,stack,r::SDLRendered)
  stack = filter(r -> display_duration(r) > 0.0,stack)
  push!(stack,r)
end

function display_stack(window::SDLWindow)
  (stack::OrderedSet{SDLRendered}) -> begin
    clear(window)
    for r in sort(collect(stack),by=display_priority,alg=MergeSort)
      draw(window,r)
    end
    show_drawn(window)

    stack
  end
end

type SDLCompound <: SDLRendered
  data::Array{SDLRendered}
end
function +(a::SDLSimpleRendered,b::SDLSimpleRendered)
  SDLCompound([a,b])
end
function +(a::SDLCompound,b::SDLCompound)
  SDLCompound(vcat(a.data,b.data))
end
+(a::SDLRendered,b::SDLRendered) = +(promote(a,b)...)
promote_rule(::Type{SDLSimpleRendered},::Type{SDLCompound}) = SDLCompound
convert(::Type{SDLCompound},x::SDLSimpleRendered) = SDLCompound([x])
function update_stack_helper(window,stack,rs::SDLCompound)
  stack = filter(r -> display_duration(r) > 0.0,stack)
  for r in rs.data
    push!(stack,r)
  end
  stack
end
function handle_remove(signal,rs::SDLCompound)
  for r in rs.data
    handle_remove(signal,r)
  end
end

type RestoreDisplay <: SDLRendered
  x::OrderedSet{SDLRendered}
end
function update_stack_helper(window,stack,restore::RestoreDisplay)
  # only restore objects that aren't timed. Otherwise the timed objects will
  # never get deleted. There is no well defined way to set their duration again
  # and remove them, since some unknown amount of time has passed since they
  # started being displayed.
  filter(r -> display_duration(r) <= 0.0,restore.x)
end

global saved_display = OrderedSet{SDLRendered}()
function save_display(window::SDLWindow)
  global saved_display
  if window ∈ keys(display_stacks)
    saved_display = value(display_stacks[window])
  else
    saved_display = OrderedSet{SDLRendered}()
  end
end
function restore_display(window::SDLWindow)
  global display_signals
  if window in keys(display_signals)
    push!(display_signals[window],RestoreDisplay(saved_display))
  else
    clear(window)
    show_drawn(window)
  end
end

function focus(window::SDLWindow)
  ccall((:SDL_RaiseWindow,_psycho_SDL2),Void,(Ptr{Void},),window.data)
end
