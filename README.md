# Weber

[![Build status](https://ci.appveyor.com/api/projects/status/uvxq5mqlq0p2ap02/branch/master?svg=true)](https://ci.appveyor.com/project/haberdashPI/weber-jl/branch/master)
[![TravisCI Status](https://travis-ci.org/haberdashPI/Weber.jl.svg?branch=master)](https://travis-ci.org/haberdashPI/Weber.jl)

<!-- [![Coverage Status](https://coveralls.io/repos/haberdashPI/Weber.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/haberdashPI/Weber.jl?branch=master) -->

<!-- [![codecov.io](http://codecov.io/github/haberdashPI/Weber.jl/coverage.svg?branch=master)](http://codecov.io/github/haberdashPI/Weber.jl?branch=master) -->

# About

Weber is a Julia package that can be used to generate simple psychology experiments that present visual and auditory stimuli at precise times. Julia is a recent programming language designed specifically for technical computing.

Weber's intended audience is graduate students in psychology and neuroscience, so it has been built with the assumption that its users have only minimal programming experience. The hope is that users should be able to get started right away making simple experiments.

Weber's emphasis is currently on auditory psychophysics, but the package has the features necessary to generate most visual stimuli one would desire as well, thanks to [Images.jl](https://github.com/JuliaImages/Images.jl). It is named after Ernst Weber. Weber runs on Windows and Mac OS X, and supports keyboard input or Cedrus response-pad input.

# Installation

You must first [install julia](http://junolab.org/). Then, at the julia command
prompt, run this code.

```julia
julia> Pkg.add("Weber")
```

# Documentation

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://haberdashPI.github.io/Weber.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://USER_NAME.github.io/Weber.jl/latest)

# Usage

The following is a simple example to help demonstrate the basic features of the
package. Refer to the examples directory for several, more realistic, real-world
examples.

```julia
using Weber
sid,skip = @read_args("A simple frequency discrimination experiment.")

low = ramp(tone(1000,0.5))
high = ramp(tone(1100,0.5))

function one_trial()
  if rand(Bool)
    stim = moment(0.5,play,low)
    resp = response(key"q" => "low", key"p" => "high",actual = "low")
  else
    stim = moment(0.5,play,high)
    resp = response(key"q" => "low", key"p" => "high",actual = "high")
  end
  return [show_cross(),stim,resp,await_response(iskeydown)]
end

exp = Experiment(sid = sid,condition = "ConditionA",skip=skip,columns=[:actual])
setup(exp) do
  addbreak(instruct("Here are some instructions."))
  addbreak(instruct("Here's some practice."))
  for i in 1:5
    addpractice(one_trial())
  end

  addbreak(instruct("Here's the real deal."))
  for trial in 1:60
    addtrial(one_trial())
  end
end

run(exp)
```

This experiment records responses to a simple frequency discrimination
experiment. After 500ms from the start of each trial, a low or high tone is
played that lasts 500ms. At some point after the start of the tone the
listener needs to hit 'q' if they hear the low tone and 'p' if they hear the
high tone. There's no feedback, ever.

Let's step through the code:

```julia
using Weber
sid,skip = @read_args("A simple frequency discrimination experiment.")
```

This loads Weber, and reads two important parameters from the user, the
subject id, and how many _offsets_ to skip. You don't have to worry about
offsets right now. If you wish to learn about them refer to the documentation
for `@read_args`, `addtrial` and `Experiment`.

```julia
low = ramp(tone(1000,0.5))
high = ramp(tone(1100,0.5))
```

This generates the low (1000 Hz) and high (1100 Hz) tone. In addition to `ramp`
and `tone` there are many other function to help you generate sounds (`mix`,
`mult`, `silence`, `noise`, `highpass`, `lowpass`, `bandpass`, `tone`, `ramp`,
`harmonic_complex`, `attenuate`). Any arbitrary single dimensional array (or 2d for stereo
sound) can be used as a sound stimulus, and anything you can do to an array you
can do to a sound stimulus. You can also load sounds from a wav file using
`load`. Refer to the documentation of these individual functions for
details. Generally you should create the sounds prior to running an experiment,
as shown here, to minimize latency. If these functions are insufficient you may
also want to take a look at the `SampledSignals` and `DSP` packages which Weber
draws from. 

Once you are done generating a stimulus you present it using the `play`
function. The `play` function will return an object that you can call `pause` or
`stop` on, if need be.

```julia
function one_trial()
  if rand(Bool)
    stim = moment(0.5,play,low)
    resp = response(key"q" => "low", key"p" => "high",actual = "low")
  else
    stim = moment(0.5,play,high)
    resp = response(key"q" => "low", key"p" => "high",actual = "high")
  end
  return [show_cross(),stim,resp,await_response(iskeydown)]
end
```

This function will be used below to create each trial of the experiment. It does
this by returning several **moments**. Moments are relatively brief events
intended to occur at a precise time during a trial. They are the basic building
blocks of trials. There are many ways to create moments: please refer to the
documentation for `addtrial` for a complete list of available moment types, and
some guidlines about creating low-latency moments. In the above, the function
`moment`, `response` and `await_response` are functions that generate a kind of
moment. The call to `moment` is used to present the tone (e.g. `play,low`) 0.5
seconds after the start of the last moment. The `response` moment records all
presses of 'q' and 'p' to a data file stored in the a subdirectory called
data. The `await_response` moment waits until the user presses any key before
moving on to the next moment (in this case, the end of the trail).

The `response` function uses the macro `key"str"` to reference keyboard keys.
Look up the documentation for `@key_str` for more details. There are
several lower-level functions for working with user input as well. Look at the
description of watchers in the documentation of  `addtrial`, and refer
to the event processing methods `time`, `response_time`, `keycode`, `iskeydown`
`iskeyup`, `reset_response`, `isfocused` and `isunfocused`.

```julia
exp = Experiment(sid = sid,condition = "ConditionA",skip=skip,columns=[:actual])
```

This call creates the actual experiment, indicating that the subject id and
condition should be recorded on each line of the data file. Refer to the
documentation of `Experiment` for more options when creating an experiment.

The `columns=[:actual]` tells Weber that the data file should have a column
called "actual", columns can also be added during setup using `addcolumn`. The
call to record `response`, during the function `one_trial`, sets this column to
"low" or "high" depending on which tone was actually played to the subject. If
`:actual` was not specified here, this call would result in an error during the
experiment.

```julia
setup(exp) do
  addbreak(instruct("Here are some instructions."))
  addbreak(instruct("Here's some practice."))
  for i in 1:5
    addpractice(one_trial())
  end
  addbreak(instruct("Here's the real deal."))
  for trial in 1:60
    addtrial(one_trial())
  end
end
```

This section of the program is the where all trials of the experiment are
created. It adds several breaks, which can be used to give the subject
useful information or let them rest. Then it adds 5 practice trials, and a total
of 60 actual trials. Weber will automatically record the trial number for
each trial (added using `addtrial`) on each line of the resulting data
file. Both trials and practice trials also increment a second number
recorded to the data file, called the offset, which can be used to
restart the experiment from some time point in the middle of an experiment.

Note that the experiment has not actually been run after this code has completed
running, it is merely ready to begin. Normally experiments have a fixed number
of trials specified during setup, as shown here, but if you wish to do more
advanced types of experiments with some arbitrary number of trials, refer to the
documentation for `@addtrials`.

```julia
run(exp)
```

Once you have created the experiment you need to actually run it by calling
`run`. This organization helps ensure that as much as possible is computed
before the experiment is actually run. The only code that executes during `run`
are the operations defined in moments, such as the call to `play` in and the
recording of responses by `response`, defined in `one_trial`. Everything else
happens during the setup.

There are several features this experiment does not demonstrate: visual stimuli
and higher level primitives.

You can create visual stimuli by using `load` to open images or create a 2d
array (for grayscale) or 3d array (for color) representing pixel data. You can
then use `display` (analogous to `play`) to show them to these images (or text)
to the subject.

There is also an `addbreak_every` primitive that adds a break every N trials,
and `levitt_adapter` and `bayesian_adapter` which can be used to create trials
with stimuli that adjust adaptively adjust based on the participant's
responses. The adapter's usage is demonstrated in the example file
`freq2afc.jl`. At the present moment the bayesian adapter's default priors are
not well optimized, so it is recommended that you use `levitt_adapter`.

# Status

## Linux support

Weber does not currently support Linux. Julia's support for installation of
binary dependencies in linux is
[currently broken](https://github.com/JuliaLang/BinDeps.jl/issues/199) and even
with a manual install of the necessary libraries (SDL2, SDL2_mixer and SDL2_ttf)
I have run into LLVM errors that I have yet to track down. If you can get Weber
to work on Linux I would happily accept a
[pull request](http://docs.julialang.org/en/release-0.5/manual/packages/#making-changes-to-an-existing-package).

## Roadmap

For the 0.2.x releases
- [x] warm up JIT compilation by running a windowless, soundless experiment
during `run`.
- [x] get CI working.
- [x] improve trial timing
- [x] make sure all dependent libraries installed on mac os x (retry Homebrew.jl
  ??)
- [x] simplify moments and submoments to moments in ExperimentData
- [x] fix false mis-timing warnings when using `update_delta = false` (do we
  need this anymore?)
- [x] create a calibration program
- [x] rename `display_key_codes`
- [x] test `display` timing (using an oscilloscope)
- [x] add remaining special keys to @key_str
- [x] create helper to generate template experiment (including run, setup, 
      update, and README.md files)

For the 0.3.0 release
- [x] implement a loop and conditional that works across multiple trials
- [x] allow record, display and play (or visual and sound?) to be moments.
- [x] make it an error to directly call display and play
- [x] allow display and play to use thunks to generate visuals
      and sounds that depend on previous moments.
- [x] change exp_tick() to Weber.tick()
- [x] remove t parameter from moment functions (if needed one can use Weber.tick())
- [x] allow the function passed to moment to take extra arguments passed to `moment`

For the 0.3.x release
- [x] create 2AFC abstraction
- [x] create example 2AFC experiment that shows state dependent visuals
- [x] run a series of delta 0 moments all at once.
- [x] allow the addition of further data columns during experiment setup.
- [x] allow record callback to communicate with additional devices
- [x] improve bayesian adaptive tracking algorithms
- [x] implement extensions
- [x] move extra static columns into separeate keyword argument
- [x] edit/refine the user manual
- [x] create extension API
- [ ] document extension API
- [ ] remember to document the record codes generated automatically by Weber
- [ ] proofread documentation
- [ ] publish documentation
- [ ] create examples to demonstrate all package features
- [ ] create some more tests for state dependent experiments
- [ ] create tests for `display` and `play` logistics.
- [ ] evaluate code coverage and memory allocation for tests

For the 0.4.0 release?
- [ ] port to linux
- [ ] video playback (requires julia multi threading or custom c code)
- [ ] track audio buffer timing so we can zero-pad sounds to get sub-buffer-size timing
      accuracy. (requires julia multi threading or custom c code)
