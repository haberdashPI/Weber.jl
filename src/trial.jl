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

  if !isnull(exp.info.file)
    open(get(exp.info.file),"a") do stream
      @_ header begin
        map(c -> findkwd(kwds,c,""),_)
        join(_,",")
        println(stream,_)
      end
    end
  end
end

function record_header(exp)
  extra_keys = [:weber_version,:start_date,:start_time,:offset,:trial,:time]
  info_keys = map(x->x[1],exp.info.values)

  reserved_keys = Set([extra_keys...;info_keys...])
  reserved = filter(x -> x ∈ reserved_keys,exp.info.header)
  if length(reserved) == 1
    error("The column name \"$(reserved[1])\" is reserved. Please use "*
          " a different name.")
  elseif length(reserved) > 1
    error("The column names "*
          join(map(x -> "\""*x*"\"",reserved),", "," and ")*
          " are reserved. Please use different names.")
  end

  columns = [extra_keys...,info_keys...,:code,exp.info.header...]
  if !isnull(exp.info.file)
    open(x -> println(x,join(columns,",")),get(exp.info.file),"w")
  end
end

function record(exp::Experiment,code;kwds...)
  nothing
end

function record(exp::Experiment{SDLWindow},code;kwds...)
  kwds = exp.info.record_callback(code;kwds...)

  extra = [:weber_version => Weber.version,
           :start_date => Dates.format(exp.info.start,"yyyy-mm-dd"),
           :start_time => Dates.format(exp.info.start,"HH:MM:SS"),
           :offset => exp.data.offset,
           :trial => exp.data.trial,
           :time => exp.data.last_time]

  info_keys = map(x->x[1],exp.info.values)
  extra_keys = map(x->x[1],extra)
  record_helper(exp,tuple(extra...,exp.info.values...,:code => code,kwds...),
                [extra_keys...,info_keys...,:code,exp.info.header...])
end

"""
    record(code;column_values...)

Record an event with the given `code` to the data file.

Each event has a code which identifies it as being a particular type of
event. This is normally a string. By convention when you record something with
the same code you should specify the same set of `column_values`.

All calls to record also result in many additiaonl values being written to
the data file. The start time and date of the experiment, the trial and offset
number, the subject id, the version of Weber, and the time at which the
last moment started are all stored.  Additional information can be added during
creation of the experiment (see `Experiment`).

Each call opens and closes the data file used for the experiment, so there
should be no loss of data if the program is terminated prematurely for some
reason.

# Extending record's functionality.

In some cases, such as when recording events to a serial port during an EEG
experiment, record needs to do more than just write events to a file. You can
extend the functionality of record by specializing record's first argument using
your own custom type, and then make sure all of your codes are of this type.

This works the same way one would specialize any method: import the record
method, define your custom type and the define a method of record on this type,
you can call the more generic version of record, passing an appropriate string
when you are done with the code specific to your expeirment. Note however that
you must also define *(x::YourType,y:String) if you make use of the `response`
fucntion, because this will concatenate "_up" to the end of each code when it
calls record for keyup events.
"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

addmoment(e::Experiment,m) = addmoment(e.data.moments,m)
addmoment(q::ExpandingMoment,m::Moment) = push!(q.data,flag_expanding(m))
addmoment(q::Array{MomentQueue},m::Moment) = addmoment(first(q),m)
addmoment(q::MomentQueue,m::Moment) = enqueue!(q,m)
addmoment(q::Array{Moment,1},m::Moment) = push!(q,m)
function addmoment(q::Union{ExpandingMoment,MomentQueue,Array},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(() -> get_experiment().data.trial_watcher = watcher))
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
function addmoments(exp,moments;when=nothing,loop=nothing)
  if when != nothing || loop != nothing
    error("Trials cannot have `when` and `loop` clauses in Weber v0.3.0 and up, ",
          "use @addtrials instead.")
  else
    if isempty(addtrial_block)
      foreach(m -> addmoment(exp,m),moments)
    else
      block = top(addtrial_block)
      foreach(m -> addmoment(block,m),moments)
    end
  end
end

function addtrial_helper(exp::Experiment,trial_count,moments;keys...)

  start_trial = offset_start_moment(trial_count) do
    #gc_enable(false)
    if trial_count
      record("trial_start")
    else
      record("practice_start")
    end
    reset_response()
  end

  end_trial = moment() do
    #gc_enable(true)
  end

  addmoments(exp,[start_trial,moments,end_trial];keys...)
end

"""
@addtrials expr...

Add trials to the experiment that depend on changes to tstate that occur during
the experiment.

Example use cases include using an adaptive track to determine stimulus
presentation, repeating trials based on a performance criterion, etc...
In general if your trials do not depend on experiment-changing state,
you do not need to use @addtrials.

There are three kinds of trials you can add with this macro: blocks,
conditionals and loops.

# Blocks of Trials

    @addtrials let [assignments]
      body...
    end

Blocks of trials are useful for setting up state that will change during the
trials. Such state can then be used in a subsequent @addtrials expression. In
fact all other types of @addtrials expression will likely be nested inside
blocks. The main reason to use such a block is to ensure that the offset counter
is appropriately set whith stateful trials.

The offset counter is meant to refer to a well defined time during the
experiment.  They can be used to fast forward through the expeirment by
specifying an offset greater than 0.  However, if there is state that changes
throughout the course of several trials, trials that follow these state changes
cannot be relibably reproduced when those state-chaning trials are skipped
because the user specifies an offset > 0. Thus anytime you have
a series of trials, some of which depend on the state of one another, those
trials should be placed inside of an @addtrials let block if you want
fast-forwarding through parts of the experiment to work as expected.

# Conditional Trials

    @addtrials if [cond1]
      body...
    elseif [cond2]
      body...
    ...
    elseif [condN]
      body...
    else
      body...
    end

Adds one or mores trials that are presented only if the given conditions are
met. The expressions `cond1` through `condN` are evaluted during the experiment,
but each `body` is executed before the experiment begins, and is used to
indicate the set of trials (and breaks or practice trials) that will be run for
a given condition.

For example, the following code only runs the second trial if the user
hits the "y" key.

    @addtrials let y_hit = false
      isresponse(e) = iskeydown(e,key"y") || iskeydown(e,key"n")
      addtrial(moment(display,"Hit Y or N."),await_response(isresponse)) do event
        if iskeydown(event,key"y")
          y_hit = true
        end
      end

      @addtrials if !y_hit
        addtrial(moment(display,"You did not hit Y!"),await_response(iskeydown))
      end
    end

If `@addtrials if !y_hit` was replaced with `if !y_hit` in the above example,
the second trial would always run. This is because the `if` expression would be
evaluated before any trials were run (when `y_hit` is false).

# Looping Trials

    @addtrials while expr
      body...
    end

Add some number of trials that repeat as long as `expr` evalutes to true.
For example the follow code runs as long as the user hits the "y" key.

    @addtrials let y_hit = true
      @addtrials while y_hit
        message = moment(display,"Hit Y if you want to continue")
        addtrial(message,await_response(iskeydown)) do event
          y_hit = iskeydown(event,key"y")
        end
      end
    end

If `@addtrials while y_hit` was replaced with `while y_hit` in the above
example, the while loop would never terminate, running an infinite loop, because
`y_hit` is true before the experiment starts.

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

Each trial increments a counter tracking the number of trials, and (normally) an
offset counter. These two numbers are reported on every line of the resulting
data file (see `record`). They can be retrieved using `Weber.trial()`
and `Weber.offset()`.

# How to create moments

Moment can be added as individual arguments to addtrial, or they can be
arbitrarily nested in iterable collections. Such collections are iterated
recursively to add the moments to a trial in sequence. Each individual moment is
one of the following objects,

1. moment object

Result of calling the `moment` function, this will trigger some time after the
*start* of the previous moment, or after the start of the trial if it is the
first moment in the trial.

1. function watcher

Immediately after the *start* of the preceeding moment (or at the start of the
trial if this is the first argument), a function creates an event watcher. Any
time an event occurs this function will be called, until a new watcher replaces
it. It should take one argument (the event that occured).  This is normally the
first argument to addtrial, since rarely do we want to change how a trial
responds to events in the middle of a trial or ignore events. Placing the
function first also allows it to be specified using the do block syntax:

    addtrial(moments...) do event
      if iskeydown(event,key"y")
        display(visual("You hit y!"))
      end
    end

In this example, "You hit y!" will be displayed on screen any time the user hits
the "y" key.

3. timeout object

Result of calling the `timeout` function, this
will trigger an event if no response occurs from the *start* of the previous
moment, until the specified timeout.

4. await object

Result of calling `await_response` this moment will begin as soon as the
specified response is provided by the subject.

5. looping object

Result of calling `looping`, this will repeat a series of moments based on some
condition.

6. when object

Result of call `when`, this will present as series of moments based on some
condition.


!!! note

    In addition to these types of moments you can create more complicated
    moments by concatenating simpler moments together using the `>>` operator or
    `moment(momoment1,moment2,...)` . See the documentation of `moment` for more
    details.

# Guidlines for low-latency trials

Weber aims to present trials at low latencies for accurate experiments.

To maintain low latency, as much of the experimental logic as possible
should be precomputed, outside of trial moments. The following operations are
generally safe to perform during a moment:

1. Calls to `play` to present an object generated by `sound` before the moment.
2. Calls to `display` to present an object generated by `visual` before the
   moment.
3. Calls to `record` to save something to the data file (usually after any calls
   to `play` or `display`)
4. Simple programming logic (e.g. `if`, `elseif` and `else`).

Note that Julia compiles functions on demand (known as JIT compilation), which
can lead to very slow runtimes the first time a function runs.  To minimize JIT
compilation during an experiment, any functions called directly by a moment are
first precompiled. Futher, many methods in Weber precompiled before the
experiment begins.
"""

function addtrial(moments...;keys...)
  addtrial_helper(get_experiment(),true,moments;keys...)
end

function addtrial(exp::Experiment,moments...;keys...)
  addtrial_helper(exp,true,moments;keys...)
end

"""
   addpractice(moments...)

Identical to `addtrial`, except that it does not incriment the trial count.
"""
function addpractice(moments...;keys...)
  addtrial_helper(get_experiment(),false,moments;keys...)
end

function addpractice(exp::Experiment,moments...;keys...)
  addtrial_helper(exp,false,moments;keys...)
end

"""
   addbreak(moments...)

Identical to `addpractice` but there is no optimization to ensure that events
occur in realtime. This will allow the program to safely recover memory through
the presented moments. Otherwise memory is only refreshed between each trial,
but not during.
"""
function addbreak(moments...;keys...)
  addbreak(get_experiment(),moments...;keys...)
end

function addbreak(exp::Experiment,moments...;keys...)
  addmoments(exp,[offset_start_moment(#=t -> gc_enable(true)=#),moments];keys...)
end

"""
    moment([fn],[delta_t])
    moment([delta_t],[fn],args...;keys...)

Create a moment that occurs `delta_t` (default 0) seconds after the *start* of
the previous moment, running the specified function.

The function `fn` is passed zero arguments, or it is passed the arguments
specified in `args` and `keys`.

!!! warning

    Long running moment functions will lead to latency issues. Make sure all
    moment functions run relatively quickly. For instance, normally `play` and
    `display` return immediately, before the sound or visual is finished being
    presented to the participant. Please refer to the `addtrial` documentation
    for more details.

!!! warning

    Avoid moments that depend on state that changes during the
    experiment. Specifically, moments that depend on a state which is altered by
    moments on a previous trial can lead to undefined behavior when an
    experiment is run with a non-zero offset. If you need to do this, you likely
    want to use the `@addtrials` macro.
"""

moment(delta_t::Number) = TimedMoment(delta_t,()->nothing)
moment() = TimedMoment(0,()->nothing)

function moment(fn::Function,delta_t::Number)
  moment(delta_t,fn)
end

function moment(delta_t::Number,fn::Function,args...;keys...)
  precompile(fn,map(typeof,args))
  TimedMoment(delta_t,() -> fn(args...;keys...))
end

function moment(fn::Function,args...;keys...)
  moment(0,fn,args...;keys...)
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

Create a single moment by concatentating several moments togethor.

A concatenation of moments starts immediately, proceeding through each of the
moments in order. This is useful for playing several moments in parallel. For
example, the following code will present two sounds, one at 100ms, the other at
200ms after the start of the trial. It will also display "Too Late!" on the
screen if no keyboard key is pressed 150ms after the start of the trial.

        addtrial(moment(moment(0.1,play,soundA),moment(0.1,play,soundB)),
                 timeout(0.15,iskeydown,x -> display("Too Late!")))
!!! note

    You can also use `moment1 >> moment2 >> moment3 >> ...` to concatenate
    moments.

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

#===============================================================================
    prepare!(m)

If there is anything the moment needs to do before it occurs, it
is done during `prepare!`. This triggers immediately after the moment prior to
the current one has finished.
===============================================================================#

prepare!(m::Moment) = nothing
prepare!(m::DisplayFunctionMoment) = m.visual = Nullable(visual(m.fn();m.keys...))
prepare!(m::PlayFunctionMoment) = m.sound = Nullable(sound(m.fn()))

#===============================================================================
    handle(exp,queue,moment,x)

Internal method to handle the given event in a manner specific to the kind of
moment. For example, a timed moment will trigger when the appropriate time has
passed. Handle returns a boolean indicating whether the event was handled or if
it did not. The moment remmains on the moment queue until it handles something.
===============================================================================#

function handle(exp::Experiment,q::MomentQueue,moment::FinalMoment,x)
  for sq in exp.data.moments
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

run(exp,m::TimedMoment) = m.run()
run(exp,m::OffsetStartMoment) = m.run()
run(exp,m::PlayMoment) = _play(m.sound;m.keys...)
run(exp,m::DisplayMoment) = display(exp.win,m.visual)
run(exp,m::PlayFunctionMoment) = _play(get(m.sound);m.keys...)
run(exp,m::DisplayFunctionMoment) = display(exp.win,get(m.visual))

function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,time::Float64)
  exp.data.last_time = time
  run(exp,moment)
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
  push!(exp.data.moments,MomentQueue(queue,q.last))
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

is_moment_skipped(exp,moment::Moment) = exp.data.offset < exp.data.skip_offsets
function is_moment_skipped(exp,moment::OffsetStartMoment)
  if !moment.expanding
    exp.data.offset += 1
  end
  if moment.count_trials
    exp.data.trial += 1
  end
  exp.data.offset < exp.data.skip_offsets
end
function is_moment_skipped(exp,moment::ExpandingMoment)
  if moment.update_offset
    exp.data.offset += 1
    # each expanding moment only ever incriments the offset
    # counter once, event if it creates a loop.
    moment.update_offset = false
  end
  exp.data.offset < exp.data.skip_offsets
end
is_moment_skipped(exp,moment::FinalMoment) = false
