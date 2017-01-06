using Weber
using Base.Test

# NOTE: much of the code is interactive and multimedia driven, none of which can
# be tested here. I'm just testing some of the timing of experiments here.

# Tests the timing of an experiment without setting up
# any multimedia resources.
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

@test seq_events == [:a,:b,:c]
@test all(abs(diff(seq_times) - 0.01) .< Weber.timing_tolerance)
@test seq_trial_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
@test seq_trial_index == [1,1,1,2,2,2,3,3,3]
