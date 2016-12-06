"""
  Infrastructure for creating interdependant, but modular groups of
  experiment settings.
  """
module Settings

using Lazy: @>>
using DataStructures
import Base: getindex, show

export @settings, @optionsfor, listsettings, parent, inherits

abstract Setting
type SettingNode <: Setting
  fn::Function
end
type SettingLeaf <: Setting
  fn::Function
end

abstract AbstractSettings
abstract BoundSettings <: AbstractSettings

type SettingsParent <: BoundSettings
  assignments::Dict{Symbol,Setting}
  cache::Dict{Symbol,Any}
end

SettingsParent(a) = SettingsParent(a,Dict())
cache(p) = p.cache

type SettingsChild <: BoundSettings
  assignments::Dict{Symbol,Setting}
  parent::AbstractSettings
  cache::Dict{Symbol,Any}
end

SettingsChild(a,p) = SettingsChild(a,p,Dict())
cache(c) = c.cache

function listsettings_helper(ss::SettingsParent)
  keys(ss.assignments)
end

function listsettings_helper(ss::SettingsChild)
  [keys(ss.assignments)...,listsettings(ss.parent)...]
end

function listsettings(ss::AbstractSettings)
  sort(unique(collect(listsettings_helper(ss))))
end

function Base.show(io::IO,ss::AbstractSettings)
  println(io,"Settings for "*join(listsettings(ss),", "," and "))
end

abstract AbstractOptions
type OptionsParent <: AbstractOptions
  keyword::Symbol
  opts::Dict{AbstractString,AbstractSettings}
end

type OptionsChild <: AbstractOptions
  keyword::Symbol
  opts::Dict{AbstractString,AbstractSettings}
  parent::AbstractSettings
end

abstract ResolveState{S<:AbstractSettings}

type BaseResolveState{S} <: ResolveState{S}
  default::Nullable
  current::S
  start::AbstractSettings
end

type ReifyResolveState{S} <: ResolveState{S}
  default::Nullable
  current::S
  start::AbstractSettings
  reifying::Set{Symbol}
end

function copy{S<:AbstractSettings}(s::ReifyResolveState{S})
  ReifyResolveState(s.default,s.current,s.start,s.reifying)
end

function getindex{T <: AbstractSettings}(settings::T,x::Symbol)
  resolve(BaseResolveState{T}(Nullable(),settings,settings),x)
end

function setindex(settings::AbstractSettings,x::Symbol,value)
  settings.assignments[x] = SettingLeaf(() -> value)
end

function get{T <: AbstractSettings}(settings::T,x::Symbol)
  settings[x]
end

function get{T <: AbstractSettings}(settings::T,x::Symbol,default)
  resolve(BaseResolveState{T}(Nullable(default),settings,settings),x)
end

function itrstr(xs)
  y = string(first(xs))
  for x in drop(xs,1)
    y *= ", $x"
  end
  y
end

function startreify(state::BaseResolveState,x)
  ReifyResolveState(state.default,state.start,state.start,Set([x]))
end

function startreify(state::ReifyResolveState,x)
  if x ∈ state.reifying
    error("The settings variable :$x is self referential! Found while trying "*
          "to resolve these variables: $(itrstr(state.reifying))")
  else
    ReifyResolveState(state.default,state.start,state.start,
                      push!(deepcopy(state.reifying),x))
  end
end

function toparent(state::BaseResolveState{SettingsChild},x,
                  default=state.default)
  BaseResolveState(default,state.current.parent,state.start)
end

function toparent(state::ReifyResolveState{SettingsChild},x,
                  default=state.default)
  ReifyResolveState(default,state.current.parent,state.start,
                    state.reifying)
end

function toparent(state::ResolveState{SettingsParent},x,
                  default=state.default)
  if isnull(default)
    error("Unable to find the settings variable :$x.")
  else
    get(default)
  end
end

function resolve(state::ResolveState,x::Symbol)
  helper() = if haskey(state.current.assignments,x)
    reify(state.current.assignments[x],startreify(state,x))
  else
    resolve(toparent(state,x),x)
  end

  if (state.current === state.start)
    if haskey(state.current.cache,x)
      return state.current.cache[x]
    else
      result = helper()
      state.current.cache[x] = result
      result
    end
  else
    helper()
  end
end

reset_reify(state::BaseResolveState,sym::Symbol) = state
function reset_reify(state::ReifyResolveState,sym::Symbol)
  result = deepcopy(state)
  delete!(result.reifying,sym)
  result
end

function resolveparent(state::ResolveState{SettingsChild},
                       x::Symbol,default)
  resolve(reset_reify(toparent(state,x,Nullable(default)),x),x)
end

function resolveparent(state::ResolveState{SettingsParent},
                       x::Symbol,default)
  default
end

function reify(setting::SettingNode,state::ResolveState)
  setting.fn(state)
end

function reify(setting::SettingLeaf,state::ResolveState)
  setting.fn()
end

assignments(s::SettingsParent) = s.assignments
assignments(s::SettingsChild) = s.assignments

"""
      @settings(symbol => expr,symbol => expr,...)

  Create's list of lazily evaluated values with dependencies.

  A lazy value only gets calculated when it has to be. The advantage of lazy
  values is that two seting of interdependant values can be combined to create a
  final list. This allows for the compartmentalization of different components of
  an experiment, even though some of the settings from one part of the experiment
  depend on others. If the values weren't lazy, the code would evaluate to an
  error when you tried to define one part of the experiment using settings from
  another part that had yet to be defined.

  # Examples

```julia
julia> child = @Settings.settings begin
         :list => [1,2,parent()...]
         :list2 => [0,0,parent(:list)...]
       end
Settings for list and list2

julia> parent = @Settings.settings begin
         :list => [3,4]
         :list2 => [10,9]
       end
Settings for list and list2

julia> x = Settings.inherits(child,parent)
Settings for list and list2

julia> x[:list]
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> x[:list2]
4-element Array{Int64,1}:
 0
 0
 3
 4

julia> child[:list]
2-element Array{Int64,1}:
 1
 2
```
"""
macro settings(body)
  :(SettingsParent(Dict($(parsesettings(body)...))))
end

"""
      @optionsfor(symbol,(str => settings; str => settings;...))

  Creates a conditional group of settings.

  If a child's value for `symbol` is equal to `str` then the associated group of
  settings is treated as the parent of the child.

  # Examples
  ```julia
  julia>child = @settings begin
           :stimulus_type => "a"
           :stimulus_length_ms => 200
           :stimulus_offset_ms => :stimulus_onset_ms + :stimulus_length_ms
        end

  julia>stimuli = @optionsfor :stimulus_type begin
           "a" => :stimulus_onset_ms => 100
           "b" => :stimulus_onset_ms => 200
        end

  julia>x = inherits(child,stimuli)
  julia>x[:stimulus_offset_ms]
  300
  ```
  """
macro optionsfor(keyword,body)
  if !issymbolq(keyword)
    error("Expected \":symbol\" as first argument to @optionsfor.")
  end

  :(OptionsParent(keyword,Dict($(parseoptions(body)...))))
end

function unzip{T<:Tuple}(A::Array{T})
  res = map(x -> x[], T.parameters)
  res_len = length(res)
  for t in A
    for i in 1:res_len
      push!(res[i], t[i])
    end
  end
  res
end


issymbolq(node) = false
function issymbolq(node::QuoteNode)
  isa(node.value,Symbol)
end
function issymbolq(node::Expr)
  node.head == :quote && isa(node.args[1],Symbol)
end

function symbolval(node::QuoteNode)
  node.value
end
function symbolval(node::Expr)
  node.args[1]
end

function parsesettings(expr)
  function helper(a)
    if a.head != :(=>)
      error("Unexpected statement in settings block. Expectd a pair, e.g. "*
            ":x => :y. Instead found: \n $a")
    elseif !issymbolq(a.args[1])
      error("Unexpected left-hand side of settings assignement. Expected a "*
            "symbol, e.g. :x => 10. Instead found:\n $a")
    end

    state = gensym("state")
    sym = symbolval(a.args[1])
    replaced,settings = replace_settings(state,a.args[2],sym)
    if !isempty(settings)
      closure = Expr(:let,replaced,settings...)
      if :(parent = parent) ∈ settings
        parentdef = :(function parent(setting=$(Expr(:quote,sym));default=[])
                        Settings.resolveparent($state,setting,default)
                      end)
        :($(a.args[1]) =>
          SettingNode($(esc(:(($state) -> begin
                                $parentdef
                                $closure
                              end)))))
      else
        :($(a.args[1]) =>
          SettingNode($(esc(:(($state) -> $closure)))))
      end
    else
      :($(a.args[1]) => SettingLeaf(() -> $(esc(replaced))))
    end
  end

  if expr.head == :block
    @>> expr.args filter(x->isa(x,Expr) && x.head !== :line) map(helper)
  elseif expr.head == :(=>)
    [helper(expr)]
  else
    error("Unexpected expression in settings body. "*
          "Expected a series of pairs, e.g. :x => :y. Instead found: \n $expr")
  end
end

function parseoptions(expr)
  function helper(a)
    if a.head != :(=>)
      error("Unexpected statement in options block. Expected a pair, "*
            "e.g. \"option\" => result. Instead found: \n $a")
    elseif !isa(a,AbstractString)
      error("Unexpected left-hand side of option. Expected a "*
            "string. Instead found: \n $a")
    end

    a.args[1] => parsesettings(a.args[2])
  end

  if expr.head == :block
    @>> expr.args filter(x->isa(x,Expr) && x.head !== :line) map(helper)
  else
    error("Unexpected expression in options body. "*
          "Expected a seros of pairs, e.g. \"option\" => result. "*
          "Instead found: \n $expr")
  end
end

"""
  parent(setting=[current setting];default=[])

In the context of a @settings or @optionsfor macro, retrieves the parent's
value of a given setting.

If there is no ancenstor with this setting, the default value will be returned.
If there is no setting specified, the setting the function parent() is called
from will be used.

# Examples
  ```julia
julia> child = @settings begin
         :list => [1,2,parent()...]
         :list2 => [0,0,parent(:list)...]
       end
<Settings object>


julia> parent = @settings begin
         :list => [3,4]
         :list2 => [10,9]
       end
<Settings object>


julia> x = inherits(child,parent)
<Settings object>


julia> x[:list]
4-element Array{Int64,1}:
 1
 2
 3
 4

julia> x[:list2]
4-element Array{Int64,1}:
 0
 0
 3
 4

julia> child[:list]
2-element Array{Int64,1}:
 1
 2```
"""
function parent(setting=:default;default=[])
  # a local version of this function, one for each SettingNode object, is
  # defined inside the parsesettings (called by the @settings and @optionsfor
  # macros).
  error("The function `parent` was called outside the context of the "*
        "@settings or @optionsfor macros.")
end

replace_settings(settings,x,sym,symmap=Dict{Symbol,Symbol}()) = x,[]

## TODO: resolve symbols in a let block
## to ensure no duplicate calls, and efficient setting functions
## partially done, need to debug

function symassign(sym,resolver,symmap)
  if sym ∉ keys(symmap)
    gen = gensym(sym)
    symmap[sym] = gen
    gen,[:($gen = $resolver)]
  else
    symmap[sym],[]
  end
end

function replace_settings(state,expr::Expr,sym::Symbol,
                          symmap=Dict{Symbol,Symbol}())
  if expr.head == :quote
    symassign(expr.args[1],:(Settings.resolve($state,$expr)),symmap)
  elseif expr.head == :(=>)
    :($(expr.args[1]) => $(replace_settings(state,expr.args[2],sym,symmap))),[]
  elseif expr.head == :call && expr.args[1] == :parent
    if :parent ∉ keys(symmap)
      symmap[:parent] = :parent
      expr,[:(parent = parent)] # place holder so we can add the function later
    else
      expr,[]
    end
  else
    newargs,settings = unzip([replace_settings(state,a,sym,symmap)
                            for a in expr.args])
    Expr(expr.head,newargs...),reduce(vcat,settings)
  end
end

function replace_settings(state,qnode::QuoteNode,sym::Symbol,
                          symmap=Dict{Symbol,Symbol})
  if isa(qnode.value,Symbol)
    symassign(qnode.value,:(Settings.resolve($state,$qnode)),symmap)
  else
    qnode,[]
  end
end

"""
    inherits(a,b)

Combine settings a and b, treating b as the partent of a.

# See also
@settings
"""
function inherits(a,b,others...)
  inherits(a,inherits(b,others...))
end

function inherits(s1::AbstractSettings,options::OptionsChild)
  setting = inherits(s1,options.parent)
  option_settings = options[setting[options.keyword]]
  inherits(s1,option_settings)
end

function inherits(s1::AbstractSettings,options::OptionsParent)
  option_settings = options[s1[options.keyword]]
  inherits(s1,option_settings)
end

function inherits(s1::SettingsParent,s2::AbstractSettings)
  SettingsChild(assignments(s1),s2)
end

function inherits(s1::SettingsChild,s2::AbstractSettings)
  s1 = copy(s1)
  s1.parent = inherits(s1.parent,s2)
  s1.cache = Dict()
  s1
end

end
