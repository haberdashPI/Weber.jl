
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
  @test isapprox(duration(x[0.5s .. ends,:]),0.5s; atol = 1/samplerate(x))

  @test x[:,:left][0s .. 0.5s] == x[0s .. 0.5s,:left]
  @test x[:,:left] == x[:,:right]
  @test x[0.5s .. 0.75s] == x[0.5s .. 0.75s,:]
  @test x[0.5s .. ends] == x[0.5s .. ends,:]
  mylen = nsamples(x[0.1s .. 0.6s])
  newx = copy(x)
  @test (newx[0.1s .. 0.6s] = x[50:(50+mylen-1),:]) == x[50:(50+mylen-1),:]
  @test (newx[0.1s .. 0.6s,:] = x[50:(50+mylen-1),:]) == x[50:(50+mylen-1),:]
  myend = (0.1s + duration(x[0.5s .. ends]))
  @test (newx[0.5s .. ends] = x[0.1s .. myend]) == x[0.1s .. myend]
  @test (newx[0.5s .. ends,:] = x[0.1s .. myend,:]) == x[0.1s .. myend,:]
  @test (newx[0.1s .. 0.6s,:] = x[0.2s .. 0.700005s,:]) == x[0.2s .. 0.700005s,:]

  @test_throws BoundsError x[0.5s .. 2s,:]
  @test_throws BoundsError x[-0.5s .. 0.5s,:]
  @test_throws BoundsError x[-0.5s .. ends,:]
  @test_throws BoundsError x[:,:doodle]
  @test_throws BoundsError x[0.5s .. 2s]
  @test_throws BoundsError x[-0.5s .. 0.5s]
  @test_throws BoundsError x[-0.5s .. ends]
  @test_throws BoundsError x[0.5s .. 2s,:] = 1:10
  @test_throws BoundsError x[-0.5s .. 0.5s,:] = 1:10
  @test_throws BoundsError x[-0.5s .. ends,:] = 1:10
  @test_throws BoundsError x[:,:doodle] = 1:10
  @test_throws BoundsError x[0.5s .. 2s] = 1:10
  @test_throws BoundsError x[-0.5s .. 0.5s] = 1:10
  @test_throws BoundsError x[-0.5s .. ends] = 1:10
  @test_throws DimensionMismatch x[0.5s .. 0.6s,:] = 1:10
  @test_throws DimensionMismatch x[0.2s .. 0.5s,:] = 1:10
  @test_throws DimensionMismatch x[0.2s .. ends,:] = 1:10
  @test_throws DimensionMismatch x[0.5s .. 0.6s] = 1:10
  @test_throws DimensionMismatch x[0.5s .. 0.6s] = 1:10
  @test_throws DimensionMismatch x[0.5s .. ends] = 1:10

  @test nsamples(x[0s .. 0.5s,:]) + nsamples(x[0.5s .. ends,:]) == nsamples(x)
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
