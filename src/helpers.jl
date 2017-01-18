export run_keycode_helper, run_calibrate, create_new_project
using DataStructures

function run_keycode_helper()
  exp = Experiment(hide_output=true)
  setup(exp) do
    addbreak(instruct("Press keys to see their codes."))
    addtrial(show_cross(),await_response(iskeydown(key":escape:"))) do event
      if iskeydown(event)
        display(visual(string(keycode(event))))
      end
    end
  end

  run(exp)
end

function run_calibrate()
  exp = Experiment(hide_output=true)
  freqs = [100,250,500,1000,2000,4000,6000,8000]
  atten = collect(20.0 for f in freqs)
  tones = map(freqs) do f
    ramp(tone(f,10))
  end

  old_tone = nothing

  playing = 1
  key_to_tone(e::KeyDownEvent) = key_to_tone(keycode(e))
  key_to_tone(e::KeyboardKey) = e.code - key"1".code + 1
  key_to_tone(e) = 0

  tone_text() = visual("$(freqs[playing]) Hz, $(-round(atten[playing],2))"*
                       " dB tone",y=-0.5)

  setup(exp) do
    instructions = moment() do t
      old_tone = play(sound(attenuate(tones[1],atten[1])))
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
          old_tone == nothing || stop(old_tone)
          old_tone = play(sound(attenuate(tones[playing],atten[playing])))
          display(tone_text())
        elseif keycode(e) ∈ keys(atten_adjust)
          old_tone == nothing || stop(old_tone)
          atten[playing] -= atten_adjust[keycode(e)]
          old_tone = play(sound(attenuate(tones[playing],atten[playing])))
          display(tone_text())
        end
      end
    end
  end

  run(exp)
  return OrderedDict(f => atten for (f,atten) in zip(freqs,atten))
end

"""
   create_new_project(name,dir=".")

Creates a set of files to help you get started on a new experiment.

This creates a file called run_[name].jl, and a README.md and setup.jl file
for your expeirment. The readme provides useful information for running
the experiment that is common across all expeirments. The run file
provides some guidelines to get you started creating an experiment and
setup is a script that can be used to install Weber and an additional
dependencies for the project, for anyone who wants to download and run your
experiment.
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
