# Psychotask

[![Build Status](https://travis-ci.org/haberdashPI/Psychotask.jl.svg?branch=master)](https://travis-ci.org/haberdashPI/Psychotask.jl)

[![Coverage Status](https://coveralls.io/repos/haberdashPI/Psychotask.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/haberdashPI/Psychotask.jl?branch=master)

[![codecov.io](http://codecov.io/github/haberdashPI/Psychotask.jl/coverage.svg?branch=master)](http://codecov.io/github/haberdashPI/Psychotask.jl?branch=master)

# About

This package is a relatively recent effort to create a simple framework for
creating psychophysical experiments that present stimuli and record responses in
realtime. It is similar in concept to the likes of Presentation or ePrime. It
runs on Windows and Mac OS X, and supports keyboard input or Cendrus
response-pad input.

## Status

This is working for my own purposes, and I am running pilot experiments in it
now. It has not been throughly tested yet however, but will be as I finalize
those studies. Many of the individual functions are documented but there is
useful functionality that has not yet been documented, and there is no user
manual. Please feel free to use it, but use at your own risk.

# Installation

```julia
julia> Pkg.clone("https://github.com/haberdashPI/Psychotask.jl")
julia> Pkg.build("Psychotask")
```

