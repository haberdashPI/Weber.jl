Pkg.add("Weber",{{version}})
open("calibrate.jl","w") do s
  println(s,"# call run_calibrate() to select an appropriate attenuation.")
  println(s,"const atten_dB = 30")
  println(s,"")
  println(s,"# call Pkg.test(\"Weber\"). If the timing test fails, increase ")
  println(s,"# moment resolution to avoid warnings.")
  println(s,"const moment_resolution = Weber.default_moment_resolution")
  println(s,"")
  println(s,"# increase buffer size if you are hearing audible glitches in the sound.")
  println(s,"const buffer_size = 256")
end
