using Weber
using Base.Test
include("find_timing.jl")

when_events,_,_ = find_timing() do
  @addtrials let test = true
    @addtrials if test
      addtrial(moment(() -> (record(:a); test = false)))
    end

    @addtrials if test
      addtrial(moment(() -> (record(:b))))
    end
  end
end

elseif_events,_,_ = find_timing() do
  @addtrials let test = true, test2 = false
    @addtrials if test
      addtrial(moment(() -> (record(:a); test = false)))
    else
      addtrial(moment(() -> (record(:bad_a); test = true)))
    end

    @addtrials if test
      addtrial(moment(() -> (record(:bad_b1); test = false)))
    elseif !test2
      addtrial(moment(() -> (record(:b); test2 = true)))
    else
      addtrial(moment(() -> (record(:bad_b2); test = false)))
    end

    @addtrials if !test2
      addtrial(moment(() -> record(:bad_c1)))
    elseif test
      addtrial(moment(() -> record(:bad_c2)))
    else
      addtrial(moment(() -> record(:c)))
    end
  end
end


@testset "Conditional Moments" begin
  @test when_events == [:a]
  @test elseif_events == [:a,:b,:c]
end
