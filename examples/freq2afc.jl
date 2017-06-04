#!/usr/bin/env julia

using Weber

version = v"0.0.3"
sid,trial_skip,adapt = @read_args("Frequency Discrimination ($version).",
                                  adapt=[:levitt,:bayes])

const atten_dB = 30
const n_trials = 60
const feedback_delay = 750ms

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

const standard_freq = 1kHz
const standard = @> tone(standard_freq,100ms) ramp attenuate(atten_dB)

function one_trial(adapter)
  first_lower = rand(Bool)
  resp = response(adapter,key"q" => "first_lower",key"p" => "second_lower",
                  correct=(first_lower ? "first_lower" : "second_lower"))

  signal() = @> tone((1-delta(adapter))*standard_freq,100ms) begin
    ramp
    attenuate(atten_dB)
  end
  stimuli = first_lower? [signal,standard] : [standard,signal]

  [moment(feedback_delay,play,stimuli[1]),
   show_cross(),
   moment(900ms,play,stimuli[2]),
   moment(100ms + 300ms,display,
          "Was the first [Q] or second sound [P] lower in pitch?"),
   resp,await_response(isresponse)]
end

experiment = Experiment(
  skip=trial_skip,
  columns = [
    :sid => sid,
    :condition => "example",
    :version => version,
    :standard => standard_freq
  ]
)

setup(experiment) do
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

    function threshold_report()
      mean,sd = estimate(adapter)
      thresh = round(mean,3)*standard_freq
      thresh_sd = round(sd,3)*standard_freq

      # define this string during run time when we know
      # what the threshold estimate is.
      "Threshold $(thresh)Hz (SD: $thresh_sd)\n"*
      "Hit spacebar to continue..."
    end

    addbreak(moment(display,threshold_report,clean_whitespace=false),
             await_response(iskeydown(key":space:")))
  end

end

run(experiment)
