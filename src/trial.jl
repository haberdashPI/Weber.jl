using Lazy: @_
using DataStructures
using MacroTools
import Base: run, display
export addtrial, addbreak, addpractice, moment, await_response, record, timeout,
  when, looping, @addtrials

function findkwd(kwds,sym,default)
  for (k,v) in kwds
    if k == sym
      return v
    end
  end

  default
end

const null_record = []
function write_csv_line(exp::Experiment{NullWindow},header,kwds)
  push!(null_record,Dict{Symbol,Any}(map(c -> c => findkwd(kwds,c,""),header)))
end

function write_csv_line(exp::Experiment{SDLWindow},header,kwds)
  if !isnull(info(exp).file)
    open(get(info(exp).file),"a") do stream
      @_ (string(findkwd(kwds,c,"")) for c in header) begin
        join(_,",")
        println(stream,_)
      end
    end
  end
end

function record_helper(exp::Experiment,kwds,header)
  columns = map(x -> x[1],kwds)

  if !isempty(columns) && !all(map(c -> c ∈ header,columns))
    missing = collect(Iterators.filter(c -> c ∉ header,columns))

    error("Unexpected column $(length(missing) > 1 ? "s" : "")"*
          "$(join(missing,", "," and ")). "*
          "Make sure you specify all columns you plan to use "*
          "during experiment initialization.")
  end

  kwds = reverse(kwds) # this ensures that if the user overwrites a value
                       # it will be honored

  write_csv_line(exp,header,kwds)
end

function record_header(exp::Experiment)
  extra_keys = [:weber_version,:start_date,:start_time,:offset,:trial,:time]
  info_keys = map(x->x[1],info(exp).values)

  reserved_keys = Set([extra_keys...;info_keys...])
  reserved = filter(x -> x ∈ reserved_keys,info(exp).header)
  if length(reserved) == 1
    error("The column name \"$(reserved[1])\" is reserved. Please use "*
          " a different name.")
  elseif length(reserved) > 1
    error("The column names "*
          join(map(x -> "\""*x*"\"",reserved),", "," and ")*
          " are reserved. Please use different names.")
  end

  columns = [extra_keys...,info_keys...,:code,info(exp).header...]
  if !isnull(info(exp).file)
    open(x -> println(x,join(columns,",")),get(info(exp).file),"w")
  end
end

function record(exp::ExtendedExperiment,code;kwds...)
  record(next(exp),code;kwds...)
end
function record{T <: BaseExperiment}(exp::T,code;kwds...)
  extra = [:weber_version => Weber.version,
           :start_date => Dates.format(info(exp).start,"yyyy-mm-dd"),
           :start_time => Dates.format(info(exp).start,"HH:MM:SS"),
           :offset => data(exp).offset,
           :trial => data(exp).trial,
           :time => data(exp).last_time]

  info_keys = map(x->x[1],info(exp).values)
  extra_keys = map(x->x[1],extra)
  record_helper(exp,tuple(extra...,info(exp).values...,:code => code,kwds...),
                [extra_keys...,info_keys...,:code,info(exp).header...])
end

"""
    record(code;keys...)

Record a row to the experiment data file using a given `code`.

Each event has a code which identifies it as being a particular type of
experiment event. This is normally a string. Each keyword argument is the value
of a column (with the same name). By convention when you record something with
the same code you should specify the same set of columns.

All calls to record also result in many additional values being written to the
data file. The start time and date of the experiment, the trial and offset
number, the version of Weber, and the time at which the last moment started are
all stored.  Additional information can be added during creation of the
experiment (see [`Experiment`](@ref)).

Each call to record writes a new row to the data file used for the experiment, so
there should be no loss of data if the program is terminated prematurely for
some reason.

!!! note "Automatically Recorded Codes"

    There are several codes that are automatically recorded by Weber.
    They include:
    1. **trial_start** - recorded at the start of moments added by `addtrial`
    2. **practice_start** - recorded at the start of moments added by `addpractice`
    3. **break_start** - recorded at the start of moments added by `addbreak`
    4. **high_latency** - recorded whenever a high latency warning is triggered.
       The "value" column is set to the error between the actual and the desired
       timing of a moment, in seconds.
    5. **paused** - recorded when user hits 'escape' and the experiment is
       paused.
    6. **unpaused** - recorded when the user ends the pause, continuuing the
       experiment.
    7. **terminated** - recorded when the user manually terminates the
       experiment (via 'escape')
    8. **closed** - recorded just before the experiment window closes
"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

function addmoment(q::ExpandingMoment,m::AbstractMoment)
  m = flag_expanding(m)
  if !isempty(q.data) && can_continue_sequence(m) && sequenceable(top(q.data))
    m = sequence(pop!(q.data),m)
  end
  push!(q.data,m)
end

function addmoment(q::MomentQueue,m::AbstractMoment)
  if !isempty(q) && can_continue_sequence(m) && sequenceable(back(q))
    m = sequence(pop!(q),m)
  end
  enqueue!(q,m)
end

function addmoment(q::Vector{AbstractMoment},m::AbstractMoment)
  if !isempty(q) && can_continue_sequence(m) && sequenceable(last(q))
    m = sequence(pop!(q),m)
  end
  push!(q,m)
end

addmoment(e::Experiment,m) = addmoment(data(e).moments,m)
addmoment(q::Array{MomentQueue},m::AbstractMoment) = addmoment(first(q),m)
function addmoment(q::Union{ExpandingMoment,MomentQueue,Array{MomentQueue}},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(() -> data(get_experiment()).trial_watcher = watcher))
end
function addmoment(q,ms)
  function handle_error()
    if !(typeof(ms) <: AbstractMoment || typeof(ms) <: Function)
      error("Expected some kind of moment, but got a value of type",
            " $(typeof(ms)) instead.")
    else
      error("Cannot add moment to an object of type $(typeof(q))")
    end
  end

  try
    first(ms)
  catch e
    if e isa MethodError
      handle_error()
    else
      rethrow(e)
    end
  end

  for m in ms
    # some types iterate over themselves (e.g. numbers);
    # check for this to avoid infinite recursion
    if m == ms
      handle_error()
    end
    addmoment(q,m)
  end
  q
end

const addtrial_block = Stack(ExpandingMoment)
function addmoments(exp,moments)
  if isempty(addtrial_block)
    foreach(m -> addmoment(exp,m),moments)
  else
    block = top(addtrial_block)
    foreach(m -> addmoment(block,m),moments)
  end
end

"""
    @addtrials expr...

Marks a let block, a for loop, or an if expression as dependent on experiment
[run-time](@ref setup_time) state, leaving the offset counter unincremented within that block.  The
immediately proceeding loop or conditional logic will be run during
experiment run-time rather than setup-time.

Refer to the [`Advanced Topics`](advanced.md) of the manual section for
more details.
"""
macro addtrials(expr)
  if isexpr(expr,:let)
    quote
      trial_block(() -> true) do
        $(esc(expr))
      end
    end
  elseif isexpr(expr,:if)
    cond,ifbody,elsebody = @match expr begin
      if cond_
        ifbody_
      end => (cond,ifbody,nothing)

      if cond_
        ifbody_
      else
        elsebody_
      end => (cond,ifbody,elsebody)
    end

    elsebody = @match elsebody begin
      ifelse_if => :(@addtrials($ifelse))
      begin
        ifelse_if
      end => :(@addtrials($ifelse))
      other_ => elsebody
    end

    if elsebody == nothing
      quote
        trial_block(() -> $(esc(cond))) do
          $(esc(ifbody))
        end
      end
    else
      quote
        let ifpassed = false
          trial_block(() -> ifpassed = $(esc(cond))) do
            $(esc(ifbody))
          end
          trial_block(() -> !ifpassed) do
            $(esc(elsebody))
          end
        end
      end
    end
  elseif isexpr(expr,:while)
    cond,body = @match expr begin
      while cond_
        body_
      end => (cond,body)
    end

    quote
      trial_block(loop=true,() -> $(esc(cond))) do
        $(esc(body))
      end
    end
  else
    error("@addtrials expects a `let`, `if` or `while` expression.")
  end
end

function trial_block(body,condition;keys...)
  trial_block(get_experiment(),body,condition;keys...)
end

function trial_block(exp::Experiment,body::Function,condition::Function;loop=false)
  moment = ExpandingMoment(condition,Stack(AbstractMoment),loop,true)
  push!(addtrial_block,moment)
  body()
  pop!(addtrial_block)

  addmoments(exp,[moment])
end

"""
    addtrial(moments...)

Adds a trial to the experiment, consisting of the specified moments.

Each trial records a "trial_start" code, and increments a counter tracking the
number of trials, and (normally) an offset counter. These two numbers are
reported on every line of the resulting data file (see [`record`](@ref)). They can be
retrieved using [`Weber.trial()`](@ref) and [`Weber.offset()`](@ref).
"""

function addtrial(moments...)
  addtrial_helper(get_experiment(),"trial_start",moments)
end

addtrial(exp::ExtendedExperiment,moments...) = addtrial(next(exp),moments...)
function addtrial{T <: BaseExperiment}(exp::T,moments...)
  addtrial_helper(exp,"trial_start",moments)
end

function addtrial_helper(exp::Experiment,start_code,moments)
  start_trial = offset_start_moment(start_code == "trial_start") do
    record(start_code)
  end

  addmoments(exp,[start_trial,moments])
end


"""
    addpractice(moments...)

Identical to [`addtrial`](@ref), except that it does not incriment the trial count,
and records a "practice_start" instead of "trial_start" code.
"""
function addpractice(moments...)
  addtrial_helper(get_experiment(),"practice_start",moments)
end

addpractice(exp::ExtendedExperiment,moments...) = addpractice(next(exp),moments...)
function addpractice{T <: BaseExperiment}(exp::T,moments...)
  addtrial_helper(exp,"practice_start",moments...)
end

"""
    addbreak(moments...)

Identical to [`addpractice`](@ref), but records "break_start" instead of "practice_start".
"""
function addbreak(moments...)
  addbreak(get_experiment(),moments...)
end

addbreak(exp::ExtendedExperiment,moments...) = addbreak(next(exp),moments...)
function addbreak{T <: BaseExperiment}(exp::T,moments...)
  addtrial_helper(exp,"break_start",moments)
end

"""
    moment([delta_t],[fn],args...;keys...)

Create a moment that occurs `delta_t` (default 0) seconds after the onset of
the previous moment, running the specified function.

The function `fn` is passed the arguments specified in `args` and `keys`.
"""
function moment(delta_t::Number=0.0s,fn::Function=()->nothing,args...;keys...)
  precompile(fn,map(typeof,args))
  delta_t = ustrip(inseconds(delta_t))
  TimedMoment(delta_t,() -> fn(args...;keys...),stacktrace()[2:end])
end

function moment(fn::Function,args...;keys...)
  moment(0.0s,fn,args...;keys...)
end

const PlayFunction = typeof(play)
function moment(delta_t::Number,::PlayFunction,x;channel=0)
  PlayMoment(ustrip(inseconds(delta_t)),playable(x),channel,stacktrace()[2:end])
end
function moment(delta_t::Number,::PlayFunction,fn::Function;channel=0)
  PlayFunctionMoment(ustrip(inseconds(delta_t)),fn,channel,stacktrace()[2:end])
end

# const StreamFunction = typeof(TimedSound.stream)
# function moment(delta_t::Number,::StreamFunction,itr,channel::Int)
#   StreamMoment(ustrip(inseconds(delta_t)),itr,channel,stacktrace()[2:end])
# end

const DisplayFunction = typeof(display)
function moment(delta_t::Number,::DisplayFunction,x;keys...)
  DisplayMoment(ustrip(inseconds(delta_t)),visual(x;keys...),stacktrace()[2:end])
end
function moment(delta_t::Number,::DisplayFunction,fn::Function;keys...)
  DisplayFunctionMoment(ustrip(inseconds(delta_t)),fn,keys,stacktrace()[2:end])
end

"""
    moment(moments...)
    moment(moments::Array)

Create a single, compound moment by concatentating several moments togethor.
"""
moment(moments...) = moment(collect(moments))
moment(moments::Array) = CompoundMoment(addmoment(Array{AbstractMoment,1}(),moments))
function moment(moments)
  try
    start(moments)
  catch
    throw(MethodError(moment,typeof(moments)))
  end
  moment(collect(Any,moments))
end

function offset_start_moment(fn::Function=()->nothing,count_trials=false)
  precompile(fn,(Float64,))
  OffsetStartMoment(fn,count_trials,false,stacktrace()[2:end])
end

"""
    await_response(isresponse;[atleast=0.0])

This moment starts when the `isresponse` function evaluates to true.

The `isresponse` function will be called anytime an event occurs. It should
take one parameter (the event that just occured).

If the response is provided before `atleast` seconds, the moment does not start
until `atleast` seconds have passed.
"""
function await_response(fn::Function;atleast=0.0)
  for t in concrete_events
    precompile(fn,(t,))
  end

  ResponseMoment(fn,() -> nothing,0,atleast,stacktrace()[2:end])
end

"""
    timeout(fn,isresponse,timeout,[atleast=0s])

This moment starts when either `isresponse` evaluates to true or
timeout time (in seconds) passes.

The `isresponse` function will be called anytime an event occurs. It should
take one parameter (the event that just occured).

If the moment times out, the function `fn` (with no arguments) will be called.

If the response is provided before `atleast` seconds, the moment does not begin
until `atleast` seconds (`fn` will not be called).
"""
function timeout(fn::Function,isresponse::Function,timeout;atleast=0.0s)
  precompile(fn,())
  for t in concrete_events
    precompile(isresponse,(t,))
  end

  ResponseMoment(isresponse,fn,ustrip(inseconds(timeout)),
                 ustrip(inseconds(atleast)),stacktrace()[2:end])
end

flag_expanding(m::AbstractMoment) = m
function flag_expanding(m::OffsetStartMoment)
  OffsetStartMoment(m.run,m.count_trials,true,m.trace)
end
function flag_expanding(m::ExpandingMoment)
  if m.update_offset
    ExpandingMoment(m.condition,m.data,m.repeat,false)
  else
    m
  end
end

"""
    looping(when=fn,moments...)

This moment will begin at the *start* of the previous moment, and repeats the
listed moments (possibly in nested iterable objects) until the `when` function
(which takes no arguments) evaluates to false.
"""
function looping(moments...;when=() -> error("infinite loop!"))
  Weber.when(when,moments...;loop=true)
end

"""
    when(condition,moments...)

This moment will begin at the *start* of the previous moment, and presents the
following moments (possibly in nested iterable objects) if the `condition`
function (which takes no arguments) evaluates to true.
"""
function when(condition::Function,moments...;loop=false,update_offset=false)
  precompile(condition,())
  e = ExpandingMoment(condition,Stack(AbstractMoment),loop,update_offset)
  foreach(m -> addmoment(e,m),moments)
  e
end

"""
    Weber.prepare!(m,[onset_s])

If there is anything the moment needs to do before it occurs, it is done during
`prepare!`. Prepare can be used to set up precise timing even when hardware
latency is high, if that latency can be predicted, and accounted for. A moment's
prepare! method is called just before the first non-zero pause between moments
that occurs before this moment: in the simplest case, when this moment has a
non-zero value for [`delta_t`](@ref), preapre! will occur `delta_t` seconds
before this moment. However, if several moments with no pause occur, prepare!
will occur before all of those moments as well.

Prepare accepts an optional second argument used to indicate the time, in
seconds from the start of the experiemnt when this moment will begin (as a
Float64).  This argument may be Inf, indicating that it is not possible to
predict when the moment will occur at this point, because the timing depends on
some stateful information (e.g. a participant's response). It is accetable in
this case to throw an error, explaining that this kind of moment must be able to
know precisely when it occurs to be prepared.

!!! note

    This method is part of the private interface for moments. It
    should not be called directly, but implemented as part of an extension.
    You need only extend the method taking a single arugment unless you
    intend to use this information during prepartion.
"""
prepare!(m::AbstractMoment,onset_s::Float64) = prepare!(m)
prepare!(m::AbstractMoment) = nothing
function prepare!(ms::MomentSequence,onset_s::Float64)
  for m in ms.data prepare!(m,onset_s) end
end

function prepare!(m::DisplayFunctionMoment)
  m.visual = Nullable(visual(m.fn();m.keys...))
end

function prepare!(m::PlayMoment,onset_s::Float64)
  if !isinf(onset_s)
    TimedSound.play_(m.sound,onset_s,m.channel)
  else
    m.prepared = true
  end
end

function prepare!(m::PlayFunctionMoment,onset_s::Float64)
  if !isinf(onset_s)
    TimedSound.play_(playable(m.fn()),onset_s,m.channel)
  else
    m.prepared = Nullable(playable(m.fn()))
  end
end

run(exp,q,m::TimedMoment) = m.run()
run(exp,q,m::OffsetStartMoment) = m.run()
run(exp,q,m::MomentSequence) = foreach(x -> run(exp,q,x),m.data)

run(exp,q,m::DisplayMoment) = display(win(exp),m.visual)
run(exp,q,m::DisplayFunctionMoment) = display(win(exp),get(m.visual))

function run(exp,q,m::PlayMoment)
  if m.prepared
    m.prepared = false
    TimedSound.play_(m.sound,0.0,m.channel)
  end
end

function run(exp,q,m::PlayFunctionMoment)
  if !isnull(m.prepared)
    TimedSound.play_(get(m.prepared),0.0,m.channel)
    m.prepared = Nullable()
  end
end

"""
    handle(exp,queue,moment,to_handle)

Internal method to handle the given moment object in a manner specific to its
type.

The function `handle` is only called when the appropriate time has been
reached for the next moment to be presented (according to [`delta_t`](@ref)) or
when an event occurs.

The `to_handle` object is either a `Float64`, indicating the current experiment
time, or it is an `ExpEvent` indicating the event that just occured. As an
example, a timed moment, will run when it recieves any `Float64` value, but
nothing occurs when passed an event.

The queue is a `MomentQueue` object, which has the same interface as the
`Dequeue` object (from the `DataStructures` package) but it is also
iterable. Upon calling handle, `top(queue) == moment`.

Handle should return a boolean indicating whether the event was "handled" or
not. If unhandled, the moment should remain on top of the queue. If returning
true, handle should *normally* remove the top moment from the queue. Exceptions
exist (for instance, to allow for loops), but one does not normally need to
implement custom moments that have such behavior.

!!! note

    This method is part of the private interface for moments. It
    should not be called directly, but implemented as part of an extension.
    It is called during the course of running an experiment.

"""
function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,time::Float64)
  run(exp,q,moment)
  q.last = time
  dequeue!(q)
  true
end

# function handle(exp::Experiment,q::MomentQueue,
#                 moment::StreamMoment,time::Float64)
#   stream(moment.itr,moment.channel)
#   dequeue!(q)
#   true
# end

function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,event::ExpEvent)
  false
end

function handle(exp::Experiment,q::MomentQueue,
                moment::ResponseMoment,time::Float64)
  moment.timeout()
  q.last = time
  dequeue!(q)
  true
end

function handle(exp::Experiment,q::MomentQueue,m::ResponseMoment,event::ExpEvent)
  if m.respond(event)
    dequeue!(q)
    unshift!(q,ResponseMomentMin(max(0.0,m.minimum_delta_t),m.trace))
    true
  end
  false
end

function handle(exp::Experiment,q::MomentQueue,
                moment::ResponseMomentMin,time::Float64)
  q.last = time
  dequeue!(q)
  true
end


function handle(exp::Experiment,q::MomentQueue,
                moment::ResponseMomentMin,evt::ExpEvent)
  false
end

function handle(exp::Experiment,q::MomentQueue,moments::CompoundMoment,x)
  compq = MomentQueue(moments.data,q.last)
  push!(data(exp).moments,compq)
  prepare!(compq,q.last)
  dequeue!(q)
  true
end

function handle(exp::Experiment,q::MomentQueue,m::ExpandingMoment,x)
  if m.condition()
    if !m.repeat
      dequeue!(q)
    end

    for x in m.data
      unshift!(q,x)
    end
    unshift!(q,expanding_stub)
  else
    dequeue!(q)
  end
  true
end

function handle(exp::Experiment,q::MomentQueue,m::ExpandingMomentStub,x)
  dequeue!(q)
  true
end

is_moment_skipped(exp,moment::AbstractMoment) = data(exp).offset < data(exp).skip_offsets
function is_moment_skipped(exp,moment::OffsetStartMoment)
  if !moment.expanding
    data(exp).offset += 1
  end
  if moment.count_trials
    data(exp).trial += 1
  end
  data(exp).offset < data(exp).skip_offsets
end
function is_moment_skipped(exp,moment::ExpandingMoment)
  if moment.update_offset
    data(exp).offset += 1
    # each expanding moment only ever incriments the offset
    # counter once, event if it creates a loop.
    moment.update_offset = false
  end
  data(exp).offset < data(exp).skip_offsets
end
