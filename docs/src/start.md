In the following example, we'll run through all the basics of how to create an
experiment in Weber. It's assumed you have already followed the [directions for
installing Julia and Juno](@ref install). First, open Atom.

You may want to familiarize yourself with the basics of Julia. There are a
useful resources
[here](http://docs.julialang.org/en/stable/manual/getting-started/#resources)
and [here](https://julialang.org/learning/) to learn Julia.

# Creating a simple project

First, open the Julia console, and enter the following lines of code.

```julia
using Weber
create_new_project("simple")
```

This will create a set of files in your current directory to get you started
creating your experiment project. Open the file called `run_simple.jl` in Atom.

Remove all text in run_simple.jl and replace it with the following.

```julia
using Weber
sid,skip = @read_args("A simple frequency discrimination experiment.")

const low = ramp(tone(1kHz,0.5s))
const high = ramp(tone(1.1kHz,0.5s))

function one_trial()
  if rand(Bool)
    stim1 = moment(0.5s,play,low)
	stim2 = moment(0.5s,play,high)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_first")
  else
	stim1 = moment(0.5s,play,high)
	stim2 = moment(0.5s,play,low)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_second")	
  end
  return [show_cross(),stim1,stim2,resp,await_response(iskeydown)]
end

exp = Experiment(columns = [:sid => sid,condition => "ConditionA",:correct],skip=skip)
setup(exp) do
  addbreak(instruct("Press 'q' when you hear the low tone first and 'p' otherwise."))
  for trial in 1:10
    addtrial(one_trial())
  end
end

run(exp)
```

# Running the program

Now, [open the julia console](@ref install), and enter the following:

```juila
include("run_simple.jl")
```

!!! note "Make sure you're in the correct directory"

    You may get an error that looks like "could not open file [file name here]".
    This probably means Julia's working directory is not set correctly. Open
    run_simple.jl in Atom, make sure you are focused on this file (by clicking
    inside the file), and then, in the menu, click "Julia" > "Working Directory" >
    "Current File's Folder". This will set Julia's working directory to
    run_simple.jl's directory.

!!! note "You can exit at any time"

    To prematurely end the experiment hit the escape key.

# Code Walk-through

After running the experiment on yourself, let's walk through the parts of this
experiment piece-by-piece.

## Read Experiment Parameters

```julia
using Weber
sid,skip = @read_args("A simple frequency discrimination experiment.")
```

The first line loads Weber. Then, when the script is run, the second line will read two important experimental parameters from the user: their subject ID, and an *offset*.

Don't worry about the offset right now. (If you wish to learn more you can read
about the [`Weber.offset`](@ref) function).

## Stimulus Generation

```julia
const low = ramp(tone(1kHz,0.5s))
const high = ramp(tone(1.1kHz,0.5s))
```

These next two lines create two stimuli. A 1000 Hz tone (`low`) and a 1100 Hz
tone (`high`) each 0.5 seconds long. The [`ramp`](@ref) function tapers the
start and end of a sound to avoid click sounds. In Weber you can affix Hz or kHz
to indicate a frequency and s or ms to indicate an amount of time (thanks to
[Unitful.jl](http://ajkeller34.github.io/Unitful.jl/stable/)).

You can generate many simple stimuli in Weber, or you can use `sound("sound.wav")`
to open a sound file on your computer. Refer the section on
[stimulus generation](stimulus.md) for more details.

## Creating a trial

```julia
function one_trial()
  if rand(Bool)
    stim1 = moment(0.5s,play,low)
	stim2 = moment(0.5s,play,high)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_first")
  else
	stim1 = moment(0.5s,play,high)
	stim2 = moment(0.5s,play,low)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_second")	
  end
  return [show_cross(),stim1,stim2,resp,await_response(iskeydown)]
end
```

These lines define a function that is used to create a single trial of the
experiment. To create a trial, a random boolean value (true or false) is
produced. When true, the low stimulus is presented first, when false, the high
stimulus is presented first. There are two basic components of trial creation:
trial moments and trial events.

### Trial Moments

Each trial is composed of a sequence of *moments*. Most moments just run a
short function at some well defined point in time. For example, during the
experiment, the moment `moment(0.5,play,low)` will call the function
[`play`](@ref) on the `low` stimulus, doing so 0.5 seconds after the onset of
the previous moment. All moments running at a specified time do so in reference
to the onset of the prior moment.

There are two other moments created in this function: [`show_cross`](@ref)--which simply
displays a "+" symbol in the middle of the screen--and
[`await_response`](@ref)--which is a moment that begins only once a key is
pressed, and then immediately ends.

Once all of the moments have been defined, they are returned in an array and
will be run in sequence during the experiment.

For more details on how to create trial moments you can refer to the
[`Trial Creation`](trial_guide.md) section of the user guide and the [`Trials`](trials.md)
section of the reference.

### Trial Events

The [`response`](@ref) function also creates a moment. It's purpose is to record
the keyboard presses to q or p. It works a little differently than other
moments. Rather than running once after a specified time, it runs anytime an
event occurs.

Events indicate that something has changed: e.g. a key has been pressed, a key
has been released, the experiment has been paused. Keyboard events signal a
particular code, referring to the key the experiment participant pressed. In the
code above `key"p"` and `key"q"` are used to indicate the 'q' and 'p' keys on
the keyboard. For details on how events work you can refer to the reference
section on [`Events`](event.md). The `response` moment listens for events with the
'p' or 'q' key codes, and records those events.

## Experiment Definition

```julia
exp = Experiment(columns = [:sid => sid,condition => "ConditionA",:correct],skip=skip) 
```

This line creates the actual experiment. It creates a datafile with an
appropriate name, and opens a window for the experiment to be displayed in.

The code `columns` creates a number of columns. Some of these columns have fixed
values, that are the same for each row of the data (e.g. `:sid => sid`) but one
of them, `:correct`, is different on each line. Note that in the call to `response` in
`one_trial`, the value of correct is set to the response listeners should have
pressed during a trial.

You can add as many columns as you want, either when you first create an
experiment, as above, or using [`addcolumn`](@ref). Trying to record values to a
column you haven't added results in an error.

## Experiment Setup

```julia
setup(exp) do
  addbreak(instruct("Press 'q' when you hear the low tone first and 'p' otherwise."))
  for trial in 1:10
    addtrial(one_trial())
  end
end
```

Once the experiment is defined, you can setup any trials and instructions that
you want the experiment to have. The above code adds a break providing
instructions for the listeners, and 10 trials, created using the `one_trial`
function we defined above. Please refer to the
[`Trial Creation`](trial_guide.md) section of the user guide for more details on
how to add trials.

### [Setup- vs. run-time](@id setup_time)

```julia
run(exp)
```

This final part of the code actually runs the experiment. Note that almost none of the
code in setup actually runs during the experiment. This is _important_! Weber is
designed to run as much code as possible before the experiment starts, during
setup. This is called setup-time. This ensures that code which
does run during the experiment, during run-time, can do so in a timely manner. The
only code that actually runs during the experiment is the behavior defined
within each moment (e.g. playing sounds, displaying text, etc...).

# Where to go from here

From here you can begin writing your own simple experiments. Take a look at some
of the example experiments under Weber's example directory to see what you can
do. You can find the location of this directory by typing
`Pkg.dir("Weber","examples")` in the julia console. To further your
understanding of the details of Weber, you can also read through the rest of the
user guide. Topics in the guide have been organized from simplest, and most
useful, to the more advanced, least-frequently-necessary features.
