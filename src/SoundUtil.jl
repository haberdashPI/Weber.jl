using SampledSignals
using DSP
using LibSndFile
using Gadfly
using FixedPointNumbers

import Gadfly: plot
import Base: wait

export match_lengths, mix, mult, silence, noise, bandpass, tone, ramp,
	harmonic_complex, attenuate, sound, loadsound, play,
  wait, savesound, stretch, highpass, lowpass, duration

const loadsound = LibSndFile.load
const savesound = LibSndFile.save

function plot(x::SampleBuf;resolution=1000)
  plot(x=linspace(0,length(x)/x.samplerate,resolution),
       y=Float64.(x.data[floor(Int,linspace(1,length(x),resolution))]),
       Geom.line)
end

function match_lengths(xs...)
	max_length = maximum(map(x -> size(x,1), xs))

  map(xs) do x
    if size(x,1) < max_length
      vcat(x,SampleBuf(zeros(eltype(x),
                             max_length - size(x,1),size(x,2)),samplerate(x)))
    else
      x
    end
  end
end

function mix(xs...)
  xs = match_lengths(xs...)
  reduce(+,xs)
end

function mult(xs...)
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
	t = linspace(0,length_s,round(Int,length_s*sample_rate_Hz))
	return SampleBuf(sin(2π*t * freq_Hz + phase),sample_rate_Hz)
end

# TODO: debug
function harmonic_complex(f0,harmonics,amps,length_s;
						  sample_rate_Hz=44100,phases=zeros(length(harmonics)))
	n = maximum(harmonics)+1

  unit_length = 1/f0
  max_length = floor(Int,sample_rate_Hz*unit_length)
  unit = zeros(n*max_length)

	extra = sample_rate_Hz*n / f0
	highest_freq = tone(f0,n*unit_length + extra;sample_rate_Hz=sample_rate_Hz)

	for (amp,harm,phase) in zip(amps,harmonics,phases)
		phase_offset = round(Int,n*phase/2π*sample_rate_Hz/f0)
		unit += amp*highest_freq[(1:max_length) * (n-harm) + phase_offset]
	end

  int_length = ceil(Int,length_s / unit_length)
  full_length = round(Int,length_s*sample_rate)
  full_sound = reduce(vcat,repeating(unit,int_length))[1:full_length]

	SampleBuf(full_sound,sample_rate_Hz)
end

function bandpass(x,low,high;order=5)
	ftype = Bandpass(float(low),float(high),fs=samplerate(x))
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),samplerate(x))
end

function lowpass(x,low;order=5)
	ftype = Lowpass(float(low),fs=samplerate(x))
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),samplerate(x))
end

function highpass(x,high;order=5)
	ftype = Highpass(float(high),fs=samplerate(x))
	f = digitalfilter(ftype,Butterworth(order))
	SampleBuf(filt(f,x),samplerate(x))
end

function ramp(x,ramp_s=0.005)
	ramp_len = floor(Int,samplerate(x) * ramp_s)
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

function sound(x::Array{Float64};sample_rate_Hz=44100)
  SampleBuf(trunc(Fixed{Int16,15},x),sample_rate_Hz)
end

function sound(x::SampleBuf)
  sound(SampleBuf(Fixed{Int16,15}.(x),samplerate(x)))
end

function play(x,async=true)
  play(sound(x),async)
end

immutable MixChunk
  allocated::Cint
  buffer::Ptr{Fixed{Int16,15}}
  byte_length::UInt32
  volume::UInt8
end

immutable Sound
  chunk::MixChunk
  samplerate::Int
end

function sound(x::SampleBuf{Fixed{Int16,15}})
  Sound(MixChunk(0,pointer(x.data),sizeof(x.data),128),samplerate(x))
end

type SoundEnvironment
end

const SDL_INIT_AUDIO = 0x0010
const AUDIO_S16LSB = 0x8010
function init_sound(samplerate=44100)
  Libdl.dlopen("libSDL")
  #dlopen("libSDL_mixer")
  init = ccall((:SDL_Init,"libSDL"),Cint,(UInt32,),SDL_INIT_AUDIO)
  if init < 0
    error_str = ccall((:SDL_GetError(),"libSDL"),Cstring,(Void,))
    error("Failed to initialize SDL: $error_str")
  end

  # we use a very small buffer, to minimize latency
  mixer_init = ccall((:Mix_OpenAudio,"libSDL_mixer"),Cint,
                     (Cint,UInt16,Cint,Cint),samplerate,AUDIO_S16LSB,2,64)
  if mixier_init < 0
    error("Failed to initialize sound.")
  end

  result = SoundEnvironment()
  finalize(result,x -> close_sound())
  result
end

function close_sound()
  ccall((:Mix_CloseAudio,"libSDL_mixer"),Void,(Void,))
  ccall((:SDL_Quit,"libSDL"),Void,(Void,))
end

sound_environment = init_sound()
function play(x::Sound,async=true)
  result = ccall((:Mix_PlayChannel,"libSDL_mixer"),Cint,
                 (Cint,Ref{MixChunk},Cint),
                 -1,x.chunk,0)
  if result < 0
    error("Failed to play sound!")
  end
  if !async
    error("unsupported functionality: synchronous audio playback")
  end
end

function duration(s::SampleBuf)
  length(s) / samplerate(s)
end

function duration(s::Array{Float64};sample_rate_Hz=44100)
  length(s) / sample_rate_Hz
end
