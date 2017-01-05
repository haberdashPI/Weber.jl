export display_key_codes

function display_key_codes()
  exp = Experiment()
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
