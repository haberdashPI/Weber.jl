using Weber
using Base.Test
include("find_timing.jl")

function cause_addtrial_error()
  find_timing() do
    addtrial(1)
  end
end

@testset "Moment Type Checks" begin
  @test cause_reserved_error(:bob,:bob) == nothing
end
