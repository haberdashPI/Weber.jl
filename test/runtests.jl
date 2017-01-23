using Weber
using Base.Test

# NOTE: much of the code is interactive and multimedia driven, none of which can
# be tested here. I'm just testing some of the timing of experiments here.

# this allows a test of timing for an experiment without setting up any
# multimedia resources, so it can be run just about anywhere.
function find_timing(fn)
  recording = Tuple{Symbol,Any}[]
  record_time(name,t) = push!(recording,(name,t))

  exp = Experiment(null_window=true,hide_output=true)
  setup(() -> fn(record_time),exp)
  run(exp,await_input=false)

  getindex.(recording,1),getindex.(recording,2)
end

_,many_times = find_timing() do record
  addtrial(repeated(moment(0.0005,t -> record(:a,t)),1000))
end

seq_events,_ = find_timing() do record
  addtrial(moment(0.01,t -> record(:a,t)),
           moment(0.01,t -> record(:b,t)),
           moment(0.01,t -> record(:c,t)))
end

seq_trial_events,seq_trial_index = find_timing() do record
  addtrial(moment(t -> record(:a,experiment_trial())),
           moment(t -> record(:b,experiment_trial())),
           moment(t -> record(:c,experiment_trial())))
  addtrial(moment(t -> record(:a,experiment_trial())),
           moment(t -> record(:b,experiment_trial())),
           moment(t -> record(:c,experiment_trial())))
  addtrial(moment(t -> record(:a,experiment_trial())),
           moment(t -> record(:b,experiment_trial())),
           moment(t -> record(:c,experiment_trial())))
end

# warm up JIT...
find_timing() do record
  addtrial(moment(0.05,t -> record(:a,t)),
           moment(0.1,t -> record(:b,t)) >> moment(0.1,t -> record(:d,t)),
           moment(0.15,t -> record(:c,t)))
end

comp_events,comp_times = find_timing() do record
  addtrial(moment(0.05,t -> record(:a,t)),
           moment(0.05,t -> record(:b,t)) >> moment(0.1,t -> record(:d,t)),
           moment(0.1,t -> record(:c,t)),
           moment(0.1,t -> record(:e,t)))
end

loop_events,loop_index = find_timing() do record
  let i = 0
    @addtrials while i < 3
      addtrial(moment(t -> (i+=1; record(:a,(experiment_trial(),
                                             experiment_offset())))),
               moment(t -> record(:b,(experiment_trial(),experiment_offset()))),
               moment(t -> record(:c,(experiment_trial(),experiment_offset()))))
    end
  end
end

when_events,_ = find_timing() do record
  let test = true
    @addtrials if test
      addtrial(moment(t -> (record(:a,0); test = false)))
    end

    @addtrials if test
      addtrial(moment(t -> (record(:b,0))))
    end
  end
end

check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"

const moment_eps = 1e-3

@testset "Trial Sequencing" begin
  if check_timing
    @testset "Timing" begin
      diffs = abs(0.0005 - diff(many_times))
      middle99 = diffs[quantile(diffs,0.005) .< diffs .< quantile(diffs,0.995)]
      @test mean(middle99) < moment_eps
    end
  end

  @testset "Moment Sequencing" begin
    @test seq_events == [:a,:b,:c]
  end

  @testset "Moment Indexing" begin
    @test seq_trial_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
    @test seq_trial_index == [1,1,1,2,2,2,3,3,3]
  end

  @testset "Compound Moments" begin
    @test comp_events == [:a,:b,:c,:d,:e]
    if check_timing
      comp_diff = maximum(diff(comp_times) - 0.05)
      @test comp_diff < moment_eps
    end
  end

  @testset "Looping Moments" begin
    @test loop_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
    @test loop_index == [(1,1),(1,1),(1,1),(2,1),(2,1),(2,1),(3,1),(3,1),(3,1)]
  end

  @testset "Conditional Moments" begin
    @test when_events == [:a]
  end
end
