using Weber
using Base.Test
include("find_timing.jl")

const check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"
const moment_eps = 2.5e-3

_,many_times,_ = find_timing() do
  addtrial(repeated(moment(0.5ms,() -> record(:a)),1000))
end

if check_timing
  @testset "Timing" begin
    diffs = abs.(0.0005 - diff(many_times))
    middle99 = diffs[quantile(diffs,0.005) .< diffs .< quantile(diffs,0.995)]
    @test mean(middle99) < moment_eps
  end
end
