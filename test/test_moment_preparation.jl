
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
