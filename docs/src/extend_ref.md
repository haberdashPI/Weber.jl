# Available Extensions

Extensions provide additional functionality.

Currently there are two extensions availble:

* [WeberCedrus](https://github.com/haberdashPI/WeberCedrus.jl.git).
* [WeberDAQmx](https://github.com/haberdashPI/WeberDAQmx.jl.git).

# Creating Extensions

The following functions are used when [extending experiments](extend.md).

## Functions operating over extensions

These functions operate directly on an `ExtendedExperiment`.

```@meta
CurrentModule = Weber
```

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

New `Weber.Moment` subtypes can define methods for the following functions to extend
the possible runtime behavior of Weber.

```@docs
Weber.prepare!
Weber.handle
Weber.delta_t
```
