#!/usr/bin/env julia

using Weber
using Lazy: @> # see https://github.com/MikeInnes/Lazy.jl

version = v"0.0.1"
sid,skip = @read_args("Gap Detection ($version).")

#===============================================================================
Experiment Settings
===============================================================================#
# 2AFC gap detection. Each stimulus consists of a marker---a band-pass noise---
# and masker---a notch noise of the same width. Each stimulus either does or
# does not have a gap in the middle. The task is to indicate which of 2 stimuli
# has this gap.

const atten_dB = 30 # adjust to calibrate sound levels
const n_trials_per_block = 60
const n_blocks = 6

const marker_center_freq = 200Hz
const marker_width_octaves = 1
const marker_SNR = 20

const gap_ramp_ms = 0.5ms
const feedback_delay = 700ms

const visual_delay = 300ms

const SOA = 900ms # "onset" asynchrony of the no-gap and gap interval
const trial_spacing = 500ms # how long to wait at the start and end of trials
const max_delta = 400ms
const first_delta = 50ms
const big_step = 5ms
const little_step = 1ms

const adapter = levitt_adapter(first_delta=first_delta/max_delta,down=3,up=1,
                               big=big_step / first_delta,
                               little=little_step / first_delta,
                               min_delta=0,max_delta=1)

experiment = Experiment(
  skip=skip,
  moment_resolution=5ms,
  columns = [
    :sid => sid,
    :condition => "example",
    :version => version,
    :block
  ]
)

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

#==============================================================================
Stimulus and Trial Generation
===============================================================================#

low_freq = marker_center_freq*2^(-marker_width_octaves/2)
high_freq = marker_center_freq*2^(marker_width_octaves/2)

# marker: the band-pass noise which will have a gap (or not)
marker() = @> begin
  noise(trial_spacing+SOA+trial_spacing)
  bandpass(low_freq,high_freq)
  ramp
  attenuate(atten_dB)
end

# masker: an infinite stream of noise above and below the marker
masker() = @> begin
  noise(trial_spacing+SOA+trial_spacing)
  bandstop(low_freq,high_freq)
  ramp
  attenuate(atten_dB+marker_SNR)
end

# gap_noise: generates the gap
function gap_noise(gap_first,adapter)
  @assert max_delta*delta(adapter) > 2gap_ramp_ms || delta(adapter) == 0
  if delta(adapter) == 0 # no gap
    mix(masker(),marker)
  elseif gap_first
    @> begin
      envelope(1,trial_spacing)
      fadeto(silence(max_delta*delta(adapter)),gap_ramp_ms)
      fadeto(envelope(1,SOA+trial_spacing-max_delta*delta(adapter)),gap_ramp_ms)
      mult(marker())
      mix(masker())
    end
  else # gap second
    @> begin
      envelope(1,trial_spacing+SOA)
      fadeto(silence(max_delta*delta(adapter)),gap_ramp_ms)
      fadeto(envelope(1,trial_spacing-max_delta*delta(adapter)))
      mult(marker())
      mix(masker())
    end
  end
end

# creates a single, 2-interval forced-choice trial

function gap2AFC(adapter;keys...)
  gap_first = rand(Bool)
  resp = response(adapter,key"q" => "gap_first",key"p" => "gap_second",
                  correct=(gap_first? "gap_first" : "gap_second");
                  keys...)
  stim() = gap_noise(gap_first,adapter)

  [moment(feedback_delay,play,stim),
   show_cross(),
   moment(trial_spacing,display,"Interval 1"),
   moment(SOA,display,"Interval 2"),
   moment(trial_spacing+visual_delay,display,
          "Was there a gap in the first [Q] or second interval [P]?"),
   resp,await_response(isresponse)]
end

#===============================================================================
Experiment Creation
===============================================================================#

setup(experiment) do
  # play a test tone, to verify sound levels
  addbreak(moment(record,"start"),
           moment(250ms,play,@> tone(1kHz,1s) ramp attenuate(atten_dB)),
           moment(1s))

  addbreak(instruct("""

      On each trial, you will hear a gap in a noise at one of two
  possible time intervals. Indicate which of the two intervals had a gap. Hit
  'Q' if the first interval had a gap, and 'P' if the second had a gap.

  """),moment(display,colorant"gray"))

  for block in 1:n_blocks
    @addtrials let adapter = adapter
      for trial in 1:n_trials_per_block
        addtrial(gap2AFC(adapter,block=block))
      end

      # define this string during experiment setup
      # when we know what block we're on...
      heading = "Block $block of $n_blocks"

      function threshold_report()
        mean,sd = estimate(adapter)
        thresh = usconvert(ms,round(mean,3)*max_delta)
        thresh_sd = uconvert(ms,round(sd,3)*max_delta)

        # define this string during run time when we know
        # what the threshold estimate is.
        "$heading: Threshold $thresh (SD: $thresh_sd)\n"*
        "Hit spacebar to continue..."
      end

      addbreak(moment(display,threshold_report,clean_whitespace=false),
               await_response(iskeydown(key":space:")))
    end
  end
end

run(experiment)
