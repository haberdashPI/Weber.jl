using Weber
using Base.Test
include("find_timing.jl")

seq_events,_,_ = find_timing() do
  addtrial(moment(10ms,() -> record(:a)),
           moment(10ms,() -> record(:b)),
           moment(10ms,() -> record(:c)))
end

@testset "Moment Sequencing" begin
  @test seq_events == [:a,:b,:c]
end
