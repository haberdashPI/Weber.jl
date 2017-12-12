struct WeberSoundHooks <: TimedSound.Hooks
end

function TimedSound.show_latency_warnings(::WeberSoundHooks)
  show_sound_latency_warnings()
end

function show_sound_latency_warnings()
  if in_experiment()
    !info(get_experiment()).warn_on_trials_only || Weber.trial() > 0
  else
    true
  end
end


function TimedSound.on_play(::WeberSoundHooks)
  if in_experiment() && !experiment_running()
    error("You cannot call `play` during experiment `setup`. During `setup`",
          " you should add play to a trial (e.g. ",
          "`addtrial(moment(play,my_sound))`).")
  end
end

TimedSound.tick(::WeberSoundHooks) = Weber.tick()
function TimedSound.on_high_latency(::WeberSoundHooks,latency)
  record("high_latency",value=latency)
end

function TimedSound.on_no_timing(::WeberSoundHooks)
  warn("Cannot guarantee the timing of a sound. Add a delay before playing the",
       " sound if precise timing is required.",moment_trace_string())
end

function TimedSound.get_streamers(::WeberSoundHooks)
  if in_experiment()
    data(get_experiment()).streamers
  else
    error("Cannot stream sounds during setup. Stream a sound within a moment.",
          "(e.g. moment(play,tone(1kHz))")
  end
end
