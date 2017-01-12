using Weber
using Gadfly
using Compose
using DataFrames: readtable

# HOW TO USE: run this script, replacing the two lines below with the files
# you generated using audiotiming.jl. This script will then report
# the error in audio playback onsets.

audiofile = "/Users/davidlittle/Desktop/beeps2.wav"
timing_file = "data/audio_timing_2017-01-11__09_19_19.csv"
relt = 0.6 # the relative threshold, you may need to change this.

# NOTE: this script may require a little troubleshooting depending on your
# recording fideltiy. As is, for me, this works quite well even using laptop
# speakers and a built-in microphone. I was able to detect all but the first few
# onsets (which played on top of one another as the program was loading into
# memory/ JIT compiling). You can plot intermediate results as needed using the
# commented out Gadfly plots.

beeps = load(audiofile)[:,1]

# the following finds the onsets by detecting peaks in the envelope gradient
function findpeaks(x,relt)
  t = relt*maximum(x)
  peakstart = -1
  peaks = Array{Int,1}()

  for i in eachindex(x)
    if x[i] > t && peakstart < 0
      peakstart = i
    elseif x[i] < t && peakstart > 0
      _,j = findmax(x[peakstart:i])
      push!(peaks,j+peakstart)
      peakstart = -1
    end
  end

  peaks
end

envelope = lowpass(max(beeps,0),100)
atimes = findpeaks(diff(envelope),relt)/44100

# # you can use this plot to troubleshoot the threshold
# # for finding onsets

# a = round(Int,0*44100+1)
# b = round(Int,1*44100)

# plot(x=(a:b)/44100,
#      y=beeps[a:b],#diff(envelope)[a:b],
#      yintercept=[relt*maximum(diff(envelope))],
#      xintercept=atimes[a/44100 .< atimes .< b/44100],
#      Geom.line,Geom.hline(color=colorant"red",size=0.5mm),
#      Geom.vline(color=colorant"purple",size=0.5mm))

df = readtable(timing_file)
times = df[df[:code] .== "sound",:time]
times += atimes[end] - times[end]

# # you can use this plot to compare the actual and measured times
# # across absolute times
# a = maximum(times) - 2
# b = maximum(times) - 1
# des = times[a .< times .< b]
# mes = atimes[a .< atimes .< b]

# plot(layer(x=des,y=repeat([1],inner=length(des)),
#            color=repeat(["desired"],inner=length(des)),Geom.point),
#      layer(x=mes,y=repeat([-1],inner=length(mes)),
#            color=repeat(["measured"],inner=length(mes)),Geom.point),
#      Scale.y_continuous(minvalue=-20,maxvalue=20))

d_delta = diff(-reverse(times))
# cut off the first few onsets, as they are normally wrong
# as the program is loading into memory (/ JIT compilation?)
m_delta = diff(-reverse(atimes[3:end]))

d_delta = d_delta[1:length(m_delta)]

# # you can use this plot to visually inspect the error
# # without collapsing the measured and desired dimensions
# plot(layer(x=d_delta,y=m_delta,Geom.point),
#      layer(x=[minimum([d_delta;m_delta]),
#               maximum([d_delta;m_delta])],
#            y=[minimum([d_delta;m_delta]),
#               maximum([d_delta;m_delta])],
#            Geom.line),
#      Coord.cartesian(xmin=0.1,xmax=0.2,ymin=0.1,ymax=0.2),
#      Guide.xlabel("desired delta"),
#      Guide.ylabel("measured delta"))

# # Histrogram without abs
# plot(x=1000(d_delta-m_delta),
#      Geom.histogram(bincount=15,density=true),
#      Theme(bar_highlight=colorant"black"),
#      Guide.xlabel("desired - measured onset (ms)"))

err = quantile(1000abs.(d_delta-m_delta),0.75)
merr = 1000 * df[:latency][1]

p = plot(x=1000abs.(d_delta-m_delta),
         layer(xintercept=[merr],
               Geom.vline(size=0.5mm,color=colorant"red")),
         Guide.annotation(compose(context(),
                                  text(merr+0.25,0.15,"Playback Latency"),
                                  Compose.font("Calibri"),
                                  fontsize(12pt),
                                  fill(RGB(0.3,0.3,0.3)))),
         Geom.histogram(bincount=12,density=true),
         Theme(bar_highlight=colorant"black"),
         Guide.xlabel("| desired - measured | onset (ms)"))

file = joinpath(dirname(@__FILE__),"audio_onset_error.png")
draw(PNG(file,4inch,3inch),p)
info("A graph of onset errors has been saved to $file")
info("Audio timing has an error of ~$(round(err,2))ms.")
info("The minimum expected error, given audio playback settings is $(round(merr,2))ms")
