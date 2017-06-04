Some experiments require the use of an adaptive adjustment of a stimulus based on participant responses. There are several basic adaptive tracking algorithms built into Weber, and you can also implement your own as well.

# Using an Adaptive Track

To use an adaptive track in your experiment, you need to make use of some of the
[advanced features](advanced.md) of Weber. In this section we'll walk through
the necessary steps, using a simple frequency discrimination experiment.

In this experiment, on each trial, listeners hear a low and a high tone, separated in frequency by an adaptively adjusted delta. Their task is to indicate which tone is lower, and the delta is adjusted to determine the difference in frequency at which listeners respond with 79% accuracy. The entire example code is provided below. 

```julia
using Weber

version = v"0.0.3"
sid,trial_skip,adapt = @read_args("Frequency Discrimination ($version).",
                                  adapt=[:levitt,:bayes])

const atten_dB = 30
const n_trials = 60
const feedback_delay = 750ms

isresponse(e) = iskeydown(e,key"p") || iskeydown(e,key"q")

const standard_freq = 1kHz
const standard = @> tone(standard_freq,100ms) ramp attenuate(atten_dB)

function one_trial(adapter)
  first_lower = rand(Bool)
  resp = response(adapter,key"q" => "first_lower",key"p" => "second_lower",
                  correct=(first_lower ? "first_lower" : "second_lower"))

  signal() = @> tone((1-delta(adapter))*standard_freq,100ms) begin
    ramp
    attenuate(atten_dB)
  end
  stimuli = first_lower? [signal,standard] : [standard,signal]

  [moment(feedback_delay,play,stimuli[1]),
   show_cross(),
   moment(900ms,play,stimuli[2]),
   moment(100ms + 300ms,display,
          "Was the first [Q] or second sound [P] lower in pitch?"),
   resp,await_response(isresponse)]
end

experiment = Experiment(
  skip=trial_skip,
  columns = [
    :sid => sid,
    :condition => "example",
    :version => version,
    :standard => standard_freq
  ]
)

setup(experiment) do
  addbreak(moment(record,"start"))

  addbreak(instruct("""

    On each trial, you will hear two beeps. Indicate which of the two beeps you
heard was lower in pitch. Hit 'Q' if the first beep was lower, and 'P' if the
second beep was lower.
"""))

  if adapt == :levitt
    adapter = levitt_adapter(down=3,up=1,min_delta=0,max_delta=1,
                             big=2,little=sqrt(2),mult=true)
  else
    adapter = bayesian_adapter(min_delta = 0,max_delta = 0.95)
  end

  @addtrials let a = adapter
    for trial in 1:n_trials
      addtrial(one_trial(a))
    end

    function threshold_report()
      mean,sd = estimate(adapter)
      thresh = round(mean,3)*standard_freq
      thresh_sd = round(sd,3)*standard_freq

      # define this string during run time when we know
      # what the threshold estimate is.
      "Threshold $(thresh)Hz (SD: $thresh_sd)\n"*
      "Hit spacebar to continue..."
    end

    addbreak(moment(display,threshold_report,clean_whitespace=false),
             await_response(iskeydown(key":space:")))
  end

end

run(experiment)
```

In what follows we'll walk through the parts of this code unique to creating an adaptive track. For more details on the basics of creating an experiment see [Getting Started](start.md).

## Creating the Adapter
```julia
if adapt == :levitt
  adapter = levitt_adapter(down=3,up=1,min_delta=0,max_delta=1,
                           big=2,little=sqrt(2),mult=true)
else
  adapter = bayesian_adapter(min_delta = 0,max_delta = 0.95)
end
```

The present experiment can be run using either of two built-in adapters: [`levitt_adapter`](@ref) and [`bayesian_adapter`](@ref). An adapter
is the object you create to run an adaptive track, and defines the particular algorithm that will be used to select a new delta on each trial, based on the responses to previous deltas. 

## Generating Stimuli

```julia
const standard = attenuate(ramp(tone(standard_freq,0.1s)),atten_dB)
...
signal() = attenuate(ramp(tone(standard_freq*(1-delta(adapter)),0.1s)),atten_dB)
stimuli = first_lower? [signal,standard] : [standard,signal]
```

The two stimuli presented to the listener are the standard (always at 1kHz) and the signal (1kHz - delta). The standard is always the same, and so can be generated in advance before the experiment begins. The signal must be generated during the experiment, on each trial. The next delta is queried from the adapter using [`delta`](@ref). The signal is defined as a function that takes no arguments. When passed a function, [`play`](@ref) generates the stimulus defined by that function at runtime, rather than [setup time](@ref setup_time), which is precisely what we want in this case.

## Collecting Responses

```julia
resp = response(adapter,key"q" => "first_lower",key"p" => "second_lower",
                  correct=(first_lower ? "first_lower" : "second_lower"))
```

To update the adapter after each response, a special method of the [`response`](@ref) function is used, which takes the adapter as its first argument. We also must indicate which response is correct by setting `correct` appropriately.

## Generating Trials

```julia
@addtrials let a = adapter
  for trial in 1:n_trials
    addtrial(one_trial(a))
  end
  addbreak(moment(display,() -> "Estimated threshold: $(estimate(adapter)[1])\n",
                                "Hit spacebar to exit."),
           await_response(iskeydown(key":space:")))
end
```

To generate the trials, which depend on the run-time state of the adapter, we use the [`@addtrials`](@ref) macro. Any time the behavior of listeners in one trial influences subsequent trials, this macro will be necessary. In this case it is used to signal to Weber that the trials added inside the loop depend on the run-time state of the adapter.

After all trials have been run, we report the threshold estimated by the adapter
using the [`estimate`](@ref) function, which returns both the mean and
measurement error.

# Reporting the Threshold

```julia
function threshold_report()
  mean,sd = estimate(adapter)
  thresh = round(mean,3)*standard_freq
  thresh_sd = round(sd,3)*standard_freq

  # define this string during run time when we know
  # what the threshold estimate is.
  "Threshold $(thresh)Hz (SD: $thresh_sd)\n"*
  "Hit spacebar to continue..."
end

addbreak(moment(display,threshold_report,clean_whitespace=false),
         await_response(iskeydown(key":space:")))
```

You can report the threshold at the end of an experiment using
[`estimate`](@ref), as above, but this isn't strictly necessary. The tricky part
is to make sure you find the estimate *after* trials have been run (during run
time).

# Custom Adaptive Tracking Algorithms

You can define your own adaptive tracking algorithms by defining a new type that is a child of `Adapter`. You must define an appropriate function to generate the adapter, and methods of [`Weber.update!`](@ref), [`estimate`](@ref) and [`delta`](@ref) for this type. Strictly speaking estimate need not be implemented, if you choose not to make use of this method in your experiment.
