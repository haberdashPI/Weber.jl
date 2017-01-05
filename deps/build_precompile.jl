using SnoopCompile
using Weber

# run build_precompile_csv.jl to generate this csv file
# currently requires that I manually delete one line that casues a parse
# error
data = SnoopCompile.read("/tmp/psychotask_compiles.csv")

pc, discards = SnoopCompile.parcel(data[end:-1:1,2])
SnoopCompile.write("/tmp/precompile", pc)
