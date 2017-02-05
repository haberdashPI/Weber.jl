using Distributions
export levitt_adapter, bayesian_adapter, delta

"""
Adpaters, created through their individual constructors, can be used to estiamte
some delta at which listeners respond correctly at a given threshold (e.g. 80%
correct). They must define `update`, `estimate` and `delta`.
"""
abstract Adapter

"""
    Weber.update!(adapter,response,correct)

Updates any internal state for the adapter when the listener responds with
`response` and the correct response is `correct`. Usually not called directly,
but instead called within `response`, when the adapter is passed as the first
argument.
"""
function update!(adapter,response,correct)
end

"""
    Weber.estimate(adapter)

Returns the mean and error of the adapters threshold estimate. May take some
time to run.  Usually not called directly, but instead called within `response`,
when the adapter is passed as the first argument.
"""
function estimate(adapter)
end

"""
    delta(adapter)

Returns the next delta that should be tested to help estimate the threshold.
"""
function delta(adapter)
end

"""
    response([fn],track,[key1] => ["resp1"],...;correct=[resp],
             [show_feedback=true],
             [feedback=Dict(true=>"Correct",false=>"Wrong!")]
             keys...)

Record a response in a n-alternative forced choice task and update
an adapter.

The first response recieved is interprted as the actual response. Subsequent
response will be recorded, without a delta or correct value set, and appending
"late_" to the specified response string.

# Function Callback

Optionally, upon participant response, `fn` receives two arguments: the
provided response, and the correct response.

# Keyword Arguments

- `correct`: the response string corresponding to the correct response
- `show_feedback` (default = true): whether to show feedback to the
  participant after they respond.
- `feedback` (default = Dict(true => "Correct!",false => "Wrong!"): the text
  to display to a participant when they are correct (for the true key) or
  incorrect (for the false key).

Any additional keyword arguments are added as column values when the
response is recorded.

"""
function response(track::Adapter,resp::Pair...;keys...)
  response((x,y) -> nothing,track,resp...;keys...)
end

function response(callback::Function,adapter::Adapter,responses::Pair...;
                  correct=nothing,show_feedback=true,
                  feedback=Dict(true => "Correct!",false => "Wrong!"),
                  keys...)
  addcolumn(:correct)
  addcolumn(:delta)

  if correct ∉ map(x -> x[2],responses)
    error("The value of `correct` must be "*
          join(map(x -> x[2],responses),", "," or "))
  end
  feedback_visuals = map((pair) -> pair[1] => visual(pair[2]),feedback)

  let responded = false
    begin (event) ->
      for (key,resp) in responses
        if iskeydown(event,key)
          if !responded
            responded = true
            record(resp;correct=correct,delta=delta(adapter),keys...)

            update!(adapter,resp,correct)
            callback(resp,correct)
            if show_feedback
              display(feedback_visuals[resp==correct])
            end

          else
            record("late_"*resp;keys...)
          end
        end
      end
    end
  end
end

"""
    levit_adapter([first_delta=0.1],[down=3],[up=1],
                  [big_reverse=3],[big=0.01],[little=0.005],
                  [min_reversals=7],[min_delta=-Inf],[max_delta=Inf],
                  [mult=false])

Creates a N-down M-up adaptor ala Levitt (1971). See documentaiton
of `Adapter` for usage.

This can be used to adjust a perceptual difference (delta) to reach a desired
threshold, as determiend by N and M. For instnace a 3-down, 1-up adapter finds
the 79%-correct threshold.

# Keyword Arguments

- `first_delta`: the delta that the first trial should present.
- `up`: how many incorrect responses in a row must occur for the delta
  to move up
- `down`: how many correct responses in a row must occur for the delta
  to move down.
- `big`: the amount delta changes by (up or down) at first
- `big_reverse`: how many reveresals (up to down or down to up) must
  occur before `little` is used instead of `big`
- 'little': the amount delat changes by (up or down) after
  `big_reverse` reversals.
- `min_reversals`: the smallest number of reversals that can
  be used to estimate a threshold.
- `min_delta`: the smallest delta allowed
- `max_delta`: the largest delta allowed
- `mult`: whether the delta change should be additive (false) or
   multiplicative (true).
"""
function levitt_adapter(;first_delta=0.1,down=3,up=1,big_reverse=3,
                        big=0.01,little=0.005,min_reversals=7,
                        drop_reversals=3,min_delta=0,max_delta=Inf,
                        mult=false)
  delta = first_delta
  reversals = Float64[]
  last_direction = 0
  num_correct = 0
  num_incorrect = 0
  operator = (mult ? :mult : :add)
  adapter = Levitt{operator}(delta,up,down,big_reverse,big,little,
                             min_reversals,drop_reversals,min_delta,max_delta,
                             reversals,last_direction,num_correct,num_incorrect)
end

type Levitt{OP} <: Adapter
  delta::Float64

  up::Int
  down::Int
  big_reverse::Int
  big::Float64
  little::Float64
  min_reversals::Int
  drop_reversals::Int

  min_delta::Float64
  max_delta::Float64

  reversals::Array{Float64}
  last_direction::Int
  num_correct::Int
  num_incorrect::Int
end
delta(a::Levitt) = a.delta

function update_reversals(adapter::Levitt,direction::Int)
  if (adapter.last_direction != 0 && direction != adapter.last_direction)
    push!(adapter.reversals,adapter.delta)
  end
  adapter.last_direction = direction
end

bound(x,min_,max_) = min(max_,max(min_,x))

up(adapter::Levitt{:add}) = +
down(adapter::Levitt{:add}) = -
up(adapter::Levitt{:mult}) = *
down(adapter::Levitt{:mult}) = /

function update_delta(adapter,op)
  if length(adapter.reversals) < adapter.big_reverse
    adapter.delta = bound(op(adapter.delta,adapter.big),
                          adapter.min_delta,adapter.max_delta)
  else
    adapter.delta = bound(op(adapter.delta,adapter.little),
                          adapter.min_delta,adapter.max_delta)
  end
end

function update!(adapter::Levitt,response,correct)
  if correct == response
    adapter.num_correct += 1
    adapter.num_incorrect = 0
    if adapter.num_correct >= adapter.down
      adapter.num_correct = 0
      update_reversals(adapter,-1)
      update_delta(adapter,down(adapter))
    end
  else
    adapter.num_incorrect += 1
    adapter.num_correct = 0
    if adapter.num_incorrect >= adapter.up
      adapter.num_incorrect = 0
      update_reversals(adapter,1)
      update_delta(adapter,up(adapter))
    end
  end
  adapter
end

estimate_helper(a::Levitt{:add}) = mean(a),sd(a)
estimate_helper(a::Levitt{:mult}) = exp(mean(log(a))),exp(sd(log(a)))

function estimate(adapter::Levitt)
  if length(adapter.reversals) < adapter.min_reversals
    NaN,NaN
  else
    if isodd(length(adapter.reversals))
      estimate_helper(adapter.reversals[adapter.drop_reversals:end])
    else
      estimate_helper(adapter.reversals[adapter.drop_reversals+1:end])
    end
  end
end

type ImportanceSampler <: Adapter
  miss::Float64
  threshold::Float64
  n_samples::Int
  thresh_d::UnivariateDistribution
  slope_d::UnivariateDistribution
  delta::Float64
  min_delta::Float64
  max_delta::Float64
  delta_repeat::Int
  resp::Dict{Float64,Int}
  N::Dict{Float64,Int}
  thresh_samples::Vector{Float64}
  thresh_weights::Vector{Float64}
  repeat2_thresh::Float64
  repeat3_thresh::Float64
end

"""
    baysian_adapter([first_delta=0.1],[n_samples=1000],[miss=0.01],
                    [threshold=0.79],[thresh_d=Uniform(0,1)],
                    [slope_d=LogNormal(log(1),log(100))],[repeat3_thresh=0.1],
                    [repeat2_thresh=0.01],[min_delta=0],[max_delta=Inf])

Creates an adapter that estimates the desired response threshold using
a bayesian approach, selecting the delta to be the best estimate of this
threshold. This is a modified version of the approach described in
Kontsevich & Tyler 1999.

This estimator is designed to find, in a reasonably short time, a good estimate
of the threshold. While Kontsevich & Tyler's method selects a delta
quite possibly far from the threshold (to better estiamte the overall
psychometric function), in practice this can lead to a less efficient estimates
of the threshold itself.

Further, for stability and robustness, this adapter begins by repeating the same
delta multiple times and only begins quickly changing deltas trial-by-trial when
the ratio of standard deviation to the mean is small.

# Keyword Arugments

- first_delta: the delta to start measuring with
- n_samples: the number of samples to use during importance sampling
- miss: the expected rate at which that listeners will make mistakes
  even for easy to percieve differences.
- threshold: the %-response threhsold to be estimated
- thresh_d: the distribution over-which to draw samples for the threshold
  during importance sampling
- slope_d: the distribution over-which to draw samples for the slope
  during importance sampling.
- repeat3_thresh: the ratio of sd / mean required to move from
  repeating a delta 3 times to 2 times before changing the delta.
- repeat2_thresh: the ratio of sd / mean required to move from
  repeating a delta 2 times to 1 time before changing the delta.
"""
function bayesian_adapter(;first_delta=0.1,
                          n_samples=1000,miss=0.01,threshold=0.79,
                          repeat3_thresh=0.1,repeat2_thresh=0.01,
                          min_delta=0,max_delta=1,
                          thresh_d=Uniform(min_delta,max_delta),
                          slope_d=LogNormal(log(1),log(100)))
  delta = first_delta
  delta_repeat = 0
  resp = Dict{Float64,Int}()
  N = Dict{Float64,Int}()
  samples = ones(0)
  weights = ones(0)
  ImportanceSampler(miss,threshold,n_samples,thresh_d,slope_d,delta,
                    min_delta,max_delta,delta_repeat,resp,N,samples,weights,
                    repeat3_thresh,repeat2_thresh)
end

const sqrt_2 = sqrt(2)
function sample(a::ImportanceSampler)
  if length(a.thresh_samples) == 0
    theta = rand(a.thresh_d,a.n_samples)
    slope = rand(a.slope_d,a.n_samples)
    q_log_prob = logpdf(a.thresh_d,theta) .+ logpdf(a.slope_d,slope)

    udeltas = collect(keys(a.resp))
    p = (a.miss/2) + (1-a.miss)*cdf(Normal(),exp((udeltas' .- theta).*slope)/sqrt_2)
    log_prob = sum(enumerate(udeltas)) do x
      i,delta = x
      logpdf.(Binomial.(a.N[delta],p[:,i]),a.resp[delta])
    end

    lweights = log_prob - q_log_prob
    weights = exp.(lweights - maximum(lweights))
    weights = weights ./ sum(weights)
    ess = 1 / sum(weights.^2)

    # if ess / length(weights) < 0.1
    #   warn("Effective sampling size of importance samples is low ",
    #        "($(round(ess,1))). Consider adjusting the `thresh_d` and `slope_d`.")
    #   record("poor_adaptor_ess",value=ess)
    # end

    dprime = invlogcdf(Normal(),log((a.threshold-a.miss/2)/(1-a.miss)))
    thresh_off = -log(dprime)./slope

    a.thresh_samples = theta + thresh_off
    a.thresh_weights = weights
  end
  a.thresh_samples, a.thresh_weights
end

function update!(adapter::ImportanceSampler,response,correct)
  adapter.thresh_samples = ones(0)
  adapter.resp[adapter.delta] = get(adapter.resp,adapter.delta,0) +
    (response==correct)
  adapter.N[adapter.delta] = get(adapter.N,adapter.delta,0) + 1

  thresh,weights = sample(adapter)
  μ,σ = estimate(adapter)

  sd_ratio = σ / μ
  if sd_ratio > adapter.repeat3_thresh
    repeats = 2
  elseif sd_ratio > adapter.repeat2_thresh
    repeats = 1
  else
    repeats = 0
  end

  if repeats > adapter.delta_repeat
    adapter.delta_repeat += 1
  else
    adapter.delta_repeat = 0
    adapter.delta = bound(sum(thresh .* weights),adapter.min_delta,adapter.max_delta)
  end

  adapter
end

function estimate(adapter::ImportanceSampler)
  thresh,weights = sample(adapter)
  μ = sum(thresh .* weights)
  M = sum(weights .> 0)
  σ = sqrt.(sum(((μ .- thresh) .* weights).^2) ./
           ((M-1)/M)*sum(weights))

  μ,σ
end

delta(adapter::ImportanceSampler) = bound(adapter.delta,adapter.min_delta,
adapter.max_delta)
