using Weber
using Base.Test
include("find_timing.jl")

seq_trial_events,_,rows = find_timing() do
  addtrial(moment(() -> record(:a)),
           moment(() -> record(:b)),
           moment(() -> record(:c)))
  addtrial(moment(() -> record(:a)),
           moment(() -> record(:b)),
           moment(() -> record(:c)))
  addtrial(moment(() -> record(:a)),
           moment(() -> record(:b)),
           moment(() -> record(:c)))
end
seq_trial_index = map(x -> x[:trial],rows)

@testset "Moment Indexing" begin
  @test seq_trial_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
  @test seq_trial_index == [1,1,1,2,2,2,3,3,3]
end
