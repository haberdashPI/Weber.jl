export run_keycode_helper, run_calibrate, create_new_project
using DataStructures
using Lazy: @>
"""
    run_keycode_helper(;extensions=[])

Runs a program that will display the keycode for each key that you press.
"""
function run_keycode_helper(;extensions=Extension[])
  result = @spawn run_keycode_helper__(extensions=extensions)
  fetch(result)
end

function run_keycode_helper__(;extensions=Extension[])
  exp = Experiment(hide_output=true,extensions=extensions)
  setup(exp) do
    addbreak(instruct("Press keys to see their codes."))
    addtrial(show_cross(),await_response(iskeydown(key":escape:"))) do event
      if iskeydown(event)
        display(visual(string(keycode(event))))
      end
    end
  end

  run(exp,await_input=false)
end

"""
   run_calibrate()

Runs a program that will allow you to play pure tones and adjust their level.

This program provides one means of calibrating the levels of sound in
your experiment. Using a sound-level meter you can determine the dB SPL of
each tone, and adjust the attenuation to achieve a desired sound level.
"""
function run_calibrate()
  result = @spawn run_calibrate__()
  fetch(result)
end

function run_calibrate__()
  exp = Experiment(hide_output=true)
  freqs = [100,250,500,1000,2000,4000,6000,8000]
  atten = collect(20.0 for f in freqs)
  old_tone = nothing

  playing = 1
  key_to_tone(e::KeyDownEvent) = key_to_tone(keycode(e))
  key_to_tone(e::KeyboardKey) = e.code - key"1".code + 1
  key_to_tone(e) = 0

  tone_text() = visual("$(freqs[playing]) Hz, $(-round(atten[playing],2))"*
                       " dB tone",y=-0.5)

  setup(exp) do
    instructions = moment() do
      @> tone(freqs[playing]) attenuate(atten[playing]) fadeto
      display(visual("Hit 1-8 to play a tone.",y=0.75,duration=Inf) +
              visual("Hit - or = to adjust dB by 10 dB\n"*
                     "Hit [ or ] to adjust dB by 1 dB\n"*
                     "Hit ; or ' to adjust dB by 0.1 dB\n"*
                     "Hit , or . to adjust dB by 0.01 dB\n",
                     clean_whitespace=false,y=0.25,duration=Inf) +
              visual("$(freqs[1]) Hz, $(-atten[1]) dB tone",y=-0.5))
    end
    atten_adjust = Dict(key"-" => -10,   key"=" => +10,
                        key"[" => -1,    key"]" => +1,
                        key";" => -0.1,  key"'" => +0.1,
                        key"," => -0.01, key"." => +0.01)

    addtrial(instructions,await_response(iskeydown(key":escape:"))) do e
      if iskeydown(e)
        if 1 <= (p = key_to_tone(e)) <= 8
          playing = p
          @> tone(freqs[playing]) attenuate(atten[playing]) fadeto
          display(tone_text())
        elseif keycode(e) ∈ keys(atten_adjust)
          atten[playing] -= atten_adjust[keycode(e)]
          @> tone(freqs[playing]) attenuate(atten[playing]) fadeto
          display(tone_text())
        end
      end
    end
  end

  run(exp,await_input=false)
  return OrderedDict(f => atten for (f,atten) in zip(freqs,atten))
end

"""
    create_new_project(name,dir=".")

Creates a set of files to help you get started on a new experiment.

This creates a file called run_[name].jl, and a README.md and setup.jl file for
your experiment. The readme provides useful information for running the
experiment that is common across all experiments. The run file provides some
guidelines to get you started creating an experiment and the setup file is a
script that can be used to install Weber and any additional dependencies for the
project, for anyone who wants to download and run your experiment.
"""

function create_new_project(name,dir=".")
  values = Dict(r"{{project}}" => name,
                r"{{weber_dir}}" => abspath(joinpath(dirname(@__FILE__),"..")),
                r"{{version}}" => "v\"$(Weber.version)\"")

  apply_template(joinpath(dirname(@__FILE__),"..","templates","README.md"),
                 joinpath(dir,"README.md"),values)
  apply_template(joinpath(dirname(@__FILE__),"..","templates","setup.jl"),
                 joinpath(dir,"setup.jl"),values)
  apply_template(joinpath(dirname(@__FILE__),"..","templates","run_project.jl"),
                 joinpath(dir,"run_$name.jl"),values)
  apply_template(joinpath(dirname(@__FILE__),"..","templates",".gitignore"),
                 joinpath(dir,".gitignore"),values)
end

function apply_template(sourcefile,destfile,values)
  open(sourcefile,"r") do source
    open(destfile,"w") do dest
      for line in readlines(source)
        for (pat,result) in values
          line = replace(line,pat,result)
        end
        write(dest,line)
      end
    end
  end
end
