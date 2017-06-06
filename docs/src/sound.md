# Sound Creation

```@docs
sound
tone
noise
silence
harmonic_complex
irn
audible
```

# Sound Manipulation

```@docs
highpass
lowpass
bandpass
bandstop
ramp
rampon
rampoff
fadeto
attenuate
mix
mult
envelope
duration
nchannels(::Weber.Sound)
nsamples(::Weber.Sound)
audiofn
leftright
left
right
```

# Playback

```@docs
play 
setup_sound 
playable
DSP.Filters.resample(::Weber.Sound,::Any)
stop
samplerate
current_sound_latency
pause_sounds
resume_sounds
run_calibrate
```

