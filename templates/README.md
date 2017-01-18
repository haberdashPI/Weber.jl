# About

... insert description here ...

# Installation

You need to install julia, and then run the setup.jl script.

One way to do this is as follows:

1. [Download](https://github.com/[username]/{{project}}/archive/master.zip)
   and unzip this project.
2. Follow the directions to
   [install Juno](https://github.com/JunoLab/uber-juno/blob/master/setup.md)
3. Open the setup.jl file for this project in Juno.
4. Run setup.jl in Juno (e.g. Julia > Run File).

# Running

If you installed Juno (see above) just run `run_{{project}}.jl` in Juno.  Make
sure you have the console open (Julia > Open Console), as you will be prompted
to enter a number of experimental parameters. Also note that important warnings
and information about the experiment will be written to the console.

Alternatively, if you have julia setup in your `PATH`, you can run the
experiment from a terminal by typing `julia run_{{project}}.jl`. On mac (or unix)
this can be shortened to `./run_{{project}}.jl`. You can get help about how to
use the console verison by typing `julia run_{{project}}.jl -h`.

## Restarting the experiment

If the experiment gets interrupted, the program will report an offset
number. This number is also saved on each line of the data recorded during
the experiment. You can use this number to call `run_{{project}}.jl` starting from
somewhere in the middle of the experiment.

