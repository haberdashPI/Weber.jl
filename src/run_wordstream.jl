# NOTES:

# concernt there is a dealy in when you hear a sream switch and when you
# indicate that switch , sometimes occuring on the *next* stimulus. Might
# make relationship between EEG and beahvioral data difficult to interpret.

# alternative explanation for gap effect: the gap forces a switch to 1 stream,
# meaning that more often than not a gap will occur during a 1 strema response.
# rather than the 1 stream making the gap easier to detect.

include("util.jl")
include("Psychotask.jl")
using Psychotask
using Lazy: @_, @>

# make sure the play function is fully compiled
play(noise(1))

sid = (length(ARGS) > 0 ? ARGS[1] : "test_sid")

sr = 44100.0
s_sound = loadsound("/Users/davidlittle/Downloads/Stimuli for Joel/Canadian/s_natural_ds.wav")
dhone_sound = loadsound("/Users/davidlittle/Downloads/Stimuli for Joel/Canadian/dohne_norm_ds.wav")
dome_sound = loadsound("/Users/davidlittle/Downloads/Stimuli for Joel/Canadian/dome_norm_ds.wav")

s_sound = s_sound[1:end-round(Int,sr*0.027)]

function gapstone(gap)
  sound(attenuate(mix(s_sound,[silence(length(s_sound)/sr+gap); dhone_sound]),20))
end

function gapstome(gap)
  sound(attenuate(mix(s_sound,[silence(length(s_sound)/sr+gap); dome_sound]),20))
end

const ms = 1/1000

stimuli = Dict(
  (:normal,   :nogap,  :w2nw) => gapstone(27ms),
  (:small,    :nogap,  :w2nw) => gapstone(8ms),
  (:negative, :nogap,  :w2nw) => gapstone(-100ms),
  (:normal,   :small,  :w2nw) => gapstone(27ms+20ms),
  (:normal,   :medium, :w2nw) => gapstone(27ms+35ms),
  (:normal,   :large,  :w2nw) => gapstone(27ms+50ms),
  (:normal,   :nogap,  :nw2w) => gapstome(27ms),
  (:small,    :nogap,  :nw2w) => gapstome(8ms),
  (:negative, :nogap,  :nw2w) => gapstome(-100ms),
  (:normal,   :small,  :nw2w) => gapstome(27ms+20ms),
  (:normal,   :medium, :nw2w) => gapstome(27ms+35ms),
  (:normal,   :large,  :nw2w) => gapstome(27ms+50ms)
)

cross = render_text("+")
break_text = render_text("You can take a break. Hit"*
                            " any key when you're ready to resume...")

# We need SOA instead of ISI, becuase otherwise the gap detection
# can be more easily accomplished using duration discrimination
SOA = 672.5ms

n_trials = 60
n_break_after = 10

stimuli_per_phase = 25 # phase = context or test
context_types = [:normal,:small,:negative]
word_types = [:w2nw,:nw2w]

words,contexts = @> begin
  [(w,c) for w in word_types, c in context_types,i in 1:10][:]
  shuffle
  unzip
end

n_gaps = round(Int,stimuli_per_phase*n_trials*0.06/3)
gaps = shuffle([s for s in [:small,:medium,:large], i in 1:n_gaps][:])

gap_positions = @> begin
  [(i,j) for i in 1:n_trials, j in 2:stimuli_per_phase-1][:]
  shuffle
  take(3*n_gaps)
  Set()
end

function asmoment(spacing,gap,stimulus,phase)
  sound = stimuli[spacing,gap,stimulus]
  moment(SOA) do t
    play(sound,false)
    record("stimulus",time=t,stimulus=stimulus,
           spacing=spacing,gap=gap,phase=phase)
  end
end

# TODO: use SDL instead of SFML and make sure this works on Windows.

# TODO: fix timing to skip over pauses correctly. record
# start of each trial

# TODO: create higher level primitives from these lower level primitives
# e.g. continuous response, adpative 2AFC, and constant stimulus 2AFC tasks.

# TODO: rewrite Trial.jl so that it is cleaner, probably using
# a more Reactive style

# TODO: generate errors for any sounds or image generated during
# a moment. Allow a 'dynamic' moment and response object that allows
# for this.

# TODO: only show the window when we call "run"

exp = Experiment(condition = "pilot",sid = sid,version = v"0.0.3") do
  anykey_message = moment() do t
    record("start",time=t,stimulus="none",spacing="none",gap=0,phase="none")
    clear()
    draw("Hit any key to continue...")
    display()
  end

  addbreak(anykey_message,response(e -> iskeydown(e) || endofpause(e)))
  gap_index = 1

  for i in 1:n_trials
    if i > 0 && i % n_break_after == 0
      break_text = render_text("You can take a break. Hit"*
                               " any key when you're ready to resume..."*
                               "\n$(div(i,n_break_after)) of "*
                               "$(div(n_trials,n_break_after)) breaks.")
      message = moment() do t
        record("break")
        clear()
        draw(break_text)
        display()
      end

      addbreak(message,response(e -> iskeydown(e) || endofpause(e)))
    end

    blank = moment() do t
      clear()
      display()
    end

    show_cross = moment(1.5) do t
      clear()
      draw(cross)
      display()
    end

    context = asmoment(contexts[i],:nogap,words[i],"context")
    test = asmoment(:normal,:nogap,words[i],"test")

    play_contexts = repeated(context,stimuli_per_phase)

    play_tests = collect(repeated(test,stimuli_per_phase))
    I = filter(j -> (i,j) in gap_positions,1:stimuli_per_phase)
    play_tests[I] = map(j -> asmoment(:normal,gaps[j],words[i],"test"),
                          gap_index:gap_index+length(I)-1)
    gap_index += length(I)

    addtrial(blank,show_cross,play_contexts...,
             blank,show_cross,play_tests...) do event

      if iskeydown(event,key"q")
        record("stream_1",time = event.time)
      elseif iskeydown(event,key"p")
        record("stream_2",time = event.time)

      elseif iskeyup(event,key"q")
        record("stream_1_off",time = event.time)
      elseif iskeyup(event,key"p")
        record("stream_2_off",time = event.time)

      elseif iskeydown(event,key" ")
        record("gap",time = event.time)

      elseif endofpause(event)
        clear()
        draw(cross)
        display()
      end
    end
  end
end

run(exp)

# prediction: acoustic variations would prevent streaming...
