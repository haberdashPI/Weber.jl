# Weber

[![Build status](https://ci.appveyor.com/api/projects/status/uvxq5mqlq0p2ap02/branch/master?svg=true)](https://ci.appveyor.com/project/haberdashPI/weber-jl/branch/master)
[![TravisCI Status](https://travis-ci.org/haberdashPI/Weber.jl.svg?branch=master)](https://travis-ci.org/haberdashPI/Weber.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://haberdashPI.github.io/Weber.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://haberdashPI.github.io/Weber.jl/latest)

<!-- [![Coverage Status](https://coveralls.io/repos/haberdashPI/Weber.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/haberdashPI/Weber.jl?branch=master) -->

<!-- [![codecov.io](http://codecov.io/github/haberdashPI/Weber.jl/coverage.svg?branch=master)](http://codecov.io/github/haberdashPI/Weber.jl?branch=master) -->

# About

Weber is a [Julia](http://julialang.org/) package that can be used to generate
simple psychology experiments that present visual and auditory stimuli at
precise times. Julia is a recent programming language designed specifically for
technical computing.

Weber has been built with the assumption that most of its users have only
minimal programming experience. The hope is that such users should be able to
get started quickly, making simple experiments today.

Weber's emphasis is currently on auditory psychophysics, but the package has the
features necessary to generate most visual stimuli one would desire as well,
thanks to [Images.jl](https://github.com/JuliaImages/Images.jl). It is named
after Ernst Weber. Weber runs on Windows and Mac OS X, and supports keyboard
input or Cedrus response-pad input. Additional functionality can be added by
making [extensions](https://haberdashpi.github.io/Weber.jl/stable/extend/)

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
- [x] implement non-overlapping layered extensions
- [x] move extra static columns into separeate keyword argument
- [x] edit/refine the user manual
- [x] create extension API
- [x] document extension API
- [x] make the cedrus response pad input an extension
- [x] remember to document the record codes generated automatically by Weber
- [x] publish documentation
- [ ] more documentation editing
- [ ] create a simple abstraction for 2AFC adaptive tracking.
- [ ] create adaptive tracking guide
- [ ] create examples to demonstrate all package features
- [ ] have docs direct to relevant example scripts
- [ ] create some more tests for state dependent experiments
- [ ] create tests for `display` and `play` logistics.
- [ ] evaluate code coverage and memory allocation for tests

For the 0.4.0 release?
- [ ] port to linux
- [ ] video playback (requires julia multi threading or custom c code)
- [ ] track audio buffer timing so we can zero-pad sounds to get sub-buffer-size timing
      accuracy. (requires julia multi threading or custom c code)
