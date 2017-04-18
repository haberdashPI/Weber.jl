
using Weber
using Base.Test
using Lazy: @>
x = leftright(ramp(tone(1kHz,1s)),ramp(tone(1kHz,1s)))
rng() = MersenneTwister(1983)

show_str = "1.0 s 16 bit PCM stereo sound
Sampled at 44100 Hz
▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆
▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆▆"

@testset "Sound Indexing" begin
  @test isapprox(duration(x[0s .. 0.5s,:]),0.5s; atol = 1/samplerate(x))
  @test isapprox(duration(x[0.5s .. end,:]),0.5s; atol = 1/samplerate(x))
  @test x[:,:left][0s .. 0.5s] == x[0s .. 0.5s,:left]
  @test x[:,:left] == x[:,:right]
  @test_throws BoundsError x[0.5s .. 2s,:]
  @test_throws BoundsError x[-0.5s .. 0.5s,:]
  @test_throws BoundsError x[-0.5s .. end,:]
  @test_throws BoundsError x[:,:doodle]
  @test nsamples(x[0s .. 0.5s,:]) + nsamples(x[0.5s .. end,:]) == nsamples(x)
  strbuff = IOBuffer()
  show(strbuff,playable(x))
  @test show_str == String(strbuff)
end

@inline same(x,y) = isapprox(x,y,rtol=1e-6)

@testset "Sound Construction" begin
  @test same(sound("sounds/tone.wav"),x)
  @test same(sound("sounds/two_tone.wav"),
             [tone(1kHz,100ms);silence(800ms);tone(1kHz,100ms)])
  a,b = tone(1kHz,200ms),tone(2kHz,200ms)
  @test leftright(a,b)[:,:left] == a
  @test leftright(a,b)[:,:right] == b
  @test size([tone(1kHz,0.2s); tone(2kHz,0.2s)],2) == 1
  @test [tone(1kHz,0.2s); leftright(tone(1.5kHz,0.2s),tone(0.5kHz,0.2s))] ==
    [leftright(tone(1kHz,0.2s),   tone(1kHz,0.2s));
     leftright(tone(1.5kHz,0.2s), tone(0.5kHz,0.2s))]
  @test_throws ErrorException ramp(tone(1kHz,50ms),100ms)
  @test same(sound("sounds/rampon.wav"),rampon(tone(1kHz,1s)))
  @test same(sound("sounds/rampoff.wav"),rampoff(tone(1kHz,1s)))
  @test same(sound("sounds/fadeto.wav"),
             fadeto(tone(1kHz,0.5s),tone(2kHz,0.5s)))
  @test fadeto(leftright(tone(1kHz,100ms),tone(1.5kHz,100ms)),
               tone(2kHz,100ms)) != 0
  @test same(sound("sounds/noise.wav"),noise(1s,rng=rng()))
  @test same(sound("sounds/bandpass.wav"),
             @> noise(1s,rng=rng()) bandpass(400Hz,800Hz))
  @test same(sound("sounds/complex.wav"),
             @> harmonic_complex(200Hz,0:5,ones(6),1s) attenuate(20))
end

# TODO: new REPL tests of audio playback functions
# TODO: apply unitful to moment interface
