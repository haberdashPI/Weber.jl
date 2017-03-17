#!/usr/bin/env julia

using Weber
using Lazy

version = v"0.0.1"
# sid,trial_skip = @read_args("Adaptive Mistuning ($version).")
sid = "test"
trial_skip = 11

experiment = Experiment(
  moment_resolution=0.005,
  skip=trial_skip,
  columns = [
    :sid => sid,
    :version => version,
    :mistuning
  ]
)

################################################################################
# settings

const ms = 1/1000
atten_dB = 30
n_trials = 60
feedback_delay = 750ms
f0 = 100
n_harmonics = 10
mistune_harmonic = 1
stim_length = 6.72
example_length = stim_length

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

################################################################################
# stimuli

function mistuned(percent)
  h = 0:n_harmonics
  h = h[h .!= mistune_harmonic]
  amps = ones(n_harmonics) #2.0.^-h

  x = harmonic_complex(f0,h,amps,stim_length)
  x += tone((mistune_harmonic+1)*f0 + percent*f0,stim_length)
  x = ramp(x,50ms)
  attenuate(x,atten_dB)
end

################################################################################
# trial definition: on each trial we track the total amount of time each button
# is pressed, and record the button that was pressed more, on average.

function one_trial(adapter)
  let time_mistuned = 0, total_time = 0,
      last_response = true, last_response_time = NaN,

    stimulus() = mistuned(delta(adapter))

    function update_response()
      time = (Weber.tick() - last_response_time)
      time_mistuned += last_response*time
      total_time += time
    end

    function collect_responses(event)
      if !isnan(last_response_time)
        update_response()
      end
      last_response = iskeydown(event,key"p")
      last_response_time = Weber.tick()
    end

    function record_average_response()
      update_response()

      response = time_mistuned / total_time > 0.5
      record(response ? "mistuned" : "tuned",mistuning = delta(adapter))
      update!(adapter,response,true)
    end

    [show_cross(),moment(1500ms,play,stimulus),collect_responses,
     moment(stim_length,record_average_response)]
  end
end

################################################################################
# full experiment

setup(experiment) do
  addbreak(instruct("""
    In the following expeirment you will be listening for
    a mistuned harmonic inside a tone complex. To start, here is an example
    of what a tone complex sounds like.
  """))

  complex = harmonic_complex(f0,0:n_harmonics,ones(n_harmonics),example_length)
  complex = attenuate(complex,atten_dB)
  addpractice(moment(display,colorant"gray"),
              moment(250ms,play,complex),moment(duration(complex)))

  addbreak(instruct("""
    Next, here is the sound of the one tone from the complex, which
    will be mistuned.
  """))
  harmonic = ramp(tone((mistune_harmonic+1)*f0 +0.16*f0,example_length))
  harmonic = attenuate(harmonic,atten_dB)
  addpractice(moment(display,colorant"gray"),
              moment(250ms,play,harmonic),moment(duration(harmonic)))

  addbreak(instruct("""
    Now, let's compare the tone in the complex, to the tone out of the
    complex.
  """))
  example_mistune = mistuned(0.16)
  addpractice(moment(250ms,play,example_mistune),
              moment(display,"Mistuned tone in complex"),
              moment(duration(example_mistune) + 250ms,play,harmonic),
              moment(display,"Mistuned tone alone"),

              moment(duration(harmonic) + 250ms,play,example_mistune),
              moment(display,"Mistuned tone in complex"),
              moment(duration(example_mistune) + 250ms,play,harmonic),
              moment(display,"Mistuned tone alone"),
              moment(duration(harmonic)))

  addbreak(instruct("""
    Now, let's compare the complex when there is a mistuned harmonic
    to a complex with no mistuning.
  """))

  addpractice(moment(250ms,play,example_mistune),
              moment(display,"Mistuned complex"),
              moment(duration(example_mistune) + 250ms,play,complex),
              moment(display,"Tuned complex"),

              moment(duration(complex) + 250ms,play,example_mistune),
              moment(display,"Mistuned complex"),
              moment(duration(example_mistune) + 250ms,play,complex),
              moment(display,"Tuned complex"),
              moment(duration(complex)))

  addbreak(instruct("""
    During the experiment, as long as what you hear sounds tuned, hold
    down 'q'. As long as what you hear sounds mistuned, hold down 'p'.
    Your responses may, or may not change while listening to one
    continuous sound.
  """))

  addbreak(moment(display,"Hit any key when you're ready to start..."),
           await_response(iskeydown))

  masker = @> noise() begin
    lowpass(500)
    rampon()
    attenuate(atten_dB-2)
  end

  @addtrials let adapter = levitt_adapter(first_delta=0.04,down=2,up=2,
                                          min_delta=0,max_delta=0.16,
                                          big=0.02,little=0.005)
    for trial in 1:n_trials
      if trial == 1
        addtrial(moment(record,"experiment_start"),
                 moment(stream,masker),
                 one_trial(adapter))
      else
        addtrial(one_trial(adapter))
      end
    end
  end

end

play(attenuate(ramp(tone(1000,1)),atten_dB))
run(experiment)
