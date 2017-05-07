# This example is primarily for expository purposes. Do not copy
# the practices demosntrated here!!! Instead refer to some of the
# other examples for best practices.

using Weber
sid,skip = @read_args("A simple frequency discrimination experiment.")

const low = ramp(tone(1kHz,0.5s))
const high = ramp(tone(1.1kHz,0.5s))

function one_trial()
  if rand(Bool)
    stim1 = moment(0.5s,play,low)
	  stim2 = moment(0.5s,play,high)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_first")
  else
	  stim1 = moment(0.5s,play,high)
	  stim2 = moment(0.5s,play,low)
    resp = response(key"q" => "low_first", key"p" => "low_second",correct = "low_second")
  end
  return [show_cross(),stim1,stim2,resp,await_response(iskeydown)]
end

exp = Experiment(columns = [:sid => sid,:condition => "ConditionA",:correct],skip=skip)
setup(exp) do
  addbreak(instruct("Press 'q' when you hear the low tone first and 'p' otherwise."))
  for trial in 1:10
    addtrial(one_trial())
  end
end

run(exp)
