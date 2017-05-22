using MacroTools

function clean_kws(args)
  map(args) do arg
    !isexpr(arg,:(=)) ? arg : Expr(:kw,arg.args...)
  end
end

function isdocstr_block(docstr)
  if isexpr(docstr,:block)
    filtered = filter(x -> !isexpr(x,:line),docstr.args)
    length(filtered) == 1 &&
    filtered[1] isa String
  end
end

function warn_doc(name)
  """

!!! warning "Do not call inside a package"

    Do not call @$(name) inside of a package or in tests. It should
    only be used in one-off scripts. If Weber$(name) is not currently installed
    it will be installed by this macro using `Pkg.add` which can lead to
    problems when called in packages or tests.

    If you want to include an extension without this behavior you can call
    @$(name)_safe which mimics @$(name) except that it will never call
    `Pkg.add`.

"""
end

"""
    @extension [Symbol] begin
      [docstring...]
    end

Registers a given Weber extension. This creates a macro called `@[Symbol]` which
imports `Weber[Symbol]` and calls `Weber[Symbol].InitExtension`, with the given
arguments. InitExtension should return either `nothing` or an extension
object.

The doc string is used to document the usage of the extension, and
should normally include a link to the website of a julia package for the
extension.
"""
macro extension(symbol,docstr)
  if (symbol isa Symbol) & isdocstr_block(docstr)
    mod = Symbol("Weber"string(symbol))
    args = gensym("args")
    safe_doc = "See documentation for @$(string(symbol))."
    expr = quote
      export $(Symbol("@"string(symbol))), $(Symbol("@"string(symbol)"_safe"))

      @doc $(filter(x -> !isexpr(x,:line),docstr.args)[1]*
             warn_doc(string(symbol))) ->
      macro $symbol($args...)
        init_call = :($$(Expr(:quote,mod)).InitExtension())
        append!(init_call.args,Weber.clean_kws($args))
        quote
          try
            $(Expr(:import,$(Expr(:quote,mod))))
          catch
            Pkg.add($$(string(mod)))
            $(Expr(:import,$(Expr(:quote,mod))))
          end
          $(esc(init_call))
        end
      end

      @doc $(safe_doc) ->
      macro $(Symbol(string(symbol)"_safe"))($args...)
        init_call = :($$(Expr(:quote,mod)).InitExtension())
        append!(init_call.args,Weber.clean_kws($args))
        quote
          $(Expr(:import,$(Expr(:quote,mod))))
          $(esc(init_call))
        end
      end
    end
    esc(expr)
  else
    error("Unexpected syntax: @extension expects a sybmol followed by a",
          " block containing a doc string.")
  end
end
