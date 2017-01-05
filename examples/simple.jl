# This example is primarily for expository purposes. Do not copy
# the practices demosntrated here!!! Instead refer to some of the
# other examples for best practices.

using Psychotask
sid,skip = @read_args("A simple frequency discrimination experiment.")

low = sound(ramp(tone(1000,0.5)))
high = sound(ramp(tone(1100,0.5)))

function one_trial()
  if rand(Bool)
    stim = moment(0.5,t -> play(low))
    resp = response(key"q" => "low", key"p" => "high",actual = "low")
  else
    stim = moment(0.5,t -> play(high))
    resp = response(key"q" => "low", key"p" => "high",actual = "high")
  end
  return [show_cross(),stim,resp,await_response(iskeydown)]
end

exp = Experiment(sid = sid,condition = "ConditionA",skip=skip,columns=[:actual])
setup(exp) do
  addbreak(instruct("Here are some instructions."))
  addbreak(instruct("Here's some practice."))
  for i in 1:5
    addpractice(one_trial())
  end

  addbreak(instruct("Here's the real deal."))
  for trial in 1:60
    addtrial(one_trial())
  end
end

run(exp)
