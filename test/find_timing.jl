
# this allows a test of timing for an experiment without setting up any
# multimedia resources, so it can be run just about anywhere.
function find_timing(fn;keys...)
  empty!(Weber.null_record)
  exp = Experiment(;null_window=true,hide_output=true,keys...)
  setup(() -> fn(),exp)

  run(exp,await_input=false)

  nostarts = filter(x -> !endswith(string(x[:code]),"_start") &&
                    x[:code] != "terminated" &&
                    x[:code] != "closed",
                    Weber.null_record)
  map(x -> x[:code],nostarts),map(x -> x[:time],nostarts),nostarts
end
