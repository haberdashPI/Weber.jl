using Weber
using Base.Test
import Weber: prepare!, handle

# this allows a test of timing for an experiment without setting up any
# multimedia resources, so it can be run just about anywhere.
function find_timing(fn;keys...)
  empty!(Weber.null_record)
  exp = Experiment(;null_window=true,hide_output=true,keys...)
  setup(() -> fn(),exp)

  run(exp,await_input=false)

  nostarts = filter(x -> !endswith(string(x[:code]),"_start") &&
                    x[:code] != "terminated" &&
                    x[:code] != "closed",
                    Weber.null_record)
  map(x -> x[:code],nostarts),map(x -> x[:time],nostarts),nostarts
end

_,many_times,_ = find_timing() do
  addtrial(repeated(moment(0.0005,() -> record(:a)),1000))
end

seq_events,_,_ = find_timing() do
  addtrial(moment(0.01,() -> record(:a)),
           moment(0.01,() -> record(:b)),
           moment(0.01,() -> record(:c)))
end

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

type TestPrepareMoment <: Weber.SimpleMoment
  event::Symbol
end
function handle(exp::Weber.Experiment,queue::Weber.MomentQueue,
                moment::TestPrepareMoment,x)
  Weber.dequeue!(queue)
  true
end

prepare!(moment::TestPrepareMoment) = record(moment.event)

ks,vs,_ = find_timing() do
  addtrial(TestPrepareMoment(:a),moment(0.5),moment(),moment(),
           TestPrepareMoment(:b),moment(record,:b_post),moment(0.5))
  addtrial(moment(),TestPrepareMoment(:c),moment(record,:c_post),
           timeout(() -> nothing,iskeydown,0.5),TestPrepareMoment(:d))
  addtrial(moment(0.1),TestPrepareMoment(:e) >> TestPrepareMoment(:f))
end
prepare_timing = Dict(k => v for (k,v) in zip(ks,vs))

type TestPrepareError <: Weber.SimpleMoment end
function handle(exp::Weber.Experiment,queue::Weber.MomentQueue,
                moment::TestPrepareError,x)
  Weber.dequeue!(queue)
  true
end
type TestPrepareException <: Exception end
prepare!(moment::TestPrepareError,time) =
  isinf(time) ? throw(TestPrepareException()) : record(:success)

function cause_prepare_error1()
  find_timing() do
    addtrial(moment(0.5),timeout(() -> nothing,iskeydown,0.5),TestPrepareError())
  end
end

prepare_noerror,_,_ = find_timing() do
  addtrial(moment(0.5),TestPrepareError())
end

type ExtensionA <: Weber.Extension end
type ExtensionB <: Weber.Extension end
type ExtensionC <: Weber.Extension
  triggered::Bool
end
ExtensionC() = ExtensionC(false)

import Weber: setup, record, poll_events, run

function setup(fn::Function,e::ExtendedExperiment{ExtensionA})
  setup(next(e)) do
    addcolumn(top(e),:extension_a)
    fn()
  end
end

function record(e::ExtendedExperiment{ExtensionA},code;kwds...)
  record(next(e),code;extension_a = :test,kwds...)
end

function setup(fn::Function,e::ExtendedExperiment{ExtensionB})
  setup(next(e)) do
    addcolumn(top(e),:extension_b)
    fn()
  end
end

function record(e::ExtendedExperiment{ExtensionB},code;kwds...)
  record(next(e),code;extension_b = :test,kwds...)
end

function run(e::ExtendedExperiment{ExtensionB};keys...)
  record(top(e),:extension_b_run)
  run(next(e);keys...)
end

function poll_events(callback,e::ExtendedExperiment{ExtensionC},time::Float64)
  if !extension(e).triggered
    extension(e).triggered = true
    record(top(e),:extension_c_polled)
  end
  poll_events(callback,next(e),time)
end

_,_,extension_events1 = find_timing(extensions=[ExtensionA(),ExtensionB(),ExtensionC()]) do
  addtrial(moment(0.001))
end

_,_,extension_events2 = find_timing(extensions=[ExtensionC(),ExtensionB(),ExtensionA()]) do
  addtrial(moment(0.001))
end

check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"

const moment_eps = 1e-3

@testset "Weber" begin
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

    @testset "Moment Preparation" begin
      @test :a in keys(prepare_timing)
      @test :d in keys(prepare_timing)
      @test :e in keys(prepare_timing)
      @test :f in keys(prepare_timing)
      @test abs(prepare_timing[:b_post] - prepare_timing[:b] - 0.5) < 0.25
      @test abs(prepare_timing[:c_post] - prepare_timing[:c] - 0.5) < 0.25
      @test_throws TestPrepareException cause_prepare_error1()
      @test prepare_noerror == [:success]
    end

    @testset "Looping Moments" begin
      @test loop_events == [:a,:b,:c,:a,:b,:c,:a,:b,:c]
      @test loop_index == [(1,1),(1,1),(1,1),(2,1),(2,1),(2,1),(3,1),(3,1),(3,1)]
    end

    @testset "Conditional Moments" begin
      @test when_events == [:a]
      @test elseif_events == [:a,:b,:c]
    end
  end
  @testset "Extensions" begin
    extension_event1 = filter(r -> r[:code] == :extension_c_polled,extension_events1)
    extension_event2 = filter(r -> r[:code] == :extension_c_polled,extension_events2)
    @test extension_event1[1][:extension_a] == :test
    @test extension_event1[1][:extension_b] == :test
    @test extension_event2[1][:extension_a] == :test
    @test extension_event2[1][:extension_b] == :test

    extension_b_run1 = filter(r -> r[:code] == :extension_b_run,extension_events1)
    extension_b_run2 = filter(r -> r[:code] == :extension_b_run,extension_events2)
    @test length(extension_b_run1) == 1
    @test length(extension_b_run2) == 1
  end
end
