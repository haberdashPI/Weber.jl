using Colors
using FixedPointNumbers
using Images
using FileIO
using DataStructures
using Lazy: @>>
using LRUCache

import Base: display, close, +, convert, promote_rule, convert, push!,
  filter!, length, collect, copy

 # importing solely to allow their use in user code
import Colors: @colorant_str, RGB

export visual, window, font, display, close, @colorant_str, RGB,
  clear_image_cache

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

abstract type SDLRendered end
abstract type SDLSimpleRendered <: SDLRendered end
timed(r) = 0.0 < display_duration(r) < Inf
visual(x::SDLRendered;kwds...) = update_arguments(x;kwds...)

struct RenderItem
  r::SDLRendered
  delete_at::Float64
end
display_priority(x::RenderItem) = display_priority(x.r)
display_duration(x::RenderItem) = display_duration(x.r)
timed(x::RenderItem) = timed(x.r)

mutable struct DisplayStack
  data::OrderedSet{RenderItem}
  next_change::Float64
end
DisplayStack() = DisplayStack(OrderedSet{RenderItem}(),Inf)

function push!(x::DisplayStack,r::SDLRendered)
  item = RenderItem(r,(timed(r) ? Weber.tick() + display_duration(r) : Inf))
  push!(x.data,item)
  if timed(r)
    x.next_change = min(x.next_change,item.delete_at)
  end
  x
end

function delete_untimed!(x::DisplayStack)
  filter!(r -> display_duration(r) > 0.0,x.data)
end

function delete_timed!(x::DisplayStack)
  filter!(r -> display_duration(r) <= 0.0 || isinf(display_duration(r)),x.data)
  x
end

const change_resolution = 0.001
function delete_expired!(stack::DisplayStack,tick=Weber.tick())
  next_change = Inf
  stack.data = filter!(stack.data) do item
    if item.delete_at + change_resolution <= tick
      next_change = min(next_change,item.delete_at)
      false
    else
      true
    end
  end
  stack.next_change = next_change

  stack
end
length(x::DisplayStack) = length(x.data)
collect(x::DisplayStack) = collect(x.data)
copy(x::DisplayStack) = DisplayStack(copy(x.data),x.next_change)
ischanging(x::DisplayStack,tick) = x.next_change + change_resolution <= tick

abstract type ExperimentWindow end
mutable struct NullWindow <: ExperimentWindow
  w::Cint
  h::Cint
  closed::Bool
end
visual(win::NullWindow,args...;kwds...) = nothing
display(win::NullWindow,r;kwds...) = nothing

mutable struct SDLWindow <: ExperimentWindow
  data::Ptr{Void}
  renderer::Ptr{Void}
  w::Cint
  h::Cint
  closed::Bool
  stack::DisplayStack
end

const SDL_WINDOWPOS_CENTERED = 0x2fff0000
const SDL_WINDOW_FULLSCREEN_DESKTOP = 0x00001001
const SDL_WINDOW_INPUT_GRABBED = 0x00000100
const SDL_WINDOW_INPUT_FOCUS = 0x00000200
const SDL_WINDOW_MOUSE_FOCUS = 0x00000400
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
                title="Experiment",accel=true,null=false)

  if !display_is_setup[] && !null
    setup_display()
    display_is_setup[] = true
  elseif null
    return NullWindow(width,height,false)
  end

  if !ccall((:SDL_SetHint,weber_SDL2),Bool,(Cstring,Cstring),
            "SDL_RENDER_SCALE_QUALITY","1")
    warn("Linear texture filtering not enabled.")
  end

  if ccall((:TTF_Init,weber_SDL2_ttf),Cint,()) == -1
    error("Failed to initialize SDL_ttf: "*TTF_GetError())
  end

  x = y = SDL_WINDOWPOS_CENTERED
  flags = (fullscreen ? SDL_WINDOW_FULLSCREEN_DESKTOP : 0x0) |
    SDL_WINDOW_INPUT_GRABBED | SDL_WINDOW_INPUT_FOCUS | SDL_WINDOW_MOUSE_FOCUS

  win = ccall((:SDL_CreateWindow,weber_SDL2),Ptr{Void},
              (Cstring,Cint,Cint,Cint,Cint,UInt32),
              pointer(title),x,y,width,height,flags)
  if win == C_NULL
    error("Failed to create a window: "*SDL_GetError())
  end

  flags = SDL_RENDERER_ACCELERATED |
    SDL_RENDERER_PRESENTVSYNC |
    SDL_RENDERER_TARGETTEXTURE

  fallback_flags = SDL_RENDERER_SOFTWARE

  rend = ccall((:SDL_CreateRenderer,weber_SDL2),Ptr{Void},
               (Ptr{Void},Cint,UInt32),win,-1,(accel ? flags : fallback_flags))
  if rend == C_NULL
    accel_error = SDL_GetError()
    if accel
      rend = ccall((:SDL_CreateRenderer,weber_SDL2),Ptr{Void},
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
  ccall((:SDL_GetWindowSize,weber_SDL2),Void,
        (Ptr{Void},Ptr{Cint},Ptr{Cint}),win,pointer(wh,1),pointer(wh,2))
  ccall((:SDL_ShowCursor,weber_SDL2),Void,(Cint,),0)

  x = SDLWindow(win,rend,wh[1],wh[2],false,DisplayStack())
  finalizer(x,x -> (x.closed ? nothing : close(x)))

  x
end

"""
    close(win::SDLWindow)

Closes a visible SDLWindow window.
"""
function close(win::SDLWindow)
  ccall((:SDL_DestroyRenderer,weber_SDL2),Void,(Ptr{Void},),win.renderer)
  ccall((:SDL_DestroyWindow,weber_SDL2),Void,(Ptr{Void},),win.data)
  ccall((:SDL_ShowCursor,weber_SDL2),Void,(Cint,),1)

  win.closed = true
end
close(win::NullWindow) = win.closed = true

function clear(window,color::Color)
  clear(window,convert(RGB{N0f8},color))
end

function clear(window::SDLWindow,color::RGB{N0f8}=colorant"gray")
  ccall((:SDL_SetRenderDrawColor,weber_SDL2),Void,
        (Ptr{Void},UInt8,UInt8,UInt8),window.renderer,
        reinterpret(UInt8,red(color)),
        reinterpret(UInt8,green(color)),
        reinterpret(UInt8,blue(color)))
  ccall((:SDL_RenderClear,weber_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end
clear(win::NullWindow,color) = nothing

mutable struct SDLFont
  data::Ptr{Void}
  color::RGBA{N0f8}
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
  font = ccall((:TTF_OpenFont,weber_SDL2_ttf),Ptr{Void},(Cstring,Cint),
               pointer(file),size)
  if font == C_NULL
    error("Failed to load the font $file: "*TTF_GetError())
  end

  x = SDLFont(font,color)
  finalizer(x,x -> ccall((:TTF_CloseFont,weber_SDL2_ttf),Void,
                         (Ptr{Void},),x.data))
  x
end

const forever = -1

"""
    visual(obj,[duration=0s],[priority=0],keys...)

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
visual(x,args...;keys...) = visual(win(get_experiment()),x,args...;keys...)
visual(win::SDLWindow,x,args...;keys...) =
  throw(MethodError(visual,typeof((win,x))))

function draw(r::SDLRendered)
  draw(win(get_experiment()),r)
end

struct SDLClear <: SDLSimpleRendered
  color::Color
  duration::Float64
  priority::Float64
end
display_duration(clear::SDLClear) = clear.duration
display_priority(clear::SDLClear) = clear.priority
draw(window::SDLWindow,cl::SDLClear) = clear(window,cl.color)
function update_arguments(cl::SDLClear;duration=cl.duration*s,
                          priority=cl.priority,kwds...)
  SDLClear(cl.color,ustrip(inseconds(duration)),priority)
end

"""
    visual(color,[duration=0s],[priority=0])

Render a color, across the entire screen.
"""
function visual(window::SDLWindow,color::Color;duration=0s,priority=0)
  SDLClear(color,ustrip(inseconds(duration)),priority)
end

immutable SDLRect
  x::Cint
  y::Cint
  w::Cint
  h::Cint
end

function as_screen_coordinates(window,x,y,w,h)
  max(0,min(window.w,round(Cint,window.w/2 + x*window.w/4 - w / 2))),
  max(0,min(window.h,round(Cint,window.h/2 - y*window.h/4 - h / 2)))
end

function as_screen_coordinate_x(window,x,w)
  max(0,min(window.w,round(Cint,window.w/2 + x*window.w/4 - w / 2)))
end
function as_screen_coordinate_y(window,y,w)
  max(0,min(window.h,round(Cint,window.h/2 - y*window.h/4 - h / 2)))
end

function update_arguments(rect::SDLRect;w=NaN,h=NaN,x=NaN,y=NaN,kwds...)
  if !isnan(x) || !isnan(y) || !isnan(w) || !isnan(h)
    if isnan(w)
      w = rect.w
    end
    if isnan(h)
      h = rect.h
    end

    if !isnan(x)
      newx = as_screen_coordinate_x(window,x,w)
    else
      newx = rect.x
    end

    if !isnan(y)
      newy = as_screen_coordinate_y(window,y,h)
    else
      newy = rect.y
    end

    SDLRect(x,y,w,h)
  else
    rect
  end
end


abstract type SDLTextured <: SDLSimpleRendered end

function draw(window::SDLWindow,texture::SDLTextured)
  ccall((:SDL_RenderCopy,weber_SDL2),Void,
        (Ptr{Void},Ptr{Void},Ptr{Void},Ptr{SDLRect}),
        window.renderer,data(texture),C_NULL,Ref(rect(texture)))
  nothing
end

mutable struct SDLText <: SDLTextured
  str::String
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
function update_arguments(text::SDLText;w=NaN,h=NaN,color=nothing,
                          duration=text.duration*s,priority=text.priority,
                          kwds...)
  if !isnan(w) || !isnan(h)
    error("Cannot update the height or width of text on display. These",
          "properties are automatically determiend by the original string",
          " used to render the text")
  end

  if color != nothing
    error("You cannot change the color of text on display. Create"*
          " a new text object using the desired color.")
  end

  rect = update_arguments(text.rect;kwds...)
  SDLText(text.str,text.data,rect,ustrip(inseconds(duration)),priority,text.color)
end

fonts = Dict{Tuple{String,Int},SDLFont}()

image_formats = [
  "BMP",
  "AVI",
  "CRW",
  "CUR",
  "DCX",
  "DOT",
  "EPS",
  "GIF",
  "HDR",
  "ICO",
  "INFO",
  "JP2",
  "JPEG",
  "PCX",
  "PDB",
  "PDF",
  "PGM",
  "PNG",
  "PSD",
  "RGB",
  "TIFF",
  "WMF",
  "WPG",
  "TGA"
]
function isimage(str::String)
  ismatch(r".*\.(\w{3,4})$",str) &&
    uppercase(match(r".*\.(\w{3,4})$",str)[1]) in image_formats
end

"""
    visual(str::String, [font=nothing], [font_name="arial"], [size=32],
           [color=colorant"white"],
           [wrap_width=0.8],[clean_whitespace=true],[x=0],[y=0],[duration=0s],
           [priority=0])

Render the given string as an image that can be displayed. An optional second
argument can specify a font, loaded using the `font` function.

!!! note "Strings treated as files..."

    If the string passed refers to an image file--becasue the string ends in a
    file type, like .bmp or .png---it will be treated as an image to be loaded
    and displayed, rather than as a string to be printed to the screen.
    Refer to the documentation of `visual` for image objects.

# Arguments
* wrap_width: the proporition of the screen that the text can utilize
  before wrapping.
* clean_whitespace: if true, replace all consecutive white space with a single
  space.
"""
function visual(window::SDLWindow,str::String,cache=true;keys...)
  if isimage(str)
    image_cache(cache,str) do
      visual(window,load(str),false;keys...)
    end
  else
    visual_text(window,str;keys...)
  end
end

function visual_text(window::SDLWindow,str::String;
                     font=nothing,font_name="arial",size=32,info...)
  if font == nothing
    f = get!(fonts,(font_name,size)) do
      Weber.font(font_name,size)
    end
    visual(window,str,f;info...)
  else
    if font_name != "arial" || size != 32
      error("Cannot specify both a font object and font_name or size. Either ",
            "use a font object, or specify the font using a name and size.")
    end
    visual(window,str,font;info...)
  end
end

function visual(window::SDLWindow,str::String,font::SDLFont;
                color::RGB{N0f8}=colorant"white",
                wrap_width=0.8,clean_whitespace=true,x=0,y=0,
                duration=0s,priority=0)
  if clean_whitespace
    str = replace(str,r"^\s+","")
    str = replace(str,r"\s+"," ")
  end
  visual(window,x,y,font,color,round(UInt32,window.w*wrap_width),str,
         inseconds(duration),priority)
end

const w_ptr = 0x0000000000000010 # icxx"offsetof(SDL_Surface,w);"
const h_ptr = 0x0000000000000014 # icxx"offsetof(SDL_Surface,h);"

const text_cache = LRU{Tuple{String,UInt32,SDLFont},SDLText}(256)

function visual(window::SDLWindow,x::Real,y::Real,font::SDLFont,color::RGB{N0f8},
                wrap_width::UInt32,str::String,duration=0s,priority=0)
  get!(text_cache,(str,wrap_width,font)) do
    surface = ccall((:TTF_RenderUTF8_Blended_Wrapped,weber_SDL2_ttf),Ptr{Void},
                    (Ptr{Void},Cstring,RGBA{N0f8},UInt32),
                    font.data,pointer(str),color,wrap_width)
    if surface == C_NULL
      error("Failed to render text: "*TTF_GetError())
    end

    texture = ccall((:SDL_CreateTextureFromSurface,weber_SDL2),Ptr{Void},
                    (Ptr{Void},Ptr{Void}),window.renderer,surface)
    if texture == C_NULL
      error("Failed to create texture for render text: "*SDL_GetError())
    end

    w = at(surface,Cint,w_ptr)
    h = at(surface,Cint,h_ptr)

    xint,yint = as_screen_coordinates(window,x,y,w,h)

    result = SDLText(str,texture,SDLRect(xint,yint,w,h),
                     ustrip(inseconds(duration)),priority,color)
    finalizer(result,x ->
              ccall((:SDL_DestroyTexture,weber_SDL2),Void,(Ptr{Void},),x.data))
    ccall((:SDL_FreeSurface,weber_SDL2),Void,(Ptr{Void},),surface)

    result
  end
end

mutable struct SDLImage <: SDLTextured
  data::Ptr{Void}
  img::Array{RGBA{N0f8}}
  rect::SDLRect
  duration::Float64
  priority::Float64
end
display_duration(img::SDLImage) = img.duration
display_priority(img::SDLImage) = img.priority
data(img::SDLImage) = img.data
rect(img::SDLImage) = img.rect
function update_arguments(img::SDLImage;w=NaN,h=NaN,duration=img.duration*s,
                          priority=img.priority,kwds...)
  if !isnan(w) || !isnan(h)
    error("Cannot update the height or width of an image on display. These",
          "properties are automatically determiend by the original image.")
  end

  rect = update_arguments(img.rect;kwds...)
  SDLImage(img.data,img.img,rect,ustrip(inseconds(duration)),priority)
end

const convert_cache = LRU{UInt,Array{RGBA{N0f8}}}(256)
const _image_cache = LRU{UInt,SDLImage}(256)

function clear_image_cache()
  empty!(convert_cache)
  empty!(_imge_cache)
end

function image_cache(fn,usecache,x)
  if usecache
    get!(fn,_image_cache,object_id(x))
  else
    fn()
  end
end

function image_cache(fn,usecache::Union{File,String},x)
  if usecache
    get!(fn,_image_cache,x)
  else
    fn()
  end
end

"""
    visual(img, [x=0],[y=0],[duration=0s],[priority=0])

Prepare the color or gray scale image to be displayed to the screen.

For a string or file reference, this loads and prepares for display the given
image file. For an array this utilizes all the conventions in the `Images`
package for representing images. Internally, real-number 2d arrays are
interpreted as gray scale images, and real-number 3d arrays as an RGB image or
RGBA image, depending on whether size(img,1) is of size 3 or 4. A 3d array with
a size(img,1) ∉ [3,4] results in an error.
"""
function visual(window::SDLWindow,img::Array{<:AbstractFloat},cache=true;keys...)
  image_cache(cache,img) do
    converted = if length(size(img)) == 3
      if size(img,1) == 3
        n0f8.(colorview(RGB,img))
      elseif size(img,1) == 4
        n0f8.(colorview(RGBA,img))
      else
        error("Could not interpret array of size $(size(imge)) as a color image.")
      end
    elseif length(size(img)) == 2
      n0f8.(colorview(Gray,img))
    end
    visual(window,converted,false;keys...)
  end
end

function visual(window::SDLWindow,img::Array,cache=true;keys...)
  image_cache(cache,img) do
    visual(window,convert(RGBA,n0f8.(img)),false;keys...)
  end
end

function visual(window::SDLWindow,img::Array{RGBA{N0f8}},cache=true;
                x=0,y=0,duration=0s,priority=0)
  image_cache(cache,img) do
    surface = ccall((:SDL_CreateRGBSurfaceFrom,weber_SDL2),Ptr{Void},
                    (Ptr{Void},Cint,Cint,Cint,Cint,UInt32,UInt32,UInt32,UInt32),
                    pointer(copy(img')),size(img,2),size(img,1),32,
                    4size(img,2),0x000000ff,0x0000ff00,0x00ff0000,0xff000000)
    if surface == C_NULL
      error("Failed to create image surface: "*SDL_GetError())
    end

    texture = ccall((:SDL_CreateTextureFromSurface,weber_SDL2),Ptr{Void},
                    (Ptr{Void},Ptr{Void}),window.renderer,surface)
    if texture == C_NULL
      error("Failed to create texture from image surface: "*SDL_GetError())
    end

    h,w = size(img)
    xint,yint = as_screen_coordinates(window,x,y,w,h)

    result = SDLImage(texture,img,SDLRect(xint,yint,w,h),
                      ustrip(inseconds(duration)),priority)
    finalizer(result,x ->
              ccall((:SDL_DestroyTexture,weber_SDL2),Void,(Ptr{Void},),x.data))
    ccall((:SDL_FreeSurface,weber_SDL2),Void,(Ptr{Void},),surface)

    result
  end
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
                           [dpi=72],[priority=0],[duration=0s])

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

    surface = ccall((:SDL_CreateRGBSurfaceFrom,weber_SDL2),Ptr{Void},
                    (Ptr{Void},Cint,Cint,Cint,Cint,UInt32,UInt32,UInt32,UInt32),
                    cairo_surface.ptr,w,h,8,4w,0,0,0,0)
    if surface == C_NULL
      error("Failed to create surface for Compose.Context: "*SDL_GetError())
    end

    texture = ccall((:SDL_CreateTextureFromSurface,weber_SDL2),Ptr{Void},
                    (Ptr{Void},Ptr{Void}),window.renderer,surface)
    if texture == C_NULL
      error("Failed to create texture from Compose.Context surface: "*SDL_GetError())
    end

    xint,yint = as_screen_coordinates(window,x,y,w,h)

    result = SDLComposed(texture,cairo_surface,SDLRect(xint,yint,w,h),
                         duraiton,priority)
    finalizer(result,x ->
              ccall((:SDL_DestroyTexture,weber_SDL2),Void,(Ptr{Void},),x.data))

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
  ccall((:SDL_RenderPresent,weber_SDL2),Void,(Ptr{Void},),window.renderer)
  nothing
end
show_drawn(win::NullWindow) = nothing

const SDL_INIT_VIDEO = 0x00000020
function setup_display()
  init = ccall((:SDL_Init,weber_SDL2),Cint,(UInt32,),SDL_INIT_VIDEO)
  if init < 0
    error("Failed to initialize SDL: "*SDL_GetError())
  end
  if !sdl_is_setup[]
    sdl_is_setup[] = true
    atexit(() -> ccall((:SDL_Quit,weber_SDL2),Void,()))
  end

  #=
  if !sdl_compose_implemented && Pkg.installed("Compose") != nothing
    warn("The Compose package was installed after Weber. "*
         "To render Compose objects using Weber you will need to run\n "*
         "rm(Pkg.dir(\"Weber\"),recursive=true,force=true); "*
         "Pkg.add(\"Weber\")\n before you call `using Weber`.")
  end
  =#
end

"""
    display(r::SDLRendered;kwds...)

Displays anything rendered by `visual` onto the current experiment window.

Any keyword arguments, available from [`visual`](@ref) are also available here.
They overload the arguments as specified during visual (but do not change them).

    display(x;kwds...)

Short-hand for `display(visual(x);kwds...)`. This is the most common way to use
display. For example:

    moment(0.5s,display,"Hello, World!")

This code will show the text "Hello, World!" on the screen 0.5 seconds after
the start of the previous moment.

!!! warning

    Assuming your hardware and video drivers permit it, `display` sycnrhonizes
    to the screen refresh rate so long as the experiment window uses accelerated
    graphics (true by default). The display of a visual can be no more accurate
    than that permitted by this refresh rate. In particular, display can block
    for up to the length of an entire refresh cycle. If you want accurate timing
    in your experiment, make sure that there is nothing you want to occur
    immediately after calling display. If you want to display multiple visuals
    at once remember that you can compose visuals using the `+` operator, do not
    call display multiple times and expect these visual to all display at the
    same time (also note that the default behavior of visuals is to disappear
    when the next visual is shown).

"""
function display(r::SDLRendered;kwds...)
  if in_experiment() && !experiment_running()
    error("You cannot call `display` during experiment `setup`. During `setup`",
          " you should add `dispaly` to a trial (e.g. ",
          "`addtrial(moment(display,my_visual))`).")
  end
  display(win(get_experiment()),r;kwds...)
end

"""
    display(fn::Function;kwds...)

Display the visual returned by calling `fn`.
"""
display(fn::Function;kwds...) = display(fn();kwds...)

update_arguments(r) = r
function display(window::SDLWindow,r::SDLRendered;kwds...)
  r = update_arguments(r;kwds...)
  update_stack!(window,r)

  # if there's no experiment, handle display duration
  if timed(r) && !in_experiment()
    eventually_remove!(window,stack,r)
    warn("calling display outside of an experiment")
  end
end

function update_stack!(window,r)
  update_stack_helper!(window,r)
  draw_stack(window)
end

function eventually_remove!(window::SDLWindow,stack::DisplayStack,r::SDLRendered)
  Timer(duration(r)) do t
    window.stack = delete_expired!(window.stack,precise_time())
    draw_stack(window)
  end
end

function display(w::SDLWindow,r)
  if experiment_running()
    warn("Visual was not precomputed! To minimize latency* call "*
         "`x = visual(obj)` before running an experiment* then call"*
         " `display(x)` during the experiment.",moment_trace_string())
  end
  display(w,visual(w,r))
end

function update_stack_helper!(window,r::SDLRendered)
  delete_untimed!(window.stack)
  push!(window.stack,r)
end

function draw_stack(window::SDLWindow)
  clear(window)
  for item in sort(collect(window.stack),by=display_priority,alg=MergeSort)
    draw(window,item.r)
  end
  show_drawn(window)
end

function refresh_display(window::SDLWindow,tick=Weber.tick())
  if ischanging(window.stack,tick)
    window.stack = delete_expired!(window.stack,tick)
    draw_stack(window)
  end
end

refresh_display(window::NullWindow) = nothing

struct SDLCompound <: SDLRendered
  data::Array{SDLRendered}
end
function +(a::SDLSimpleRendered,b::SDLSimpleRendered)
  SDLCompound([a,b])
end
function +(a::SDLCompound,b::SDLCompound)
  SDLCompound(vcat(a.data,b.data))
end
+(a::SDLRendered,b::SDLRendered) = +(promote(a,b)...)
promote_rule{T <: SDLSimpleRendered}(::Type{SDLCompound},::Type{T}) = SDLCompound
convert(::Type{SDLCompound},x::SDLSimpleRendered) = SDLCompound([x])
function update_stack_helper!(window,rs::SDLCompound)
  delete_untimed!(window.stack)
  for r in rs.data
    push!(window.stack,r)
  end
end
function eventually_remove!(window::SDLWindow,stack::DisplayStack,
                            rs::SDLCompound)
  for r in rs
    eventually_remove!(window,stack,r)
  end
end
timed(r::SDLCompound) = any(timed,r.data)

function update_arguments(rs::SDLCompound;kwds...)
  SDLCompound(map(r -> update_arguments(r;kwds...),rs.data))
end

struct RestoreDisplay <: SDLRendered
  x::DisplayStack
end
function update_stack_helper!(window,restore::RestoreDisplay)
  # only restore objects that aren't timed. Otherwise the timed objects will
  # never get deleted. There is no well defined way to set their duration again
  # and remove them, since some unknown amount of time has passed since they
  # started being displayed. TODO: this is no longer true,
  # their duration could be calculated
  window.stack = delete_timed!(restore.x)
end

const saved_display = Array{DisplayStack}()
saved_display[] = DisplayStack()
function save_display(window::SDLWindow)
  saved_display[] = copy(window.stack)
end
save_display(win::NullWindow) = nothing

function restore_display(window::SDLWindow)
  update_stack!(window,RestoreDisplay(saved_display[]))
end
restore_display(win::NullWindow) = nothing

function focus(window::SDLWindow)
  ccall((:SDL_RaiseWindow,weber_SDL2),Void,(Ptr{Void},),window.data)
end
focus(win::NullWindow) = nothing
