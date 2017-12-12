import Base: show, isempty, time, >>, length, unshift!, promote_rule, convert,
  hash, ==, isless, pop!, info, next, start, done, next, getindex
import DataStructures: front, back, top
using MacroTools

export iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, keycode,
  endofpause, @key_str, time, response_time, keycode, listkeys,
  ExtendedExperiment, extension, next, top, modifiedby

################################################################################
# event types

abstract type ExpEvent end

const concrete_events = []

"""
    @Weber.event type [name] <: [ExpEvent or ExpEvent child]
      [fields...]
    end

Marks a concrete type as being an experiment event.

This tag is necessary to ensure that all watcher moments are properly
precompiled. This macro adds the event to a list of concrete events
for which each watcher method must have a precompiled method.
"""
macro event(type_form)
  if !isexpr(type_form,:type)
    error("@event expects a type or struct")
  end
  decl = type_form.args[2]
  if !isexpr(decl,:<:)
    error("@event type must inhert from ExpEvent or a child of ExpEvent.")
  end
  name = decl.args[1] = esc(decl.args[1])

  quote
    $type_form
    push!(concrete_events,$name)
  end
end

@event struct QuitEvent <: ExpEvent
end

@event struct KeyUpEvent <: ExpEvent
  code::UInt32
  mod::UInt16
  time::Float64
end

@event struct KeyDownEvent <: ExpEvent
  code::UInt32
  mod::UInt16
  time::Float64
end

@event struct WindowFocused <: ExpEvent
  time::Float64
end

@event struct WindowUnfocused <: ExpEvent
  time::Float64
end


"""
    time(e::ExpEvent)

Get the time an event occured relative to the start of the experiment.
Resolution is limited by an experiment's input_resolution (which can be
specified upon initialization), and the response rate of the device. For
instance, keyboards usually have a latency on the order of 20-30ms.
"""
time(event::ExpEvent) = NaN
time(event::KeyUpEvent) = event.time
time(event::KeyDownEvent) = event.time
time(event::WindowFocused) = event.time
time(event::WindowUnfocused) = event.time

abstract type Key end
==(x::Key,y::Key) = false

struct KeyboardKey <: Key
  code::Int32
end
hash(x::KeyboardKey,h::UInt) = hash(KeyboardKey,hash(x.code,h))
==(x::KeyboardKey,y::KeyboardKey) = x.code == y.code
isless(x::KeyboardKey,y::KeyboardKey) = isless(x.code,y.code)
isless(x::Key,y::Key) = hash(typeof(x)) < hash(typeof(y))

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

const str_to_code = Dict{String,Key}(
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
  ":num 0:" => KeyboardKey(0x40000062)
)

function show(io::IO,key::KeyboardKey)
  found = filter((_,akey) -> (akey isa KeyboardKey) && akey.code == key.code,
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

Generate a key code, using a single character (e.g. key"q" or key"]"), or
some special key name surrounded by colons (e.g. :escape:).

Note that keys are orderd and you can list all implemented keys in order, using
`listkeys`. If you want to quickly see the name for a given button you can use
`run_keycode_helper()`.

!!! note "Creating Custom Keycodes"

    Extensions to Weber can define their own keycodes. Such codes must
    but of some new type inheriting from `Weber.Key`, and can be added
    to the list of codes this macro can generate by updating the
    private constant `Weber.str_to_code`. See the section in the user guide
    on extensions for more details.
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
iskeydown(key::KeyboardKey) = e -> iskeydown(e,key::KeyboardKey)
iskeydown(event::ExpEvent,keycode::Key) = false
iskeydown(event::KeyDownEvent,key::KeyboardKey) = event.code == key.code

"""
    modifiedby([event],[modifier = :shift,:ctrl,:alt or :gui])

Returns true if the given event represents a keydown event modified by a given
modifier key.

Without the first argument, returns a function that tests if the given event
is a keydown event modified by a given modifier key.
"""
modifiedby(modifier::Symbol) = e -> modifiedby(e,modifier)
modifiedby(event::ExpEvent,modifier::Symbol) = false
const shift_bit = 0x0003  # SDL2: KMOD_SHIFT
const ctrl_bit = 0x0c0 # SDL2: KMOD_CTRL
const alt_bit = 0x0300 # SDL2: KMOD_ALT
const gui_bit = 0x0c00 # SDL2: KMOD_GUI
function modifiedby(event::KeyDownEvent,modifier::Symbol)
  if modifier == :shift
    event.mod & shift_bit > 0
  elseif modifier in [:ctrl,:control]
    event.mod & ctrl_bit > 0
  elseif modifier == :alt
    event.mod & alt_bit > 0
  elseif modifier in [:gui,:windows,:apple]
    event.mod & gui_bit > 0
  else
    error("Undefined modifier key $modifier")
  end
end

"""
    iskeyup(event,[key])

Evalutes to true if the event indicates that the given keyboard key (or any key)
was released.  (See `@key_str`)

    iskeyup(key)

Returns a function which tests if an event indicates the given key was released.
"""
iskeyup(event::ExpEvent) = false
iskeyup(event::KeyUpEvent) = true
iskeyup(key::KeyboardKey) = e -> iskeydown(e,key)
iskeyup(event::ExpEvent,keycode::Key) = false
iskeyup(event::KeyUpEvent,key::KeyboardKey) = event.code == key.code

isfocused(event::ExpEvent) = false
isfocused(event::WindowFocused) = true

isunfocused(event::ExpEvent) = false
isunfocused(event::WindowUnfocused) = true


@event struct EndPauseEvent <: ExpEvent
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

################################################################################
# trial types

abstract type AbstractMoment end
abstract type SimpleMoment <: AbstractMoment end

"""
    delta_t(m::AbstractMoment)

Returns the time, since the start of the previous moment, at which this
moment should begin. The default implementation returns zero.

!!! note

    This method is part of the private interface for moments. It
    should not be called directly, but implemented as part of an extension.
"""
delta_t(m::AbstractMoment) = 0.0
required_delta_t(m::AbstractMoment) = delta_t(m)
can_continue_sequence(m::AbstractMoment) = false
sequenceable(m::AbstractMoment) = false
warn_delta_t(m::AbstractMoment) = 0.0 < required_delta_t(m) < Inf

"""
    moment_trace(m)

Returns the stacktrace indicating where this moment was defined.

!!! note

    This method is part of the private interface for moments. It should not be
    called directly, but implemented as part of an extension.  You can get a
    stacktrace inside the function you define that constructs your custom moment
    using `stacktrace()[2:end]`.
"""
moment_trace(m::AbstractMoment) = Vector{StackFrame}()

struct ResponseMoment <: SimpleMoment
  respond::Function
  timeout::Function
  timeout_delta_t::Float64
  minimum_delta_t::Float64
  trace::StackTrace
end
function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0.0 ? moment.timeout_delta_t : Inf)
end
required_delta_t(m::ResponseMoment) = Inf
can_continue_sequence(m::ResponseMoment) = false
moment_trace(m::ResponseMoment) = m.trace

struct ResponseMomentMin <: SimpleMoment
  delta_t::Float64
  trace::StackTrace
end
delta_t(m::ResponseMomentMin) = m.delta_t
required_delta_t(m::ResponseMomentMin) = Inf
can_continue_sequence(m::ResponseMomentMin) = false
moment_trace(m::ResponseMomentMin) = m.trace

abstract type AbstractTimedMoment <: SimpleMoment end
sequenceable(m::AbstractTimedMoment) = true
can_continue_sequence(m::AbstractTimedMoment) = delta_t(m) == 0.0

struct TimedMoment <: AbstractTimedMoment
  delta_t::Float64
  run::Function
  trace::StackTrace
end
delta_t(moment::TimedMoment) = moment.delta_t
sequenceable(m::TimedMoment) = true
moment_trace(m::TimedMoment) = m.trace

struct OffsetStartMoment <: AbstractTimedMoment
  run::Function
  count_trials::Bool
  expanding::Bool
  trace::StackTrace
end
delta_t(moment::OffsetStartMoment) = 0.0
can_continue_sequence(m::OffsetStartMoment) = false
sequenceable(m::OffsetStartMoment) = false
moment_trace(m::OffsetStartMoment) = m.trace

mutable struct PlayMoment <: AbstractTimedMoment
  delta_t::Float64
  sound::TimedSound.Sound
  channel::Int
  trace::StackTrace
  prepared::Bool
end
PlayMoment(d,f,c,t) = PlayMoment(d,f,c,t,false)
delta_t(m::PlayMoment) = m.delta_t
sequenceable(m::PlayMoment) = true
moment_trace(m::PlayMoment) = m.trace
warn_delta_t(m::PlayMoment) = false

mutable struct PlayFunctionMoment <: AbstractTimedMoment
  delta_t::Float64
  fn::Function
  channel::Int
  trace::StackTrace
  prepared::Nullable{TimedSound.Sound}
end
PlayFunctionMoment(d,f,c,t) = PlayFunctionMoment(d,f,c,t,Nullable())
delta_t(m::PlayFunctionMoment) = m.delta_t
sequenceable(m::PlayFunctionMoment) = true
moment_trace(m::PlayFunctionMoment) = m.trace
warn_delta_t(m::PlayFunctionMoment) = false

struct StreamMoment <: AbstractTimedMoment
  delta_t::Float64
  itr
  channel::Int
  trace::StackTrace
end
delta_t(m::StreamMoment) = delta_t
required_delta_t(m::StreamMoment) = Inf
can_continue_sequence(m::StreamMoment) = false
sequenceable(m::StreamMoment) = false
moment_trace(m::StreamMoment) = m.trace

struct DisplayMoment <: AbstractTimedMoment
  delta_t::Float64
  visual::SDLRendered
  trace::StackTrace
end
delta_t(m::DisplayMoment) = m.delta_t
sequenceable(m::DisplayMoment) = true
moment_trace(m::DisplayMoment) = m.trace

struct DisplayFunctionMoment <: AbstractTimedMoment
  delta_t::Float64
  fn::Function
  keys::Vector
  trace::StackTrace
  visual::Nullable{SDLRendered}
end
DisplayFunctionMoment(d,f,k,t) = DisplayFunctionMoment(d,f,k,t,Nullable())
delta_t(m::DisplayFunctionMoment) = m.delta_t
sequenceable(m::DisplayFunctionMoment) = true
moment_trace(m::DisplayFunctionMoment) = m.trace

struct CompoundMoment <: AbstractMoment
  data::Array{AbstractMoment}
end
delta_t(m::CompoundMoment) = 0.0
can_continue_sequence(m::CompoundMoment) = false
>>(a::SimpleMoment,b::SimpleMoment) = CompoundMoment([a,b])
>>(a::CompoundMoment,b::CompoundMoment) = CompoundMoment(vcat(a.data,b.data))
>>(a::AbstractMoment,b::AbstractMoment) = >>(promote(a,b)...)
>>(a::AbstractMoment,b::AbstractMoment,c::AbstractMoment,d::AbstractMoment...) = moment(a,b,c,d...)
promote_rule{T <: SimpleMoment}(::Type{CompoundMoment},::Type{T}) = CompoundMoment
convert(::Type{CompoundMoment},x::SimpleMoment) = CompoundMoment([x])

# optimize a seequence of moments that can occur, immediately, one after
# the other
struct MomentSequence <: AbstractTimedMoment
  data::Vector{AbstractMoment}
end
delta_t(m::MomentSequence) = delta_t(m.data[1])
required_delta_t(m::MomentSequence) = required_delta_t(m.data[1])
warn_delta_t(m::MomentSequence) = warn_delta_t(m.data[1])
push!(m::MomentSequence,x) = push!(m.data,x)
sequence(m1::AbstractMoment,m2::AbstractMoment) = MomentSequence([m1,m2])
sequence(ms::MomentSequence,m::AbstractMoment) = (push!(ms.data,m); ms)

mutable struct ExpandingMoment <: AbstractMoment
  condition::Function
  data::Stack{AbstractMoment}
  repeat::Bool
  update_offset::Bool
end
delta_t(m::ExpandingMoment) = 0.0
required_delta_t(m::ExpandingMoment) = Inf
can_continue_sequence(m::ExpandingMoment) = false

struct ExpandingMomentStub <: AbstractMoment
end
const expanding_stub = ExpandingMomentStub()
delta_t(m::ExpandingMomentStub) = 0.0
required_delta_t(m::ExpandingMomentStub) = Inf
can_continue_sequence(m::ExpandingMomentStub) = false

struct EmptyMoment <: AbstractMoment end
empty_moment = EmptyMoment()

mutable struct MomentQueue
  data::Vector{AbstractMoment}
  last::Float64
  start_index::Int
  end_index::Int
  very_first::Bool
end
show(io::IO,q::MomentQueue) = write(io,"MomentQueue[$(join(q,","))]")
start(m::MomentQueue) = 1
done(m::MomentQueue,i::Int) = i > length(m)
next(m::MomentQueue,i::Int) = m[i], i+1
@inline function getindex(m::MomentQueue,i)
  @boundscheck 0 < i <= length(m)
  real_index = i + m.start_index - 1
  if real_index > length(m.data)
    real_index = real_index - length(m.data)
  end
  @inbounds return m.data[real_index]
end

function MomentQueue(xs,last::Float64)
  size = 2^ceil(Int,log(length(xs))/log(2))
  data = repeat(AbstractMoment[empty_moment],inner=[size])
  data[1:length(xs)] = xs
  MomentQueue(data,last,1,length(xs),true)
end

MomentQueue(size=256) =
  MomentQueue(repeat(AbstractMoment[empty_moment],inner=[size]),0.0,1,1,true)
isempty(m::MomentQueue) = m.data[m.start_index] == empty_moment
function length(m::MomentQueue)
  if m.start_index < m.end_index
    m.end_index - m.start_index + 1
  elseif m.start_index > m.end_index
    length(m.data) - m.start_index + m.end_index + 1
  else
    Int(m.data[m.start_index] != empty_moment)
  end
end

function resize!(mq::MomentQueue,n)
  new_data = repeat(AbstractMoment[empty_moment],inner=[n])
  @inbounds for (i,m) in enumerate(mq)
    new_data[i] = m
  end
  mq.data = new_data
  end_index = length(mq)
  mq.start_index = 1
  mq.end_index = end_index

  mq
end

function enqueue!(mq::MomentQueue,x)
  if isempty(mq)
    mq.data[mq.start_index] = x
  elseif length(mq) < length(mq.data)
    mq.end_index == length(mq.data) ? mq.end_index = 1 : mq.end_index += 1
    mq.data[mq.end_index] = x
  else enqueue!(resize!(mq,2*length(mq.data)),x) end
  mq
end

function dequeue!(m::MomentQueue)
  @assert !isempty(m)
  result = m.data[m.start_index]

  if length(m) > 1
    m.data[m.start_index] = empty_moment
    if m.start_index < length(m.data)
      m.start_index += 1
    else
      m.start_index = 1
    end
  else
    m.data[m.start_index] = empty_moment
  end

  m.very_first = false
  result
end

function unshift!(m::MomentQueue,x)
  if isempty(m)
    m.data[m.start_index] = x
  elseif length(m) < length(m.data)
    m.start_index > 1 ? m.start_index -= 1 : m.start_index = length(m.data)
    m.data[m.start_index] = x
  else unshift!(resize!(m,2*length(m.data)),x) end
  m
end

function pop!(m::MomentQueue)
  @assert !isempty(m)
  result = m.data[m.end_index]

  if length(m) > 1
    m.data[m.end_index] = empty_moment
    if m.end_index == 1
      m.end_index = length(m.data)
    else
      m.end_index -= 1
    end
  else
    m.data[m.end_index] = empty_moment
  end

  result
end

front(m::MomentQueue) = m.data[m.start_index]
back(m::MomentQueue) = m.data[m.end_index]
very_first(m::MomentQueue) = m.very_first
function next_moment_time(m::MomentQueue)
  (isempty(m) ? Inf : m.last + delta_t(front(m)))
end

################################################################################
# experiment types

# information that remains true throughout an experiment
struct ExperimentInfo
  values::Array
  meta::Dict{Symbol,Any}
  input_resolution::Float64
  moment_resolution::Float64
  start::DateTime
  header::Array{Symbol}
  file::Nullable{String}
  hide_output::Bool
  warn_on_trials_only::Bool
end

# ongoing state about an experiment that changes moment to moment
mutable struct ExperimentData
  offset::Int
  trial::Int
  skip_offsets::Int
  last_time::Float64
  next_moment::Float64
  trial_watcher::Function
  pause_mode::Int
  moments::Array{MomentQueue,1}
  streamers::Dict{Int,TimedSound.Streamer}
  last_good_delta::Float64
  last_bad_delta::Float64
end

# flags to track experiment state
mutable struct ExperimentFlags
  running::Bool
  processing::Bool
end

abstract type Extension end
abstract type Experiment{W} end

struct UnextendedExperiment{W} <: Experiment{W}
  info::ExperimentInfo
  data::ExperimentData
  flags::ExperimentFlags
  win::W
end
info(e::UnextendedExperiment) = e.info
data(e::UnextendedExperiment) = e.data
flags(e::UnextendedExperiment) = e.flags
win(e::UnextendedExperiment) = e.win

"""
    top(experiment::Experiment)

Get the the top-most extended verison for this experiment, if any.
"""
top(e::Experiment) = e

struct ExtendedExperiment{E <: Extension,ES <: Tuple,N,W} <: Experiment{W}
  exp::UnextendedExperiment{W}
  extensions::ES
end
info(e::ExtendedExperiment) = e.exp.info
data(e::ExtendedExperiment) = e.exp.data
flags(e::ExtendedExperiment) = e.exp.flags
win(e::ExtendedExperiment) = e.exp.win

"""
    extension(experiment::ExtendedExperiment)

Get the extension object for this extended expeirment
"""
extension{E,ES,N,W}(e::ExtendedExperiment{E,ES,N,W}) = e.extensions[N]

function top{E,ES <: Tuple,N,W}(e::ExtendedExperiment{E,ES,N,W})
  E1 = ES.parameters[end]
  N1 = length(e.extensions)
  ExtendedExperiment{E1,ES,N1,W}(e.exp,e.extensions)
end

"""
     next(experiment::ExtendedExperiment)

Get the next extended version of this experiment.
"""
function next{E,ES,N,W}(e::ExtendedExperiment{E,ES,N,W})
  E1 = ES.parameters[N-1]
  ExtendedExperiment{E1,ES,N-1,W}(e.exp,e.extensions)
end
function next{E,ES,W}(e::ExtendedExperiment{E,ES,1,W})
  BaseExtendedExperiment{W,typeof(top(e))}(top(e))
end

struct BaseExtendedExperiment{W,E <: ExtendedExperiment} <: Experiment{W}
  top::E
end
info(e::BaseExtendedExperiment) = e.top.exp.info
data(e::BaseExtendedExperiment) = e.top.exp.data
flags(e::BaseExtendedExperiment) = e.top.exp.flags
win(e::BaseExtendedExperiment) = e.top.exp.win
top(e::BaseExtendedExperiment) = e.top

const BaseExperiment{W} = Union{UnextendedExperiment{W},BaseExtendedExperiment{W}}

function extend{W}(exp::UnextendedExperiment{W},exts)
  if isempty(exts)
    exp
  else
    exts = filter(x -> !(x isa Void),exts)
    exts = reverse(exts) # first extension takes precedence over subsequent ones
    exts_tup = tuple(exts...)
    E = typeof(exts[end])
    ES = typeof(exts_tup)
    N = length(exts)
    ExtendedExperiment{E,ES,N,W}(exp,exts_tup)
  end
end
