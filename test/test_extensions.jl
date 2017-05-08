using Weber
using Base.Test
include("find_timing.jl")

import Weber: poll_events

struct ExtensionA <: Weber.Extension end
struct ExtensionB <: Weber.Extension end
mutable struct ExtensionC <: Weber.Extension
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
  addtrial(moment(1ms))
end

_,_,extension_events2 = find_timing(extensions=[ExtensionC(),ExtensionB(),ExtensionA()]) do
  addtrial(moment(1ms))
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
