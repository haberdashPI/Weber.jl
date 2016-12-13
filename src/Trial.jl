# TODO: use the version indicated by Pkg
const psych_version = v"0.0.4"

using Reactive
using Lazy: @>>, @>, @_
using DataStructures
import Base: isnull, run, time

export Experiment, run, addtrial, addbreak, moment, response, record, timeout,
  iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, endofpause,
  @key_str

const default_moment_resolution = 1000
const default_input_resolution = 60
const exp_width = 1024
const exp_height = 768
const exp_color_depth = 32

abstract ExpEvent

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

type EndPauseEvent <: ExpEvent
  time::Float64
end

type EmptyEvent <: ExpEvent
end

const concrete_events = [
  KeyUpEvent,
  KeyDownEvent,
  WindowFocused,
  WindowUnfocused,
  EndPauseEvent,
  EmptyEvent
]

"""
    time(e::ExpEvent)

Get the time an event occured relative to the start of the experiment.
"""
time(event::ExpEvent) = 0
time(event::KeyUpEvent) = event.time
time(event::KeyDownEvent) = event.time
time(event::WindowFocused) = event.time
time(event::WindowUnfocused) = event.time
time(event::EndPauseEvent) = event.time

isnull(e::ExpEvent) = false
isnull(e::EmptyEvent) = true

str_to_code = Dict(
  "a" => reinterpret(Int32,icxx"SDLK_a;"),
  "b" => reinterpret(Int32,icxx"SDLK_b;"),
  "c" => reinterpret(Int32,icxx"SDLK_c;"),
  "d" => reinterpret(Int32,icxx"SDLK_d;"),
  "e" => reinterpret(Int32,icxx"SDLK_e;"),
  "f" => reinterpret(Int32,icxx"SDLK_f;"),
  "g" => reinterpret(Int32,icxx"SDLK_g;"),
  "h" => reinterpret(Int32,icxx"SDLK_h;"),
  "i" => reinterpret(Int32,icxx"SDLK_i;"),
  "j" => reinterpret(Int32,icxx"SDLK_j;"),
  "k" => reinterpret(Int32,icxx"SDLK_k;"),
  "l" => reinterpret(Int32,icxx"SDLK_l;"),
  "m" => reinterpret(Int32,icxx"SDLK_m;"),
  "n" => reinterpret(Int32,icxx"SDLK_n;"),
  "o" => reinterpret(Int32,icxx"SDLK_o;"),
  "p" => reinterpret(Int32,icxx"SDLK_p;"),
  "q" => reinterpret(Int32,icxx"SDLK_q;"),
  "r" => reinterpret(Int32,icxx"SDLK_r;"),
  "s" => reinterpret(Int32,icxx"SDLK_s;"),
  "t" => reinterpret(Int32,icxx"SDLK_t;"),
  "u" => reinterpret(Int32,icxx"SDLK_u;"),
  "v" => reinterpret(Int32,icxx"SDLK_v;"),
  "w" => reinterpret(Int32,icxx"SDLK_w;"),
  "x" => reinterpret(Int32,icxx"SDLK_x;"),
  "y" => reinterpret(Int32,icxx"SDLK_y;"),
  "z" => reinterpret(Int32,icxx"SDLK_z;"),
  "0" => reinterpret(Int32,icxx"SDLK_0;"),
  "1" => reinterpret(Int32,icxx"SDLK_1;"),
  "2" => reinterpret(Int32,icxx"SDLK_2;"),
  "3" => reinterpret(Int32,icxx"SDLK_3;"),
  "4" => reinterpret(Int32,icxx"SDLK_4;"),
  "5" => reinterpret(Int32,icxx"SDLK_5;"),
  "6" => reinterpret(Int32,icxx"SDLK_6;"),
  "7" => reinterpret(Int32,icxx"SDLK_7;"),
  "8" => reinterpret(Int32,icxx"SDLK_8;"),
  "9" => reinterpret(Int32,icxx"SDLK_9;"),
  " " => reinterpret(Int32,icxx"SDLK_SPACE;"),
  ":space:" => reinterpret(Int32,icxx"SDLK_SPACE;"),
  ":up:" => reinterpret(Int32,icxx"SDLK_UP;"),
  ":down:" => reinterpret(Int32,icxx"SDLK_DOWN;"),
  ":left:" => reinterpret(Int32,icxx"SDLK_LEFT;"),
  ":right:" => reinterpret(Int32,icxx"SDLK_RIGHT;"),
  ":escape:" => reinterpret(Int32,icxx"SDLK_ESCAPE;")
)

macro key_str(key)
  try
    str_to_code[key]
  catch
    error("Unknown key \"$key\".")
  end
end

endofpause(event::ExpEvent) = false
endofpause(event::EndPauseEvent) = true

iskeydown(event::ExpEvent) = false
iskeydown(event::KeyDownEvent) = true
iskeydown(keycode::Number) = e -> iskeydown(e,keycode::Number)
iskeydown(event::ExpEvent,keycode::Number) = false
iskeydown(event::KeyDownEvent,keycode::Number) = event.code == keycode

iskeyup(event::ExpEvent) = false
iskeyup(event::KeyUpEvent) = true
iskeyup(keycode::Number) = e -> iskeyup(e,keycode::Number)
iskeyup(event::ExpEvent,keycode::Number) = false
iskeyup(event::KeyUpEvent,keycode::Number) = event.code == keycode

isfocused(event::ExpEvent) = false
isfocused(event::WindowFocused) = true

isunfocused(event::ExpEvent) = false
isunfocused(event::WindowUnfocused) = true

# the C++ SDL_Event* is very verbose expressed in Cxx.jl so
# this macro makes the code to access fields of an SDL_event more
# readable
macro cxx_SDL_Event_str(str)
  event_type_str = "Cxx.CppPtr{Cxx.CxxQualType{Cxx.CppBaseType{:SDL_Event},(false,false,false)},(false,false,false)}"
  mstr = replace(str,"\$:(event)",
                 "\$:(event::"*event_type_str*")")
  :(@icxx_str($mstr))
end

function event_streamer(win)
  function helper(time::Float64)
    events = Signal(ExpEvent,EmptyEvent())
    event = icxx"new SDL_Event();"
    while @cxx(SDL_PollEvent(event)) != 0
      if cxx_SDL_Event"$:(event)->type == SDL_KEYDOWN;"
        code = reinterpret(Int32,cxx_SDL_Event"$:(event)->key.keysym.sym;")
        push!(events,KeyDownEvent(code,time))
      elseif cxx_SDL_Event"$:(event)->type == SDL_KEYUP;"
        code = reinterpret(Int32,cxx_SDL_Event"$:(event)->key.keysym.sym;")
        push!(events,KeyUpEvent(code,time))
      elseif cxx_SDL_Event"$:(event)->type == SDL_WINDOWEVENT;"
        if cxx_SDL_Event"$:(event)->window.event == SDL_WINDOWEVENT_FOCUS_GAINED;"
          push!(events,WindowFocused(time))
        elseif cxx_SDL_Event"$:(event)->window.event == SDL_WINDOWEVENT_FOCUS_LOST;"
          push!(events,WindowUnfocused(time))
        end
      end
    end
    events
  end
end

function findkwd(kwds,sym,default)
  for (k,v) in kwds
    if k == sym
      return v
    end
  end

  default
end


abstract TrialMoment

type ResponseMoment <: TrialMoment
  respond::Function
  timeout::Function
  timeout_delta_t::Float64
end

type TimedMoment <: TrialMoment
  delta_t::Float64
  run::Function
end

type MomentQueue
  data::Queue{TrialMoment}
  last::Float64
end

type ExperimentState
  trial::Int
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
  state::Reactive.Signal{Bool}
  file::String
  win::SDLWindow
  cleanup::Function
  exception::Nullable{Tuple{Exception,Array{Ptr{Void}}}}
  moment_resolution::Float64
  pause_state::Reactive.Signal{Bool}
  pause_events::Reactive.Signal{ExpEvent}
end

function record_helper(exp::ExperimentState,kwds,onlyifheader=false)
  columns = map(x -> x[1],kwds)

  if isempty(exp.header)
    if onlyifheader
      return
    end
    for column in columns
      push!(exp.header,column)
    end
    open(x -> println(x,join(columns,",")),exp.file,"a")
  elseif !isempty(columns) && !all(map(c -> c ∈ exp.header,columns))
    missing = filter(c -> c ∉ exp.header,columns)

    error("Unexpected columns $(join(missing,", "," and ")). "*
          "Make sure that the first call to record includes all "*
          "columns you plan to use.")
  end

  open(exp.file,"a") do stream
    @_ exp.header begin
      map(c -> findkwd(kwds,c,""),_)
      join(_,",")
      println(stream,_)
    end
  end
end

function record(exp::ExperimentState,code;kwds...)
  extra = [:psych_version => psych_version,
           :start_date => Dates.format(exp.start,"yyyy-mm-dd"),
           :start_time => Dates.format(exp.start,"HH:MM:SS"),
           :trial => exp.trial]
  record_helper(exp,tuple(extra...,exp.info...,:code => code,kwds...))
end


function record_ifheader(exp::ExperimentState,code;kwds...)
  extra = [:psych_version => psych_version,
           :start_date => Dates.format(exp.start,"yyyy-mm-dd"),
           :start_time => Dates.format(exp.start,"HH:MM:SS"),
           :trial => exp.trial]
  record_helper(exp,tuple(extra...,exp.info...,:code => code,kwds...),true)
end

function record(code;kwds...)
  record(get_experiment(),code;kwds...)
end

experiment_context = Nullable{ExperimentState}()
type Experiment
  runfn::Function
  state::ExperimentState

  function Experiment(fn::Function;debug=false,kwds...)
    global experiment_context

    exp = ExperimentState(debug;kwds...)

    clenup_run = Condition()
    function cleanup()
      push!(exp.running,false)
      push!(exp.started,false)
      close(exp.win)

      # gc is disabled during individual trials (and enabled at the end of
      # a trial). Make sure it really does return to an enabled state.
      gc_enable(true)

      # indicate that the expeirment is done running
      notify(clenup_run)
    end

    try
      # the first moment just waits a short time to ensure
      # notify(clean_run) runs after wait(cleanup_run)
      enqueue!(exp.moments.data,moment(0.1))
      exp.cleanup = cleanup

      # setup all trial moments for this experiment
      experiment_context = Nullable(exp)
      fn()
      experiment_context = Nullable{ExperimentState}()

      # the last moment run cleans up the experiment
      enqueue!(exp.moments.data,moment(t -> cleanup()))
    catch e
      close(exp.win)
      gc_enable(true)
      rethrow(e)
    end

    function runfn()
      global experiment_context
      experiment_context = Nullable(exp)
      exp.mode = Running
      push!(exp.started,true)
      push!(exp.running,true)

      try
        wait(clenup_run)
      catch
        close(exp.win)
        gc_enable(true)
        rethrow()
      end

      # if an exception occuring during the experiment, it is handled here
      if !isnull(exp.exception)
        record(exp,"program_error")
        println("Stacktrace in experiment: ")
        map(println,stacktrace(get(exp.exception)[2]))
        rethrow(get(exp.exception)[1])
      end

      experiment_context = Nullable{ExperimentState}()
    end

    new(runfn,exp)
  end
end

function run(exp::Experiment)
  exp.runfn()
  nothing
end

function get_experiment()
  if isnull(experiment_context)
    error("Unknown experiment context, call me inside run_experiment.")
  else
    get(experiment_context)
  end
end

function ExperimentState(debug::Bool;
                         moment_resolution = default_moment_resolution,
                         data_dir = "data",
                         input_resolution = default_input_resolution,
                         width=exp_width,height=exp_height,info...)
  mkpath(data_dir)
  exp_start = now()
  timestr = Dates.format(exp_start,"yyyy-mm-dd__HH_MM_SS")
  data_file = joinpath(data_dir,findkwd(info,:sid,"file")*"_"*timestr*".csv")

  win = window(width,height,fullscreen=!debug)

  running = Reactive.Signal(false)
  started = Reactive.Signal(false)

  timing = foldp(+,0.0,fpswhen(running,moment_resolution))
  pause_events = Reactive.Signal(ExpEvent,EmptyEvent())
  events = @_ fpswhen(started,input_resolution) begin
    sampleon(_,timing)
    map(event_streamer(win),_)
    flatten(_)
    merge(_,pause_events)
  end

  state = Reactive.Signal(Bool,false)

  exp = ExperimentState(0,exp_start,info,running,started,Array{Symbol}(0),events,
                        e -> nothing,Reactive.Signal(false),Running,
                        MomentQueue(Queue(TrialMoment),0),state,data_file,win,
                        () -> error("no cleanup function available!"),
                        Nullable{Tuple{Exception,Array{Ptr{Void}}}}(),
                        moment_resolution,Reactive.Signal(false),pause_events)

  exp.state = map(filterwhen(running,EmptyEvent(),merge(timing,events))) do x
    if !isnull(x)
      handle(exp,exp.moments,x)
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

function addtrial(watcher::Function,moments...)
  addtrial(watcher,get_experiment(),moments...)
end

function addtrial(moments...)
  addtrial(get_experiment(),moments...)
end

function addtrial(exp::ExperimentState,moments...)
  addtrial(e -> nothing,exp,moments...)
end

addmoment(exp::ExperimentState,m::TrialMoment) = enqueue!(exp.moments.data,m)
function addmoment(exp::ExperimentState,ms)
  try
    for m in ms
      # some types iterate over themselves (e.g. numbers);
      # check for this to avoid infinite recursion
      if m == ms
        error("Expected a value of type `TrialMoment` but got a value of type "*
              "$(typeof(ms)) instead.")
      end
      addmoment(exp,m)
    end
  catch e
    if isa(e,MethodException)
        error("Expected a value of type `TrialMoment` but got a value of type "*
              "$(typeof(ms)) instead.")
    end
    rethrow(e)
  end
end

function addtrial(watcher::Function,exp::ExperimentState,moments...)
  for t in concrete_events
    precompile(watcher,(t,))
  end

  start_trial = moment() do t
    # make sure the trial doesn't lag due to memory allocation
    gc_enable(false)
    exp.trial += 1
    exp.trial_watcher = watcher
    record("trial_start",time=t)
  end
  enqueue!(exp.moments.data,start_trial)

  foreach(m -> addmoment(exp,m),moments)
  enqueue!(exp.moments.data,moment(t -> gc_enable(true)))
end

function addbreak(watcher::Function,moments...)
  addbreak(watcher,get_experiment(),moments...)
end

function addbreak(moments...)
  addbreak(get_experiment(),moments...)
end

function addbreak(exp::ExperimentState,moments...)
  addbreak(e -> nothing,exp,moments...)
end

function addbreak(watcher::Function,exp::ExperimentState,moments...)
  for t in concrete_events
    precompile(watcher,(t,))
  end

  enqueue!(exp.moments.data,moment(t -> exp.trial_watcher = watcher))
  foreach(m -> addmoment(exp,m),moments)
end

function pause(exp,message,time)
  push!(exp.running,false)
  record_ifheader(exp,"paused",time=time)
  display(exp.win,render(message))
end

function unpause(exp,time)
  record_ifheader(exp,"unpaused",time=time)
  exp.mode = Running
  clear(exp.win)
  display(exp.win)
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
  elseif exp.mode == Running && isunfocused(e)
    pause(exp,"Waiting for window focus...",time(e))
    exp.mode = Unfocused
  elseif exp.mode == ToExit && iskeydown(e,key"y")
    record_ifheader(exp,"terminated")
    exp.cleanup()
  elseif exp.mode == ToExit && iskeydown(e,key"n")
    unpause(exp,time(e))
  elseif exp.mode == Unfocused && isfocused(e)
    pause(exp,"Paused. [To exit hit Y, to resume hit N]",time(e))
    exp.mode = ToExit
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

function response(fn::Function)
  for t in concrete_events
    precompile(fn,(t,))
  end

  ResponseMoment(fn,(t) -> nothing,0)
end

function timeout(fn::Function,isresponse::Function,timeout)
  precompile(fn,(Float64,))
  for t in concrete_events
    precompile(isresponse,(t,))
  end

  ResponseMoment(isresponse,fn,timeout)
end

function delta_t(moment::TimedMoment)
  moment.delta_t
end

function handle(exp::ExperimentState,moment::TimedMoment,time::Float64)
  try
    moment.run(time)
  catch e
    exp.exception = Nullable((e,catch_backtrace()))
    exp.mode = Error
    exp.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::TimedMoment,event::ExpEvent)
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

function handle(exp::ExperimentState,queue::MomentQueue,event::ExpEvent)
  if !isempty(queue.data)
    moment = front(queue.data)
    handled = handle(exp,moment,event)
    if handled
      dequeue!(queue.data)
    end
  end
  true
end

function handle(exp::ExperimentState,queue::MomentQueue,t::Float64)
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
        queue.last = run_time
      end
    end
  end
  true
end
