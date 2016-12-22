# TODO: document the exported functions

# TODO: define some tests to evaluate the documented effects of addtrial,
# addbreak and addpractice on the offest and trial counts, to ensure reasonable
# timing of individual moments, and the effects of the expanding moments.

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style.

# TODO: submit the package to METADATA.jl

# TODO: use the version number indicated by Pkg

using Reactive
using Lazy: @>>, @>, @_
using DataStructures
import DataStructures: front
import Base: run, time, *, length, unshift!, isempty

export Experiment, setup, run, addtrial, addbreak, addpractice, moment,
  await_response, record, timeout, when, looping, endofpause

const default_moment_resolution = 1000
const default_input_resolution = 60
const exp_width = 1024
const exp_height = 768

type EndPauseEvent <: ExpEvent
  time::Float64
end

"""
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
delta_t(m::CompoundMoment) = 0
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
delta_t(m::ExpandingMoment) = 0

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

type ExperimentState
  meta::Dict{Symbol,Any}
  offset::Int
  trial::Int
  skip_offsets::Int
  start::DateTime
  info::Array
  running::Reactive.Signal{Bool}
  started::Reactive.Signal{Bool}
  header::Array{Symbol}
  events::Reactive.Signal{Any}
  trial_watcher::Function
  watcher_state::Reactive.Signal{Bool}
  mode::Int
  moments::MomentQueue
  submoments::Array{MomentQueue}
  state::Reactive.Signal{Bool}
  file::String
  win::SDLWindow
  cleanup::Function
  exception::Nullable{Tuple{Exception,Array{Ptr{Void}}}}
  moment_resolution::Float64
  pause_state::Reactive.Signal{Bool}
  pause_events::Reactive.Signal{ExpEvent}
end

function record_helper(exp::ExperimentState,kwds,header)
  columns = map(x -> x[1],kwds)

  if !isempty(columns) && !all(map(c -> c ∈ header,columns))
    missing = filter(c -> c ∉ header,columns)

    error("Unexpected column$(length(missing) > 1 ? "s" : "")"*
          "$(join(missing,", "," and ")). "*
          "Make sure you specify all columns you plan to use "*
          "during experiment initialization.")
  end

  open(exp.file,"a") do stream
    @_ header begin
      map(c -> findkwd(kwds,c,""),_)
      join(_,",")
      println(stream,_)
    end
  end
end

function record_header(exp)
  extra_keys = [:psych_version,:start_date,:start_time,:offset,:trial]
  info_keys = map(x->x[1],exp.info)

  reserved_keys = Set([extra_keys...;info_keys...])
  reserved = filter(x -> x ∈ reserved_keys,exp.header)
  if length(reserved) > 0
    plural = length(reserved) > 1
    error("The column name$(plural ? "s" : "")"*
          "$(join(missing,", "," and ")) $(plural ? "are" : "is") reserved."*
          "Please use $(plural ? "" : "a ")different name$(plural ? "s" : "").")
  end

  columns = [extra_keys...,info_keys...,:code,exp.header...]
  open(x -> println(x,join(columns,",")),exp.file,"w")
end

function record(exp::ExperimentState,code;kwds...)
  extra = [:psych_version => psych_version,
           :start_date => Dates.format(exp.start,"yyyy-mm-dd"),
           :start_time => Dates.format(exp.start,"HH:MM:SS"),
           :offset => exp.offset,
           :trial => exp.trial]

  info_keys = map(x->x[1],exp.info)
  extra_keys = map(x->x[1],extra)
  record_helper(exp,tuple(extra...,exp.info...,:code => code,kwds...),
                [extra_keys...,info_keys...,:code,exp.header...])
end

"""
    record(code;column_values...)

Record an event with the given `code` to the data file.

Each event has a code which identifies it as being a particular type
of event. Conventially the same code should have the same set of column
values. Unspecified columns are left blank.

All calls to record also result in many types of information being
written to the data file. The start time and date, the trial and offset
number, the subject id and the version of Psychotask are all stored.
Additional information can be added during creation of the experiment.
"""
function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

experiment_context = Nullable{ExperimentState}()
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
  global experiment_context

  # create data file header
  record_header(exp.state)
  clenup_run = Condition()
  function cleanup()
    push!(exp.state.running,false)
    push!(exp.state.started,false)
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
    enqueue!(exp.state.moments,moment(0.1))
    exp.state.cleanup = cleanup

    # setup all trial moments for this experiment
    experiment_context = Nullable(exp.state)
    fn()
    experiment_context = Nullable{ExperimentState}()

    # the last moment run cleans up the experiment
    enqueue!(exp.state.moments,final_moment(t -> cleanup()))
  catch e
    close(exp.state.win)
    gc_enable(true)
    rethrow(e)
  end

  function runfn()
    global experiment_context
    experiment_context = Nullable(exp.state)
    exp.state.mode = Running
    push!(exp.state.started,true)
    push!(exp.state.running,true)

    try
      wait(clenup_run)
    catch
      close(exp.state.win)
      gc_enable(true)
      rethrow()
    end

    # if an exception occured during the experiment, it is handled here
    if !isnull(exp.state.exception)
      record(exp.state,"program_error")
      println("Stacktrace in experiment: ")
      map(println,stacktrace(get(exp.state.exception)[2]))
      rethrow(get(exp.state.exception)[1])
    end

    experiment_context = Nullable{ExperimentState}()
  end

  exp.runfn = runfn
  nothing
end

function run(exp::Experiment)
  try
    focus(exp.state.win)
    exp.runfn()
  finally
    info("Experiment terminated at offset $(exp.state.offset).")
  end
  nothing
end

function get_experiment()
  if isnull(experiment_context)
    error("Unknown experiment context, call me inside `setup`.")
  else
    get(experiment_context)
  end
end

function ExperimentState(debug::Bool,skip::Int,header::Array{Symbol};
                         moment_resolution = default_moment_resolution,
                         data_dir = "data",
                         input_resolution = default_input_resolution,
                         width=exp_width,height=exp_height,info...)
  mkpath(data_dir)
  exp_start = now()
  timestr = Dates.format(exp_start,"yyyy-mm-dd__HH_MM_SS")
  data_file = joinpath(data_dir,findkwd(info,:sid,"file")*"_"*timestr*".csv")

  win = window(width,height,fullscreen=!debug,accel=!debug)

  running = Reactive.Signal(false)
  started = Reactive.Signal(false)

  timing = foldp(+,0.0,fpswhen(running,moment_resolution))
  pause_events = Reactive.Signal(ExpEvent,EmptyEvent())

  events = Reactive.Signal(Any,EmptyEvent())
  state = Reactive.Signal(Bool,false)

  exp = ExperimentState(Dict{Symbol,Any}(),0,0,skip,exp_start,info,running,
                        started,header,events,e -> nothing,
                        Reactive.Signal(false),Running,
                        MomentQueue(Deque{Moment}(),0),Array{MomentQueue,1}(),
                        state,data_file,win,
                        () -> error("no cleanup function available!"),
                        Nullable{Tuple{Exception,Array{Ptr{Void}}}}(),
                        moment_resolution,Reactive.Signal(false),pause_events)

  events = @_ fpswhen(started,input_resolution) begin
    sampleon(_,timing)
    map(event_streamer(win,() -> exp.cleanup()),_)
    flatten(_)
    merge(_,pause_events)
  end

  exp.state = map(filterwhen(running,EmptyEvent(),merge(timing,events))) do x
    if !isnull(x)
      process(exp,exp.moments,x)
      process(exp,exp.submoments,x)
      true
    end
    false
  end

  exp.pause_state = map(events) do e
    watch_pauses(exp,e)
    false
  end

  exp.watcher_state = map(filterwhen(running,EmptyEvent(),events)) do e
    if !isnull(e)
      try
        exp.trial_watcher(e)
      catch e
        exp.exception = Nullable((e,catch_backtrace()))
        exp.mode = Error
        exp.cleanup()
      end
    end
    false
  end

  exp
end

addmoment(e::ExperimentState,m) = addmoment(e.moments,m)
addmoment(q::ExpandingMoment,m::Moment) = push!(q.data,flag_expanding(m))
addmoment(q::MomentQueue,m::Moment) = enqueue!(q,m)
function addmoment(q::Union{ExpandingMoment,MomentQueue},watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  addmoment(q,moment(t -> get_experiment().trial_watcher = watcher))
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
      record("trial_start",time=t)
    else
      record("practice_start",time=t)
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

Adds a trial to the expeirment, consisting of the specified moments.

Each trial increments a counter for the number of trials, and the offset,
these two numbers are reported on ever line of the resulting data file
(see `record`)

If a `when` function (with no arguments) is specified the trial only occurs if
the function evaluates to true. If a `loop` function is specified the trial
repeats until the function (with no arguments) evaluates to false.

Moments can be arbitrarily nested in iterable collections. Each individual
moment is one of the following objects:

1. function - immediately after the *start* of the preceeding moment (or at the
start of the trial if it is the first argument), this function becomes the event
watcher. Any time an event occurs this function will be called, until a new
watcher replaces it. It shoudl take one argument (the event that occured).

2. moment object - result of calling the `moment` function, this will
trigger some time after the *start* of the previosu moment.

3. timeout object - result of calling the `timeout` function, this
will trigger an event if no response occurs from the *start* of the previous
moment, until the specified timeout.

4. await object - reuslt of calling `await_response` this moment will
begin as soon as the specified response is provided by the subject.

5. looping object - result of calling `looping`, this will repeat
a series of moments based on some condition

6. when object - result of call `when`, this will present as series
of moments based on some condition.
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
  push!(exp.running,false)
  record(exp,"paused",time=time)
  if firstpause
    save_display(exp.win)
  end
  overlay = render(colorant"gray",priority=Inf) + render(message,priority=Inf)
  display(exp.win,overlay)
end

function unpause(exp,time)
  record(exp,"unpaused",time=time)
  exp.mode = Running
  restore_display(exp.win)
  push!(exp.running,true)
  push!(exp.pause_events,EndPauseEvent(time))
end

const Running = 0
const ToExit = 1
const Unfocused = 2
const Error = 3

function watch_pauses(exp,e)
  if exp.mode == Running && iskeydown(e,key":escape:")
    pause(exp,"Exit? [Y for yes, or N for no]",time(e))
    exp.mode = ToExit
  elseif exp.mode == Running && isunfocused(e) && value(exp.started)
    pause(exp,"Waiting for window focus...",time(e))
    exp.mode = Unfocused
  elseif exp.mode == ToExit && iskeydown(e,key"y")
    record(exp,"terminated")
    exp.cleanup()
  elseif exp.mode == ToExit && iskeydown(e,key"n")
    unpause(exp,time(e))
  elseif exp.mode == Unfocused && isfocused(e)
    if value(exp.started)
      pause(exp,"Paused. [To exit hit Y, to resume hit N]",time(e),false)
      exp.mode = ToExit
    else
      exp.mode = Running
      push!(exp.running,true)
    end
  end
end

"""
    moment([fn],[delta_t])
    moment([delta_t],[fn])

Create a moment that occurs `delta_t` (default 0) seconds after the *start*
of the previous moment, running the specified function (doing nothing by
default).

The function `fn` will be passed one argument indicating the time
in seconds since the start of the experiment.
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

This moment starts when the function evaluates to true.

The `is response` function will be called anytime an event occurs. It should
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

This moment will begin at the *start* of the previous moment, and
repeats the listed moments (possibly in nested iterable objects)
until fn (which takes no arguments) evaluates to false.
"""
function looping(moments...;when=() -> error("infinite loop!"))
  when(when,moments...;loop=true)
end


"""
    when(condition,moments...)

This moment will begin at the *start* of the previous moment, and
presents the following moments (possibly in nested iterable objects)
if fn (which takes no arguments) evaluates to true.
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

function delta_t(moment::OffsetStartMoment)
  0
end

function delta_t(moment::FinalMoment)
  0
end

function run(moment::TimedMoment,time::Float64)
  moment.run(time)
end

function run(moment::OffsetStartMoment,time::Float64)
  moment.run(time)
end

function run(moment::FinalMoment,time::Float64)
  moment.run(time)
end

function handle(exp::ExperimentState,moment::AbstractTimedMoment,time::Float64)
  try
    run(moment,time)
  catch e
    exp.exception = Nullable((e,catch_backtrace()))
    exp.mode = Error
    exp.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::AbstractTimedMoment,event::ExpEvent)
  false
end

function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0 ? moment.timeout_delta_t : Inf)
end

function handle(exp::ExperimentState,moment::ResponseMoment,time::Float64)
  try
    moment.timeout(time)
  catch e
    exp.exception = Nullable((e,catch_backtrace()))
    exp.mode = Error
    exp.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::ResponseMoment,event::ExpEvent)
  handled = true
  try
    handled = moment.respond(event)
  catch e
    exp.exception = Nullable((e,catch_backtrace()))
    exp.mode = Error
    exp.cleanup()
  end
  handled
end

keep_skipping(exp,moment::Moment) = exp.offset < exp.skip_offsets
function keep_skipping(exp,moment::OffsetStartMoment)
  # start moments that originate from an expanding moment do not increment the
  # offset. This is because expanding moments can generate an aribtrary number
  # of such offset moments, so we can not determine a priori how many moments
  # will occur. Thus, there is no good way to skip past part of an expanding
  # moment. However, we still increment the trial count, if appropriate so the
  # reported data correctly shows where trials begin and end.
  if !moment.expanding
    exp.offset += 1
  end
  if moment.count_trials
    exp.trial += 1
  end
  exp.offset < exp.skip_offsets
end
function keep_skipping(exp,moment::ExpandingMoment)
  if moment.update_offset
    exp.offset += 1
  end
  exp.offset < exp.skip_offsets
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
  push!(exp.submoments,MomentQueue(queue,0))
  true
end

function handle(exp::ExperimentState,m::ExpandingMoment,x)
  expand(m,exp.moments)
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

function process(exp::ExperimentState,queue::MomentQueue,t::Float64)
  skip_offsets(exp,queue)

  if !isempty(queue)
    start_time = time()
    moment = front(queue)
    event_time = delta_t(moment) + queue.last
    if event_time - t <= 1/exp.moment_resolution
      offset = t - start_time
      run_time = offset + time()
      while event_time > run_time
        run_time = offset + time()
      end
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
