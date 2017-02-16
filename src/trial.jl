using Lazy: @_
using DataStructures
using MacroTools
import Base: run
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
  push!(null_record,Dict(map(c -> c => findkwd(kwds,c,""),header)))
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
    missing = collect(filter(c -> c ∉ header,columns))

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
    record(code;column_values...)

Record a row to the experiment data file using a given `code`.

Each event has a code which identifies it as being a particular type of
experiment event. This is normally a string. By convention when you record
something with the same code you should specify the same set of `column_values`.

All calls to record also result in many additional values being written to the
data file. The start time and date of the experiment, the trial and offset
number, the version of Weber, and the time at which the last moment started are
all stored.  Additional information can be added during creation of the
experiment (see `Experiment`).

Each call to record writes a new row to the data file used for the experiment, so
there should be no loss of data if the program is terminated prematurely for
some reason.

!!! note "Automatic Recorded Codes"

    There are several codes that are automatically recorded by Weber.
    They include:
    1. **trial_start** - recorded at the start of moments added by `addtrial`
    2. **practice_start** - recorded at the start of moments added by `addpractice`
    3. **break_start** - recorded at the start of moments added by `addbreak`
    4. **high_latency** - recorded whenever a high latency warning is triggered.
       The "value" column is set to the error between the actual and the desired
       timing of a moment, in seconds.

"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

function addmoment(q::ExpandingMoment,m::Moment)
  m = flag_expanding(m)
  if !isempty(q.data) && isimmediate(m) && sequenceable(top(q.data))
    m = sequence(pop!(q.data),m)
  end
  push!(q.data,m)
end

function addmoment(q::MomentQueue,m::Moment)
  if !isempty(q) && isimmediate(m) && sequenceable(back(q))
    m = sequence(pop!(q),m)
  end
  enqueue!(q,m)
end

function addmoment(q::Vector{Moment},m::Moment)
  if !isempty(q) && isimmediate(m) && sequenceable(last(q))
    m = sequence(pop!(q),m)
  end
  push!(q,m)
end

"""
    addmoment(experiment,moment)

Adds a given moment object to the experiment.

!!! warning

    This function should never be called directly by user code. It
    can be extended. This is useful, for example, when one wishes
    to transform one type of moment to some custom type of moment.
"""
addmoment(e::Experiment,m) = addmoment(data(e).moments,m)
addmoment(q::Array{MomentQueue},m::Moment) = addmoment(first(q),m)
function addmoment(q::Union{ExpandingMoment,MomentQueue,Array{MomentQueue}},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(() -> data(get_experiment()).trial_watcher = watcher))
end
function addmoment(q,ms)
  function handle_error()
    if !(typeof(ms) <: Moment || typeof(ms) <: Function)
      error("Expected some kind of moment, but got a value of type",
            " $(typeof(ms)) instead.")
    else
      error("Cannot add moment to an object of type $(typeof(q))")
    end
  end

  try
    first(ms)
  catch e
    if isa(e,MethodError)
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

function addtrial_helper(exp::Experiment,trial_count,moments)
  start_trial = offset_start_moment(trial_count) do
    #gc_enable(false)
    if trial_count
      record("trial_start")
    else
      record("practice_start")
    end
  end

  end_trial = moment() do
    #gc_enable(true)
  end

  addmoments(exp,[start_trial,moments,end_trial])
end

"""
    @addtrials expr...

Marks a let block, a for loop, or an if expression as dependent on experiment
run-time state, leaving the offset counter unincremented within that block.  The
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
  moment = ExpandingMoment(condition,Stack(Moment),loop,true)
  push!(addtrial_block,moment)
  body()
  pop!(addtrial_block)

  addmoment(exp,moment)
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
  addtrial_helper(get_experiment(),true,moments)
end

addtrial(exp::ExtendedExperiment,moments...) = addtrial(next(exp),moments...)
function addtrial{T <: BaseExperiment}(exp::T,moments...)
  addtrial_helper(exp,true,moments)
end

"""
   addpractice(moments...)

Identical to [`addtrial`](@ref), except that it does not incriment the trial count,
and records a "practice_start" instead of "trial_start" code.
"""
function addpractice(moments...;keys...)
  addtrial_helper(get_experiment(),false,moments)
end

addpractice(exp::ExtendedExperiment,moments...) = addpractice(next(exp),moments...)
function addpractice{T <: BaseExperiment}(exp::T,moments...)
  addtrial_helper(exp,false,moments...)
end

"""
   addbreak(moments...)

Identical to [`addpractice`](@ref), but records "break_start" instead of "practice_start".
"""
function addbreak(moments...;keys...)
  addbreak(get_experiment(),moments...;keys...)
end

addbreak(exp::ExtendedExperiment,moments...) = addbreak(next(exp),moments...)
function addbreak{T <: BaseExperiment}(exp::T,moments...;keys...)
  addmoments(exp,[offset_start_moment(() -> record("break_start")),moments];
             keys...)
end

"""
    moment([fn],[delta_t])
    moment([delta_t],[fn],args...;keys...)

Create a moment that occurs `delta_t` (default 0) seconds after the onset of
the previous moment, running the specified function.

The function `fn` is passed zero arguments, or it is passed the arguments
specified in `args` and `keys`.
"""
function moment(delta_t::Number,fn::Function,args...;keys...)
  precompile(fn,map(typeof,args))
  TimedMoment(delta_t,() -> fn(args...;keys...))
end

function moment(fn::Function,args...;keys...)
  moment(0,fn,args...;keys...)
end

moment(delta_t::Number) = TimedMoment(delta_t,()->nothing)
moment() = TimedMoment(0,()->nothing)

function moment(fn::Function,delta_t::Number)
  moment(delta_t,fn)
end

const PlayFunction = typeof(play)
function moment(delta_t::Number,::PlayFunction,x;keys...)
  PlayMoment(delta_t,sound(x),keys)
end
function moment(delta_t::Number,::PlayFunction,fn::Function;keys...)
  PlayFunctionMoment(delta_t,fn,keys)
end

const DisplayFunction = typeof(display)
function moment(delta_t::Number,::DisplayFunction,x;keys...)
  DisplayMoment(delta_t,visual(x;keys...))
end
function moment(delta_t::Number,::DisplayFunction,fn::Function;keys...)
  DisplayFunctionMoment(delta_t,fn,keys)
end

"""
    moment(moments...)
    moment(moments::Array)

Create a single, compound moment by concatentating several moments togethor.
"""
moment(moments...) = moment(collect(moments))
moment(moments::Array) = CompoundMoment(addmoment(Array{Moment,1}(),moments))
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
  OffsetStartMoment(fn,count_trials,false)
end

function final_moment(fn::Function)
  precompile(fn,())
  FinalMoment(fn)
end

"""
   await_response(isresponse;[atleast=0.0])

This moment starts when the `isresponse` function evaluates to true.

The `isresponse` function will be called anytime an event occurs. It should
take one parameter (the event that just occured).

If the response is provided before `atleast` seconds, the moment does not start
until `atleast` seconds.
"""
function await_response(fn::Function;atleast=0.0)
  for t in concrete_events
    precompile(fn,(t,))
  end

  ResponseMoment(fn,() -> nothing,0,atleast)
end

"""
    timeout(fn,isresposne,timeout,[atleast=0.0])

This moment starts when either `isresponse` evaluates to true or
timeout time (in seconds) passes.

If the moment times out, the function `fn` (with no arguments) will be called.

If the response is provided before `atleast` seconds, the moment does not begin
until `atleast` seconds (`fn` will not be called).
"""
function timeout(fn::Function,isresponse::Function,timeout;atleast=0.0)
  precompile(fn,())
  for t in concrete_events
    precompile(isresponse,(t,))
  end

  ResponseMoment(isresponse,fn,timeout,atleast)
end

flag_expanding(m::Moment) = m
function flag_expanding(m::OffsetStartMoment)
  OffsetStartMoment(m.run,m.count_trials,true)
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
  e = ExpandingMoment(condition,Stack(Moment),loop,update_offset)
  foreach(m -> addmoment(e,m),moments)
  e
end

"""
    Weber.prepare!(m)

If there is anything the moment needs to do before it occurs, it
is done during `prepare!`. This triggers immediately after the moment prior to
the current one has finished.

!!! note

    This method is part of the private interface for moments. It
    should not be called directly, but implemented as part of an extension.
"""
prepare!(m::Moment) = nothing
prepare!(m::DisplayFunctionMoment) = m.visual = Nullable(visual(m.fn();m.keys...))
prepare!(m::PlayFunctionMoment) = m.sound = Nullable(sound(m.fn()))
prepare!(m::MomentSequence) = foreach(prepare!,m.data)

"""
    handle(exp,queue,moment,to_handle)

Internal method to handle the given object in a manner specific to the kind of
moment. The `to_handle` object is either a `Float64`, indicating the current
time, or it is an `ExpEvent` indicating the event that just occured. A timed
moment, for instance, will run when it recieves a Float64 value indicating a
specified time has passed.  The queue is a MomentQueue object, which has the
same interface as the Dequeue object (from the DataStructures
package). Upon calling handle, top(queue) == moment.

Handle returns a boolean indicating whether the event was "handled" or not. If
unhandled, the moment should remain on top of the queue. If returning true,
handle should *normally* remove the top moment from the queue. Exceptions exist
(for instance, to allow for loops), but one does not normally need to implement
custom moments that have such behavior.

!!! note

    This method is part of the private interface for moments. It
    should not be called directly, but implemented as part of an extension.
    It is called during the course of running an experiment.

"""
function handle(exp::Experiment,q::MomentQueue,moment::FinalMoment,x)
  for sq in data(exp).moments
    if sq != q && !isempty(sq)
      enqueue!(sq,moment)
      dequeue!(q)
      return true
    end
  end
  moment.run()
  dequeue!(q)
  true
end

run(exp,q,m::TimedMoment) = m.run()
run(exp,q,m::OffsetStartMoment) = m.run()
run(exp,q,m::PlayMoment) = _play(m.sound;m.keys...)
run(exp,q,m::DisplayMoment) = display(win(exp),m.visual)
run(exp,q,m::PlayFunctionMoment) = _play(get(m.sound);m.keys...)
run(exp,q,m::DisplayFunctionMoment) = display(win(exp),get(m.visual))
run(exp,q,m::MomentSequence) = foreach(x -> run(exp,q,x),m.data)

function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,time::Float64)
  data(exp).last_time = time
  run(exp,q,moment)
  q.last = time
  dequeue!(q)
  true
end

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
    if (m.minimum_delta_t > 0.0 &&
        m.minimum_delta_t + q.last > Weber.tick(exp))
      dequeue!(q)
      unshift!(q,moment(m.minimum_delta_t))
    else
      dequeue!(q)
    end
    true
  end
  false
end

function handle(exp::Experiment,q::MomentQueue,moments::CompoundMoment,x)
  queue = Deque{Moment}()
  for moment in moments.data
    push!(queue,moment)
  end
  push!(data(exp).moments,MomentQueue(queue,q.last))
  dequeue!(q)
  true
end

function handle(exp::Experiment,q::MomentQueue,m::ExpandingMoment,x)
  if m.condition()
    if !m.repeat
      dequeue!(q)
    end

    for x in m.data
      unshift!(q.data,x)
    end
  else
    dequeue!(q)
  end
  true
end

is_moment_skipped(exp,moment::Moment) = data(exp).offset < data(exp).skip_offsets
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
is_moment_skipped(exp,moment::FinalMoment) = false
