export run_keycode_helper

function run_keycode_helper()
  exp = Experiment(hide_output=true)
  setup(exp) do
    addbreak(instruct("Press keys to see their codes."))
    addtrial(show_cross(),await_response(iskeydown(key":escape:"))) do event
      if iskeydown(event)
        display(visual(string(keycode(event))))
      end
    end
  end

  run(exp)
end
