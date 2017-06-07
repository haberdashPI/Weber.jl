using Weber
using Base.Test

rng() = MersenneTwister(1983)


@testset "Oddball Design" begin
  pattern = oddball_paradigm(identity,20,150,rng=rng())
  @test sum(pattern) == 20
  @test length(pattern) == 170
  @test !any(pattern[2:end] .& (pattern[2:end] .== pattern[1:(end-1)]))
  @test any(pattern[3:end] .& (pattern[3:end] .== pattern[1:(end-2)]))
  @test !any(pattern[1:20])
  @test_throws AssertionError oddball_paradigm(identity,61,80)
  pattern2 = oddball_paradigm(identity,60,80,rng=rng())
  @test sum(pattern2) == 60
  @test length(pattern2) == 140
  pattern3 = oddball_paradigm(identity,60,140,oddball_spacing=2,rng=rng())
  @test sum(pattern3) == 60
  @test length(pattern3) == 200
  @test !any(pattern3[2:end] .& (pattern3[2:end] .== pattern3[1:(end-1)]))
  @test !any(pattern3[3:end] .& (pattern3[3:end] .== pattern3[1:(end-2)]))
  @test any(pattern3[4:end] .& (pattern3[4:end] .== pattern3[1:(end-3)]))
end
