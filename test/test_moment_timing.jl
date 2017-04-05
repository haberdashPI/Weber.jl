_,many_times,_ = find_timing() do
  addtrial(repeated(moment(0.0005,() -> record(:a)),1000))
end

if check_timing
  @testset "Timing" begin
    diffs = abs(0.0005 - diff(many_times))
    middle99 = diffs[quantile(diffs,0.005) .< diffs .< quantile(diffs,0.995)]
    @test mean(middle99) < moment_eps
  end
end
