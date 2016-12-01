include(joinpath(dirname(@__FILE__),"Psychotask.jl"))
using Psychotask

sid = (length(ARGS) > 0 ? ARGS[1] : "test_sid")

sr = 44100.0
s_sound = loadsound("/Users/davidlittle/Downloads/Stimuli for Joel/Canadian/s_natural_ds.wav")
dhone_sound = loadsound("/Users/davidlittle/Downloads/Stimuli for Joel/Canadian/dohne_norm_ds.wav")
s_sound = s_sound[1:end-round(Int,sr*0.027)]

stone = mix(s_sound,
                 [silence(length(s_sound)/sr+0.05); dhone_sound],
                 silence(0.25+(length(s_sound)+length(dhone_sound))/sr))

stone = sound(stone)
not_stream_text = render_text("1 stream",0.75,0.75)
stream_text = render_text("2 streams",-0.75,0.75)
gap_text = render_text("Gap!",0,-0.75)
cross = render_text("+")

n_trials = 60

# TODO: first!! save to git repo

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style

# TODO: create higher level primitives from these lower level primitives
# e.g. continuous response, adpative 2AFC, and constant stimulus 2AFC tasks.

exp = Experiment(condition = "pilot",sid = sid,version = v"0.0.1") do
  anykey_message = moment() do t
    record("start",time=t,stimulus=0)
    clear()
    draw("Hit any key to continue...")
    display()
  end

  addtrial(anykey_message,response(iskeydown))

  for i = 1:n_trials
    blank = moment(0) do t
      clear()
      display()
    end

    show_cross = moment(2) do t
      clear()
      draw(cross)
      display()
    end

    play_stone = moment(0.81) do t
      play(stone)
      record("stimulus",time = t,stimulus = 1)
    end

    addtrial(blank,show_cross,repeated(play_stone,rand(14:17))...) do event
      if iskeydown(event,key"q")
        record("stream_1",time = event.time)
      elseif iskeydown(event,key"p")
        record("stream_2",time = event.time)
      elseif iskeydown(event,key" ")
        record("gap",time = event.time)
      end
    end
  end
end

run(exp)

# prediction: acoustic variations would prevent streaming...
