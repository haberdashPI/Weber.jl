import Base: run
export Experiment, setup, run, addcolumn

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
  !isnull(experiment_context[]) && flags(get(experiment_context[])).processing
end

"""
    Weber.trial()

Returns the current trial of the experiment.
"""
trial(exp) = data(exp).trial
trial() = trial(get_experiment())


"""
    Weber.offset()

Returns the current offset. The offset represents a well defined time in the
experiment. Rerunning the experiemnt and skipping to a given offset will restart
the experiment in exactly the same state it was on a previous run. The offset
is typically incremented once for every call to [`addpractice`](@ref) and
[`addtrial`](@ref) unless you use [`@addtrials`](@ref).

!!! warning

    For offsets to be well defined, all calls to [`moment`](@ref) and
    [`@addtrials`](@ref) must follow the guidlines in the user guide. In
    particular, moments should not rely on state that changes during the
    experiment unless they are wrapped in an @addtrials macro.

"""
offset(exp) = data(exp).offset
offset() = offset(get_experiment())

"""
    Weber.tick()

With microsecond precision, this returns the number of elapsed seconds from the
start of the experiment to the start of the most recent moment.

If there is no experiment running, this returns the time since epoch with
microsecond precision.
"""
tick(exp) = data(exp).last_time
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
metadata(exp) = info(exp).meta
metadata() = metadata(get_experiment())

"""
    addcolumn(column::Symbol)

Adds a column to be recorded in the data file.

This function must be called during setup.  It cannot be called once the
experiment has begun. Repeatedly adding the same column only adds the column
once. After adding a column you can include that column as a keyword argument
to [`record`](@ref). You need not write to the column for every record.
If left out, the column will be empty in the resulting row of the data file.
"""
function addcolumn{T <: BaseExperiment}(exp::T,col::Symbol)
  if flags(exp).processing
    error("You cannot change the data file header once the experiment starts! ",
          "Make sure you call `addcolumn` during setup-time, not run-time.")
  end
  if col ∉ info(exp).header
    push!(info(exp).header,col)
  end
end
function addcolumn(exp::ExtendedExperiment,col::Symbol)
  addcolumn(next(exp),col)
end
addcolumn(col::Symbol) = addcolumn(get_experiment(),col)

"""
    Experiment([skip=0],[columns=[symbols...]],[debug=false],
               [moment_resolution=0.0015],[input_resolution=1/60],[data_dir="data"],
               [width=1024],[height=768],[extensions=[]])

Prepares a new experiment to be run.

# Keyword Arguments
* **skip**: the number of offsets to skip. Allows restarting of an experiment
  somewhere in the middle. When an experiment is terminated, the most
  recent offset is reported. The offset is also recorded in each row
  of the resulting data file (also reported on exit).
* **columns****: the** names (as symbols) of columns that will be recorded during the
  experiment (using `record`). These can be set to fixed values (using :name =>
  value), or be filled in during a call to record (:name). The column `:value`
  is always included here, even if not specified, since there are number of
  events recorded automatically which make use of this column.
* **debug**: if true, experiment will show in a windowed view
* **moment_resolution**: the desired precision (in seconds) that moments
  should be presented at. Warnings will be printed for moments that
  lack this precision.
* **input_resolution**: the** precision (in seconds) that input events should
  be queried at. This almost never needs to be changed. Keyboards do not provide
  precise timing, and the timing of response pads is queried independently
  from input_resolution, using `response_time`.
* **data_dir**: the** directory where data files should be stored (can be set to
  nothing to prevent a file from being created)
* **width** and **height**: specified** the screen resolution during the experiment
* **extensions**: an array of Weber.Extension objects, which extend the
  behavior of an experiment.

"""
function Experiment(;skip=0,columns=Symbol[],debug=false,
                    moment_resolution = default_moment_resolution,
                    data_dir = "data",
                    null_window = false,
                    hide_output = false,
                    input_resolution = default_input_resolution,
                    extensions = Extension[],
                    width=exp_width,height=exp_height)
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
  info_values = filter(x -> isa(x,Pair),columns)
  reserved_columns = filter(x -> !isa(x,Pair),columns)
  info_str = join(map(x -> x[2],info_values),"_")
  filename = (data_dir == nothing || hide_output ? Nullable() :
              Nullable(joinpath(data_dir,info_str*"_"*timestr*".csv")))
  einfo = ExperimentInfo(info_values,meta,input_resolution,moment_resolution,
                         start_date,reserved_columns,filename,hide_output)

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

  extend(UnextendedExperiment(einfo,data,flags,win),extensions)
end


"""
    setup(fn,experiment)

Setup the experiment, adding breaks, practice, and trials.

Setup creates the context necessary to generate elements of an experiment. All
calls to `addtrial`, `addbreak` and `addpractice` must be called inside of
`fn`. This function must be called before `run`.
"""
setup(fn::Function,exp::ExtendedExperiment) = setup(fn,next(exp))
function setup{T <: BaseExperiment}(fn::Function,exp::T)
  # create data file header
  function cleanup()
    flags(exp).running = false
    flags(exp).processing = false
    close(win(exp))

    # OBSOLETE: gc is disabled during individual trials (and enabled at the end of
    # a trial). Make sure it really does return to an enabled state.
    # gc_enable(true)
  end

  try
    # the first moment just waits a short time to ensure
    # notify(clean_run) runs after wait(cleanup_run)
    data(exp).cleanup = cleanup

    # setup all trial moments for this experiment
    experiment_context[] = Nullable(top(exp))
    fn()
    experiment_context[] = Nullable{Experiment}()

    # the last moment run cleans up the experiment
    enqueue!(first(data(exp).moments),final_moment(() -> cleanup()))
  catch e
    close(win(exp))
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
  flags(exp).running = false
  record(top(exp),"paused")
  if firstpause
    save_display(win(exp))
    pause_sounds()
  end
  overlay = visual(colorant"gray",priority=Inf) + visual(message,priority=Inf)
  display(win(exp),overlay)
end

function unpause(exp,time)
  record(top(exp),"unpaused")
  data(exp).pause_mode = Running

  restore_display(win(exp))
  resume_sounds()

  data(exp).last_bad_delta = -1.0
  data(exp).last_good_delta = -1.0
  flags(exp).running = true
  process_event(exp,EndPauseEvent(time))
end

const Running = 0
const ToExit = 1
const Unfocused = 2
const Error = 3

function watch_pauses(exp,e)
  if data(exp).pause_mode == Running && iskeydown(e,key":escape:")
    pause(exp,"Exit? [Y for yes, or N for no]",time(e))
    data(exp).pause_mode = ToExit
  elseif data(exp).pause_mode == Running && isunfocused(e) && flags(exp).processing
    pause(exp,"Waiting for window focus...",time(e))
    data(exp).pause_mode = Unfocused
  elseif data(exp).pause_mode == ToExit && iskeydown(e,key"y")
    record(top(exp),"terminated")
    data(exp).cleanup()
  elseif data(exp).pause_mode == ToExit && iskeydown(e,key"n")
    unpause(exp,time(e))
  elseif data(exp).pause_mode == Unfocused && isfocused(e)
    if flags(exp).processing
      pause(exp,"Paused. [To exit hit Y, to resume hit N]",time(e),false)
      data(exp).pause_mode = ToExit
    else
      data(exp).pause_mode = Running
      flags(exp).running = true
    end
  end
end

process_event(exp::Experiment,event::QuitEvent) = data(exp).cleanup()
function process_event(exp::Experiment,event)
  if flags(exp).running
    data(exp).trial_watcher(event)
    process(exp,data(exp).moments,event)
  end
  if flags(exp).processing
    watch_pauses(exp,event)
  end
end

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
run(exp::ExtendedExperiment;keys...) = run(next(exp);keys...)
function run{T <: BaseExperiment}(exp::T;await_input=!Juno.isactive())
  if Juno.isactive()
    if await_input
      error("`await_input` must be false when Juno is active.")
    else
      warn("""
        Running Weber experiment directly in Juno. Consider using @read_args.
        When runing directly in Juno, the experiment may not respond to input
        correctly.  To solve this problem on Windows, once the experiment
        begins, hit alt-tab to switch away from the expeirment, and then hit
        alt-tab again to switch back to the experiment. On Mac you can use
        command-tab to do the same thing.
      """)
    end
  end

  warmup_run(exp)
  # println("========================================")
  # println("Completed warmup run.")
  try
    record_header(exp)
    focus(win(exp))

    experiment_context[] = Nullable(top(exp))
    data(exp).pause_mode = Running
    flags(exp).processing = true
    flags(exp).running = true

    start = precise_time()
    tick = data(exp).last_time = last_input = last_delta = 0.0
    while flags(exp).processing
      tick = data(exp).last_time = precise_time() - start

      # notify all moments about the new time
      if flags(exp).running
        process(exp,data(exp).moments,tick)
      end

      # handle all input events (handles pauses, and notifys moments of events)
      if tick - last_input > info(exp).input_resolution
        poll_events(process_event,top(exp),tick)
        last_input = tick
      end

      # # report on any irregularity in the timing of moments
      # if flags(exp).running && tick - last_delta > last_delta_resolution
      #   report_deltas(exp)
      #   last_delta = tick
      # end

      # refresh screen
      refresh_display(win(exp))

      # if after all this processing there's still plenty of time left
      # then sleep for a little while. (pausing also sleeps the loop)
      new_tick = precise_time() - start
      if !flags(exp).running
        gc()
        sleep(sleep_amount)
      elseif ((new_tick - last_delta) > sleep_resolution &&
              (new_tick - last_input) > sleep_resolution &&
              (data(exp).next_moment - new_tick) > sleep_resolution)
        if (data(exp).next_moment - new_tick) > gc_time
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
    close(win(exp))
    # gc_enable(true)
    if !info(exp).hide_output
      info("Experiment terminated at offset $(data(exp).offset).")
      if !isnull(info(exp).file)
        info("Data recorded to: $(get(info(exp).file))")
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
        prepare!(front(queue),time(event))
      end
      data(exp).next_moment = minimum(map(next_moment_time,data(exp).moments))
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
    if event_time - t <= info(exp).moment_resolution
      offset = t - start_time
      run_time = offset + precise_time()
      while event_time > run_time
        run_time = offset + precise_time()
      end
      data(exp).last_time = run_time
      last = queue.last
      if handle(exp,queue,moment,run_time)
        d = required_delta_t(moment)
        if !isempty(queue)
          prepare!(front(queue),run_time)
        end

        latency = run_time - event_time

        if (0.0 < d < Inf && latency > info(exp).moment_resolution &&
            !info(exp).hide_output)
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

        data(exp).next_moment = minimum(map(next_moment_time,data(exp).moments))
      end
    end
  end

  queue
end
