using PortAudio
using SampledSignals
using DSP
using LibSndFile
using SFML
using Gadfly
using FixedPointNumbers

import SFML: play, stop, pause
import Gadfly: plot
import Base: wait

export match_lengths, mix, mult, silence, noise, bandpass, tone, ramp,
	harmonic_complex, attenuate, sound, loadsound, stop, pause, play,
  wait, savesound, stretch, highpass, lowpass, duration

const loadsound = LibSndFile.load
const savesound = LibSndFile.save

function plot(x::SampleBuf;resolution=1000)
  plot(x=linspace(0,length(x)/x.samplerate,resolution),
       y=Float64.(x.data[floor(Int,linspace(1,length(x),resolution))]),
       Geom.line)
end

function plot(x::Sound,resolution=1000)
  plot(SampleBuf(get_samples(get_buffer(x)) / 2^15,
                 get_samplerate(get_buffer(x))),resolution=resolution)
end

function match_lengths(xs...)
	max_length = maximum(map(x -> size(x,1), xs))

  map(xs) do x
    if size(x,1) < max_length
      [x; zeros(max_length - size(x,1),size(x,2))]
    else
      x
    end
  end
end

function mix(xs...;sample_rate_Hz=44100)
  xs = match_lengths(xs...)
  reduce(.+,xs)
end

function mult(xs...;sample_rate_Hz=44100)
	xs = match_lengths(xs...)
	reduce(.*,xs)
end

function silence(length_s;sample_rate_Hz=44100)
	SampleBuf(zeros(floor(Int,sample_rate_Hz * length_s)),sample_rate_Hz)
end

function noise(length_s;sample_rate_Hz=44100)
	return SampleBuf(1-2rand(floor(Int,length_s*sample_rate_Hz)),sample_rate_Hz)
end

function tone(freq_Hz,length_s;sample_rate_Hz=44100,phase=0)
	t = linspace(0,length_s,length_s*sample_rate_Hz)
	return SampleBuf(sin(2π*t * freq_Hz + phase),sample_rate_Hz)
end

function harmonic_complex(f0,harmonics,amps,length_s;
						  sample_rate_Hz=44100,phases=zeros(length(harmonics)))
	c = zeros(length_s*sample_rate_Hz)
	n = maximum(harmonics)+1

	max_length = floor(sample_rate_Hz*length_s)
	extra = sample_rate_Hz*n / f0
	highest_freq = tone(f0,n*length_s + extra;sample_rate_Hz=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
		c += amp*highest_freq[(1:max_length) * (n-harm) + phase_offset]
	end

	SampleBuf(c,sample_rate_Hz)
end

function bandpass(x,low,high;order=5,sample_rate_Hz=44100)
	ftype = Bandpass(float(low),float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	filt(f,x)
end

function lowpass(x,low;order=5,sample_rate_Hz=44100)
	ftype = Lowpass(float(low),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	filt(f,x)
end

function highpass(x,high;order=5,sample_rate_Hz=44100)
	ftype = Highpass(float(high),fs=sample_rate_Hz)
	f = digitalfilter(ftype,Butterworth(order))
	filt(f,x)
end

function ramp(x,ramp_s=0.005;sample_rate_Hz=44100)
	ramp_len = floor(Int,sample_rate_Hz * ramp_s)
	@assert size(x,1) > 2ramp_len

	ramp_t = (1.0:ramp_len) / ramp_len
	up = -0.5cos(π*ramp_t)+0.5
	down = 0.5cos(π*ramp_t)+0.5
	envelope = [up; ones(size(x,1) - 2*ramp_len); down]
	mult(x,envelope)
end

function attenuate(x,atten_dB=20)
	10^(-atten_dB/20) * x/sqrt(mean(x.^2))
end

type SoundUtilSound
  data::SFML.Sound
end

function sound(x::Array{Float64};atten_dB=20,ramp_s=0.005,sample_rate_Hz=44100)
	sound(attenuate(ramp(SampleBuf(x,sample_rate_Hz),ramp_s),atten_dB))
end

function sound{N}(x::SampleBuf{PCM16Sample,N})
  sound(Sound(SoundBuffer(reinterpret(Int16,x.data),floor(Int,samplerate(x)))))
end

function sound{N}(x::SampleBuf{Float64,N})
  buf = SampleBuf(PCM16Sample,samplerate(x),size(x)...)
  rate = samplerate(x)
  vals = trunc(Int16,max(min(2^15*x.data,typemax(Int16)),typemin(Int16)))
  sound(Sound(SoundBuffer(vals,floor(Int,rate))))
end

function sound(x::Sound)
  SoundUtilSound(x)
end

function SFML.play(x::SampleBuf,thread=true)
  SFML.play(sound(x),thread)
end

function SFML.play(x::Array{Float64},thread=true)
  SFML.play(sound(x),thread)
end

function SFML.play(s::SoundUtilSound,thread=true)
  SFML.play(s.data)
  if !thread
    sleep(as_seconds(get_duration(get_buffer(s.data))))
  else
    s
  end
end

function SFML.pause(s::SoundUtilSound)
  SFML.pause(s.data)
end

function SFML.stop(s::SoundUtilSound)
  SFML.stop(s.data)
end

function Base.wait(s::SoundUtilSound)
  sleep(as_seconds(get_duration(get_buffer(s.data))) -
        as_seconds(get_playing_offset(s.data)))
end

function duration(s::SoundUtilSound)
  as_seconds(get_duration(get_buffer(s.data)))
end

function duration(s::SampleBuf)
  length(s) / samplerate(s)
end

function duration(s::Array{Float64};sample_rate_Hz=44100)
  length(s) / sample_rate_Hz
end
