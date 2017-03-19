Pkg.add("Weber",{{version}})
if !isfile("calibrate.jl")
  open("calibrate.jl","w") do s
    print(s,"""
    # call run_calibrate() to select an appropriate attenuation.
    const atten_dB = 30

    # call Pkg.test(\"Weber\"). If the timing test fails, increase
    # moment resolution to avoid warnings.
    const moment_resolution = 0.0015
    """)
  end
end
