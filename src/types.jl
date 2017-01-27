import Base: show, isempty, time, >>, length, unshift!, promote_rule, convert,
  hash, ==, isless
import DataStructures: front

export iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, keycode,
  endofpause, @key_str, time, response_time, keycode, listkeys

################################################################################
# event types

abstract ExpEvent

type QuitEvent <: ExpEvent
end

type KeyUpEvent <: ExpEvent
  code::UInt32
  time::Float64
end

type KeyDownEvent <: ExpEvent
  code::UInt32
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

macro os(kwds...)
  @assert kwds[1].args[1] == :apple
  @assert kwds[2].args[1] == :windows
  @assert kwds[3].args[1] == :linux

  if is_apple()
    kwds[1].args[2]
  elseif is_windows()
    kwds[2].args[2]
  elseif is_linux()
    kwds[3].args[2]
  else
    error("Unsupported operating system")
  end
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
==(x::Key,y::Key) = false

type KeyboardKey <: Key
  code::Int32
end
hash(x::KeyboardKey,h::UInt) = hash(KeyboardKey,hash(x.code,h))
==(x::KeyboardKey,y::KeyboardKey) = x.code == y.code
isless(x::KeyboardKey,y::KeyboardKey) = isless(x.code,y.code)

type CedrusKey <: Key
  code::Int
end
hash(x::CedrusKey,h::UInt) = hash(CedrusKey,hash(x.code,h))
==(x::CedrusKey,y::CedrusKey) = x.code == y.code
isless(x::CedrusKey,y::CedrusKey) = isless(x.code,y.code)

isless(x::KeyboardKey,y::CedrusKey) = false
isless(x::CedrusKey,y::KeyboardKey) = true

const str_to_code = Dict(
  "a" => KeyboardKey(reinterpret(UInt32,'a')),
  "b" => KeyboardKey(reinterpret(UInt32,'b')),
  "c" => KeyboardKey(reinterpret(UInt32,'c')),
  "d" => KeyboardKey(reinterpret(UInt32,'d')),
  "e" => KeyboardKey(reinterpret(UInt32,'e')),
  "f" => KeyboardKey(reinterpret(UInt32,'f')),
  "g" => KeyboardKey(reinterpret(UInt32,'g')),
  "h" => KeyboardKey(reinterpret(UInt32,'h')),
  "i" => KeyboardKey(reinterpret(UInt32,'i')),
  "j" => KeyboardKey(reinterpret(UInt32,'j')),
  "k" => KeyboardKey(reinterpret(UInt32,'k')),
  "l" => KeyboardKey(reinterpret(UInt32,'l')),
  "m" => KeyboardKey(reinterpret(UInt32,'m')),
  "n" => KeyboardKey(reinterpret(UInt32,'n')),
  "o" => KeyboardKey(reinterpret(UInt32,'o')),
  "p" => KeyboardKey(reinterpret(UInt32,'p')),
  "q" => KeyboardKey(reinterpret(UInt32,'q')),
  "r" => KeyboardKey(reinterpret(UInt32,'r')),
  "s" => KeyboardKey(reinterpret(UInt32,'s')),
  "t" => KeyboardKey(reinterpret(UInt32,'t')),
  "u" => KeyboardKey(reinterpret(UInt32,'u')),
  "v" => KeyboardKey(reinterpret(UInt32,'v')),
  "w" => KeyboardKey(reinterpret(UInt32,'w')),
  "x" => KeyboardKey(reinterpret(UInt32,'x')),
  "y" => KeyboardKey(reinterpret(UInt32,'y')),
  "z" => KeyboardKey(reinterpret(UInt32,'z')),
  "0" => KeyboardKey(reinterpret(UInt32,'0')),
  "1" => KeyboardKey(reinterpret(UInt32,'1')),
  "2" => KeyboardKey(reinterpret(UInt32,'2')),
  "3" => KeyboardKey(reinterpret(UInt32,'3')),
  "4" => KeyboardKey(reinterpret(UInt32,'4')),
  "5" => KeyboardKey(reinterpret(UInt32,'5')),
  "6" => KeyboardKey(reinterpret(UInt32,'6')),
  "7" => KeyboardKey(reinterpret(UInt32,'7')),
  "8" => KeyboardKey(reinterpret(UInt32,'8')),
  "9" => KeyboardKey(reinterpret(UInt32,'9')),
  "-" => KeyboardKey(reinterpret(UInt32,'-')),
  "=" => KeyboardKey(reinterpret(UInt32,'=')),
  "_" => KeyboardKey(reinterpret(UInt32,'-')),
  "+" => KeyboardKey(reinterpret(UInt32,'=')),
  "[" => KeyboardKey(reinterpret(UInt32,'[')),
  "]" => KeyboardKey(reinterpret(UInt32,']')),
  "\\" => KeyboardKey(reinterpret(UInt32,'\\')),
  ":backslash:" => KeyboardKey(reinterpret(UInt32,'\\')),
  ";" => KeyboardKey(reinterpret(UInt32,';')),
  "'" => KeyboardKey(reinterpret(UInt32,''')),
  "," => KeyboardKey(reinterpret(UInt32,',')),
  "." => KeyboardKey(reinterpret(UInt32,'.')),
  "/" => KeyboardKey(reinterpret(UInt32,'/')),
  "`" => KeyboardKey(reinterpret(UInt32,'`')),
  ":tab:" => KeyboardKey(reinterpret(UInt32,'\t')),
  ":space:" => KeyboardKey(reinterpret(UInt32,' ')),
  " " => KeyboardKey(reinterpret(UInt32,' ')),
  ":up:" => KeyboardKey(0x40000052),
  ":down:" => KeyboardKey(0x40000051),
  ":left:" => KeyboardKey(0x40000050),
  ":right:" => KeyboardKey(0x4000004f),
  ":delete:" => KeyboardKey(0x0000007f),
  ":backspace:" => KeyboardKey(0x00000008),
  ":enter:" => KeyboardKey(0x0000000d),
  ":return:" => KeyboardKey(0x0000000d),

  ":lshift:" => KeyboardKey(0x400000e1),
  ":rshift:" => KeyboardKey(0x400000e5),
  ":left-shift:" => KeyboardKey(0x400000e1),
  ":right-shift:" => KeyboardKey(0x400000e5),

  ":lctrl:" => KeyboardKey(0x400000e0),
  ":rctrl:" => KeyboardKey(0x400000e4),
  ":left-ctrl:" => KeyboardKey(0x400000e0),
  ":right-ctrl:" => KeyboardKey(0x400000e4),

  ":lalt:" => KeyboardKey(0x400000e2),
  ":ralt:" => KeyboardKey(0x400000e6),
  ":left-alt:" => KeyboardKey(0x400000e2),
  ":right-alt:" => KeyboardKey(0x400000e6),

  @os(apple=":apple:",windows=":windows:",linux=":application:") =>
    KeyboardKey(0x40000065),

  ":caps-lock:" => KeyboardKey(0x40000039),
  ":escape:" => KeyboardKey(0x0000001b),
  ":esc:" => KeyboardKey(0x0000001b),

  ":f1:" => KeyboardKey(0x4000003a),
  ":f2:" => KeyboardKey(0x4000003b),
  ":f3:" => KeyboardKey(0x4000003c),
  ":f4:" => KeyboardKey(0x4000003d),
  ":f5:" => KeyboardKey(0x4000003e),
  ":f6:" => KeyboardKey(0x4000003f),
  ":f7:" => KeyboardKey(0x40000040),
  ":f8:" => KeyboardKey(0x40000041),
  ":f9:" => KeyboardKey(0x40000042),
  ":f10:" => KeyboardKey(0x40000043),
  ":f11:" => KeyboardKey(0x40000044),
  ":f12:" => KeyboardKey(0x40000045),

  ":pause:" => KeyboardKey(0x40000048),
  ":insert:" => KeyboardKey(0x40000049),
  ":home:" => KeyboardKey(0x4000004a),
  ":pageup:" => KeyboardKey(0x4000004b),
  ":end:" => KeyboardKey(0x4000004d),
  ":pagedown:" => KeyboardKey(0x4000004e),

  ":numlock:" => KeyboardKey(0x40000053),
  ":num /:" => KeyboardKey(0x40000054),
  ":num *:" => KeyboardKey(0x40000055),
  ":num -:" => KeyboardKey(0x40000056),
  ":num +:" => KeyboardKey(0x40000057),
  ":num =:" => KeyboardKey(0x40000067),
  ":num enter:" => KeyboardKey(0x40000058),
  ":num tab:" => KeyboardKey(0x400000ba),
  ":num ." => KeyboardKey(0x40000063),
  ":num 1:" => KeyboardKey(0x40000059),
  ":num 2:" => KeyboardKey(0x4000005a),
  ":num 3:" => KeyboardKey(0x4000005b),
  ":num 4:" => KeyboardKey(0x4000005c),
  ":num 5:" => KeyboardKey(0x4000005d),
  ":num 6:" => KeyboardKey(0x4000005e),
  ":num 7:" => KeyboardKey(0x4000005f),
  ":num 8:" => KeyboardKey(0x40000060),
  ":num 9:" => KeyboardKey(0x40000061),
  ":num 0:" => KeyboardKey(0x40000062),

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
  listkeys()

Lists all available key codes in order.

Also see `@key_str`.
"""
listkeys() = foreach(println,values(str_to_code) |> unique |> collect |> sort)

"""
    key"keyname"

Generate a key code, using a single character (e.g. key"q" or key"]"), a
special-key name, or Cedrus response-pad key.

Note that keys are orderd, you can list all implemented keys in order, using
`listkeys`. If you want to quickly see the name for a given button you can use
`run_keycode_helper()`.
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
required_delta_t(m::Moment) = delta_t(m)

type ResponseMoment <: SimpleMoment
  respond::Function
  timeout::Function
  timeout_delta_t::Float64
  minimum_delta_t::Float64
end
function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0.0 ? moment.timeout_delta_t : Inf)
end
required_delta_t(m::ResponseMoment) = Inf

abstract AbstractTimedMoment <: SimpleMoment

type TimedMoment <: AbstractTimedMoment
  delta_t::Float64
  run::Function
end
delta_t(moment::TimedMoment) = moment.delta_t

type OffsetStartMoment <: AbstractTimedMoment
  run::Function
  count_trials::Bool
  expanding::Bool
end
delta_t(moment::OffsetStartMoment) = 0.0

type PlayMoment <: AbstractTimedMoment
  delta_t::Float64
  sound::Sound
  keys::Vector
end
delta_t(m::PlayMoment) = m.delta_t
type PlayFunctionMoment <: AbstractTimedMoment
  delta_t::Float64
  fn::Function
  keys::Vector
  sound::Nullable{Sound}
end
PlayFunctionMoment(d,f,k) = PlayFunctionMoment(d,f,k,Nullable())

type DisplayMoment <: AbstractTimedMoment
  delta_t::Float64
  visual::SDLRendered
end
delta_t(m::DisplayMoment) = m.delta_t
type DisplayFunctionMoment <: AbstractTimedMoment
  delta_t::Float64
  fn::Function
  keys::Vector
  visual::Nullable{SDLRendered}
end
DisplayFunctionMoment(d,f,k) = DisplayFunctionMoment(d,f,k,Nullable())

type FinalMoment <: SimpleMoment
  run::Function
end
delta_t(moment::FinalMoment) = 0.0


type CompoundMoment <: Moment
  data::Array{Moment}
end
delta_t(m::CompoundMoment) = 0.0
>>(a::SimpleMoment,b::SimpleMoment) = CompoundMoment([a,b])
>>(a::CompoundMoment,b::CompoundMoment) = CompoundMoment(vcat(a.data,b.data))
>>(a::Moment,b::Moment) = >>(promote(a,b)...)
>>(a::Moment,b::Moment,c::Moment,d::Moment...) = moment(a,b,c,d...)
promote_rule{T <: SimpleMoment}(::Type{CompoundMoment},::Type{T}) = CompoundMoment
convert(::Type{CompoundMoment},x::SimpleMoment) = CompoundMoment([x])

type ExpandingMoment <: Moment
  condition::Function
  data::Stack{Moment}
  repeat::Bool
  update_offset::Bool
end
delta_t(m::ExpandingMoment) = 0.0

type MomentQueue
  data::Deque{Moment}
  last::Float64
end
isempty(m::MomentQueue) = isempty(m.data)
length(m::MomentQueue) = length(m.data)
enqueue!(m::MomentQueue,x) = push!(m.data,x)
dequeue!(m::MomentQueue) = shift!(m.data)
unshift!(m::MomentQueue,x) = unshift!(m.data,x)
front(m::MomentQueue) = front(m.data)
function next_moment_time(m::MomentQueue)
  (isempty(m) ? Inf : m.last + delta_t(front(m)))
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
  file::Nullable{String}
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
