seq_events,_,_ = find_timing() do
  addtrial(moment(0.01,() -> record(:a)),
           moment(0.01,() -> record(:b)),
           moment(0.01,() -> record(:c)))
end

@testset "Moment Sequencing" begin
  @test seq_events == [:a,:b,:c]
end
