Functionality can be added to Weber via extensions. You can add multiple extensions to the same experiment. To handle multiple extensions properly, so that all extensions work, the following methods have special extension machinery.

```@meta
CurrentModule = Weber
```

* [`addcolumn`](@ref)
* [`setup`](@ref)
* [`run`](@ref)
* [`record`](@ref)
* [`addtrial`](@ref)
* [`addbreak`](@ref)
* [`poll_events`](@ref)

To extend one of these functions you define an extension type. For example:

```julia
type MyExtension <: Weber.Extension
  my_value::String
end
```

For all fo the public functions above (everything but `poll_events`), you define
a new method of these functions that includes one additional argument beyond
that listed in its documentation, located before all other arguments. This
argument should be of type `ExtendedExperiment{MyExtension}`. To extend the
private `poll_events` function, replace the `Experiment` argument with an
`ExtendedExperiment{MyExtension}` argument.

!!! warning "Don't extend unlisted functions"

    These functions have specific machinery setup to make extension possible.
    Don't use the same approach with other functions and expect your extension to work.

As an example, [`record`](@ref) could be extended as follows.

```julia
function record(experiment::ExtendedExperiment{MyExtension},code;keys...)
  record(next(experiment),code;my_extension=extension(experiment).my_value,keys...)
end
```

There are a few things to note about this implementation. First, it accesses
the extension object in the experiment using `extension`.

Second, each experiment can have multiple extensions, so each subsequent
*version* of the experiment must be dispatched over. Each version of an
experiment refers to the experiment paired with one of its extensions. The
top-most version is the first extension specified in the call to
[`Experiment`](@ref), the bottom-most the experiment without any extensions.  As
all extensions should, the above method calls the function being extended
(`record`) in its body, but dispatching over the next experiment version. In
this way, all behavior from each extension, and the base experiment, without any
extensions, is executed. The next version is accessed using the [`next`](@ref)
function.

For this extension to actually work, `setup` must also be extended to add the column `:my_extension` to the data file.

```julia
function setup(fn::Function,experiment::ExtendedExperiment{MyExtension})
  setup(next(experiment)) do
    addcolumn(top(experiment),:my_extension)
    fn()
  end
end
```

This demonstrates one last important concept. When calling `addcolumn`, the function `top` is called on the experiment to get the top-most version of the experiment, so that any functionality of versions above the current one will be utilized in the call to `addcolumn`.

# The private interface of run-time objects.

Most of the functionality above allows the extension of [`setup-time`](@ref setup_time) functionality. However, there are two ways to implement new run-time functionality: the generation of new kinds of events and the creation of new kinds of moments.

## Custom Events

Extensions to [`poll_events`](@ref) can be used to generate new subtypes of the abstract type `Weber.ExpEvent`. These events should be tagged with the `@event` macro, to ensure proper pre-compilation of moment functions. Such events can implement new methods for the existing [public functions on events](event.md) or their own new functions.

If you define new functions, instead of leveraging the existing event methods, they should generally have some default behavior for all `ExpEvent` objects, so it is easy
to call the method on any event a watcher moment receive.

### Custom Key Events

One approach, if you are implementing events for a hardware input device, is to leverage the existing methods [`iskeydown`](@ref). You can define your own type of keycode (which should be of some new custom type `<: Weber.Key`). You can then make use of the [`@key_str`](@ref) macro by adding entries to the `Weber.str_to_code` dictionary (a private global constant). So for example, you could add the following to the module implementing your extension.

```julia
Weber.str_to_code["my_button1"] = MyHardwareKey(1)
Weber.str_to_code["my_button1"] = MyHardwareKey(2)
```

Such key types should implement `==`, `hash` and `isless` so that the events can be ordered. This
allows them to be displayed in an organized fashion when printed using [`listkeys`](@ref). 

You could then extend poll_events so that it generates events that return true for `iskeydown(myevent,key"my_button1")` (and a corresponding method for `iskeydown`). These buttons could then be used in code using your module by calling `response` as follows.

```julia
response(key"my_button1" => "button1_pressed",key"my_button2" => button2_pressed)
```

## Custom Moments

You can create your own moment types, which must be `<: Weber.Moment`. These new
moments will have to be generated using some newly defined function, or added
automatically by extending `addtrial`. Once created, and added to trials, these
moments will be processed at run-time using the function [`handle`](@ref), which
should define the moment's run-time behavior.

A moment can also define [`delta_t`](@ref)---to define when it occurs---or [`prepare!`](@ref)---to have some sort of initialization occur before its onset---but these both have default implementations.

Methods of `handle` should not make use of the extension machinery described above. What this means is that methods of `handle` should never dispatch on an extended experiment, and no calls to `top`, `next` or `extension` should occur on the experiment object. Further, each moment should belong to one specific extension, in which all functionality for that custom moment should be implemented. 

