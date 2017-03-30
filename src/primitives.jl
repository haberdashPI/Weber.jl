export instruct, response, addbreak_every, show_cross, @read_args, randomize_by
using ArgParse
using Juno: input, selector
import Juno

"""
    response(key1 => response1,key2 => response2,...;kwds...)

Create a watcher moment that records press of `key[n]` as
`record(response[n];kwds...)`.

See [`record`](@ref) for more details on how events are recorded.

When a key is pressed down, the record event occurs. Key releases are also
recorded, but are suffixed, by default, with "_up". This suffix can be changed
using the `keyup_suffix` keyword argument.
"""
function response(responses::Pair...;keyup_suffix="_up",info...)
  begin (event) ->
    for (key,response) in responses
      if iskeydown(event,key)
        record(response;info...)
      elseif iskeyup(event,key)
        record(response*keyup_suffix;info...)
      end
    end
  end
end

"""
    instruct(str;keys...)

Presents some instructions to the participant.

This adds "(Hit spacebar to continue...)" to the end of the text, and waits for
the participant to press spacebar to move on. It records an "instructions"
event to the data file.

Any keyword arguments are passed onto to `visual`, which can be used
to adjust how the instructions are displayed.
"""
function instruct(str;keys...)
  text = visual(str*" (Hit spacebar to continue...)";keys...)
  m = moment() do
    record("instructions")
    display(text)
  end
  [m,await_response(iskeydown(key":space:"))]
end

"""
    addbreak_every(n,total,
                   [response=key":space:"],[response_str="the spacebar"])

Adds a break every `n` times this event is added given a known number of
total such events.

By default this waits for the user to hit spacebar to move on.
"""
function addbreak_every(n,total,response=key":space:",
                        response_str="the spacebar")
  meta = Weber.metadata()
  index = meta[:break_every_index] = get(meta,:break_every_index,0) + 1
  if n <= index < total && (n == 1 || index % n == 1)
    message = moment() do
      display(visual("You can take a break. Hit "*
                     "$response_str when you're ready to resume... "*
                     "$(div(index,n)) of $(div(total-1,n)) breaks."))
    end

    addbreak(message,await_response(e -> iskeydown(e,response)))
  end
end

"""
    oddball_paradigm(trial_body_fn,n_oddballs,n_standards;
                     lead=20,no_oddball_repeats=true)

Helper to generate trials for an oddball paradigm.

The trial_body_fn should setup stimulus presentation: it takes one argument,
indicating if the stimulus should be a standard (false) or oddball (true)
stimulus.

It is usually best to use oddball_paradigm with a do block syntax. For instance,
the following code sets up 20 oddball and 150 standard trials.

    oddball_paradigm(20,150) do isoddball
      if isoddball
        addtrial(...create oddball trial here...)
      else
        addtrial(...create standard trial here...)
      end
    end

# Keyword arguments

* **lead**: determines the number of standards that repeat before any oddballs
  get presented
* **no_oddball_repeats**: determines if at least one standard must occur
  between each oddball (true) or not (false).
"""
function oddball_paradigm(fn,n_oddballs,n_standards;lead=20,no_oddball_repeats=true)
  oddballs_left = n_oddballs
  standards_left = n_standards
  oddball_n_stimuli = n_oddballs + n_standards
  last_stim_odd = false
  for trial in 1:oddball_n_stimuli
    stimuli_left = oddballs_left + standards_left
    oddball_chance = oddballs_left / (stimuli_left - n_oddballs)

    if (trial > lead &&
        (!last_stim_odd || no_oddball_repeats) &&
        rand() < oddball_chance)

      last_stim_odd = true
      oddballs_left -= 1
      fn(true)
    else
      last_stim_odd = false
      standards_left -= 1
      fn(false)
    end
  end
end

"""
    show_cross([delta_t])

Creates a moment that shows a cross hair `delta_t` seconds after the start
of the previous moment (defaults to 0 seconds).
"""
function show_cross(delta_t::Number=0;render_options...)
  moment(delta_t,display,"+";render_options...)
end

function as_arg(expr)
  if isa(expr,Symbol) || expr.head != :kw
    error("Expected keyword parameters specifying additional program arguments.")
  end

  if isa(expr.args[2],Symbol)
    quote
      $(string(expr.args[1]))
      $(esc(:required)) = true
      $(esc(:arg_type)) = $(expr.args[2])
    end
  elseif expr.args[2].head == :vect
    quote
      $(string(expr.args[1]))
      $(esc(:required)) = true
      $(esc(:arg_type)) = String
      $(esc(:help)) = $(join(map(x -> x.args[1],expr.args[2].args),", "," or "))
    end
  else
    error("Expected keyword value to be a vector of symbols or a type.")
  end
end

function as_arg_checker(expr)
  if !isa(expr.args[2],Symbol) && expr.args[2].head == :vect
    quote
      let str = $(string(expr.args[1])), vals = $(expr.args[2])
        if !any(s -> string(s) == parsed[str],vals)
          println("Expected \"$str\" argument to be "*join(vals,", "," or ")*".")
          println(usage_string(s))
          exit()
        end
      end
    end
  else
    :nothing
  end
end

function as_arg_result(expr)
  if !isa(expr.args[2],Symbol) && expr.args[2].head == :vect
    :(Symbol(parsed[$(string(expr.args[1]))]))
  else
    :(parsed[$(string(expr.args[1]))])
  end
end

"""
    randomize_by(itr)

Randomize by a given iterable object, usually a string (e.g. the subject id.)

If the same iterable is given, calls to random functions (e.g. `rand`, `randn`
and `shuffle`) will result in the same output.
"""
randomize_by(itr) = srand(reinterpret(UInt32,collect(itr)))

"""
    @read_args(description,[keyword args...])

Reads experimental parameters from the user.

With no additional keyword arguments this requests the subject id, and an
optional `skip` parameter (defaults to 0) from the user, and then returns them
both in a tuple. The skip can be used to restart an experiment by passing it as
the `skip` keyword argument to the `Experiment` constructor.

You can specify additional keyword arguments to request additional
values from the user. Arguments that are a type will yield a request for
textual input, and will verify that that input can be parsed as the given type.
Arguments whose values are a list of symbols yield a request that the user select
one of the specified values.

Arguments are requested from the user either as command-line arguments,
or, if no command-line arguments were specified, interactively. Interactive
arguments work both in the terminal or in Juno. This macro also
generates useful help text that will be displayed to the user
when they give a single command-line "-h" argument. This help text
will print out the `desecription` string.

# Example

    subject_id,skip,condition,block = @read_args("A simple experiment",
      condition=[:red,:green,:blue],block=Int)
"""
macro read_args(description,keys...)
  arg_expr = quote
    "sid"
    $(esc(:help)) = "The subject id."
    $(esc(:required)) = true
    $(esc(:arg_type)) = String
  end

  for arg_body in map(as_arg,keys)
    for line in arg_body.args
      push!(arg_expr.args,line)
    end
  end

  skip_expr = quote
    "skip"
    $(esc(:help)) = "# of offsets to skip. Useful for restarting in middle of experiment."
    $(esc(:required)) = false
    $(esc(:arg_type)) = Int
    $(esc(:default)) = 0
  end
  arg_expr.args = vcat(arg_expr.args,skip_expr.args)

  arg_body = quote
    s = ArgParseSettings(description = $(esc(description)))

    @add_arg_table s begin
      $arg_expr
    end

    parsed = parse_args(ARGS,s)
  end


  for line in map(as_arg_checker,keys)
    push!(arg_body.args,line)
  end

  result_tuple = :((parsed["sid"],parsed["skip"]))
  for result = map(as_arg_result,keys)
    push!(result_tuple.args,result)
  end
  push!(arg_body.args,result_tuple)

  script_file = gensym(:script_file)
  collect_args = :(collect_args($(esc(description))))
  for k in keys
    push!(collect_args.args,k)
  end
  push!(collect_args.args,script_file)

  quote
    cd(dirname(@__FILE__))
    if length(ARGS) > 0
      $arg_body
    else
      $script_file = @__FILE__
      $collect_args
    end
  end
end

function collect_args(description,script_file;keys...)
  if Juno.isactive()
    info("Please type your responses directly below the prompt."*
         "Entering them further down (next to the '>') will not work.")
  end

  print("Enter subject id: ")
  sid = chomp(input())
  args = Array{Any}(length(keys))
  for (i,(kw,value)) in enumerate(keys)
    if isa(value,Type)
      except = true
      while except
        try
          print("Enter $kw: ")
          args[i] = parse(value,chomp(input()))
          except = false
        catch
          except = true
          println("Expected $value.")
        end
      end
    else
      error = true
      while error
        print("Enter $kw ($(join(map(string,value),", "," or "))): ")
        args[i] = chomp(input())
        if Symbol(args[i]) ∉ value
          println("Expected $kw to be $(join(map(string,value),", "," or ")) "*
                  "but got $(args[i]).")
          error = true
        else
          error = false
        end
      end
    end
  end
  print("Offset to start at? (default = 0): ")
  str = input()
  if isempty(chomp(str))
    skip = 0
  else
    skip = parse(Int,str)
  end

  if Juno.isactive()
    info("Spawning experiment in new child process...")
    info("If you need to debug your experiment, don't call @read_args."*
         " Set your experiment parameters manually inside your script "*
         " add `cd(dirname(@__FILE__))` to a new line, and then run the script.")
    timestr = Dates.format(now(),"yyyy-mm-dd__HH_MM_SS")
    logfile = "weber_$timestr.log"
    child = spawn(pipeline(`$(joinpath(JULIA_HOME,"julia")) $script_file $sid $args $skip`,
                           stdout=logfile,stderr=logfile))
    info("Experiment log will be written to $logfile. The experiment should begin shortly...")
    wait(child)
    info("Experiment complete. Terminating julia, so the next run of an "*
         "expeirment runs cleanly.")
    exit()
  else
    info("Running...")
    (sid,skip,args...)
  end
end
