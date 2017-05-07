#!/usr/bin/env julia

using Weber

const version = v"0.0.1"
const sid,skip = @read_args("Duration Discrimination ($version).")

#======================================================================
Experiment Setup
======================================================================#
# 3AFC duration discrimination. Each stimulus consists of 2 short tones
# separated by given duration. The task is to indicate which of 3 intervals
# is longer.

const atten_dB = 30 # adjust to calibrate levels
const n_trials_per_block = 60
const n_blocks = 6

const tone_freq = 1kHz
const tone_length = 10ms
const standard_length = 100ms # from start of tone 1 to start of tone 2

const SOA = 900ms
const response_delay = 300ms
const feedback_delay = 700ms

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

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"b") || iskeydown(e,key"q")

const beep = attenuate(ramp(tone(tone_freq,tone_length)),atten_dB)
beep_beep(len) = [beep;silence(len - tone_length);beep]

function trial_stimuli(longer_sound,delta)
  standard = beep_beep(standard_length)
  signal = beep_beep(standard_length*(1+delta))
  if longer_sound == 1
    [signal;silence(SOA-duration(signal));
     standard;silence(SOA-duration(standard));
     standard]
  elseif longer_sound == 2
    [standard;silence(SOA-duration(standard));
     signal;silence(SOA-duration(signal));
     standard]
  elseif longer_sound == 3
    [standard;silence(SOA-duration(standard));
     standard;silence(SOA-duration(standard));
     signal]
  else
    error("longer_sound is $longer_sound, must be 1, 2 or 3.")
  end
end

const longer_sound_text = ["first_longer","second_longer","third_longer"]
function duration2AFC(adapter;keys...)
  longer_sound = rand(1:3)
  resp = response(adapter,
                  key"q" => "first_longer",
                  key"b" => "second_longer",
                  key"p" => "third_longer",
                  correct = longer_sound_text[longer_sound];
                  keys...)

  stim() = trial_stimuli(longer_sound,delta(adapter))
  [moment(feedback_delay,play,stim),show_cross(),
   moment(3SOA + response_delay,display,
          "Was the first [Q], second [B] or third sound [P] longer?"),
   resp,await_response(isresponse)]
end

setup(experiment) do
  # play a test tone, to verify sound levels
  addbreak(moment(record,"start"),
           moment(play,@> tone(1kHz,1s) ramp attenuate(atten_dB)),
           moment(1))

  addbreak(instruct("""

      On each trial, you will hear three sounds. Indicate which of the sounds
  you heard as longer. Hit 'Q' if the first sound was longer, 'B' if the
  second was longer, and 'P' if the third sound was longer.

  """),moment(display,colorant"gray"))

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

run(experiment)
