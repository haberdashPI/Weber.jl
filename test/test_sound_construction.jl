
using Weber
using Base.Test
using Lazy: @>
x = sound(ramp(tone(1kHz,1s)))
rng() = MersenneTwister(1983)

show_str = "1.0 s 16 bit PCM stereo sound
Sampled at 44100 Hz
▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆
▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆"

@testset "Sound Indexing" begin
  @test isapprox(duration(x[0s .. 0.5s,:]),0.5s; atol = 1/samplerate(x))
  @test isapprox(duration(x[0.5s .. end,:]),0.5s; atol = 1/samplerate(x))
  @test x[:,left] == x[:,right]
  @test_throws BoundsError x[0.5s .. 2s,:]
  @test_throws BoundsError x[-0.5s .. 0.5s,:]
  @test_throws BoundsError x[-0.5s .. end,:]
  @test nsamples(x[0s .. 0.5s,:]) + nsamples(x[0.5s .. end,:]) == nsamples(x)
  strbuff = IOBuffer()
  show(strbuff,sound(x))
  @test show_str == String(strbuff)
end

@testset "Sound Construction" begin
  @test sound("sounds/tone.wav") == x
  @test (sound("sounds/two_tone.wav") ==
         sound([tone(1kHz,100ms);silence(800ms);tone(1kHz,100ms)]))
  a,b = tone(1kHz,200ms,false),tone(2kHz,200ms,false)
  @test leftright(a,b)[:,left] == a
  @test leftright(a,b)[:,right] == b
  @test sound("sounds/rampon.wav") == sound(rampon(tone(1kHz,1s)))
  @test sound("sounds/rampoff.wav") == sound(rampoff(tone(1kHz,1s)))
  @test (sound("sounds/fadeto.wav") ==
         sound(fadeto(tone(1kHz,0.5s),tone(2kHz,0.5s))))
  @test sound("sounds/noise.wav") == sound(noise(1s,rng=rng()))
  @test (sound("sounds/bandpass.wav") ==
         sound(@> noise(1s,rng=rng()) bandpass(400Hz,800Hz)))
  @test (sound("sounds/complex.wav") ==
         sound(@> harmonic_complex(200Hz,0:5,ones(6),1s) attenuate(20)))
end

# TODO: new REPL tests of audio playback functions
