import Base: isnull, time
export iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, @key_str

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

"""
    time(e::ExpEvent)

Get the time an event occured relative to the start of the experiment.
"""
time(event::ExpEvent) = 0
time(event::KeyUpEvent) = event.time
time(event::KeyDownEvent) = event.time
time(event::WindowFocused) = event.time
time(event::WindowUnfocused) = event.time

isnull(e::ExpEvent) = false
isnull(e::EmptyEvent) = true

str_to_code = Dict(
  "a" => reinterpret(Int32,'a'),
  "b" => reinterpret(Int32,'b'),
  "c" => reinterpret(Int32,'c'),
  "d" => reinterpret(Int32,'d'),
  "e" => reinterpret(Int32,'e'),
  "f" => reinterpret(Int32,'f'),
  "g" => reinterpret(Int32,'g'),
  "h" => reinterpret(Int32,'h'),
  "i" => reinterpret(Int32,'i'),
  "j" => reinterpret(Int32,'j'),
  "k" => reinterpret(Int32,'k'),
  "l" => reinterpret(Int32,'l'),
  "m" => reinterpret(Int32,'m'),
  "n" => reinterpret(Int32,'n'),
  "o" => reinterpret(Int32,'o'),
  "p" => reinterpret(Int32,'p'),
  "q" => reinterpret(Int32,'q'),
  "r" => reinterpret(Int32,'r'),
  "s" => reinterpret(Int32,'s'),
  "t" => reinterpret(Int32,'t'),
  "u" => reinterpret(Int32,'u'),
  "v" => reinterpret(Int32,'v'),
  "w" => reinterpret(Int32,'w'),
  "x" => reinterpret(Int32,'x'),
  "y" => reinterpret(Int32,'y'),
  "z" => reinterpret(Int32,'z'),
  "0" => reinterpret(Int32,'0'),
  "1" => reinterpret(Int32,'1'),
  "2" => reinterpret(Int32,'2'),
  "3" => reinterpret(Int32,'3'),
  "4" => reinterpret(Int32,'4'),
  "5" => reinterpret(Int32,'5'),
  "6" => reinterpret(Int32,'6'),
  "7" => reinterpret(Int32,'7'),
  "8" => reinterpret(Int32,'8'),
  "9" => reinterpret(Int32,'9'),
  " " => reinterpret(Int32,' '),
  ":space:" => reinterpret(Int32,' '),
  ":up:" => reinterpret(Int32,0x40000052),
  ":down:" => reinterpret(Int32,0x40000051),
  ":left:" => reinterpret(Int32,0x40000050),
  ":right:" => reinterpret(Int32,0x4000004f),
  ":escape:" => reinterpret(Int32,0x0000001b)
)

macro key_str(key)
  try
    str_to_code[key]
  catch
    error("Unknown key \"$key\".")
  end
end

iskeydown(event::ExpEvent) = false
iskeydown(event::KeyDownEvent) = true
iskeydown(keycode::Number) = e -> iskeydown(e,keycode::Number)
iskeydown(event::ExpEvent,keycode::Number) = false
iskeydown(event::KeyDownEvent,keycode::Number) = event.code == keycode

iskeyup(event::ExpEvent) = false
iskeyup(event::KeyUpEvent) = true
iskeyup(keycode::Number) = e -> iskeyup(e,keycode::Number)
iskeyup(event::ExpEvent,keycode::Number) = false
iskeyup(event::KeyUpEvent,keycode::Number) = event.code == keycode

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

function event_streamer(win,quit_callback)
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
    events
  end
end
