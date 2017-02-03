Pkg.add("Weber",{{version}})
open("calibrate.jl","w") do s
  print(s,"""
  # call run_calibrate() to select an appropriate attenuation.
  const atten_dB = 30

  # call Pkg.test(\"Weber\"). If the timing test fails, increase
  # moment resolution to avoid warnings.
  const moment_resolution = Weber.default_moment_resolution

  # increase buffer size if you are hearing audible glitches in the sound.
  const buffer_size = 256
  """)
end
