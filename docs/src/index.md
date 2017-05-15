# About

Weber is a [Julia](http://julialang.org/) package that can be used to generate
simple psychology experiments that present visual and auditory stimuli at
precise times. 

Weber's emphasis is currently on auditory psychophysics, but the package has the
features necessary to generate most visual stimuli one would desire as well,
thanks to [Images.jl](https://github.com/JuliaImages/Images.jl). It is named
after Ernst Weber. Weber runs on Windows and Mac OS X. Additional functionality
can be added through [extensions](extend.md)

# [Installation](@id install)

The following instructions are designed for those new to Julia, and coding in general.

## 1. Install Julia and Juno

To use Weber you will need to have Julia, and an appropriate code editor installed. [Follow these instructions](https://github.com/JunoLab/uber-juno/blob/master/setup.md) to install Julia
and the Juno IDE. Juno is an extension for the code editor Atom (which these instructions will also ask you to download).

## 2. Install Weber

Once Julia and Juno are installed, open Atom. Go to "Open Console" under the Julia menu.

![Image of "Open Console" in Menu](install1.png)

A console window will appear. Type `Pkg.add("Weber")` in the console and hit enter.

![Image of `Pkg.add("Weber")` in Console](install2.png)

