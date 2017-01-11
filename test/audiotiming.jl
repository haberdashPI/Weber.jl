using Weber
using DataFrames: DataFrame, writetable

# HOW TO USE: Run this script, while recording its sound (e.g. using your phone,
# or Audacity). Then run the script analyze_audiotiming.jl to extract the peaks
# from the recorded audio, and determine the timing accuracy of audio playback.
setup_sound(buffer_size=16)
timing = 0.2abs.(randn(Float64,100)) + 0.11
writetable("audio_timing.csv",DataFrame(times = cumsum(timing),
                                        latency=current_sound_latency()))
beep = attenuate(ramp(tone(1000,0.05)),25)

exp = Experiment()

setup(exp) do
  addbreak(instruct("Test is ready."))

  moments = map(timing) do delta
    moment(delta,t -> play(beep))
  end
  addtrial(show_cross(),moments)
end

run(exp)
