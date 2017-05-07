#!/usr/bin/env julia

using Weber

version = v"0.0.1"
sid,skip = @read_args("Duration Discrimination ($version).")

#======================================================================
Experiment Setup
======================================================================#
# 2AFC duration discrimination. Each stimulus consists of 2 short tones
# separated by given duration. The task is to indicate which of 2 intervals
# is longer.

const atten_dB = 30 # adjust to calibrate levels
const n_trials_per_block = 60
const n_blocks = 6

const tone_freq = 1kHz
const tone_length = 10ms
const standard_length = 100ms # from start of tone 1 to start of tone 2

const SOA = 900ms # how long to wait to starting play stimulus 2
const response_delay = 300ms # how long to wait before asking for a response
const trial_spacing = 500ms # how long to wait between trials

const adapter = levitt_adapter(first_delta=2,down=3,up=1,
                               big=0.5,little=0.05,min_delta=0,
                               max_delta=(SOA/2-tone_length)/tone_length)

#======================================================================#

experiment = Experiment(
  skip=skip,
  columns = [
    :sid => sid,
    :condition => "example",
    :version => version,
    :standard => standard_length,
    :block
  ]
)

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

beep = attenuate(ramp(tone(tone_freq,tone_length)),atten_dB)
beep_beep(len) = [beep;silence(len - tone_length);beep]

function trial_stimuli(first_longer,delta)
  standard = beep_beep(standard_length)
  signal = beep_beep(standard_length*(1+delta))
  if first_longer
    [signal;silence(SOA-duration(signal));standard]
  else
    [standard;silence(SOA-duration(standard));signal]
  end
end

function duration2AFC(adapter;keys...)
  first_longer = rand(Bool)
  resp = response(adapter,key"q" => "first_longer",key"p" => "second_longer",
                  correct=(first_longer? "first_longer" : "second_longer");
                  keys...)

  stim() = trial_stimuli(first_longer,delta(adapter))
  [moment(trial_spacing,play,stim),show_cross(),
   moment(SOA + standard_length + response_delay,display,
          "Was the first [Q] or second sound [P] longer?"),
   resp,await_response(isresponse)]
end

setup(experiment) do
  addbreak(moment(record,"start"),
           moment(play,@> tone(1kHz,1s) ramp attenuate(atten_dB)),
           moment(1s))

  addbreak(instruct("""

      On each trial, you will hear two sounds. Indicate which of the two sounds
  you heard as longer. Hit 'Q' if the first sound was longer, and 'P' if the
  second was longer.

  """))

  for block in 1:n_blocks
    @addtrials let adapter = adapter
      for trial in 1:n_trials_per_block
        addtrial(duration2AFC(adapter,block=block))
      end
      # define this string during experiment setup
      # when we know what block we're on...
      heading = "Block $block of $n_blocks"

      function report_threshold()
        mean,sd = estimate(adapter)
        thresh = round(mean,3)*standard_length
        thresh_sd = round(sd,3)*standard_length

        # define this string during run time when we know
        # what the threshold estimate is.
        "$heading: Threshold $thresh (SD: $thresh_sd)\n"*
        "Hit spacebar to continue..."
      end

      addbreak(moment(display,report_threshold,clean_whitespace=false),
               await_response(iskeydown(key":space:")))
    end
  end
end

# play a test tone, to verify levels
run(experiment)
