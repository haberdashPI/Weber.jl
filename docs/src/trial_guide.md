We'll look in detail at how to create trials of an experiment. For a broad overview of trial creation refer to [Getting Started](start.md). The two basic steps to creating a trial are (1) defining a set of moments and (2) adding those moments to a trial.

# Defining Moments

Trials are composed of moments. There are several types of moments: timed
moments, compound moments, watcher moments, and conditional moments, each of
which have somewhat different effects during a trial.

## Timed Moments

Timed moments are the simplest kind of moment. They are are normally created by calling [`moment`](@ref).

```julia
moment([delta_t],[fn],args...;keys...)
```

A timed moment waits `delta_t` seconds after the onset of the previous moment, and then runs the specified function (`fn`), if any, passing it any `args` and `keys` provided. Below is an example of creating a timed moment.

```julia
moment(0.5s,play,mysound)
```

This moment plays `mysound` 0.5 seconds after the onset of the previous moment.

There are several other kinds of timed moments, other than those created by calling [`moment`](@ref). Specifically, [`timeout`](@ref) and [`await_response`](@ref) wait for a particular event to occur (such as a key press) before they begin.

### Guidlines for low-latency moments

Weber aims to present moments at low latencies for accurate experiments.

To maintain low latency, as much of the experimental logic as possible should be precomputed, outside of trial moments, during [setup time](@ref setup_time). The following operations are definitely safe to perform during a moment:

1. Calls to [`play`](@ref) to present a sound
2. Calls to [`display`](@ref) to present a visual.
3. Calls to [`record`](@ref) to save something to a data file (usually after any calls
   to [`play`](@ref) or [`display`](@ref))

Note that Julia compiles functions on demand (known as just-in-time or JIT compilation), which can lead to very slow runtimes the first time a function runs.  To minimize JIT compilation during an experiment, any functions called directly by a moment are first precompiled.

!!! warning "Keep Moments Short"

    Long running moments will lead to latency issues. Make sure all
    functions that run in a moment terminate relatively quickly.

!!! warning "Sync visuals to the refresh rate."

    Visuals synchronize to the screen refresh rate. You can 
    find more details about this in the documentation of [`display`](@ref)

## Compound Moments

You can create more complicated moments by concatenating simpler moments together using the `>>` operator or `moment(moment1,moment2,...)`.

A concatenation of moments starts immediately, proceeding through each of the moments in order. This allows for a more complex relationship in inter-moment timing. For example, the following code will present two sounds, one at 100 ms, the other 200 ms after the start of the trial. It will also display "Too Late!"  on the screen if no keyboard key is pressed 150 ms after the start of the trial.

```julia
addtrial(moment(100ms,play,soundA) >> moment(100ms,play,soundB),
         timeout(() -> display("Too Late!"),iskeydown,150ms))
```

This exact sequence of timing would not be possible without using the `>>` operator because the timing of the `timeout` moment depends on user input, and we want soundB to be played at a reliable time.

## Watcher Moments

Watcher moments are used to respond to events. Often, watcher moments need not be directly used. Instead, the higher level [`response`](@ref) method can be used.

As long as a watcher moment is active it occurs any time an event is triggered. A watcher moment becomes active at the start of the preceding moment, or at the start of a trial (if it's the first moment in a trial). This latter form is most common, since generally one wishes to listen to all events during a trial. A watcher moments is simply a function that takes one argument: the event to be processed.

If the watcher is the first moment in a trial, the convenient `do` block syntax is possible.

```julia
message = visual("You hit spacebar!")
addtrial(moment2,moment3) do event
  if iskeydown(key":space:")
    display(message,duration=500ms)
    record("spacebar_hit")
  end
end
```

In the above example, "You hit spacebar!" is displayed for 500 ms every time the spacebar is hit.

Refer to the documentation for [Events](event.md) for full details on how to respond to events.

## Conditional Moments

Conditional moments are a more advanced technique for creating moments and aren't normally necessary. They run a function only when a certain condition is true (the [`when`](@ref) moment) or repeat a function until a condition is false (the [`looping`](@ref) moment). They require a good understanding of the difference between [setup- and run-time](@ref setup_time), [anonymous functions](http://docs.julialang.org/en/stable/manual/functions/#anonymous-functions), and [scoping rules](http://docs.julialang.org/en/stable/manual/variables-and-scoping/) in julia.

# Adding Trials

Normally, to add moments to a trial you simply call [`addtrial`](@ref). There is also [`addpractice`](@ref), and [`addbreak`](@ref). These functions are nearly identical to [`addtrial`](@ref) but differ in how they update the trial and offset counters, and what they automatically [`record`](@ref) to a data file.

All of these functions take a series of iterable objects of moments. The moments of all arguments are added in sequence. For convenience these iterables can be nested, allowing functions that return multiple moments themselves to be easily passed to [`addtrial`](@ref) just as one would pass a single moment to [`addtrial`](@ref).
