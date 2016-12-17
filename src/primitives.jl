export instruct, response, addbreak_every, show_cross, @read_args
using ArgParse

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
  text = render(str*" (Hit spacebar to continue...)")
  m = moment() do t
    record("instructions";[time_col => t]...)
    display(text)
  end
  [m,await_response(iskeydown(key":space:"))]
end

function addbreak_every(n,total,response=key":space:",
                        response_str="the spacebar")
  exp = get_experiment()
  trial = exp.meta[:break_every_count] = get(exp.meta,:break_every_count,0) + 1
  if n <= trial < total && (n == 1 || trial % n == 1)
    message = moment() do t
      record("break")
      display(render("You can take a break. Hit "*
                     "$response_str when you're ready to resume... "*
                     "$(div(exp.trial,n)) of $(div(total,n)-1) breaks."))
    end

    addbreak(message,await_response(e -> iskeydown(e,response)))
  end
end

function show_cross(delta_t::Number;render_options...)
  c = render("+";render_options...)
  moment(delta_t,t -> display(c))
end

macro read_args(description)
  quote
    begin
      s = ArgParseSettings(description = $description)
      @add_arg_table s begin
        "sid"
          $(esc(:help)) = "Subject id. Trials are randomized per subject."
          $(esc(:required)) = true
          $(esc(:arg_type)) = String
        "skip"
          $(esc(:help)) = "# of offsets to skip. Useful for restarting in middle of experiment."
          $(esc(:required)) = false
          $(esc(:arg_type)) = Int
          $(esc(:default)) = 0
      end
      parsed = parse_args(ARGS,s)
      parsed["sid"],parsed["skip"]
    end
  end
end
