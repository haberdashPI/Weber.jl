#!/usr/bin/env julia

using Weber

version = v"0.0.2"
sid,trial_skip,adapt = @read_args("Frequency Discrimination ($version).",
                                  adapt=[:levitt,:bayes])

const ms = 1/1000
atten_dB = 30
n_trials = 60

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

standard = attenuate(ramp(tone(1000,0.1)),atten_dB)
function one_trial(adapter)
  first_lower = rand(Bool)
  resp = response(adapter,key"q" => "first_lower",key"p" => "second_lower",
                  correct=(first_lower ? "first_lower" : "second_lower"))

  signal() = attenuate(ramp(tone(1000*(1-delta(adapter)),0.1)),atten_dB)
  stimuli = first_lower? [signal,standard] : [standard,signal]

  [show_cross(),
   moment(play,stimuli[1]),moment(0.9,play,stimuli[2]),
   moment(0.1 + 0.3,display,
          "Was the first [Q] or second sound [P] lower in pitch?"),
   resp,await_response(isresponse),moment(0.75)]
end

exp = Experiment(
  skip=trial_skip,
  columns = [
    :sid => sid,
    :condition => "example",
    :version => version,
    :standard => 1000
  ]
)

setup(exp) do
  addbreak(moment(record,"start"))

  addbreak(instruct("""

    On each trial, you will hear two beeps. Indicate which of the two beeps you
heard was lower in pitch. Hit 'Q' if the first beep was lower, and 'P' if the
second beep was lower.
"""))

  if adapt == :levitt
    adapter = levitt_adapter(down=3,up=1,min_delta=0,max_delta=1,
                             big=2,little=sqrt(2),mult=true)
  else
    adapter = bayesian_adapter(min_delta = 0,max_delta = 0.95)
  end

  @addtrials let a = adapter
    for trial in 1:n_trials
      addtrial(one_trial(a))
    end
  end
end

play(attenuate(ramp(tone(1000,1)),atten_dB))
run(exp)
