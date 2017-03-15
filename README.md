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
get started quickly, making simple experiments today. You can start by reading
the [manual](https://haberdashPI.github.io/Weber.jl/stable).

Weber's emphasis is currently on auditory psychophysics, but the package has the
features necessary to generate most visual stimuli one would desire as well,
thanks to [Images.jl](https://github.com/JuliaImages/Images.jl). It is named
after Ernst Weber. Weber runs on Windows and Mac OS X. Additional functionality
can be added through 
[extensions](https://haberdashpi.github.io/Weber.jl/stable/extend/).

# Linux support

Weber does not currently support Linux. Julia's support for installation of
binary dependencies in linux is
[currently broken](https://github.com/JuliaLang/BinDeps.jl/issues/199) and even
with a manual install of the necessary libraries (SDL2, SDL2_mixer and SDL2_ttf)
I have run into LLVM errors that I have yet to track down. If you can get Weber
to work on Linux I would happily accept a
[pull request](http://docs.julialang.org/en/release-0.5/manual/packages/#making-changes-to-an-existing-package).
