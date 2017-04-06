using Weber
using Base.Test
import Weber: prepare!, handle
include("find_timing.jl")

const check_timing = get(ENV,"WEBER_TIMING_TESTS","Yes") != "No"
const moment_eps = 2.5e-3

@testset "Weber" begin
  @testset "Trial Sequencing" begin
    include("test_moment_timing.jl")
    include("test_moment_sequencing.jl")
    include("test_moment_indexing.jl")
    include("test_compound_moments.jl")
    include("test_moment_preparation.jl")
    include("test_moment_looping.jl")
    include("test_moment_conditions.jl")
  end
  include("test_record_columns.jl")
  include("test_moment_checks.jl")
  include("test_extensions.jl")
end
