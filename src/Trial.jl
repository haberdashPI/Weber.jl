# TODO: use the version indicated by Pkg
const psych_version = v"0.0.1"

using Reactive
using Lazy: @>>, @>, @_
using DataStructures
using SFML
import SFML: KeyCode
import Base: isnull, run

export Experiment, run, addtrial, moment, response, record,
  iskeydown, iskeyup, iskeypressed, isfocused, isunfocused, KeyCode,
  @key_str

const default_moment_resolution = 1000
const default_input_resolution = 60
const exp_width = 1024
const exp_height = 768
const exp_color_depth = 32

type WindowEvent
  data::Nullable{SFML.Event}
  time::Float64
end

WindowEvent() = WindowEvent(Nullable{SFML.Event}(),0)

isnull(event::WindowEvent) = isnull(event.data)

str_to_code = Dict(
  "a" => KeyCode.A,
  "b" => KeyCode.B,
  "c" => KeyCode.C,
  "d" => KeyCode.D,
  "e" => KeyCode.E,
  "f" => KeyCode.F,
  "g" => KeyCode.G,
  "h" => KeyCode.H,
  "i" => KeyCode.I,
  "j" => KeyCode.J,
  "k" => KeyCode.K,
  "l" => KeyCode.L,
  "m" => KeyCode.M,
  "n" => KeyCode.N,
  "o" => KeyCode.O,
  "p" => KeyCode.P,
  "q" => KeyCode.Q,
  "r" => KeyCode.R,
  "s" => KeyCode.S,
  "t" => KeyCode.T,
  "u" => KeyCode.U,
  "v" => KeyCode.V,
  "w" => KeyCode.W,
  "x" => KeyCode.X,
  "y" => KeyCode.Y,
  "z" => KeyCode.Z,
  "0" => KeyCode.NUM0,
  "1" => KeyCode.NUM1,
  "2" => KeyCode.NUM2,
  "3" => KeyCode.NUM3,
  "4" => KeyCode.NUM4,
  "5" => KeyCode.NUM5,
  "6" => KeyCode.NUM6,
  "7" => KeyCode.NUM7,
  "8" => KeyCode.NUM8,
  "9" => KeyCode.NUM9,
  " " => KeyCode.SPACE
)

macro key_str(key)
  try
    str_to_code[key]
  catch
    error("Unknown key \"$key\".")
  end
end

function iskeydown(event::WindowEvent)
  !isnull(event.data) && (get_type(get(event.data)) == EventType.KEY_PRESSED)
end

const iskeypressed = is_key_pressed

function iskeydown(event::WindowEvent,keycode)
  !isnull(event.data) &&
    get_type(get(event.data)) == EventType.KEY_PRESSED &&
    get_key(get(event.data)).key_code == keycode
end

function iskeyup(event::WindowEvent,keycode)
  !isnull(event.data) &&
    get_type(get(event.data)) == EventType.KEY_RELEASED &&
    get_key(get(event.data)).key_code == keycode
end

function iskeyup(event::WindowEvent)
  !isnull(event.data) && get_type(get(event.data)) == EventType.KEY_RELEASED
end

function isfocused(event::WindowEvent)
  !isnull(event.data) && get_type(get(event.data)) == EventType.GAINED_FOCUS
end

function isunfocused(event::WindowEvent)
  !isnull(event.data) && get_type(get(event.data)) == EventType.LOST_FOCUS
end

function event_streamer(window)
  function helper(time::Float64)
    events = Signal(WindowEvent())
    event = Event()
    while pollevent(window,event)
      push!(events,WindowEvent(event,time))
      event = Event()
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
  window::SFML.RenderWindow
  cleanup::Function
  exception::Nullable{Exception}
  moment_resolution::Float64
  pause_state::Reactive.Signal{Bool}
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

    error("""Unexpected columns $(join(missing,", "," and ")).
             Make sure that the first call to record includes all
             columns you plan to use.""")
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
      close(exp.window)
      experiment_context = Nullable{ExperimentState}()

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
      close(exp.window)
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
        close(exp.window)
        gc_enable(true)
        rethrow()
      end

      # if an exception occuring during the experiment, it is handled here
      if !isnull(exp.exception)
        record(exp,"program_error")
        rethrow(get(exp.exception))
      end
    end

    new(runfn,exp)
  end
end

function run(exp::Experiment)
  exp.runfn()
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
  data_file = joinpath(data_dir,findkwd(info,:sid,"file")*"_"*timestr)

  window = RenderWindow(VideoMode(width,height,exp_color_depth),
                        "Psychoacoustics",
                        (debug ? window_defaultstyle : window_fullscreen))
  set_keyrepeat_enabled(window,false)
  set_mousecursor_visible(window,false)

  running = Reactive.Signal(false)
  started = Reactive.Signal(false)

  timing = foldp(+,0.0,fpswhen(running,moment_resolution))
  events = @_ fpswhen(started,input_resolution) begin
    sampleon(_,timing)
    map(event_streamer(window),_)
    flatten(_)
  end

  state = Reactive.Signal(Bool,false)

  exp = ExperimentState(0,exp_start,info,running,started,Array{Symbol}(0),events,
                        e -> nothing,Reactive.Signal(false),Running,
                        MomentQueue(Queue(TrialMoment),0),state,data_file,window,
                        () -> error("no cleanup function available!"),
                        Nullable{Exception}(),
                        moment_resolution,Reactive.Signal(false))

  exp.state = map(filterwhen(running,WindowEvent(),merge(timing,events))) do x
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

  exp.watcher_state = map(filterwhen(running,WindowEvent(),events)) do e
    if !isnull(e)
      try
        exp.trial_watcher(e)
      catch e
        exp.exception = Nullable(e)
        exp.mode = Error
        exp.cleanup()
      end
    end
    false
  end

  exp
end

function addtrial(watcher::Function,moments::Vararg{TrialMoment})
  addtrial(watcher,get_experiment(),moments...)
end

function addtrial(moments::Vararg{TrialMoment})
  addtrial(get_experiment(),moments...)
end

function addtrial(exp::ExperimentState,moments::Vararg{TrialMoment})
  addtrial(e -> nothing,exp,moments...)
end

function addtrial(watcher::Function,exp::ExperimentState,moments::Vararg{TrialMoment})
  precompile(watcher,(WindowEvent,))

  start_trial = moment() do t
    # make sure the trial doesn't lag due to memory allocation
    gc_enable(false)
    exp.trial += 1
    exp.trial_watcher = watcher
  end

  end_trial = moment(t -> gc_enable(true))

  enqueue!(exp.moments.data,start_trial)
  for m in moments;enqueue!(exp.moments.data,m);end
  enqueue!(exp.moments.data,end_trial)
end

function pause(exp,message)
  push!(exp.running,false)
  pushview(exp.window)
  record_ifheader(exp,"paused")
  clear(exp.window,SFML.black)
  draw(exp.window,message)
  display(exp.window)
end

function unpause(exp)
  popview(exp.window)
  record_ifheader(exp,"unpaused")
  exp.mode = Running
  push!(exp.running,true)
end

const Running = 0
const ToExit = 1
const Unfocused = 2
const Error = 3

function watch_pauses(exp,e)
  if exp.mode == Running && iskeydown(e,KeyCode.ESCAPE)
    pause(exp,"Exit program? [hit Y or N]")
    exp.mode = ToExit
  elseif exp.mode == Running && isunfocused(e)
    pause(exp,"Waiting for window focus...")
    exp.mode = Unfocused
  elseif exp.mode == ToExit && iskeydown(e,key"y")
    record_ifheader(exp,"terminated")
    exp.cleanup()
  elseif exp.mode == ToExit && iskeydown(e,key"n")
    unpause(exp)
  elseif exp.mode == Unfocused && isfocused(e)
    popview(exp.window)
    record_ifheader(exp,"unpaused")
    exp.mode = Running
    push!(exp.running,true)
  end
end

function moment(delta_t::Float64)
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

function response(fn::Function;timeout = 0,timeout_callback = t->nothing)
  precompile(fn,(WindowEvent,))
  precompile(timeout_callback,(Float64,))
  ResponseMoment(fn,timeout_callback,timeout)
end

function delta_t(moment::TimedMoment)
  moment.delta_t
end

function handle(exp::ExperimentState,moment::TimedMoment,time::Float64)
  try
    moment.run(time)
  catch e
    exp.exception = Nullable(e)
    exp.mode = Error
    exp.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::TimedMoment,event::WindowEvent)
  false
end

function delta_t(moment::ResponseMoment)
  (moment.timeout_delta_t > 0 ? moment.timeout_delta_t : Inf)
end

function handle(exp::ExperimentState,moment::ResponseMoment,time::Float64)
  try
    moment.timeout(time)
  catch e
    exp.exception = Nullable(e)
    exp.mode = Error
    exp.cleanup()
  end
  true
end

function handle(exp::ExperimentState,moment::ResponseMoment,event::WindowEvent)
  handled = true
  try
    handled = moment.respond(event)
  catch e
    exp.exception = Nullable(e)
    exp.mode = Error
    exp.cleanup()
  end
  handled
end

function handle(exp::ExperimentState,queue::MomentQueue,event::WindowEvent)
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
      while event_time > offset + time(); end
      handled = handle(exp,moment,t)
      if handled
        dequeue!(queue.data)
        queue.last += delta_t(moment)
      end
    end
  end
  true
end
