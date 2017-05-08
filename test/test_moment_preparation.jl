using Weber
using Base.Test
include("find_timing.jl")

import Weber: prepare!, handle

struct TestPrepareMoment <: Weber.SimpleMoment
  event::Symbol
end
function handle(exp::Weber.Experiment,queue::Weber.MomentQueue,
                moment::TestPrepareMoment,x)
  Weber.dequeue!(queue)
  true
end

prepare!(moment::TestPrepareMoment) = record(moment.event)

ks,vs,_ = find_timing() do
  addtrial(TestPrepareMoment(:a),moment(0.5s),moment(),moment(),
           TestPrepareMoment(:b),moment(record,:b_post),moment(0.5s))
  addtrial(moment(),TestPrepareMoment(:c),moment(record,:c_post),
           timeout(() -> nothing,iskeydown,0.5s),TestPrepareMoment(:d))
  addtrial(moment(100ms),TestPrepareMoment(:e) >> TestPrepareMoment(:f))
end
prepare_timing = Dict(k => v for (k,v) in zip(ks,vs))

expanding_prepare,_,_ = find_timing() do
  @addtrials let test = 1
    addtrial(TestPrepareMoment(:a))
  end
end

struct TestPrepareError <: Weber.SimpleMoment end
function handle(exp::Weber.Experiment,queue::Weber.MomentQueue,
                moment::TestPrepareError,x)
  Weber.dequeue!(queue)
  true
end
struct TestPrepareException <: Exception end
prepare!(moment::TestPrepareError,time::Float64) =
  isinf(time) ? throw(TestPrepareException()) : record(:success)

function cause_prepare_error1()
  find_timing() do
    addtrial(moment(0.5s),timeout(() -> nothing,iskeydown,0.5s),TestPrepareError())
  end
end

prepare_noerror,_,_ = find_timing() do
  addtrial(moment(0.5s),TestPrepareError())
end

@testset "Moment Preparation" begin
  @test :a in keys(prepare_timing)
  @test :d in keys(prepare_timing)
  @test :e in keys(prepare_timing)
  @test :f in keys(prepare_timing)
  @test :a in expanding_prepare
  @test abs(prepare_timing[:b_post] - prepare_timing[:b] - 0.5) < 0.25
  @test abs(prepare_timing[:c_post] - prepare_timing[:c] - 0.5) < 0.25
  @test_throws TestPrepareException cause_prepare_error1()
  @test prepare_noerror == [:success]
end
