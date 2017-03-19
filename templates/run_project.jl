#!/usr/bin/env julia

################################################################################
# Please see Weber's manual for detailed instructions on how to
# create an experiment:
#
# {{weber_dir}}README.md
################################################################################

using Weber
include("calibrate.jl") # machine specific parameters

version = v"0.0.1"
sid,skip = @read_args("... insert brief project description ...")

experiment = Experiment(
  skip = skip
  columns = [
    :sid => sid,
    :version => version
  ]
)

setup(experiment) do
  # define experiment variables here
  n_trials = 60

  # setup experimental stimuli here

  # define a function to create a trial here
  function one_trial()
    # TODO
  end

  for trial in 1:n_trials
    # add trials to the experiment here
    addtrial(one_trial())
  end
end

# run the experiment
run(experiment)
