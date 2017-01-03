using Reactive
using Lazy: @>>, @>, @_
using DataStructures
import DataStructures: front
import Base: run, time, *, length, unshift!, isempty

export Experiment, setup, run, addtrial, addbreak, addpractice, moment,
  await_response, record, timeout, when, looping, endofpause, experiment_trial,
  experiment_metadata

const default_moment_resolution = 1000
const default_input_resolution = 60
const exp_width = 1024
const exp_height = 768

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
  EmptyEvent,
  XID_DownEvent,
  XID_UpEvent
]

function findkwd(kwds,sym,default)
  for (k,v) in kwds
    if k == sym
      return v
    end
  end

  default
end


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

type FinalMoment <: AbstractTimedMoment
  run::Function
end

type CompoundMoment <: Moment
  data::Array{Moment}
end
delta_t(m::CompoundMoment) = 0.0
*(a::SimpleMoment,b::SimpleMoment) = CompoundMoment([a,b])
*(a::CompoundMoment,b::CompoundMoment) = CompoundMoment(vcat(a.data,b.data))
*(a::Moment,b::Moment) = *(promote(a,b)...)
promote_rule(::Type{SimpleMoment},::Type{CompoundMoment}) = CompoundMoment
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
front(m::MomentQueue) = front(m.data)

function expand(m::ExpandingMoment,q::MomentQueue)
  if m.condition()
    for x in m.data
      unshift!(q.data,x)
    end
    if m.repeat
      unshift!(q.data,m)
    end
  end
end

# information that remains true throughout an experiment
immutable ExperimentInfo
  values::Array
  meta::Dict{Symbol,Any}
  moment_resolution::Float64
  start::DateTime
  header::Array{Symbol}
  file::String
end

# ongoing state about an experiment that changes moment to moment
type ExperimentData
  offset::Int
  trial::Int
  skip_offsets::Int
  last_time::Float64
  trial_watcher::Function
  mode::Int
  moments::MomentQueue
  submoments::Array{MomentQueue}
  exception::Nullable{Tuple{Exception,Array{Ptr{Void}}}}
  cleanup::Function
end

# all Reactive signals managed by the experiment only the signals that are
# accessed frequently are stored directly.  The others are stored mostly to keep
# them from being garbaged collected.
immutable ExperimentSignals
  running::Signal{Bool}
  started::Signal{Bool}
  pause_events::Signal{ExpEvent}
  delta_error::Signal{Float64}
  other::Dict{Symbol,Signal}
end

immutable ExperimentState
  info::ExperimentInfo
  data::ExperimentData
  signals::ExperimentSignals
  win::SDLWindow
end

function record_helper(exp::ExperimentState,kwds,header)
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

function record(exp::ExperimentState,code;kwds...)
  extra = [:psych_version => Psychotask.version,
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
number, the subject id, the version of Psychotask, and the time at which the
last moment started are all stored.  Additional information can be added during
creation of the experiment (see `Experiment`).

Each call opens and closes the data file used for the experiment, so there
should be no loss of data if the program is terminated prematurely for some
reason.
"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

const experiment_context = Array{Nullable{ExperimentState}}()

"""
   Experiment([skip=0],[columns=[symbols...]],[debug=false],
              [moment_resolution=1000],[input_resolution=60],[data_dir="data"],
              [width=1024],[height=768],kwds...)

Prepares a new experiment to be run.

# Keyword Arguments
* skip: the number of offsets to skip. Allows restarting of an experiment.
* columns: the names (as symbols) of columns that will be recorded during
the experiment (using `record`).
* debug: if true experiment will show in a windowed view
* moment_resolution: the precision (in ticks per second) that moments
should be presented at
* input_resolution: the precision (in ticks per second) that input events should
be queried.
* data_dir: the directory where data files should be stored
* width and height: specified the screen resolution during the experiment

Additional keyword arguments can be specified to store extra information to the
recorded data file, e.g. the experimental condition or the version of the
experiment being run.
"""
type Experiment
  runfn::Function
  state::ExperimentState

  function Experiment(;skip=0,columns=Symbol[],debug=false,kwds...)
    exp = ExperimentState(debug,skip,columns;kwds...)
    new(() -> error("Call `setup` on the expeirment before running it."),exp)
  end
end

"""
    setup(fn,experiment)

Setup the experiment, adding breaks, practice, and trials.

Setup creats the context necessary to generate elements of an expeirment. All
calls to `addtrial`, `addbreak` and `addpractice` must be called in side of
`fn`. This function must be called before `run`.
"""
function setup(fn::Function,exp::Experiment)
  # create data file header
  record_header(exp.state)
  clenup_run = Condition()
  function cleanup()
    push!(exp.state.signals.running,false)
    push!(exp.state.signals.started,false)
    close(exp.state.win)

    # gc is disabled during individual trials (and enabled at the end of
    # a trial). Make sure it really does return to an enabled state.
    gc_enable(true)

    # indicate that the experiment is done running
    notify(clenup_run)
  end

  try
    # the first moment just waits a short time to ensure
    # notify(clean_run) runs after wait(cleanup_run)
    enqueue!(exp.state.data.moments,moment(0.1))
    exp.state.data.cleanup = cleanup

    # setup all trial moments for this experiment
    experiment_context[] = Nullable(exp.state)
    fn()
    experiment_context[] = Nullable{ExperimentState}()

    # the last moment run cleans up the experiment
    enqueue!(exp.state.data.moments,final_moment(t -> cleanup()))
  catch e
    close(exp.state.win)
    gc_enable(true)
    rethrow(e)
  end

  function runfn()
    experiment_context[] = Nullable(exp.state)
    exp.state.data.mode = Running
    push!(exp.state.signals.started,true)
    push!(exp.state.signals.running,true)

    try
      wait(clenup_run)
    catch
      close(exp.state.win)
      gc_enable(true)
      rethrow()
    end

    # if an exception occured during the experiment, it is handled here
    if !isnull(exp.state.data.exception)
      record(exp.state,"program_error")
      println("Stacktrace in experiment: ")
      map(println,stacktrace(get(exp.state.data.exception)[2]))
      rethrow(get(exp.state.data.exception)[1])
    end

    experiment_context[] = Nullable{ExperimentState}()
  end

  exp.runfn = runfn
  nothing
end

"""
    run(experiment)

Runs an experiment. You must call `setup` first.
"""
function run(exp::Experiment)
  try
    focus(exp.state.win)
    exp.runfn()
  finally
    info("Experiment terminated at offset $(exp.state.data.offset).")
  end
  nothing
end

function get_experiment()
  if isnull(experiment_context[])
    error("Unknown experiment context, call me inside `setup` or during an"*
          " experiment.")
  else
    get(experiment_context[])
  end
end

function ExperimentState(debug::Bool,skip::Int,header::Array{Symbol};
                         moment_resolution = default_moment_resolution,
                         data_dir = "data",
                         input_resolution = default_input_resolution,
                         width=exp_width,height=exp_height,info_values...)
  mkpath(data_dir)

  meta = Dict{Symbol,Any}()
  start_date = now()
  timestr = Dates.format(start_date,"yyyy-mm-dd__HH_MM_SS")
  filename = joinpath(data_dir,findkwd(info_values,:sid,"file")*"_"*timestr*".csv")
  einfo = ExperimentInfo(info_values,meta,moment_resolution,start_date,
                        header,filename)

  offset = 0
  trial = 0
  trial_watcher = (e) -> nothing
  last_time = 0.0
  mode = Running
  moments = MomentQueue(Deque{Moment}(),0)
  submoments = Array{MomentQueue,1}()
  exception = Nullable{Tuple{Exception,Array{Ptr{Void}}}}()
  cleanup = () -> error("no cleanup function available!")
  data = ExperimentData(offset,trial,skip,last_time,trial_watcher,mode,moments,
                        submoments,exception,cleanup)

  running = Signal(false)
  started = Signal(false)
  pause_events = Signal(ExpEvent,EmptyEvent())
  delta_error = Signal(0.0)
  other = Dict{Symbol,Signal}()
  signals = ExperimentSignals(running,started,pause_events,delta_error,other)

  win = window(width,height,fullscreen=!debug,accel=!debug)

  exp = ExperimentState(einfo,data,signals,win)

  timing = foldp(+,0.0,fpswhen(running,moment_resolution))
  exp.signals.other[:timing] = timing

  events = @_ fpswhen(started,input_resolution) begin
    sampleon(_,timing)
    map(event_streamer(win,() -> exp.data.cleanup()),_)
    flatten(_)
    merge(_,pause_events)
  end

  timing_and_events = filterwhen(running,EmptyEvent(),merge(timing,events))
  exp.signals.other[:moment_processing] = map(timing_and_events) do x
    if !isnull(x)
      process(exp,exp.data.moments,x)
      process(exp,exp.data.submoments,x)
      true
    end
    false
  end

  exp.signals.other[:pause_processing] = map(events) do e
    watch_pauses(exp,e)
    false
  end

  filt_events = filterwhen(running,EmptyEvent(),events)
  exp.signals.other[:watcher_processing] = map(filt_events) do e
    if !isnull(e)
      try
        exp.data.last_time = time(e)
        exp.data.trial_watcher(e)
      catch e
        exp.data.exception = Nullable((e,catch_backtrace()))
        exp.data.mode = Error
        exp.data.cleanup()
      end
    end
    false
  end

  bad_times = throttle(1,filter(x -> x > timing_tolerance,0.0,delta_error))
  good_times = throttle(1,filter(x -> x < timing_tolerance,0.0,delta_error))
  exp.signals.other[:timing_warn] = map(bad_times) do err
    if err != 0.0
      warn("The latency of trial moments has exceeded desirable levels "*
           " ($err seconds). This normally occurs when the experiment first "*
           "starts up, but if unacceptable levels continue throughout the "*
           "experiment, consider closing some programs on your computer or"*
           " running this program on a faster machine.")
      record(exp,"bad_delta_latency($err)")
    end
  end
  exp.signals.other[:timing_info] = map(good_times) do err
    if err != 0.0
      info("The latency of trial moments has fallen to an acceptable level "*
           "($err seconds). It may fall further, but unless it exceedes a"*
           " tolerable level, you will not be notified. Note that this "*
           "measure of latency only verifies that the commands to generate "*
           "stimuli occur when they should. Emprical verification of "*
           "stimulus timing requires that you monitor the output of your "*
           "machine using light sensors, microphones, etc...")
      record(exp,"good_delta_latency($err)")
    end
  end

  exp
end

addmoment(e::ExperimentState,m) = addmoment(e.data.moments,m)
addmoment(q::ExpandingMoment,m::Moment) = push!(q.data,flag_expanding(m))
addmoment(q::MomentQueue,m::Moment) = enqueue!(q,m)
function addmoment(q::Union{ExpandingMoment,MomentQueue},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(t -> get_experiment().data.trial_watcher = watcher))
end
function addmoment(q,ms)
  emessage = "Expected a value of type `Moment` or `Function` but got"*
              " a value of type $(typeof(ms)) instead."
  try
    first(ms)
  catch e
    if isa(e,MethodError)
      error(emessage)
    end
    rethrow(e)
  end

  for m in ms
    # some types iterate over themselves (e.g. numbers);
    # check for this to avoid infinite recursion
    if m == ms
      error(emessage)
    end
    addmoment(q,m)
  end
end

"""
    experiment_trial()

Returns the current trial of the experiment.
"""
experiment_trial(exp) = exp.data.trial
experiment_trial() = trial(get_experiment())

"""
   experiment_metadata() = Dict{Symbol,Any}()

Returns metadata for this experiment. You can store
global state, specific to this experiment, in this dictionary.
"""
experiment_metadata(exp) = exp.info.meta
experiment_metadata() = experiment_metadata(get_experiment())

function addmoments(exp,moments;when=nothing,loop=nothing)
  if when == nothing && loop == nothing
    foreach(m -> addmoment(exp,m),moments)
  elseif when != nothing && loop != nothing
    error("You can only define a `when` or a `loop` not both.")
  elseif when != nothing
    addmoment(exp,Psychotask.when(when,update_offset=true,moments...))
  elseif loop != nothing
    addmoment(exp,Psychotask.when(loop,loop=true,update_offset=true,moments...))
  end
end

function addtrial_helper(exp::ExperimentState,trial_count,moments;keys...)

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
data file (see `record`).

# Conditional Trials

If a `when` function (with no arguments) is specified the trial only occurs if
the function evaluates to true. If a `loop` function is specified the trial
repeats until the function (with no arguments) evaluates to false. The offset
counter is not updated if `when` or `loop` are != `nothing`. Offsets
are used to restart an experiment at some well defined time point. Since
`when` and `loop` lead to trials being run some aribtrary number of times
the number of offsets that they increment would vary from run to run, and
so this would prevent the `offset` from being well defined from run to run.

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

    By using the `*` operator you can concatenate multiple moments into
    a single moment. A concatenation of moments starts immediately,
    and then proceedes through all of the concanetated moments in order.
    This is sometime useful for playing moments in parallel. The following
    example will present two sounds, one at 100ms, the other at 200ms after
    the start of the trial. It will also display "Too Late!" on the screen
    if no keyboard key is pressed 150ms after the start of the trial.

        addtrial(moment(0.1,t -> play(soundA)) * moment(0.1,t -> play(soundB)),
                 timeout(0.15,iskeydown,x -> display("Too Late!")))

# Guidlines for low-latency trials

Psychotask aims to present trials at low latencies for accurate experiments.

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
first precompiled. Futher, many methods in Psychotask and other dependent
modules are precompiled before the experiment begins.
"""

function addtrial(moments...;keys...)
  addtrial_helper(get_experiment(),true,moments;keys...)
end

function addtrial(exp::ExperimentState,moments...;keys...)
  addtrial_helper(exp,true,moments;keys...)
end

"""
   addpractice(moments...,[when=nothing],[loop=nothing])

Identical to `addtrial`, except that it does not incriment the trial count.
"""
function addpractice(moments...;keys...)
  addtrial_helper(get_experiment(),false,moments;keys...)
end

function addpractice(exp::ExperimentState,moments...;keys...)
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

function addbreak(exp::ExperimentState,moments...;keys...)
  addmoments(exp,[offset_start_moment(),moments];keys...)
end

function pause(exp,message,time,firstpause=true)
  push!(exp.signals.running,false)
  record(exp,"paused")
  if firstpause
    save_display(exp.win)
  end
  overlay = visual(colorant"gray",priority=Inf) + visual(message,priority=Inf)
  display(exp.win,overlay)
end

function unpause(exp,time)
  record(exp,"unpaused")
  exp.data.mode = Running
  restore_display(exp.win)
  push!(exp.signals.running,true)
  push!(exp.pause_events,EndPauseEvent(time))
end

const Running = 0
const ToExit = 1
const Unfocused = 2
const Error = 3

function watch_pauses(exp,e)
  if exp.data.mode == Running && iskeydown(e,key":escape:")
    pause(exp,"Exit? [Y for yes, or N for no]",time(e))
    exp.data.mode = ToExit
  elseif exp.data.mode == Running && isunfocused(e) && value(exp.signals.started)
    pause(exp,"Waiting for window focus...",time(e))
    exp.data.mode = Unfocused
  elseif exp.data.mode == ToExit && iskeydown(e,key"y")
    record(exp,"terminated")
    exp.data.cleanup()
  elseif exp.data.mode == ToExit && iskeydown(e,key"n")
    unpause(exp,time(e))
  elseif exp.data.mode == Unfocused && isfocused(e)
    if value(exp.signals.started)
      pause(exp,"Paused. [To exit hit Y, to resume hit N]",time(e),false)
      exp.data.mode = ToExit
    else
      exp.data.mode = Running
      push!(exp.signals.running,true)
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

The timing resolution is limited only by the processing speed of the computer,
so the latency of moments, and the error in reported times should be quite low,
if the only the following oeprations are perormed:

- calling `play` on sounds that have been pre-generated using `sound`
- calling `display` on graphical objects that have been pre-rendered
  using `visual`
- calling `record`
- simple programming logic

It is recommended that any calls to `record` be made at the end of a moment,
to keep the latency of any multimedia events low.

!!! warning

    Long running moment functions will lead to latency issues. Make
    sure all moment function run relatively quickly. For instance, normally `play`
    and `display` return immediately, before the sound or visual is finished
    being presented to the participant.
"""
function moment(delta_t::Number) TimedMoment(delta_t,t->nothing)
end

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

function moment()
  TimedMoment(0,()->nothing)
end

function offset_start_moment(fn::Function=t->nothing,count_trials=false)
  precompile(fn,(Float64,))
  OffsetStartMoment(fn,count_trials,false)
end

function final_moment(fn::Function)
  precompile(fn,(Float64,))
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
  when(when,moments...;loop=true)
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

run(moment::TimedMoment,time::Float64) = moment.run(time)
run(moment::OffsetStartMoment,time::Float64) = moment.run(time)
run(moment::FinalMoment,time::Float64) = moment.run(time)

function handle(exp::ExperimentState,moment::AbstractTimedMoment,time::Float64)
  try
    exp.data.last_time = time
    run(moment,time)
  catch e
    exp.data.exception = Nullable((e,catch_backtrace()))
    exp.data.mode = Error
    exp.data.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::AbstractTimedMoment,event::ExpEvent)
  false
end

function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0.0 ? moment.timeout_delta_t : Inf)
end

function handle(exp::ExperimentState,moment::ResponseMoment,time::Float64)
  try
    exp.data.last_time = time
    moment.timeout(time)
  catch e
    exp.data.exception = Nullable((e,catch_backtrace()))
    exp.data.mode = Error
    exp.data.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::ResponseMoment,event::ExpEvent)
  handled = true
  try
    handled = moment.respond(event)
  catch e
    exp.data.exception = Nullable((e,catch_backtrace()))
    exp.data.mode = Error
    exp.data.cleanup()
  end
  handled
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
  end
  exp.data.offset < exp.data.skip_offsets
end
keep_skipping(exp,moment::FinalMoment) = false

function skip_offsets(exp,queue)
  while !isempty(queue) && keep_skipping(exp,front(queue))
    dequeue!(queue)
  end
end

function handle(exp::ExperimentState,moments::CompoundMoment,x)
  queue = Deque{Moment}()
  for moment in moments.data
    push!(queue,moment)
  end
  push!(exp.data.submoments,MomentQueue(queue,0))
  true
end

function handle(exp::ExperimentState,m::ExpandingMoment,x)
  expand(m,exp.data.moments)
  true
end

function process(exp::ExperimentState,queues::Array{MomentQueue},x)
  filter!(queues) do queue
    !isempty(process(exp,queue,x).data)
  end
end

function process(exp::ExperimentState,queue::MomentQueue,event::ExpEvent)
  skip_offsets(exp,queue)

  if !isempty(queue)
    moment = front(queue)
    handled = handle(exp,moment,event)
    if handled
      dequeue!(queue)
      if update_last(moment)
        queue.last = time(event)
      end
    end
  end

  queue
end

const timing_tolerance = 0.002
function check_timing(exp::ExperimentState,moment::Moment,
                      run_t::Float64,last::Float64)
  d = delta_t(moment)
  if 0.0 < d < Inf
    empirical_delta = run_t - last
    error = abs(empirical_delta - d)
    if error > timing_tolerance
      push!(exp.signals.delta_error,error)
    elseif value(exp.signals.delta_error) > timing_tolerance
      push!(exp.signals.delta_error,error)
    end
  end
end

function process(exp::ExperimentState,queue::MomentQueue,t::Float64)
  skip_offsets(exp,queue)

  if !isempty(queue)
    start_time = time()
    moment = front(queue)
    event_time = delta_t(moment) + queue.last
    if event_time - t <= 1/exp.info.moment_resolution
      offset = t - start_time
      run_time = offset + time()
      while event_time > run_time
        run_time = offset + time()
      end
      check_timing(exp,moment,t,queue.last)
      handled = handle(exp,moment,t)
      if handled
        dequeue!(queue)
        if update_last(moment)
          queue.last = run_time
        end
      end
    end
  end

  queue
end
