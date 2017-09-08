
@static if is_windows()
  const windows_time_freq = begin
    x = Array{Int64}()
    if ccall(:QueryPerformanceFrequency,Bool,(Ptr{Int64},),pointer(x))
      x[]
    else
      error("Unsupported operating system. Use Windows XP or later.")
    end
  end
end

const approx_timer_resolution = @static if is_windows()
  1/windows_time_freq
else
  1e-6
end

@static if is_windows()
  function precise_time()
    x = Array{Int64}()
    if !ccall(:QueryPerformanceCounter,Bool,(Ptr{Int64},),pointer(x))
      error("Unsupported operating system. Use Windows XP or later.")
    else
      x[] / windows_time_freq
    end
  end
else
  const precise_time = time
end
