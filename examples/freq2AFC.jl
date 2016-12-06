#push!(LAOD_PATH,pwd())
using Psychoacoustics
using DataStructures

freq_discrim = @settings begin
  :atten_dB => calibrate("calibration.json","left_ear_86dB",:booth)
  :sid => UserNumber("Subject ID",order=1)
  :group => UserSelect("Group",["Day1","fs24D_50ms","fs24Pd_50ms",
                                "fs24D_50ms","fs7dPd_50ms","fs24Pi_50ms"],
                       order=2)
  :phase => UserSelect("Phase",["2AFC","passive"],order=2.5)
  :stimulus => UserSelect("Stimulus",["f1k50ms","f1k100ms","f4k50ms"],order=3)
  :num_blocks => UserNumber("Blocks",6,order=4)
  :num_trials => UserSelect("Trials",[60,45],order=5)
  :sample_rate_Hz => 44100
  :feedback_delay_ms => 400
  :beep_ms => 15
  :ramp_ms => 5
  :SOA_ms => 900
  :response_delay_ms => 500
  :levitt => Levitt(start=0.1 * :frequency_Hz,
                    bigstep=2,littlestep=sqrt(2),
                    down=3,up=1,mult=true,min_delta=0,
                    max_delta=:frequency_Hz - 300)
  :generate_sound => function(delta)
    beep = tone(:frequency_Hz - delta,:beep_ms,:atten_dB,
                :ramp_ms,:sample_rate_Hz)
    space = silence(:length_ms - :beep_ms,:sample_rate_Hz)
    leftear(sequence(beep,space,beep))
  end
  :record => [:group,:sid,:phase,:stimulus,others()...]
end

stimuli = @optionsfor :stimulus begin
  "f1k50ms" => begin
    :length_ms => 50
    :frequency_Hz => 1000
    :examples => OrderedDict("Higher frequency sound" => 0,
                             "Lower frequency sound" => 100)
  end

  "f1k100ms" => begin
    :length_ms => 100
    :frequency_Hz => 1000
    :examples => OrderedDict("Higher frequency sound" => 0,
                             "Lower frequency sound" => 100)
  end

  "f4k50ms" => begin
    :length_ms => 50
    :frequency_Hz => 4000
    :examples => OrderedDict("Higher frequency sound" => 0,
                             "Lower frequency sound" => 400)
  end
end

# TODO: do I want to explicitly pass settings here,
# to make it more obvious what is happening?
# this would make things very self contained.
# but possibly painful.
phases = @options :phase begin
  "2AFC" => :run => levitt()
  "passive" => :run => passive(deltas = :static)
end

run_experiment(freq_discrim,stimuli,phases)
