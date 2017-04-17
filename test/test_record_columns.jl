using Weber
using Base.Test
include("find_timing.jl")

function cause_column_error()
  find_timing() do
    addtrial(moment(record,"test",unspecified_column_name="string"))
  end
end

const reserved_columns = [:reserved, :weber_version, :start_date,
                          :start_time, :offset, :trial, :time]

function cause_reserved_error(decl,use=decl)
  find_timing(columns=[decl]) do
    addtrial(moment(record,"test";[use => "test"]...))
  end
  nothing
end

@testset "Record Columns" begin
  @test_throws ErrorException cause_column_error()
  @test_throws ErrorException cause_reserved_error(:weber_version)
  @test_throws ErrorException cause_reserved_error(:start_date)
  @test_throws ErrorException cause_reserved_error(:start_time)
  @test_throws ErrorException cause_reserved_error(:offset)
  @test_throws ErrorException cause_reserved_error(:trial)
  @test_throws ErrorException cause_reserved_error(:time)
  @test_throws ErrorException cause_reserved_error(:joe,:bob)
end
