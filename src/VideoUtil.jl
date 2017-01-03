using Colors
using Images
using Reactive
using DataStructures
using Lazy: @>>

import Base: display, close, +, convert

 # importing solely to allow their use in user code
import Colors: @colorant_str, RGB

export visual, window, font, display, close, @colorant_str, RGB

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

const display_is_setup = Array{Bool}()
display_is_setup[] = false
"""
    window([width=1024],[height=768];[fullscreen=true],[title="Experiment"],
           [accel=true])

Create a window to which various objects can be rendered. See the `visual`
method.
"""
function window(width=1024,height=768;fullscreen=true,
                title="Experiment",accel=true)
  if !display_is_setup[]
    setup_display()
    display_is_setup[] = true
  end

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

"""
    close(win::SDLWindow)

Closes a visible SDLWindow window.
"""
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

"""
    font(name,size,[dirs=os_default],[color=colorant"white"])

Creates an `SDLFont` object to be used for for rendering text as an image.

By default this function looks in the current directory and then an os specific
default font directory for a font with the given name (case insensitive). You
can specify a different list of directories using the `dirs` parameter.

"""
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
    visual(obj,[duration=0],[priority=0],keys...)

Render an object, allowing `display` to show the object in current experiment's
window.

# Arguments
* duration: A positive duration means the object is
  displayed for the given duration, otherwise the object displays until a new
  object is displayed.
* priority: Higher priority objects are always visible above lower priority ones.
  Newer objects display over same-priority older objects.

If coordinates are used they are in units of half screen widths (for x)
and heights (for y), with (0,0) at the center of the screen.

!!! note

    By using using the `+` operator, multiple visual objects can be composed
    into one object, so that they are displayed together
"""
visual(x;keys...) = visual(get_experiment().win,x;keys...)

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
draw(window::SDLWindow,cl::SDLClear) = clear(window,cl.color)

"""
    visual(color,[duration=0],[priority=0])

Render a color, across the entire screen.
"""
function visual(window::SDLWindow,color::Color;duration=0,priority=0)
  SDLClear(color,duration,priority)
end

immutable SDLRect
  x::Cint
  y::Cint
  w::Cint
  h::Cint
end

abstract SDLTextured <: SDLSimpleRendered

function draw(window::SDLWindow,texture::SDLTextured)
  ccall((:SDL_RenderCopy,_psycho_SDL2),Void,
        (Ptr{Void},Ptr{Void},Ptr{Void},Ptr{SDLRect}),
        window.renderer,data(texture),C_NULL,Ref(rect(texture)))
  nothing
end

type SDLText <: SDLTextured
  data::Ptr{Void}
  rect::SDLRect
  duration::Float64
  priority::Float64
  color::Color
end
display_duration(text::SDLText) = text.duration
display_priority(text::SDLText) = text.priority
data(text::SDLText) = text.data
rect(text::SDLText) = text.rect
fonts = Dict{Tuple{String,Int},SDLFont}()

"""
    visual(str::String, [font], [font_name="arial"], [size=32],
           [color=colorant"white"],
           [wrap_width=0.8],[clean_whitespace=true],[x=0],[y=0],[duration=0],
           [priority=0])

Render the given string as an image that can be displayed. An optional
second argument can specify a font, loaded using the `font` function.

# Arguments
* wrap_width: the proporition of the screen that the text can utilize
before wrapping.
* clean_whitespace: if true, replace all consecutive white space with a single
  space.
"""
function visual(window::SDLWindow,str::String;
                font_name="arial",size=32,info...)
  f = get!(fonts,(font_name,size)) do
    font(font_name,size)
  end
  visual(window,str,f;info...)
end

function visual(window::SDLWindow,str::String,font::SDLFont;
                color::RGB{U8}=colorant"white",
                wrap_width=0.8,clean_whitespace=true,x=0,y=0,
                duration=0,priority=0)
  if clean_whitespace
    str = replace(str,r"^\s+","")
    str = replace(str,r"\s+"," ")
  end
  visual(window,x,y,font,color,round(UInt32,window.w*wrap_width),str,
         duration,priority)
end

const w_ptr = 0x0000000000000010 # icxx"offsetof(SDL_Surface,w);"
const h_ptr = 0x0000000000000014 # icxx"offsetof(SDL_Surface,h);"

function as_screen_coordinates(window,x,y,w,h)
  max(0,min(window.w,round(Cint,window.w/2 + x*window.w/4 - w / 2))),
  max(0,min(window.h,round(Cint,window.h/2 - y*window.h/4 - h / 2)))
end

function visual(window::SDLWindow,x::Real,y::Real,font::SDLFont,color::RGB{U8},
                wrap_width::UInt32,str::String,duration=0,priority=0)
  surface = ccall((:TTF_RenderUTF8_Blended_Wrapped,_psycho_SDL2_ttf),Ptr{Void},
                  (Ptr{Void},Cstring,RGBA{U8},UInt32),
                  font.data,pointer(str),color,wrap_width)
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

  xint,yint = as_screen_coordinates(window,x,y,w,h)

  result = SDLText(texture,SDLRect(xint,yint,w,h),duration,priority,color)
  finalizer(result,x ->
            ccall((:SDL_DestroyTexture,_psycho_SDL2),Void,(Ptr{Void},),x.data))
  ccall((:SDL_FreeSurface,_psycho_SDL2),Void,(Ptr{Void},),surface)

  result
end

type SDLImage <: SDLTextured
  data::Ptr{Void}
  img::Any #Image{RGBA{U8}}
  rect::SDLRect
  duration::Float64
  priority::Float64
end
display_duration(img::SDLImage) = img.duration
display_priority(img::SDLImage) = img.priority
data(img::SDLImage) = img.data
rect(img::SDLImage) = img.rect

"""
    visual(img::Image, [x=0],[y=0],[duration=0],[priority=0])
    visual(img::Array, [x=0],[y=0],[duration=0],[priority=0])

Render the color or gray scale image to the screen.
"""
function visual(window::SDLWindow,img::Array;keys...)
  visual(window,convert(Image{RGBA{U8}},img);keys...)
end
function visual(window::SDLWindow,img::Image;keys...)
  visual(window,convert(Image{RGBA{U8}},img);keys...)
end
function visual(window::SDLWindow,img::Image{RGBA{U8}};
                x=0,y=0,duration=0,priority=0)
  surface = ccall((:SDL_CreateRGBSurfaceFrom,_psycho_SDL2),Ptr{Void},
                  (Ptr{Void},Cint,Cint,Cint,Cint,UInt32,UInt32,UInt32,UInt32),
                  pointer(raw(img)),size(img,2),size(img,1),32,
                  4size(img,2),0,0,0,0)
  if surface == C_NULL
    error("Failed to create image surface: "*SDL_GetError())
  end

  texture = ccall((:SDL_CreateTextureFromSurface,_psycho_SDL2),Ptr{Void},
                  (Ptr{Void},Ptr{Void}),window.renderer,surface)
  if texture == C_NULL
    error("Failed to create texture from image surface: "*SDL_GetError())
  end

  h,w = size(img)
  xint,yint = as_screen_coordinates(window,x,y,w,h)

  result = SDLImage(texture,img,SDLRect(xint,yint,w,h),duration,priority)
  finalizer(result,x ->
            ccall((:SDL_DestroyTexture,_psycho_SDL2),Void,(Ptr{Void},),x.data))
  ccall((:SDL_FreeSurface,_psycho_SDL2),Void,(Ptr{Void},),surface)

  result
end

# Below is a scratch implementation that uses Compose rendering. My
# implementation currently throws a mysterious MacOS GUI error on my machine. I
# suspect there is some interaction between Cairo and SDL that is causing the
# problem, but I haven't narrowed it down yet.

# Also note that this currently wont' work well because Pkg.installed isn't a
# good way to handle conditional code. Julia doesn't yet have a better
# solution for this that I know of.

#=
if Pkg.installed("Compose") != nothing && Pkg.installed("Cairo") != nothing
  import Compose
  import Cairo

  const sdl_compose_implemented = true

  type SDLComposed <: SDLTextured
    data::Ptr{Void}
    surface::Cairo.CairoSurface
    rect::SDLRect
    duration::Float64
    priority::Float64
  end
  display_duration(img::SDLComposed) = img.duration
  display_priority(img::SDLComposed) = img.priority
  data(img::SDLComposed) = img.data
  rect(img::SDLComposed) = img.rect

"""
  visual(comp::Compose.Context,[x=0],[y=0],[w=1],[h=1],
                           [dpi=72],[priority=0],[duration=0])

Renders the given Compose.jl object so it can be displayed on screen.
Width and height are specified as a proportion of the full width and height.
"""
  function visual(comp::Compose.Context;keys...)
    visual(get_experiment().win,comp;keys...)
  end
  function visual(win::SDLWindow,comp::Compose.Context;
                  x=0,y=0,w=1,h=1,dpi=72)
    w,h = round(Cint,w*win.w),round(Cint,h*win.h)
    png = Compose.PNG(w,h,dpi)
    Compose.draw(png,comp)
    cairo_surface = png.surface

    surface = ccall((:SDL_CreateRGBSurfaceFrom,_psycho_SDL2),Ptr{Void},
                    (Ptr{Void},Cint,Cint,Cint,Cint,UInt32,UInt32,UInt32,UInt32),
                    cairo_surface.ptr,w,h,8,4w,0,0,0,0)
    if surface == C_NULL
      error("Failed to create surface for Compose.Context: "*SDL_GetError())
    end

    texture = ccall((:SDL_CreateTextureFromSurface,_psycho_SDL2),Ptr{Void},
                    (Ptr{Void},Ptr{Void}),window.renderer,surface)
    if texture == C_NULL
      error("Failed to create texture from Compose.Context surface: "*SDL_GetError())
    end

    xint,yint = as_screen_coordinates(window,x,y,w,h)

    result = SDLComposed(texture,cairo_surface,SDLRect(xint,yint,w,h),
                         duraiton,priority)
    finalizer(result,x ->
              ccall((:SDL_DestroyTexture,_psycho_SDL2),Void,(Ptr{Void},),x.data))

    result
  end
elseif Pkg.installed("Compose") != nothing
  import Compose

  const sdl_compose_implemented = false
  function visual(win::SDLWindow,comp::Compose.Context;keys...)
    error("To render Compose.jl objects you must have Cairo.jl installed!\n"*
          "Please call Pkg.add(\"Cairo\") from the command line")
  end
else
  const sdl_compose_implemented = false
end
=#

function show_drawn(window::SDLWindow)
  ccall((:SDL_RenderPresent,_psycho_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end

# called in __init__() to create display_stacks global variable
const SDL_INIT_VIDEO = 0x00000020
const display_signals = Dict{SDLWindow,Signal{SDLRendered}}()
const display_stacks = Dict{SDLWindow,Signal{OrderedSet{SDLRendered}}}()
function setup_display()
  init = ccall((:SDL_Init,_psycho_SDL2),Cint,(UInt32,),SDL_INIT_VIDEO)
  if init < 0
    error("Failed to initialize SDL: "*SDL_GetError())
  end

  #=
  if !sdl_compose_implemented && Pkg.installed("Compose") != nothing
    warn("The Compose package was installed after Psychotask. "*
         "To render Compose objects using Psychotask you will need to run\n "*
         "rm(Pkg.dir(\"Psychotask\"),recursive=true,force=true); "*
         "Pkg.add(\"Psychotask\")\n before you call `using Psychotask`.")
  end
  =#
end
type EmptyRendered <: SDLRendered; end
update_stack_helper(window,stack,r::EmptyRendered) = stack

type DeleteRendered <: SDLRendered
  x::SDLRendered
end
update_stack_helper(window,stack,r::DeleteRendered) = delete!(stack,r.x)

"""
    display(r::SDLRendered)

Displays a rendered object on the current experiment window.
"""
function display(r::SDLRendered)
  display(get_experiment().win,r)
end

function display(window::SDLWindow,r::SDLRendered)
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

function display(w::SDLWindow,r)
  warn("Rendering was not precomputed!")
  display(w,visual(w,r))
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

const saved_display = Array{OrderedSet{SDLRendered}}()
saved_display[] = OrderedSet{SDLRendered}()
function save_display(window::SDLWindow)
  if window ∈ keys(display_stacks)
    saved_display[] = value(display_stacks[window])
  else
    saved_display[] = OrderedSet{SDLRendered}()
  end
end
function restore_display(window::SDLWindow)
  if window in keys(display_signals)
    push!(display_signals[window],RestoreDisplay(saved_display[]))
  else
    clear(window)
    show_drawn(window)
  end
end

function focus(window::SDLWindow)
  ccall((:SDL_RaiseWindow,_psycho_SDL2),Void,(Ptr{Void},),window.data)
end
