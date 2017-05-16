# Available Extensions

Extensions provide additional functionality for Weber. Currently there are two
extensions availble:

```@docs
@Cedrus
@DAQmx
```
# Creating Extensions

The following functions are used when [extending experiments](extend.md).

To register your extension within Weber, so users can import your extension with
ease, you use can use the `@extension` macro.

```@docs
Weber.@extension
```

## Functions operating over extensions

These functions operate directly on an `ExtendedExperiment`.

```@docs
next(::ExtendedExperiment)
top(::Experiment)
extension(::ExtendedExperiment)
```

## Extendable Private Functions

```@docs
Weber.poll_events
```

## Private Moment Functions

New `Weber.SimpleMoment` subtypes can define methods for the following functions to extend
the runtime behavior of Weber.

```@docs
Weber.prepare!
Weber.handle
Weber.moment_trace
Weber.delta_t
```
