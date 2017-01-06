using PyCall
import Base: isnull, time, show
export iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, keycode,
  @key_str, time, response_time, reset_response, keycode

# called by __init__ in Weber.jl
function init_events()
  global const pyxid = pyimport(:pyxid)
  global const pyxid_devices = pyxid[:get_xid_devices]()
end

abstract ExpEvent

type KeyUpEvent <: ExpEvent
  code::Int32
  time::Float64
end

type KeyDownEvent <: ExpEvent
  code::Int32
  time::Float64
end

type WindowFocused <: ExpEvent
  time::Float64
end

type WindowUnfocused <: ExpEvent
  time::Float64
end

type EmptyEvent <: ExpEvent
end

type CedrusDownEvent <: ExpEvent
  code::Int
  port::Int
  rt::Float64
  time::Float64
end


type CedrusUpEvent <: ExpEvent
  code::Int
  port::Int
  rt::Float64
  time::Float64
end

"""
      response_time(e::ExpEvent)

  Get the response time an event occured at. Only meaningful for response pad
  events (returns NaN in other cases). The response time is normally measured from
  the start of a trial (see `reset_response`).

  """
response_time(e::ExpEvent) = NaN
response_time(e::CedrusUpEvent) = e.rt
response_time(e::CedrusDownEvent) = e.rt

"""
      time(e::ExpEvent)

  Get the time an event occured relative to the start of the experiment.
  Resolution is limited by an expeirment's input_resolution (which can be
  specified upon initialization), and the response rate of the device. For
  instance, keyboards usually have a latency on the order of 20-30ms.
  """
time(event::ExpEvent) = NaN
time(event::KeyUpEvent) = event.time
time(event::KeyDownEvent) = event.time
time(event::WindowFocused) = event.time
time(event::WindowUnfocused) = event.time

isnull(e::ExpEvent) = false
isnull(e::EmptyEvent) = true

abstract Key

type KeyboardKey <: Key
  code::Int32
end

type CedrusKey <: Key
  code::Int
end

const str_to_code = Dict(
  "a" => KeyboardKey(reinterpret(Int32,'a')),
  "b" => KeyboardKey(reinterpret(Int32,'b')),
  "c" => KeyboardKey(reinterpret(Int32,'c')),
  "d" => KeyboardKey(reinterpret(Int32,'d')),
  "e" => KeyboardKey(reinterpret(Int32,'e')),
  "f" => KeyboardKey(reinterpret(Int32,'f')),
  "g" => KeyboardKey(reinterpret(Int32,'g')),
  "h" => KeyboardKey(reinterpret(Int32,'h')),
  "i" => KeyboardKey(reinterpret(Int32,'i')),
  "j" => KeyboardKey(reinterpret(Int32,'j')),
  "k" => KeyboardKey(reinterpret(Int32,'k')),
  "l" => KeyboardKey(reinterpret(Int32,'l')),
  "m" => KeyboardKey(reinterpret(Int32,'m')),
  "n" => KeyboardKey(reinterpret(Int32,'n')),
  "o" => KeyboardKey(reinterpret(Int32,'o')),
  "p" => KeyboardKey(reinterpret(Int32,'p')),
  "q" => KeyboardKey(reinterpret(Int32,'q')),
  "r" => KeyboardKey(reinterpret(Int32,'r')),
  "s" => KeyboardKey(reinterpret(Int32,'s')),
  "t" => KeyboardKey(reinterpret(Int32,'t')),
  "u" => KeyboardKey(reinterpret(Int32,'u')),
  "v" => KeyboardKey(reinterpret(Int32,'v')),
  "w" => KeyboardKey(reinterpret(Int32,'w')),
  "x" => KeyboardKey(reinterpret(Int32,'x')),
  "y" => KeyboardKey(reinterpret(Int32,'y')),
  "z" => KeyboardKey(reinterpret(Int32,'z')),
  "0" => KeyboardKey(reinterpret(Int32,'0')),
  "1" => KeyboardKey(reinterpret(Int32,'1')),
  "2" => KeyboardKey(reinterpret(Int32,'2')),
  "3" => KeyboardKey(reinterpret(Int32,'3')),
  "4" => KeyboardKey(reinterpret(Int32,'4')),
  "5" => KeyboardKey(reinterpret(Int32,'5')),
  "6" => KeyboardKey(reinterpret(Int32,'6')),
  "7" => KeyboardKey(reinterpret(Int32,'7')),
  "8" => KeyboardKey(reinterpret(Int32,'8')),
  "9" => KeyboardKey(reinterpret(Int32,'9')),
  "-" => KeyboardKey(reinterpret(Int32,'-')),
  "=" => KeyboardKey(reinterpret(Int32,'=')),
  "[" => KeyboardKey(reinterpret(Int32,'[')),
  "]" => KeyboardKey(reinterpret(Int32,']')),
  "\\" => KeyboardKey(reinterpret(Int32,'\\')),
  ":backslash:" => KeyboardKey(reinterpret(Int32,'\\')),
  ";" => KeyboardKey(reinterpret(Int32,';')),
  "'" => KeyboardKey(reinterpret(Int32,''')),
  "," => KeyboardKey(reinterpret(Int32,',')),
  "." => KeyboardKey(reinterpret(Int32,'.')),
  "/" => KeyboardKey(reinterpret(Int32,'/')),
  "`" => KeyboardKey(reinterpret(Int32,'`')),
  ":space:" => KeyboardKey(reinterpret(Int32,' ')),
  " " => KeyboardKey(reinterpret(Int32,' ')),
  ":up:" => KeyboardKey(reinterpret(Int32,0x40000052)),
  ":down:" => KeyboardKey(reinterpret(Int32,0x40000051)),
  ":left:" => KeyboardKey(reinterpret(Int32,0x40000050)),
  ":right:" => KeyboardKey(reinterpret(Int32,0x4000004f)),
  ":escape:" => KeyboardKey(reinterpret(Int32,0x0000001b)),
  ":esc:" => KeyboardKey(reinterpret(Int32,0x0000001b)),
  ":cedrus0:" => CedrusKey(0),
  ":cedrus1:" => CedrusKey(1),
  ":cedrus2:" => CedrusKey(2),
  ":cedrus3:" => CedrusKey(3),
  ":cedrus4:" => CedrusKey(4),
  ":cedrus5:" => CedrusKey(5),
  ":cedrus6:" => CedrusKey(6),
  ":cedrus7:" => CedrusKey(7),
  ":cedrus8:" => CedrusKey(8),
  ":cedrus9:" => CedrusKey(9),
  ":cedrus10:" => CedrusKey(10),
  ":cedrus11:" => CedrusKey(11),
  ":cedrus12:" => CedrusKey(12),
  ":cedrus13:" => CedrusKey(13),
  ":cedrus14:" => CedrusKey(14),
  ":cedrus15:" => CedrusKey(15),
  ":cedrus16:" => CedrusKey(16),
  ":cedrus17:" => CedrusKey(17),
  ":cedrus18:" => CedrusKey(18),
  ":cedrus19:" => CedrusKey(19)
)

function show(io::IO,x::CedrusKey)
  if 0 <= x.code <= 19
    write(io,"key\":cedrus$(x.code):\"")
  else
    write(io,"Weber.CedrusKey($(x.code))")
  end
end

function show(io::IO,key::KeyboardKey)
  found = filter((_,akey) -> isa(akey,KeyboardKey) && akey.code == key.code,
                 str_to_code)
  if !isempty(found)
    found = collect(found)
    _,j = findmax(map(x -> length(x[1]),found))
    name = found[j][1]
    write(io,"key\"$name\"")
  else
    write(io,"Weber.KeyboardKey($(key.code))")
  end
end

"""
    key"keyname"

Generate a key code, using a single character (e.g. key"q" or key"]"), a
special-key name, or Cedrus response-pad key.

Implemented special keys include:
- ":space:"
- ":up:"
- ":down:"
- ":left"
- ":right:"
- ":escape:"

Cedrus response-pad keys are indicated as ":cedrusN:" where N >= 0

If you want to quickly see the name for a given button you can use
`display_key_codes()`.

"""

macro key_str(key)
  try
    str_to_code[key]
  catch
    error("Unknown key \"$key\".")
  end
end

"""
     keycode(e::ExpEvent)

  Report the key code for this event, if there is one.
"""
keycode(e::ExpEvent) = nothing
keycode(e::CedrusDownEvent) = CedrusKey(e.code)
keycode(e::CedrusUpEvent) = CedrusKey(e.code)
keycode(e::KeyDownEvent) = KeyboardKey(e.code)
keycode(e::KeyUpEvent) = KeyboardKey(e.code)

"""
     iskeydown(event,[key])

  Evalutes to true if the event indicates that the given key (or any key)
  was pressed down. (See `@key_str`)

     iskeydown(key)

  Returns a function which tests if an event indicates the given key was pressed
  down.
  """
iskeydown(event::ExpEvent) = false
iskeydown(event::KeyDownEvent) = true
iskeydown(event::CedrusDownEvent) = true
iskeydown(key::KeyboardKey) = e -> iskeydown(e,key::KeyboardKey)
iskeydown(key::CedrusKey) = e -> iskeydown(e,key::CedrusKey)
iskeydown(event::ExpEvent,keycode::Key) = false
iskeydown(event::KeyDownEvent,key::KeyboardKey) = event.code == key.code
iskeydown(event::CedrusDownEvent,key::CedrusKey) = event.code == key.code

"""
     iskeyup(event,[key])

  Evalutes to true if the event indicates that the given keyboard key (or any key)
  was released.  (See `@key_str`)

     iskeyup(key)

  Returns a function which tests if an event indicates the given key was released.
  """
iskeyup(event::ExpEvent) = false
iskeyup(event::KeyUpEvent) = true
iskeyup(event::CedrusUpEvent) = true
iskeyup(key::KeyboardKey) = e -> iskeydown(e,key)
iskeyup(key::CedrusKey) = e -> iskeydown(e,key)
iskeyup(event::ExpEvent,keycode::Key) = false
iskeyup(event::KeyUpEvent,key::KeyboardKey) = event.code == key.code
iskeyup(event::CedrusUpEvent,key::CedrusKey) = event.code == key.code

isfocused(event::ExpEvent) = false
isfocused(event::WindowFocused) = true

isunfocused(event::ExpEvent) = false
isunfocused(event::WindowUnfocused) = true

const SDL_KEYDOWN = 0x00000300
const SDL_KEYUP = 0x00000301
const SDL_WINDOWEVENT = 0x00000200
const SDL_QUIT = 0x00000100

const SDL_WINDOWEVENT_FOCUS_GAINED = 0x0000000c
const SDL_WINDOWEVENT_FOCUS_LOST = 0x0000000d

const type_ptr = 0x0000000000000000       # offsetof(SDL_Event,type)
const keysym_ptr = 0x0000000000000010     # offsetof(SDL_KeyboardEvent,keysym)
const sym_ptr = 0x0000000000000004        # offsetof(SDL_Keysym,sym)
const win_event_ptr = 0x000000000000000c  # offsetof(SDL_WindowEvent,event)
const event_size = 0x0000000000000038     # sizeof(SDL_Event)

"""
      reset_resposne()

  Reset the response timer for all Cedrus response-pad devices.

  This function will rarely need to be explicitly called. The response timer is
  automatically reset at the start of each trial.
  """
function reset_response()
  for dev in pyxid_devices
    if dev[:is_response_device]()
      dev[:reset_base_timer]()
      dev[:reset_rt_timer]()
    end
  end
end

function event_streamer(win::NullWindow,quit_callback)
  helper(time::Float64) = Signal(ExpEvent,EmptyEvent())
end

function event_streamer(win::SDLWindow,quit_callback)
  function helper(time::Float64)
    events = Signal(ExpEvent,EmptyEvent())

    event_bytes = Array{Int8}(event_size)
    event = reinterpret(Ptr{Void},pointer(event_bytes))

    while ccall((:SDL_PollEvent,_psycho_SDL2),Cint,(Ptr{Void},),event) != 0
      etype = at(event,UInt32,type_ptr)
      if etype == SDL_KEYDOWN
        code = at(event,Int32,keysym_ptr + sym_ptr)
        push!(events,KeyDownEvent(code,time))
      elseif etype == SDL_KEYUP
        code = at(event,Int32,keysym_ptr + sym_ptr)
        push!(events,KeyUpEvent(code,time))
      elseif etype == SDL_WINDOWEVENT
        wevent = at(event,UInt8,win_event_ptr)
        if wevent == SDL_WINDOWEVENT_FOCUS_GAINED
          push!(events,WindowFocused(time))
        elseif wevent == SDL_WINDOWEVENT_FOCUS_LOST
          push!(events,WindowUnfocused(time))
        end
      elseif etype == SDL_QUIT
        quit_callback()
      end
    end

    for dev in pyxid_devices
      if dev[:is_response_device]()
        dev[:poll_for_response]()
        while dev[:response_queue_size]() > 0
          resp = dev[:get_next_response]()
          if resp["pressed"]
            push!(events,CedrusDownEvent(resp["key"],resp["port"],
                                         resp["time"],time))
          else
            push!(events,CedrusUpEvent(resp["key"],resp["port"],
                                       resp["time"],time))
          end
        end
      end
    end

    events
  end
end
