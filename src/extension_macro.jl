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
    expr = quote
      export $(Symbol("@"string(symbol)))

      @doc $(filter(x -> !isexpr(x,:line),docstr.args)[1]) ->
      macro $symbol($args...)
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
