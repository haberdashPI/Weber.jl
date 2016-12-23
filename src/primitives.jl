# TODO: create a 2AFC adaptive abstraction

export instruct, response, addbreak_every, show_cross, @read_args
using ArgParse
using Juno: input, selector
import Juno

function response(responses...;time_col=:time,info...)
  begin (event) ->
    for (key,response) in responses
      if iskeydown(event,key)
        record(response;[time_col => time(event),info...]...)
      end
    end
  end
end

function instruct(str;time_col=:time)
  text = visual(str*" (Hit spacebar to continue...)")
  m = moment() do t
    record("instructions";[time_col => t]...)
    display(text)
  end
  [m,await_response(iskeydown(key":space:"))]
end

function addbreak_every(n,total,response=key":space:",
                        response_str="the spacebar")
  exp = get_experiment()
  trial = exp.info.meta[:break_every_count] = get(exp.info.meta,:break_every_count,0) + 1
  if n <= trial < total && (n == 1 || trial % n == 1)
    message = moment() do t
      record("break")
      display(visual("You can take a break. Hit "*
                     "$response_str when you're ready to resume... "*
                     "$(div(exp.trial,n)) of $(div(total,n)-1) breaks."))
    end

    addbreak(message,await_response(e -> iskeydown(e,response)))
  end
end

function show_cross(delta_t::Number=0;render_options...)
  c = visual("+";render_options...)
  moment(delta_t,t -> display(c))
end

function as_arg(expr)
  if isa(expr,Symbol) || expr.head != :kw
    error("Expected keyword parameters specifying additional program arguments.")
  end

  if isa(expr.args[2],Symbol)
    quote
      $(string(expr.args[1]))
      $(esc(:required)) = true
      $(esc(:arg_type)) = $(expr.args[2])
    end
  elseif expr.args[2].head == :vect
    quote
      $(string(expr.args[1]))
      $(esc(:required)) = true
      $(esc(:arg_type)) = String
      $(esc(:help)) = $(join(map(x -> x.args[1],expr.args[2].args),", "," or "))
    end
  else
    error("Expected keyword value to be a vector of symbols or a type.")
  end
end

function as_arg_checker(expr)
  if !isa(expr.args[2],Symbol) && expr.args[2].head == :vect
    quote
      let str = $(string(expr.args[1])), vals = $(expr.args[2])
        if !any(s -> string(s) == parsed[str],vals)
          println("Expected \"$str\" argument to be "*join(vals,", "," or ")*".")
          println(usage_string(s))
          exit()
        end
      end
    end
  else
    :nothing
  end
end

function as_arg_result(expr)
  if !isa(expr.args[2],Symbol) && expr.args[2].head == :vect
    :(Symbol(parsed[$(string(expr.args[1]))]))
  else
    :(parsed[$(string(expr.args[1]))])
  end
end

macro read_args(description,keys...)
  arg_expr = quote
    "sid"
    $(esc(:help)) = "Subject id. Trials are randomized per subject."
    $(esc(:required)) = true
    $(esc(:arg_type)) = String
  end

  for arg_body in map(as_arg,keys)
    for line in arg_body.args
      push!(arg_expr.args,line)
    end
  end

  skip_expr = quote
    "skip"
    $(esc(:help)) = "# of offsets to skip. Useful for restarting in middle of experiment."
    $(esc(:required)) = false
    $(esc(:arg_type)) = Int
    $(esc(:default)) = 0
  end
  arg_expr.args = vcat(arg_expr.args,skip_expr.args)

  arg_body = quote
    s = ArgParseSettings(description = $(esc(description)))

    @add_arg_table s begin
      $arg_expr
    end

    parsed = parse_args(ARGS,s)
  end


  for line in map(as_arg_checker,keys)
    push!(arg_body.args,line)
  end

  result_tuple = :((parsed["sid"],parsed["skip"]))
  for result = map(as_arg_result,keys)
    push!(result_tuple.args,result)
  end
  push!(arg_body.args,result_tuple)

  readline_call = :(readline_args())
  for k in keys
    push!(readline_call.args,k)
  end

  quote
    cd(dirname(@__FILE__))
    if length(ARGS) > 0
      $arg_body
    else
      $readline_call
    end
  end
end

function readline_args(;keys...)
  print("Enter subject id: ")
  sid = input()
  args = Array{Any}(length(keys))
  for (i,(kw,value)) in enumerate(keys)
    if isa(value,Type)
      if Juno.isactive()
        println("Enter $kw: ")
      else
        print("Enter $kw: ")
      end
      args[i] = parse(value,input())
    else
      if Juno.isactive()
        println("Enter $kw: ")
        args[i] = selector(value)
      else
        print("Enter $kw ($(join(map(string,value),", "," or "))): ")
        args[i] = chomp(readline())
        if Symbol(args[i]) ∉ value
          error("Expected $kw to be $(join(map(string,value),", "," or ")) "*
                "but got $(args[i]).")
        end
      end
    end
  end
  print("Offset to start at? (0 by default): ")
  str = input()
  if isempty(chomp(str))
    skip = 0
  else
    skip = parse(Int,str)
  end
  println("Running...")
  (sid,skip,args...)
end
