#!/usr/bin/env julia

using Weber

version = v"0.0.4"
sid,trial_skip =
  @read_args("Runs an intermittant aba experiment, version $version.")

const ms = 1/1000
const st = 1/12
atten_dB = 30

# We might be able to change this to ISI now that there
# is no gap.
tone_len = 60ms
tone_SOA = 144ms
aba_SOA = 4tone_SOA
A_freq = 300
response_spacing = aba_SOA
n_trials = 1600
n_break_after = 75
stimuli_per_response = 2

n_repeat_example = 30
num_practice_trials = 20

function aba(step)
  A = ramp(tone(A_freq,tone_len))
  B = ramp(tone(A_freq * 2^step,tone_len))
  gap = silence(tone_SOA-tone_len)
  sound([A;gap;B;gap;A])
end

medium_st = 8st
stimuli = Dict(:low => aba(3st),:medium => aba(medium_st),:high => aba(18st))

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

function create_aba(stimulus;info...)
  [moment(play,stimuli[stimulus]),
   moment(record,"stimulus",stimulus=stimulus;info...)]
end

# runs an entire trial
function practice_trial(stimulus;limit=response_spacing,info...)
  resp = response(key"q" => "stream_1",key"p" => "stream_2";info...)

  go_faster = visual("Faster!",size=50,duration=500ms,y=0.15,priority=1)
  waitlen = aba_SOA*stimuli_per_response+limit
  min_wait = aba_SOA*stimuli_per_response+response_spacing
  await = timeout(isresponse,waitlen,atleast=min_wait) do time
    record("response_timeout";info...)
    display(go_faster)
  end

  stim = [create_aba(stimulus;info...),moment(aba_SOA)]

  [resp,show_cross(),moment(repeated(stim,stimuli_per_response)),await]
end

function real_trial(stimulus;limit=response_spacing,info...)
  resp = response(key"q" => "stream_1",key"p" => "stream_2";info...)
  stim = [create_aba(stimulus;info...),moment(aba_SOA)]

  [resp,show_cross(),moment(repeated(stim,stimuli_per_response)),
   moment(aba_SOA*stimuli_per_response + limit)]
end

exp = Experiment(sid = sid,condition = "pilot",version = version,
				 separation = "8st",
                 skip=trial_skip,columns = [:stimulus,:phase])

setup(exp) do
  start = moment(record,"start")

  addbreak(
    instruct("""

      In each trial of the present experiment you will hear a series of beeps.
      This may appear to proceeded in a galloping rhythm or it may sound like
      two distinct series of tones."""),

    instruct("""

      For instance, the following example will normally seem to be
      galloping."""))

  addpractice(show_cross(),
              repeated([create_aba(:low,phase="practice"),moment(aba_SOA)],
                       n_repeat_example))

  addbreak(instruct("""

      On the other hand, normally the following example will eventually seem to
      be two separate series of tones."""))

  addpractice(show_cross(),
              repeated([create_aba(:high,phase="practice"),moment(aba_SOA)],
                       n_repeat_example))

  x = stimuli_per_response
  addbreak(
    instruct("""

      In this experiment we'll be asking you to listen for whether it appears
      that the tones "gallop", or are separate from one antoher."""),

    instruct("""

      Every once in a while, we want you to indicate what you heard most often,
      a gallop or separate tones. Let's practice a bit.  Use "Q" to indicate
      that you heard a "gallop" most of the time, and "P" otherwise.  Respond as
      promptly as you can."""))

  addpractice(
    repeated(practice_trial(:medium,phase="practice",limit=10response_spacing),
             num_practice_trials))

  addbreak(instruct("""

    In the real experiment, your time to respond will be limited. Let's
    try another practice round, this time a little bit faster.
  """) )

  addpractice(
    repeated(practice_trial(:medium,phase="practice",limit=2response_spacing),
             num_practice_trials))

  addbreak(instruct("""

    In the real experiment, your time to respond will be even more limited.  Try
    to respond before the next trial begins, but even if you don't please still
    respond."""))

  anykey = moment(display,"Hit any key to start the real experiment...")
  addbreak(anykey,await_response(iskeydown))

  for trial in 1:n_trials
    addbreak_every(n_break_after,n_trials)
    addtrial(real_trial(:medium,phase="test"))
  end
end

play(attenuate(ramp(tone(1000,1)),atten_dB))
run(exp)
