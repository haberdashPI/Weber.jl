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
  run(exp)

  getindex.(recording,1),getindex.(recording,2)
end

# warm up JIT compilation
find_timing() do record
  addtrial(repeated(moment(0.001,t -> record(:a,t)),100))
end

seq_events,seq_times = find_timing() do record
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

# warm up JIT... not sure why this is necessary... again.
# I need to look through precompile.jl and determine
# if I need to find some other way to avoid timing errors
# early in an experiment run (maybe by doing something
# similar to what I'm doing here *within* the run method.)
find_timing() do record
  addtrial(moment(0.05,t -> record(:a,t)),
           moment(0.1,t -> record(:b,t)) >> moment(0.1,t -> record(:d,t)),
           moment(0.15,t -> record(:c,t)))
end

comp_events,comp_times = find_timing() do record
  addtrial(moment(0.05,t -> record(:a,t)),
           moment(0.05,t -> record(:b,t)) >> moment(0.1,t -> record(:d,t)),
           moment(0.1,t -> record(:c,t)))
end

loop_events,loop_index = find_timing() do record
  i = 0
  addtrial(loop=() -> (i+=1; i <= 3),
           moment(t -> record(:a,(experiment_trial(),experiment_offset()))),
           moment(t -> record(:b,(experiment_trial(),experiment_offset()))),
           moment(t -> record(:c,(experiment_trial(),experiment_offset()))))
end

when_events,_ = find_timing() do record
  test = true
  addtrial(when=() -> (test = false; true),moment(t -> record(:a,0)))
  addtrial(when=() -> test,moment(t -> record(:b,0)))
end

check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"

@test seq_events == [:a,:b,:c]
if check_timing
  @test all(abs(diff(seq_times) - 0.01) .< 3Weber.timing_tolerance)
end
@test seq_trial_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
@test seq_trial_index == [1,1,1,2,2,2,3,3,3]
@test comp_events == [:a,:b,:c,:d]
if check_timing
  @test all(abs(diff(comp_times) - 0.05) .< 3Weber.timing_tolerance)
end
@test loop_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
@test loop_index == [(1,1),(1,1),(1,1),(2,1),(2,1),(2,1),(3,1),(3,1),(3,1)]
@test when_events == [:a]
