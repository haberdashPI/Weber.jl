using Weber
using DataFrames: writetable, DataFrame

# HOW TO USE: Setup a video camera in front of your computer monitor and then
# run this script. Try as best you can to center the the monitor in the camera's
# view. Press record on the camera and then hit spacebar to start the
# test. Ideally you should increase the frame rate of your camera to at least 60
# fps. You can then use analyze_videotiming.jl to the extract onsets from the
# recorded image, and determine the timing accuracy of video playback.

timing = 0.5abs.(randn(Float64,100)) + 0.3
writetable("video_timing.csv",DataFrame(times = cumsum(timing),lengths = timing/2))

exp = Experiment()
setup(exp) do
  addbreak(instruct("Test is ready."))
  square = visual(ones(200,200),duration=0.2)
  blackness = visual(colorant"black",duration=Inf,priority=-1)

  black = moment(t -> display(blackness))
  moments = map(timing) do delta
    moment(delta,t -> display(square))
  end
  addtrial(black,moments)
end

run(exp)
