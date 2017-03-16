Functionality can be added to Weber via extensions. You can add multiple
extensions to the same experiment. The [reference](extend_ref.md) provides a
list of available extensions. Here we'll cover how to create new extensions.

To handle multiple extensions properly, so that all extensions work, the
following functions have special extension machinery.

```@meta
CurrentModule = Weber
```

* [`addcolumn`](@ref)
* [`setup`](@ref)
* [`run`](@ref)
* [`record`](@ref)
* [`addtrial`](@ref)
* [`addpractice`](@ref)
* [`addbreak`](@ref)
* [`poll_events`](@ref)

To extend one of these functions you must first define an extension type. For example:

```julia
type MyExtension <: Weber.Extension
  my_value::String
end
```

For all of the public functions above (everything but `poll_events`), you can
then define a new method of these functions that includes one additional
argument beyond that listed in its documentation, located before all other
arguments. This argument should be of type `ExtendedExperiment{MyExtension}`. To
extend the private `poll_events` function, replace the `Experiment` argument
with an `ExtendedExperiment{MyExtension}` argument.

!!! warning "Don't extend unlisted functions"

    These functions have specific machinery setup to make extension possible.
    Don't use the same approach with other functions and expect your extension to work.

As an example, [`record`](@ref) could be extended as follows.

```julia
function record(experiment::ExtendedExperiment{MyExtension},code;keys...)
  record(next(experiment),code;my_extension=extension(experiment).my_value,keys...)
end
```

There are a few things to note about this implementation. First, 
the extension object is accessed using [`extension`](@ref).

Second, `record` is called on the [`next`](@ref) extension.  **All extended
functions should follow this pattern**. Each experiment can have multiple
extensions, and each pairing of an experiment with a particular plugin is called
an experiment *version*. These are ordered from top-most to bottom-most
version. The top-most version is the first extension in the list specified in
the call to [`Experiment`](@ref). Subsequent versions are accessed in this same
order, using [`next`](@ref), until the bottom-most version, which is the
experiment without any paired extension. 

For this extension to actually work, `setup` must also be extended to add the
column `:my_extension` to the data file.

```julia
function setup(fn::Function,experiment::ExtendedExperiment{MyExtension})
  setup(next(experiment)) do
    addcolumn(top(experiment),:my_extension)
    fn()
  end
end
```

This demonstrates one last important concept. When calling `addcolumn`, the
function [`top`](@ref) is called on the experiment to get the top-most version of the
experiment. This is done so that any functionality of versions above the current one will be
utilized in the call to `addcolumn`.

!!! note "When to use `next` and `top`"

    As a general rule, inside an extended method, when you call the same
    function which that method implements, you should pass `next(experiment)`
    while all other functions taking an experiment argument should be passed
    `top(experiment)`.

# The private interface of run-time objects.

Most of the functionality above is for the extension of [setup-time](@ref
setup_time) behavior. However, there are two ways to implement new run-time
behavior: the generation of custom events and custom moments.

## Custom Events

Extensions to [`poll_events`](@ref) can be used to notify watcher functions
of new kinds of events. An event is an object that inherits from `Weber.ExpEvent`
and which is tagged with the [`@event`](@ref) macro. Custom events can implement
new methods for the existing [public functions on events](event.md) or their own
new functions.

If you define new functions, instead of leveraging the existing ones,
they should generally have some default behavior for all `ExpEvent` objects, so
it is easy to call the method on any event a watcher moment receives.

### Event Timing

To specify event timing, you must define a `time` method for your custom event.
You can simply store the time passed to [`poll_events`](@ref) in your custom
event, or, if you have more precise timing information for your hardware you can
store it here. Internally, the value returend by `time` is used to determine
when to run the next moment when a prior moment triggers on the event.

### Custom Key Events

One approach, if you are implementing events for a hardware input device, is to
implement methods for [`iskeydown`](@ref). You can define your own type
of keycode (which should be of some new custom type `<: Weber.Key`). Then, you can
then make use of the [`@key_str`](@ref) macro by adding entries to the
`Weber.str_to_code` dictionary (a private global constant). So for example, you
could add the following to the module implementing your extension.

```julia
Weber.str_to_code["my_button1"] = MyHardwareKey(1)
Weber.str_to_code["my_button1"] = MyHardwareKey(2)
```

Such key types should implement `==`, `hash` and `isless` so that the events can
be ordered. This allows them to be displayed in an organized fashion when
printed using [`listkeys`](@ref).

Once these events are defined you can extend [`poll_events`](@ref) so that it
generates events that return true for `iskeydown(myevent,key"my_button1")` (and
a corresponding method for `iskeyup`). How this happens will depend on the
specific hardware you are supporting. The buttons presses could then checked for
during an experiment as follows.

```julia
response(key"my_button1" => "button1_pressed",
         key"my_button2" => "button2_pressed")
```

## Custom Moments

You can create your own moment types, which must be children of
`Weber.SimpleMoment`. These new moments will have to be generated using some newly
defined function, or added automatically by extending [`addtrial`](@ref). Once
created, and added to trials, these moments will be processed at run-time using
the function [`handle`](@ref), which should define the moment's run-time
behavior.

A moment can also define [`delta_t`](@ref)--to define when it occurs--or
[`prepare!`](@ref)--to have some sort of initialization occur before its
onset--but these both have default implementations.

Methods of [`handle`](@ref) should not make use of the extension machinery
described above. What this means is that methods of [`handle`](@ref) should
never dispatch on an extended experiment, and no calls to [`top`](@ref),
[`next`](@ref) or [`extension`](@ref) should occur on the experiment
object. Further, each moment should belong to one specific extension, in which
all functionality for that custom moment should be implemented.

