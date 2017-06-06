using Weber
using Base.Test

rng() = MersenneTwister(1983)
same(x,y) = isapprox(x,y,rtol=1e-6)

@testset "Stream Construction" begin
  @test same(sound("sounds/tone.wav")[:,:left],
             @> tone(1kHz) rampon rampoff(5ms,1s) sound)
  @test [leftright(tone(1kHz,1s),tone(2kHz,1s)); tone(1.5kHz,1s)] ==
    @> leftright(tone(1kHz),tone(2kHz)) limit(1s) vcat(tone(1.5kHz)) sound(2s)
  @test same((@_ mix(tone(1kHz),tone(2kHz)) audiofn(x -> x ./ 2,_) sound(_,1s)),
             (@_ mix(tone(1kHz),tone(2kHz)) sound(_,1s) audiofn(x -> x ./ 2,_)))
  a,b = tone(1kHz),tone(2kHz)
  @test sound(left(leftright(a,b)),1s) == sound(tone(1kHz),1s)
  a,b = tone(1kHz),tone(2kHz)
  @test sound(right(leftright(a,b)),1s) == sound(tone(2kHz),1s)
  a = tone(1kHz)
  @test duration([sound(a,0.5s); @> a limit(1s) sound]) == 1.5s
  @test_throws ErrorException @> tone(1kHz) limit(50ms) sound ramp(100ms)
  @test same(sound("sounds/noise.wav"),@> noise(rng=rng()) sound(1s))
  @test same(sound("sounds/bandpass.wav"),
             @> noise(rng=rng()) bandpass(400Hz,800Hz) sound(1s))
  @test same(sound("sounds/complex.wav"),
             @> harmonic_complex(200Hz,0:5,ones(6)) sound(1s) attenuate(20))
  x = noise(rng=rng())
  a,b = bandpass(x,200Hz,400Hz), bandpass(x,500Hz,600Hz)
  @test_throws ErrorException @> mix(a,b) sound(500ms)

  x = noise(rng=rng())
  a,b = bandpass(x,200Hz,400Hz), bandpass(x,500Hz,600Hz)
  @test @>(mix(a,deepcopy(b)),sound(500ms))[:] ==
    mix(@>(noise(rng=rng()),bandpass(200Hz,400Hz),sound(500ms)),
        @>(noise(rng=rng()),bandpass(500Hz,600Hz),sound(500ms)))[:]

  @test_throws ErrorException mult(tone(1kHz),sound(ones(Float32,10)))

  a = tone(1kHz); b = tone(2kHz);
  @test [silence(10ms); a] != nothing
  @test fadeto(a,b) != nothing
  @test (@> tone(1kHz) attenuate(20) sound(1)) != nothing
end
