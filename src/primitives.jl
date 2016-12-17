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

function addbreak_every(trial,n_break_after,trial_response)
  # add a break after every n_break_after trials
  if trial > 0 && trial % n_break_after == 0 && trial < n_trials
    break_text = render("You can take a break. Hit"*
                        " any key (other than P or Q) when you're "*
                        "ready to resume..."*
                        "\n$(div(trial,n_break_after)) of "*
                        "$(div(n_trials,n_break_after)-1) breaks.")

    message = moment() do t
      record("break")
      display(break_text)
    end

    addbreak(message,await_response(e -> !trial_response(e) && iskeydown(e)))
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
