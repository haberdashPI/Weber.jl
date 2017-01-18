#!/usr/bin/env julia

################################################################################
# Please see Weber's README.md for detailed instructions on how to
# create an experiment:
#
# {{weber_dir}}README.md
################################################################################

using Weber

version = v"0.0.1"
sid,skip = @read_args("...insert project summary...")

exp = Experiment(sid = sid, version = version, skip = skip,
                 columns = [#= add additional data columns here =#])

# define experiment variables here
n_trials = 60

# use run_calibrate to find an appropriate attenuation level
atten_dB = 20

# define a function to create a trial here
function one_trial()
  # TODO
end

setup(exp) do
  # setup experimental stimuli here

  for trial in 1:n_trials
    # add trials to the experiment here
    addtrial(one_trial())
  end
end

# play a tone before the experiment begins to verify sound level
play(attenuate(ramp(tone(1000,1)),atten_dB),wait=true)

# run the experiment
run(exp)
