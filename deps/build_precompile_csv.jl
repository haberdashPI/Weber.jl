using SnoopCompile

file = joinpath(dirname(@__FILE__),"..","examples","streaming.jl")
@eval SnoopCompile.@snoop "/tmp/psychotask_compiles.csv" begin
  ARGS = ["test"]
  include($file)
end
