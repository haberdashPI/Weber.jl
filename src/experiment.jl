import Base: run
export Experiment, setup, run
import Juno

const default_moment_resolution = 0.0015
const default_input_resolution = 1/60
const exp_width = 1024
const exp_height = 768

const experiment_context = Array{Nullable{Experiment}}()
experiment_context[] = Nullable()

# internal function, usd to find the current experiment
function get_experiment()
  if isnull(experiment_context[])
    error("Unknown experiment context, call me inside `setup` or during an"*
          " experiment.")
  else
    get(experiment_context[])
  end
end

# internal function used to determine if there is an experiment running
function in_experiment()
  !isnull(experiment_context[])
end

function experiment_running()
  !isnull(experiment_context[]) && get(experiment_context[]).flags.processing
end

"""
    Weber.trial()

Returns the current trial of the experiment.
"""
trial(exp) = exp.data.trial
trial() = trial(get_experiment())


"""
    Weber.offset()

Returns the current offset. The offset represents a well defined time in the
experiment. Rerunning the experiemnt and skipping to a given offset will restart
the experiment in exactly the same state it was on a previous run.

!!! warning

    For offsets to be well defined, all calls to `moments` and `@addtrials` must
    following the guidlines specified in their respective documentation. In
    particular moments should not rely on state that changes during the
    experiment unless they are wrapped in an @addtrials macro.

"""
offset(exp) = exp.data.offset
offset() = offset(get_experiment())

"""
    Weber.tick()

With microsecond precision, this returns the number of elapsed seconds from the
start of the experiment to the start of the most recent moment.

If there is no experiment running, this returns the time since epoch with
microsecond precision.
"""
tick(exp) = exp.data.last_time
function tick()
  if isnull(experiment_context[])
    precise_time()
  else
    tick(get(experiment_context[]))
  end
end

"""
   Weber.metadata() = Dict{Symbol,Any}()

Returns metadata for this experiment. You can store
global state, specific to this experiment, in this dictionary.
"""
metadata(exp) = exp.info.meta
metadata() = metadata(get_experiment())


"""
   Experiment([skip=0],[columns=[symbols...]],[debug=false],
              [moment_resolution=0.0015],[input_resolution=1/60],[data_dir="data"],
              [width=1024],[height=768],kwds...)

Prepares a new experiment to be run.

# Keyword Arguments
* skip: the number of offsets to skip. Allows restarting of an experiment
  somewhere in the middle.
* columns: the names (as symbols) of columns that will be recorded during
  the experiment (using `record`). The column `:value` is always included here,
  even if not specified, since there are number of events recorded automatically
  which make use of this column.
* debug: if true experiment will show in a windowed view
* moment_resolution: the desired precision (in seconds) that moments
  should be presented at. Warnings will be printed for moments that
  lack this precision.
* input_resolution: the precision (in seconds) that input events should
  be queried. This almost never needs to be changed. Keyboards do not provide
  precise timing, and the timing of response pads is queried independently
  from input_resolution by using `response_time`.
* data_dir: the directory where data files should be stored (can be set to
  nothing to prevent a file from being created)
* width and height: specified the screen resolution during the experiment

Additional keyword arguments can be specified to store extra information to the
recorded data file, e.g. the experimental condition or the version of the
experiment being run.
"""
function Experiment(;skip=0,columns=Symbol[],debug=false,
                    moment_resolution = default_moment_resolution,
                    data_dir = "data",
                    null_window = false,
                    hide_output = false,
                    input_resolution = default_input_resolution,
                    width=exp_width,height=exp_height,info_values...)
  if !(data_dir == nothing || hide_output)
    mkpath(data_dir)
  elseif !hide_output
    warn(cleanstr("No directory specified for saving data. ALL DATA FROM THIS",
                  " EXPERIMENT WILL BE LOST!!! Refer to the documentation for",
                  "`Experiment`."))
  end

  if moment_resolution < approx_timer_resolution
    warn(cleanstr("The desired timing resolution of $moment_resolution ",
                  "seconds is probably not achievable on your system. The ",
                  "approximate minimum is $approx_timer_resolution seconds.",
                  " Try changing the moment_resolution to a higher value (see ",
                  "documentation for `Experiment`)."))
  end

  if :value ∉ columns
    push!(columns,:value)
  end

  meta = Dict{Symbol,Any}()
  start_time = precise_time()
  start_date = now()
  timestr = Dates.format(start_date,"yyyy-mm-dd__HH_MM_SS")
  info_str = join(map(x -> x[2],info_values),"_")
  filename = (data_dir == nothing || hide_output ? Nullable() :
              Nullable(joinpath(data_dir,info_str*"_"*timestr*".csv")))
  einfo = ExperimentInfo(info_values,meta,input_resolution,
                         moment_resolution,start_date,columns,filename,
                         hide_output)

  offset = 0
  trial = 0
  trial_watcher = (e) -> nothing
  last_time = 0.0
  next_moment = 0.0
  pause_mode = Running
  moments = [MomentQueue(Deque{Moment}(),0.0)]
  cleanup = () -> error("no cleanup function available!")
  last_good_delta = -1.0
  last_bad_delta = -1.0
  data = ExperimentData(offset,trial,skip,last_time,next_moment,trial_watcher,
                        pause_mode,moments,cleanup,last_good_delta,
                        last_bad_delta)

  running = processing = false
  flags = ExperimentFlags(running,processing)

  win = window(width,height,fullscreen=!debug,accel=!debug,null=null_window)

  Experiment(einfo,data,flags,win)
end


"""
    setup(fn,experiment)

Setup the experiment, adding breaks, practice, and trials.

Setup creats the context necessary to generate elements of an experiment. All
calls to `addtrial`, `addbreak` and `addpractice` must be called in side of
`fn`. This function must be called before `run`.
"""
function setup(fn::Function,exp::Experiment)
  # create data file header
  record_header(exp)
  function cleanup()
    exp.flags.running = false
    exp.flags.processing = false
    close(exp.win)

    # OBSOLETE: gc is disabled during individual trials (and enabled at the end of
    # a trial). Make sure it really does return to an enabled state.
    # gc_enable(true)
  end

  try
    # the first moment just waits a short time to ensure
    # notify(clean_run) runs after wait(cleanup_run)
    exp.data.cleanup = cleanup

    # setup all trial moments for this experiment
    experiment_context[] = Nullable(exp)
    fn()
    experiment_context[] = Nullable{Experiment}()

    # the last moment run cleans up the experiment
    enqueue!(first(exp.data.moments),final_moment(() -> cleanup()))
  catch e
    close(exp.win)
    # gc_enable(true)
    rethrow(e)
  end
end

warmup_run(exp::Experiment{NullWindow}) = nothing
function warmup_run(exp::Experiment)
  # warm up JIT compilation
  warm_up = Experiment(null_window=true,hide_output=true)
  setup(warm_up) do
    addtrial(moment(record,"a"),
             moment(record,"b") >>
             moment(record,"d"),
             moment(record,"c"))
    @addtrials let i = 0
      @addtrials while i < 3
        addtrial(moment(() -> i+=1),
                 moment(record,"a"),
                 moment(record,"b"),
                 moment(record,"c"))
      end
    end
  end
  run(warm_up,await_input=false)
end


function pause(exp,message,time,firstpause=true)
  exp.flags.running = false
  record(exp,"paused")
  if firstpause
    save_display(exp.win)
    pause_sounds()
  end
  overlay = visual(colorant"gray",priority=Inf) + visual(message,priority=Inf)
  display(exp.win,overlay)
end

function unpause(exp,time)
  record(exp,"unpaused")
  exp.data.pause_mode = Running

  restore_display(exp.win)
  resume_sounds()

  exp.data.last_bad_delta = -1.0
  exp.data.last_good_delta = -1.0
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

process_event(exp::Experiment,event::QuitEvent) = exp.data.cleanup()
function process_event(exp::Experiment,event)
  if exp.flags.running
    exp.data.trial_watcher(event)
    process(exp,exp.data.moments,event)
  end
  if exp.flags.processing
    watch_pauses(exp,event)
  end
end

# const last_delta_resolution = 1
# function report_deltas(exp::Experiment)
#   if !exp.info.hide_output
#     if exp.data.last_bad_delta > 0
#       err_str = roundstr(exp.data.last_bad_delta)
#       warn(cleanstr("""

# The latency of trial moments is at undesirable levels ($err_str
# seconds). This normally occurs when the experiment first starts up, but if
# unacceptable levels continue throughout the experiment, consider closing some
# programs on your computer or running this program on a faster machine. Poor
# latency will also occur when you pause the experiment, because moments will not
# occur during a pause.

#            """))
#       record(exp,"bad_delta_latency($err_str)")
#     end

#     if exp.data.last_good_delta > 0
#       err_str = roundstr(exp.data.last_good_delta)
#       exp.data.last_good_delta = -1.0
#       info(cleanstr("""

# The latency of trial moments has fallen to an acceptable level ($err_str
# seconds). It may fall further, but unless it exceedes a tolerable level, you
# will not be notified. Note that this measure of latency only verifies that the
# commands to generate stimuli occur when they should. Emprical verification of
# stimulus timing requires that you monitor the output of your machine using light
# sensors and microphones. You can use the scripts available in
# $(Pkg.dir("Weber","test")) to test the timing of auditory and visual
# stimuli presented with Weber.

#            """))
#       record(exp,"good_delta_latency($err_str)")
#     end
#   end
# end

const sleep_resolution = 0.05
const sleep_amount = 0.002

const gc_time = 1

"""
    run(experiment;await_input=true)

Runs an experiment. You must call `setup` first.

By default this function waits for user input before returning.
This prevents a console from closing at the end of an experiment,
preventing the user from viewing important messages. The exception
is if run is called form within Juno: await_input should
never be set to true in this case.
"""
function run(exp::Experiment;await_input=!Juno.isactive())
  if Juno.isactive() && await_input
    error("`await_input` must be false when Juno is active.")
  end

  warmup_run(exp)
  # println("========================================")
  # println("Completed warmup run.")
  try
    focus(exp.win)

    experiment_context[] = Nullable(exp)
    exp.data.pause_mode = Running
    exp.flags.processing = true
    exp.flags.running = true

    start = precise_time()
    tick = exp.data.last_time = last_input = last_delta = 0.0
    while exp.flags.processing
      tick = exp.data.last_time = precise_time() - start

      # notify all moments about the new time
      if exp.flags.running
        process(exp,exp.data.moments,tick)
      end

      # handle all input events (handles pauses, and notifys moments of events)
      if tick - last_input > exp.info.input_resolution
        check_events(process_event,exp,tick)
        last_input = tick
      end

      # # report on any irregularity in the timing of moments
      # if exp.flags.running && tick - last_delta > last_delta_resolution
      #   report_deltas(exp)
      #   last_delta = tick
      # end

      # refresh screen
      refresh_display(exp.win)

      # if after all this processing there's still plenty of time left
      # then sleep for a little while. (pausing also sleeps the loop)
      new_tick = precise_time() - start
      if !exp.flags.running
        gc()
        sleep(sleep_amount)
      elseif ((new_tick - last_delta) > sleep_resolution &&
              (new_tick - last_input) > sleep_resolution &&
              (exp.data.next_moment - new_tick) > sleep_resolution)
        if (exp.data.next_moment - new_tick) > gc_time
          gc()
        end
        sleep(sleep_amount)
      end
    end
  catch e
    if await_input
      show(e)
      Base.show_backtrace(STDOUT,catch_backtrace())
    else
      rethrow(e)
    end
  finally
    experiment_context[] = Nullable()
    close(exp.win)
    # gc_enable(true)
    if !exp.info.hide_output
      info("Experiment terminated at offset $(exp.data.offset).")
      if !isnull(exp.info.file)
        info("Data recorded to: $(get(exp.info.file))")
      end
    end
  end
  if await_input
    println("Hit enter to end experiment.")
    readline(STDIN)
  end
  nothing
end

function process(exp::Experiment,queues::Array{MomentQueue},x)
  filter!(queues) do queue
    !isempty(process(exp,queue,x).data)
  end
end


function skip_offsets(exp,queue)
  while !isempty(queue) && is_moment_skipped(exp,front(queue))
    dequeue!(queue)
  end
end

function process(exp::Experiment,queue::MomentQueue,event::ExpEvent)
  skip_offsets(exp,queue)

  if !isempty(queue)
    moment = front(queue)
    handled = handle(exp,queue,moment,event)
    if handled
      if !isempty(queue)
        prepare!(front(queue))
      end
      exp.data.next_moment = minimum(map(next_moment_time,exp.data.moments))
    end
  end

  queue
end

roundstr(x,n=6) = x > 10.0^-n ? string(round(x,n)) : "≤1e-$n"
function process(exp::Experiment,queue::MomentQueue,t::Float64)
  skip_offsets(exp,queue)

  if !isempty(queue)
    start_time = precise_time()
    moment = front(queue)
    event_time = delta_t(moment) + queue.last
    if event_time - t <= exp.info.moment_resolution
      offset = t - start_time
      run_time = offset + precise_time()
      while event_time > run_time
        run_time = offset + precise_time()
      end
      exp.data.last_time = run_time
      last = queue.last
      if handle(exp,queue,moment,run_time)
        d = required_delta_t(moment)
        if !isempty(queue)
          prepare!(front(queue))
        end

        latency = run_time - event_time

        if (0.0 < d < Inf && latency > exp.info.moment_resolution &&
            !exp.info.hide_output)
          warn(cleanstr(
            "Delivered moment with a high latency ($(roundstr(latency))
             seconds). This often happens at the start of an experiment, but
             should rarely, if ever, occur throughout the experiment. To reduce
             latency, reduce the amount of slow code in moments, close programs,
             or run on a faster machine. Or, if this amount of latency is
             acceptable, you should increase `moment_resolution` when you call
             `Experiment`."))
          record("high_latency",value=latency)
        end

        exp.data.next_moment = minimum(map(next_moment_time,exp.data.moments))
      end
    end
  end

  queue
end
