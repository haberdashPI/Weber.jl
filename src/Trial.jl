# TODO: use the version indicated by Pkg

# TODO: define a trial generator, which uses a predefined set of
# GeneratedMoments, that take an additional parameter in their callback that
# recieveds state from the generator. The generator then has a termination
# condition that is a function of that state.

# TODO: allow moments to skip the remainder of a trial

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style.

# TODO: create a 2AFC adaptive abstraction

# TODO: generate errors for any sounds or image generated during
# a moment. Create a 'dynamic' moment and response object that allows
# for this.

using Reactive
using Lazy: @>>, @>, @_
using DataStructures
import Base: run, time, *

export Experiment, setup, run, addtrial, addbreak, addpractice, moment,
  await_response, record, timeout, endofpause

const default_moment_resolution = 1000
const default_input_resolution = 60
const exp_width = 1024
const exp_height = 768

type EndPauseEvent <: ExpEvent
  time::Float64
end

endofpause(event::ExpEvent) = false
endofpause(event::EndPauseEvent) = true
time(event::EndPauseEvent) = event.time

const concrete_events = [
  KeyUpEvent,
  KeyDownEvent,
  WindowFocused,
  WindowUnfocused,
  EndPauseEvent,
  EmptyEvent
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

type MomentQueue
  data::Queue{Moment}
  last::Float64
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
    enqueue!(exp.state.moments.data,moment(0.1))
    exp.state.cleanup = cleanup

    # setup all trial moments for this experiment
    experiment_context = Nullable(exp.state)
    fn()
    experiment_context = Nullable{ExperimentState}()

    # the last moment run cleans up the experiment
    enqueue!(exp.state.moments.data,final_moment(t -> cleanup()))
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
    error("Unknown experiment context, call me inside run_experiment.")
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
                        MomentQueue(Queue(Moment),0),Array{MomentQueue,1}(),
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

addmoment(exp::ExperimentState,m::Moment) = enqueue!(exp.moments.data,m)
function addmoment(exp::ExperimentState,watcher::Function)
  for t in concrete_events
    precompile(watcher,(t,))
  end
  enqueue!(exp.moments.data,moment(t -> exp.trial_watcher = watcher))
end
function addmoment(exp::ExperimentState,ms)
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
    addmoment(exp,m)
  end
end

function addtrial_helper(exp::ExperimentState,trial_count,moments)

  # make sure the trial doesn't lag due to memory allocation
  start_trial = offset_start_moment(trial_count) do t
    gc_enable(false)
    if trial_count
      record("trial_start",time=t)
    else
      record("practice_start",time=t)
    end
  end

  end_trial = moment() do t
    gc_enable(true)
  end

  addmoment(exp,start_trial)
  foreach(m -> addmoment(exp,m),moments)
  addmoment(exp,end_trial)
end

function addtrial(moments...)
  addtrial_helper(get_experiment(),true,moments)
end

function addtrial(exp::ExperimentState,moments...)
  addtrial_helper(exp,true,moments)
end

function addpractice(moments...)
  addtrial_helper(get_experiment(),false,moments)
end

function addpractice(exp::ExperimentState,moments...)
  addtrial_helper(exp,false,moments)
end

function addbreak(moments...)
  addbreak(get_experiment(),moments...)
end

function addbreak(exp::ExperimentState,moments...)
  addmoment(exp,offset_start_moment())
  foreach(m -> addmoment(exp,m),moments)
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

function moment(delta_t::Number)
  TimedMoment(delta_t,t->nothing)
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

function offset_start_moment(fn::Function=t->nothing,count_trials=false)
  precompile(fn,(Float64,))
  OffsetStartMoment(fn,count_trials)
end

function final_moment(fn::Function)
  precompile(fn,(Float64,))
  FinalMoment(fn)
end

function await_response(fn::Function;delta_update=true)
  for t in concrete_events
    precompile(fn,(t,))
  end

  ResponseMoment(fn,(t) -> nothing,0,delta_update)
end

function timeout(fn::Function,isresponse::Function,timeout;delta_update=true)
  precompile(fn,(Float64,))
  for t in concrete_events
    precompile(isresponse,(t,))
  end

  ResponseMoment(isresponse,fn,timeout,delta_update)
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
  exp.offset += 1
  if moment.count_trials
    exp.trial += 1
  end
  exp.offset < exp.skip_offsets
end
keep_skipping(exp,moment::FinalMoment) = false

function skip_offsets(exp,queue)
  while !isempty(queue.data) && keep_skipping(exp,front(queue.data))
    dequeue!(queue.data)
  end
end

function handle(exp::ExperimentState,moments::CompoundMoment,x)
  queue = Queue(Moment)
  for moment in moments.data
    enqueue!(queue,moment)
  end
  push!(exp.submoments,MomentQueue(queue,0))
  true
end

function process(exp::ExperimentState,queues::Array{MomentQueue},x)
  filter!(queues) do queue
    !isempty(process(exp,queue,x).data)
  end
end

function process(exp::ExperimentState,queue::MomentQueue,event::ExpEvent)
  skip_offsets(exp,queue)

  if !isempty(queue.data)
    moment = front(queue.data)
    handled = handle(exp,moment,event)
    if handled
      dequeue!(queue.data)
      if update_last(moment)
        queue.last = time(event)
      end
    end
  end

  queue
end

function process(exp::ExperimentState,queue::MomentQueue,t::Float64)
  skip_offsets(exp,queue)

  if !isempty(queue.data)
    start_time = time()
    moment = front(queue.data)
    event_time = delta_t(moment) + queue.last
    if event_time - t <= 1/exp.moment_resolution
      offset = t - start_time
      run_time = offset + time()
      while event_time > run_time
        run_time = offset + time()
      end
      handled = handle(exp,moment,t)
      if handled
        dequeue!(queue.data)
        if update_last(moment)
          queue.last = run_time
        end
      end
    end
  end

  queue
end
