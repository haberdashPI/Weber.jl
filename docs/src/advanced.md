There are several concepts and techniques best avoided unless they are really necessary. These generally complicate the creation of experiments. 

# Long-form moments

Long-form moments generally follow the following pattern.

```julia
mysound = sound(tone(1000,1))
myvisual = visual("Hello, World!")
moment(0.5) do
  play(mysound)
  display(myvisual)
end
```

Note that this particular moment could just as easily be created as follows.

```julia
[moment(play,tone(1000,1)),moment(display,"Hello, World!")]
```

This demonstrates the key difference in long-form moments: visuals and sounds must
be explicitly prepared using [`sound`](@ref) and [`visual`](@ref). This should normally occur
during start-up time. Short form moments dispatch on the type of function specified
and so can automatically call sound and visual.

Long-form moments can make it easier to specify more complicated functionality. Just remember to explicitly prepare stimuli when taking this approach.

# Stateful Trials

Some experiments require that what trials present depend on responses to previous trials. For instance, adaptive tracking to find a discrimination threshold.

If your trials depend on experiment-changing state, you need to use the macro [`@addtrials`](@ref).

There are three kinds of trials you can add with this macro: blocks,
conditionals and loops.

## Blocks of Trials

    @addtrials let [assignments]
      body...
    end

Blocks of trials are useful for setting up state that will change during the
trials. Such state can then be used in a subsequent @addtrials expression. In
fact all other types of @addtrials expression will likely be nested inside
blocks. The main reason to use such a block is to ensure that the offset counter
is appropriately set with stateful trials.

The offset counter is meant to refer to a well defined time during the
experiment.  They can be used to fast forward through the expeirment by
specifying an offset greater than 0.  However, if there is state that changes
throughout the course of several trials, trials that follow these state changes
cannot be reliably reproduced when those state-chaning trials are skipped
because the user specifies an offset > 0. Thus anytime you have
a series of trials, some of which depend on the state of one another, those
trials should be placed inside of an @addtrials let block if you want
fast-forwarding through parts of the experiment to work as expected.

## Conditional Trials

    @addtrials if [cond1]
      body...
    elseif [cond2]
      body...
    ...
    elseif [condN]
      body...
    else
      body...
    end

Adds one or mores trials that are presented only if the given conditions are
met. The expressions `cond1` through `condN` are evaluted during the experiment,
but each `body` is executed before the experiment begins, and is used to
indicate the set of trials (and breaks or practice trials) that will be run for
a given condition.

For example, the following code only runs the second trial if the user
hits the "y" key.

    @addtrials let y_hit = false
      isresponse(e) = iskeydown(e,key"y") || iskeydown(e,key"n")
      addtrial(moment(display,"Hit Y or N."),await_response(isresponse)) do event
        if iskeydown(event,key"y")
          y_hit = true
        end
      end

      @addtrials if !y_hit
        addtrial(moment(display,"You did not hit Y!"),await_response(iskeydown))
      end
    end

If `@addtrials if !y_hit` was replaced with `if !y_hit` in the above example,
the second trial would always run. This is because the `if` expression would be
evaluated before any trials were run (when `y_hit` is false).

## Looping Trials

    @addtrials while expr
      body...
    end

Add some number of trials that repeat as long as `expr` evalutes to true.
For example the follow code runs as long as the user hits the "y" key.

    @addtrials let y_hit = true
      @addtrials while y_hit
        message = moment(display,"Hit Y if you want to continue")
        addtrial(message,await_response(iskeydown)) do event
          y_hit = iskeydown(event,key"y")
        end
      end
    end

If `@addtrials while y_hit` was replaced with `while y_hit` in the above
example, the while loop would never terminate, running an infinite loop, because
`y_hit` is true before the experiment starts.

# Run-time stimulus generation.

When stimuli need to be generated during an experiment the standard short-form moment will not do. Rather than resorting to long-form moments, a short-form moment calling `play` or `display` can take a zero-argument function rather than a sound or a visual. This function should return a sound or visual (like all short form moments, these need not explicitly call
`sound` or `visual`).

For example:

```julia
moment(play,() -> tone(1000+my_delta,1))
```

This moment plays a one second tone at frequency 1000+my_delta. The key point is that my_delta can be modified during the experiment, thus altering what sound will be generated.
