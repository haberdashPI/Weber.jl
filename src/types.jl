import Base: show, isempty, time, >>, length, unshift!, promote_rule, convert
import DataStructures: front

export iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, keycode,
  endofpause, @key_str, time, response_time, keycode

################################################################################
# event types

abstract ExpEvent

type QuitEvent <: ExpEvent
end

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


type EndPauseEvent <: ExpEvent
  time::Float64
end

"""
    endofpause(event)

Evaluates to true if the event indicates the end of a pause requested by
the user.
"""
endofpause(event::ExpEvent) = false
endofpause(event::EndPauseEvent) = true
time(event::EndPauseEvent) = event.time

const concrete_events = [
  KeyUpEvent,
  KeyDownEvent,
  WindowFocused,
  WindowUnfocused,
  EndPauseEvent,
  CedrusDownEvent,
  CedrusUpEvent,
  QuitEvent
]

################################################################################
# trial types

abstract Moment
abstract SimpleMoment <: Moment

type ResponseMoment <: SimpleMoment
  respond::Function
  timeout::Function
  timeout_delta_t::Float64
  update_last::Bool
end
update_last(m::ResponseMoment) = m.update_last
update_last(m::Moment) = true

abstract AbstractTimedMoment <: SimpleMoment

type TimedMoment <: AbstractTimedMoment
  delta_t::Float64
  run::Function
end

type OffsetStartMoment <: AbstractTimedMoment
  run::Function
  count_trials::Bool
  expanding::Bool
end

type FinalMoment <: SimpleMoment
  run::Function
end

type CompoundMoment <: Moment
  data::Array{Moment}
end
delta_t(m::CompoundMoment) = 0.0
update_last(m::CompoundMoment) = false
>>(a::SimpleMoment,b::SimpleMoment) = CompoundMoment([a,b])
>>(a::CompoundMoment,b::CompoundMoment) = CompoundMoment(vcat(a.data,b.data))
>>(a::Moment,b::Moment) = >>(promote(a,b)...)
>>(a::Moment,b::Moment,c::Moment,d::Vararg{Moment}) = moment(a,b,c,d...)
promote_rule(::Type{SimpleMoment},::Type{CompoundMoment}) = CompoundMoment
convert(::Type{CompoundMoment},x::SimpleMoment) = CompoundMoment([x])


type ExpandingMoment <: Moment
  condition::Function
  data::Stack{Moment}
  repeat::Bool
  update_offset::Bool
end
delta_t(m::ExpandingMoment) = 0.0
update_last(m::ExpandingMoment) = false

type MomentQueue
  data::Deque{Moment}
  last::Float64
end
isempty(m::MomentQueue) = isempty(m.data)
length(m::MomentQueue) = length(m.data)
enqueue!(m::MomentQueue,x) = push!(m.data,x)
dequeue!(m::MomentQueue) = shift!(m.data)
front(m::MomentQueue) = front(m.data)
function next_moment_time(m::MomentQueue)
  (isempty(m) ? Inf : m.last + delta_t(front(m)))
end

function expand(m::ExpandingMoment,q::MomentQueue)
  if m.condition()
    if !m.repeat
      dequeue!(q)
    end

    for x in m.data
      unshift!(q.data,x)
    end

    unshift!(q.data,m)
  end
end

################################################################################
# experiment types

# information that remains true throughout an experiment
immutable ExperimentInfo
  values::Array
  meta::Dict{Symbol,Any}
  input_resolution::Float64
  moment_resolution::Float64
  start::DateTime
  header::Array{Symbol}
  file::String
  hide_output::Bool
end

# ongoing state about an experiment that changes moment to moment
type ExperimentData
  offset::Int
  trial::Int
  skip_offsets::Int
  last_time::Float64
  next_moment::Float64
  trial_watcher::Function
  pause_mode::Int
  moments::Array{MomentQueue,1}
  cleanup::Function
  last_good_delta::Float64
  last_bad_delta::Float64
end

# flags to track experiment state
type ExperimentFlags
  running::Bool
  processing::Bool
end

immutable Experiment{T}
  info::ExperimentInfo
  data::ExperimentData
  flags::ExperimentFlags
  win::T
end
