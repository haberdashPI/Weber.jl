In addition to functions available below you can also call
[`FileIO.jl`](https://github.com/JuliaIO/FileIO.jl)'s `load` and `save`
functions for common audio file formats (e.g. "wav", "aiff", "ogg").

# Sound Creation

```@docs
tone
noise
silence
harmonic_complex
asstream
stream_unit
sound
buffer
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
```

# Playback

```@docs
setup_sound 
play
duration
stream
stop
samplerate
current_sound_latency
pause_sounds
resume_sounds
run_calibrate
```

