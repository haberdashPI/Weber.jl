using Weber
using Base.Test
include("find_timing.jl")

const check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"
const moment_eps = 2.5e-3

# warm up JIT...
find_timing() do
  addtrial(moment(0.05,() -> record(:a)),
           moment(0.05,() -> record(:b)) >> moment(0.1,() -> record(:d)),
           moment(0.1,() -> record(:c)),
           moment(0.1,() -> record(:e)))
end

comp_events,comp_times,_ = find_timing() do
  addtrial(moment(0.05,() -> record(:a)),
           moment(0.05,() -> record(:b)) >> moment(0.1,() -> record(:d)),
           moment(0.1,() -> record(:c)),
           moment(0.1,() -> record(:e)))
end

@testset "Compound Moments" begin
  @test comp_events == [:a,:b,:c,:d,:e]
  if check_timing
    comp_diff = maximum(diff(comp_times) - 0.05)
    @test comp_diff < moment_eps
  end
end
