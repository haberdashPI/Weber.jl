using Lazy: @_
using DataStructures
import Base: run
export addtrial, addbreak, addpractice, moment, await_response, record, timeout,
  when, looping

const default_moment_resolution = 1/2000
const default_input_resolution = 1/60
const exp_width = 1024
const exp_height = 768

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
  open(exp.info.file,"a") do stream
    @_ header begin
      map(c -> findkwd(kwds,c,""),_)
      join(_,",")
      println(stream,_)
    end
  end
end

function record_header(exp)
  extra_keys = [:psych_version,:start_date,:start_time,:offset,:trial,:time]
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
  open(x -> println(x,join(columns,",")),exp.info.file,"w")
end

function record(exp::Experiment,code;kwds...)
  nothing
end

function record(exp::Experiment{SDLWindow},code;kwds...)

  extra = [:psych_version => Weber.version,
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

Each event has a code which identifies it as being a particular type
of event. By convention when you record something with the same code
you should specify the same set of `column_values`.

All calls to record also result in many additiaonl values being written to
the data file. The start time and date of the experiment, the trial and offset
number, the subject id, the version of Weber, and the time at which the
last moment started are all stored.  Additional information can be added during
creation of the experiment (see `Experiment`).

Each call opens and closes the data file used for the experiment, so there
should be no loss of data if the program is terminated prematurely for some
reason.
"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

addmoment(e::Experiment,m) = addmoment(e.data.moments,m)
addmoment(q::ExpandingMoment,m::Moment) = push!(q.data,flag_expanding(m))
addmoment(q::MomentQueue,m::Moment) = enqueue!(q,m)
addmoment(q::Array{Moment,1},m::Moment) = push!(q,m)
function addmoment(q::Union{ExpandingMoment,MomentQueue,Array},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(t -> get_experiment().data.trial_watcher = watcher))
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
      error(emessage)
    end
    addmoment(q,m)
  end
  q
end

function addmoments(exp,moments;when=nothing,loop=nothing)
  if when == nothing && loop == nothing
    foreach(m -> addmoment(exp,m),moments)
  elseif when != nothing && loop != nothing
    error("You can only define a `when` or a `loop` not both.")
  elseif when != nothing
    addmoment(exp,Weber.when(when,update_offset=true,moments...))
  elseif loop != nothing
    addmoment(exp,Weber.when(loop,loop=true,update_offset=true,moments...))
  end
end

function addtrial_helper(exp::Experiment,trial_count,moments;keys...)

  # make sure the trial doesn't lag due to memory allocation
  start_trial = offset_start_moment(trial_count) do t
    gc_enable(false)
    if trial_count
      record("trial_start")
    else
      record("practice_start")
    end
    reset_response()
  end

  end_trial = moment() do t
    gc_enable(true)
  end

  addmoments(exp,[start_trial,moments,end_trial];keys...)
end

"""
    addtrial(moments...,[when=nothing],[loop=nothing])

Adds a trial to the experiment, consisting of the specified moments.

Each trial increments a counter tracking the number of trials, and (normally) an
offset counter. These two numbers are reported on every line of the resulting
data file (see `record`). They can be retrieved using `experiment_trial`
and `experiment_offset`.

# Conditional and Looping Trials

If a `when` function (with no arguments) is specified the trial only occurs if
the function evaluates to true. If a `loop` function is specified the trial
repeats until the function (with no arguments) evaluates to false. The offset
counter is only udpated once by a looping trial, even if many trial occur
because of the loop.  This is because the loop may result in an aribtrary number
of trials, and an offset number must refer to a well defined event in the
experiment, that will occur every single time the expeirment runs. If the loop
function does not depend on some state that updates during the experiment
(e.g. by changing a variable loop depends on inside of a moment), then it is
recommended that you don't use a loop function and instead simply add multiple
trials, like so:

    for i in 1:N
      addtrial(...)
    end

# How to create moments

Moments can be arbitrarily nested in iterable collections. Each individual
moment is one of the following objects.

1. function

Immediately after the *start* of the preceeding moment (or at the
start of the trial if it is the first argument), this function becomes the event
watcher. Any time an event occurs this function will be called, until a new
watcher replaces it. It shoudl take one argument (the event that occured).

2. moment object

Result of calling the `moment` function, this will
trigger some time after the *start* of the previosu moment.

3. timeout object

Result of calling the `timeout` function, this
will trigger an event if no response occurs from the *start* of the previous
moment, until the specified timeout.

4. await object

Reuslt of calling `await_response` this moment will
begin as soon as the specified response is provided by the subject.

5. looping object

Result of calling `looping`, this will repeat
a series of moments based on some condition

6. when object

Result of call `when`, this will present as series
of moments based on some condition.


!!! note

    In addition to these types of moments you can create more complicated
    moments by concatenating simpler moments togehter using the `>>` operator or
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
first precompiled. Futher, many methods in Weber and other dependent
modules are precompiled before the experiment begins.
"""

function addtrial(moments...;keys...)
  addtrial_helper(get_experiment(),true,moments;keys...)
end

function addtrial(exp::Experiment,moments...;keys...)
  addtrial_helper(exp,true,moments;keys...)
end

"""
   addpractice(moments...,[when=nothing],[loop=nothing])

Identical to `addtrial`, except that it does not incriment the trial count.
"""
function addpractice(moments...;keys...)
  addtrial_helper(get_experiment(),false,moments;keys...)
end

function addpractice(exp::Experiment,moments...;keys...)
  addtrial_helper(exp,false,moments;keys...)
end

"""
   addbreak(moments...,[when=nothing],[loop=nothing])

Identical to `addpractice` but there is no optimization to ensure that events
occur in realtime. This will allow the program to safely recover memory through
the presented moments. Otherwise memory is only refreshed between each trial,
but not during.
"""
function addbreak(moments...;keys...)
  addbreak(get_experiment(),moments...;keys...)
end

function addbreak(exp::Experiment,moments...;keys...)
  addmoments(exp,[offset_start_moment(),moments];keys...)
end

function pause(exp,message,time,firstpause=true)
  exp.flags.running = false
  record(exp,"paused")
  if firstpause
    save_display(exp.win)
  end
  overlay = visual(colorant"gray",priority=Inf) + visual(message,priority=Inf)
  display(exp.win,overlay)
end

function unpause(exp,time)
  record(exp,"unpaused")
  exp.data.pause_mode = Running
  restore_display(exp.win)
  exp.flags.running = true
  process_event(exp,EndPauseEvent(time))
end

const Running = 0
const ToExit = 1
const Unfocused = 2
const Error = 3

function watch_pauses(exp,e)
  if exp.data.pause_mode == Running && iskeydown(e,key":escape:")
    pause(exp,"Exit? [Y for yes, or N for no]",time(e))
    exp.data.pause_mode = ToExit
  elseif exp.data.pause_mode == Running && isunfocused(e) && exp.flags.processing
    pause(exp,"Waiting for window focus...",time(e))
    exp.data.pause_mode = Unfocused
  elseif exp.data.pause_mode == ToExit && iskeydown(e,key"y")
    record(exp,"terminated")
    exp.data.cleanup()
  elseif exp.data.pause_mode == ToExit && iskeydown(e,key"n")
    unpause(exp,time(e))
  elseif exp.data.pause_mode == Unfocused && isfocused(e)
    if exp.flags.processing
      pause(exp,"Paused. [To exit hit Y, to resume hit N]",time(e),false)
      exp.data.pause_mode = ToExit
    else
      exp.data.pause_mode = Running
      exp.flags.running = true
    end
  end
end

"""
    moment([fn],[delta_t])
    moment([delta_t],[fn])

Create a moment that occurs `delta_t` (default 0) seconds after the *start* of
the previous moment, running the specified function. The function `fn` is called
with one argument indicating the time in seconds since the start of the
experiment.

!!! warning

    Long running moment functions will lead to latency issues. Make sure all
    moment functions run relatively quickly. For instance, normally `play` and
    `display` return immediately, before the sound or visual is finished being
    presented to the participant. Please refer to the `addtrial` documentation
    for more details.
"""
moment(delta_t::Number) = TimedMoment(delta_t,t->nothing)
moment() = TimedMoment(0,()->nothing)

function moment(fn::Function,delta_t::Number)
  precompile(fn,(Float64,))
  TimedMoment(delta_t,fn)
end

function moment(delta_t::Number,fn::Function)
  precompile(fn,(Float64,))
  TimedMoment(delta_t,fn)
end

function moment(fn::Function)
  precompile(fn,(Float64,))
  TimedMoment(0,fn)
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

        addtrial(moment(moment(0.1,t -> play(soundA)),
                        moment(0.1,t -> play(soundB))),
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

function offset_start_moment(fn::Function=t->nothing,count_trials=false)
  precompile(fn,(Float64,))
  OffsetStartMoment(fn,count_trials,false)
end

function final_moment(fn::Function)
  precompile(fn,())
  FinalMoment(fn)
end

"""
   await_response(isresponse)

This moment starts when the `isresponse` function evaluates to true.

The `isresponse` function will be called anytime an event occurs. It should
take one parameter (the event that just occured).
"""
function await_response(fn::Function)
  for t in concrete_events
    precompile(fn,(t,))
  end

  ResponseMoment(fn,(t) -> nothing,0,true)
end

"""
    timeout(fn,isresposne,timeout,[delta_update=true])

This moment starts when either `isresponse` evaluates to true or
timeout time (in seconds) passes.

If the moment times out, the function `fn` will be called, recieving
the current time in seconds.
"""
function timeout(fn::Function,isresponse::Function,timeout;delta_update=true)
  precompile(fn,(Float64,))
  for t in concrete_events
    precompile(isresponse,(t,))
  end

  ResponseMoment(isresponse,fn,timeout,delta_update)
end

flag_expanding(m::Moment) = m
function flag_expanding(m::OffsetStartMoment)
  OffsetStartMoment(m.run,m.count_trials,true)
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

function delta_t(moment::TimedMoment)
  moment.delta_t
end

delta_t(moment::OffsetStartMoment) = 0.0
delta_t(moment::FinalMoment) = 0.0

function handle(exp::Experiment,q::MomentQueue,moment::FinalMoment,x)
  # if there's a non-empty moment queue...
  qs = filter(x -> x != q && !isempty(x),exp.data.submoments)
  if !isempty(qs)
    # ...add the final moment to one of the non-empty queues
    enqueue!(first(qs),moment)
  else # if there are no remaining non-empty moment queues...
    # ...end the experiment
    moment.run()
  end
  true
end

run(moment::TimedMoment,time::Float64) = moment.run(time)
run(moment::OffsetStartMoment,time::Float64) = moment.run(time)

function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,time::Float64)
  exp.data.last_time = time
  run(moment,time)

  true
end

function handle(exp::Experiment,q::MomentQueue,
                moment::AbstractTimedMoment,event::ExpEvent)
  false
end

function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0.0 ? moment.timeout_delta_t : Inf)
end

function handle(exp::Experiment,q::MomentQueue,
                moment::ResponseMoment,time::Float64)
  exp.data.last_time = time
  moment.timeout(time)
  true
end

function handle(exp::Experiment,q::MomentQueue,
                moment::ResponseMoment,event::ExpEvent)
  moment.respond(event)
end

keep_skipping(exp,moment::Moment) = exp.data.offset < exp.data.skip_offsets
function keep_skipping(exp,moment::OffsetStartMoment)
  # start moments that originate from an expanding moment do not increment the
  # offset. This is because expanding moments can generate an aribtrary number
  # of such offset moments, so we can not determine a priori how many moments
  # will occur. Thus, there is no good way to skip past part of an expanding
  # moment. However, we still increment the trial count, if appropriate so the
  # reported data correctly shows where trials begin and end.
  if !moment.expanding
    exp.data.offset += 1
  end
  if moment.count_trials
    exp.data.trial += 1
  end
  exp.data.offset < exp.data.skip_offsets
end
function keep_skipping(exp,moment::ExpandingMoment)
  if moment.update_offset
    exp.data.offset += 1
    # each expanding moment only ever incriments the offset
    # counter once, event if it creates a loop.
    moment.update_offset = false
  end
  exp.data.offset < exp.data.skip_offsets
end
keep_skipping(exp,moment::FinalMoment) = false

function skip_offsets(exp,queue)
  while !isempty(queue) && keep_skipping(exp,front(queue))
    dequeue!(queue)
  end
end

function handle(exp::Experiment,q::MomentQueue,moments::CompoundMoment,x)
  queue = Deque{Moment}()
  for moment in moments.data
    push!(queue,moment)
  end
  push!(exp.data.submoments,MomentQueue(queue,q.last))
  true
end

function handle(exp::Experiment,queue::MomentQueue,m::ExpandingMoment,x)
  expand(m,queue)
  true
end
