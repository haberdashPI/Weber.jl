There are several concepts and techniques best avoided unless they are really necessary. These generally complicate the creation of experiments. 

# Stateful Trials

Some experiments require that what trials present depend on responses to
previous trials. For instance, adaptive tracking to find a discrimination
threshold.

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
blocks. The main reason to use such a block is to ensure that 
[`Weber.offset`](@ref) is well defined.

The offset counter is used to fast-forward through the expeirment by specifying
an offset greater than 0.  However, if there is state that changes throughout
the course of several trials, those trials cannot reliably be reproduced when
only some of them are skipped. Either all or none of the trials that depend on
one another should be skipped.

Anytime you have a series of trials, some of which depend on what happens
earlier in an expeirment, such trials should be placed inside of an @addtrials
let block. Otherwise experiment fast forwarding will result in unexpected
behaviors.

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
run during setup-time, before any trials were run (when `y_hit` is false).

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

# Run-time stimulus generation

When stimuli need to be generated during an experiment the normal approach will
not work. For instance, if you want a tone's frequency to depend
on some delta value that changes during the experimrent the following will not work.

```julia
# THIS WILL NOT WORK!!!
moment(play,tone(1kHz+my_delta,1s))
```

The basic problem here is that tone is used to generate a sound at
[setup-time](@ref setup_time). What we want is for the run-time value of
`my_delta` to be used. To do this you can pass a function to play. This function
will be used to generate a sound during runtime.

```julia
moment(play,() -> tone(1kHz+my_delta,1s))
```

Similarly, we can use a runtime value in display by passing a function to display.

```julia
moment(display,() -> "hello $my_name.")
```

When moments are created this way, the sound or visual is generated before the
moment even begins, to eliminate any latency that would be introduced by loading
the sound or visual into memory. Specifically, the stimulus is generated during
the most recent non-zero pause occuring before a moment. So for instance, in the
following example, `mysound` will be generated ~0.5 seconds before play is
called right after "Get ready!" is displayed.

```julia
addtrial(moment(display,"Get ready!"),moment(0.5s),
         moment(display,"Here we go!"),moment(play,mysound))
```

