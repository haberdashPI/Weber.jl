using Weber
using DataFrames: DataFrame, writetable

# TODO: try with mobile pre

# HOW TO USE: Run this script, while recording its sound (e.g. using your phone,
# or Audacity). Then run the script analyze_audiotiming.jl to extract the peaks
# from the recorded audio, and determine the timing accuracy of audio playback.
setup_sound(buffer_size=16)
timing = 0.2abs.(randn(Float64,100)) + 0.11
beep = sound(attenuate(ramp(tone(1000,0.05)),25))

exp = Experiment(name = "audio_timing",latency = current_sound_latency())

setup(exp) do
  addbreak(instruct("Test is ready."))

  moments = map(timing) do delta
    moment(delta) do
      play(beep)
      record("sound")
    end
  end
  addtrial(show_cross(),moments)
end

run(exp)
