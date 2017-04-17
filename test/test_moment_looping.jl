using Weber
using Base.Test
include("find_timing.jl")

loop_events,_,rows = find_timing() do
  @addtrials let i = 0
    @addtrials while i < 3
      addtrial(moment(() -> i+=1),
               moment(() -> record(:a)),
               moment(() -> record(:b)),
               moment(() -> record(:c)))
    end
  end
end
loop_index = map(x -> (x[:trial],x[:offset]),rows)

@testset "Looping Moments" begin
  @test loop_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
  @test loop_index == [(1,1),(1,1),(1,1),(2,1),(2,1),(2,1),(3,1),(3,1),(3,1)]
end
