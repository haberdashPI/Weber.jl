using Weber
using Base.Test
using Lazy: @>, @_

rng() = MersenneTwister(1983)
same(x,y) = isapprox(x,y,rtol=1e-6)

@testset "Stream Construction" begin
  @test same(sound("sounds/tone.wav")[:,:left],
             @> tone(1kHz) rampon rampoff(5ms,1s) sound)
  @test [leftright(tone(1kHz,1s),tone(2kHz,1s)); tone(1.5kHz,1s)] ==
    @> leftright(tone(1kHz),tone(2kHz)) limit(1s) vcat(tone(1.5kHz)) sound(2s)
  a,b = tone(1kHz),tone(2kHz)
  @test same((@_ mix(tone(1kHz),tone(2kHz)) audiofn(x -> x ./ 2,_) sound(_,1s)),
             (@_ mix(tone(1kHz),tone(2kHz)) sound(_,1s) audiofn(x -> x ./ 2,_)))
  @test left(leftright(a,b)) == a
  @test right(leftright(a,b)) == b
  a = tone(1kHz)
  @test duration([sound(a,0.5s); @> a limit(1s) sound]) == 1.5s
  @test_throws ErrorException @> tone(1kHz) limit(50ms) sound ramp(100ms)
  @test same(sound("sounds/noise.wav"),@> noise(rng=rng()) sound(1s))
  @test same(sound("sounds/bandpass.wav"),
             @> noise(rng=rng()) bandpass(400Hz,800Hz) sound(1s))
  @test same(sound("sounds/complex.wav"),
             @> harmonic_complex(200Hz,0:5,ones(6)) sound(1s) attenuate(20))
end
