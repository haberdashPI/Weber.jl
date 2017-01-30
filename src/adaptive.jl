# WORK IN PROGRESS: does not compile
using Distributions
export

"""
Adpaters, created through their individual constructors, can be used to estiamte
some delta at which listeners respond correctly at a given threshold (e.g. 80%
correct). They must define `update`, `estimate` and `delta`. The function
`update` is not usually called directly, but instead called within
`response`, when the adapter is passed as the first argument.
"""
abstract Adapter

"""
    update(adapter,response,correct)

Updates any internal state for the adapter when the listener response
with `response` and the correct response is `correct`.
"""
function update(adapter,response,correct)
end

"""
    estimate(adapter)

Returns the mean and error of the adapters threshold estimate. May
take quite long to run.

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
    response([fn],track,[key1] => ["resp1"],...;correct=[resp],keys...)

Record a response in a n-alternative forced choice task and update
an adapter.

# Keyword Arguments

- `show_feedback` (default = true): whether to show feedback to the
  participant after they respond.
- `feedback` (default = Dict(true => "Correct!",false => "Wrong!"): the text
  to display to a participant when they are correct (for the true key) or
  incorrect (for the false key).

Any additional keyword arguments are added as column values when the
response is recorded.

# Function Callback

Optionally, upon participant response, `fn` resceives two arguments: the
provided response, and the correct response. There are several additional
keyword arguments. This allows for more customized feedback than possible
using `show_feedback` and `feedback`, for example.
"""
function response(track::Adapter,resp::Pair...;keys...)
  record(x -> nothing,track,resp;keys...)
end

function response(fn::Function,track::Adapter,responses::Pair...;
                  correct=nothing,show_feedback=true,
                  feedback=Dict(true => "Correct!",false => "Wrong!"),
                  keys...)
  if isempty(correct_indices)
    error("The value of `correct` must be "*
          join(getindex.(response,2),", "," or "))
  end

  begin (event) ->
    for (key,resp) in responses
      if iskeydown(event,key)
        update(track,resp,correct)
        callback(resp,correct)

        if show_feedback
          display(feedback[resp==correct])
        end
        record(resp;correct=correct,keys...)
      end
    end
  end
end

"""
    levit_adapter([first_delta=0.1],[up=3],[down=1],
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
function levitt_adapter(;first_delta=0.1,up=3,down=1,big_reverse=3,
                        big=0.01,little=0.005,min_reversals=7,
                        drop_reversals=3,min_delta=-Inf,max_delta=Inf,
                        mult=false)
  next_delta = first_delta
  reversals = Float64[]
  last_direction = 0
  num_correct = 0
  num_incorrect = 0
  operator = (mult ? :mult : :add)
  adapter = Levitt{operator}(next_delta,up,down,big_reverse,big,little,
                             min_reversals,drop_reversals,min_delta,max_delta,
                             reversals,num_correct,num_incorrect)
end

type Levitt{OP}
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

function update_reversals(adaapter::Levitt,direction::Int)
  if (adapter.last_direction != 0 && direction != adapter.last_direction)
    push!(adapter.reversals,adapter.next_delta)
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
    adapter.delta = bound(op(adatper.delta,adapter.big),
                          adapter.min_delta,adapter.max_delta)
  else
    adapter.delta = bound(op(adapter.delta,adapter.little),
                          adapter.min_delta,adapter.max_delta)
  end
end

function update(adapter::Levitt,response,correct)
  if correct == response
    num_correct += 1
    num_incorrect = 0
    if num_correct >= adapter.down
      num_correct = 0
      update_reversals(adapter,-1)
      update_delta(adapter,down(adapter))
    end
  else
    num_incorrect += 1
    num_correct = 0
    if num_incorrect >= adapter.up
      num_incorrect = 0
      update_reversals(adapter,1)
      update_delta(adapter,up(adapter))
    end
  end
end

estimate_helper(a::Levitt{:add}) = mean(a),sd(a)
estimate_helper(a::Levitt{:mult}) = exp(mean(log(a))),exp(sd(log(a)))

function estimate(adapter::Levitt)
  if length(adapter.reversals) < adapter.min_reversals
    NaN,NaN
  else
    if isodd(length(adapter.reversals))
      estimate_helper(adapter.reversals[adapter.drop_reversals:end]))
    else
      estimate_helper(adapter.reversals[adapter.drop_reversals+1:end])
    end
  end
end

type ImportanceSampler
  miss::Float64
  threshold::Float64
  n_samples::Int
  thresh_d::UnivariateDistribution
  slope_d::UnivariateDistribution
  delta::Float64
  min_delta::Float64
  max_delta::Float64
  delta_repeat::Int
  resp = Dict{Float64,Int}
  N = Dict{Float64,Int}
end

"""
    baysian_adapter([first_delta=0.1],[n_samples=1000],[miss=0.01],
                    [threshold=0.79],[thresh_d=Normal(0,1)],
                    [slope_d=Normal(1,0.1)],[repeat3_thresh=0.1],
                    [repeat2_thresh=0.01],[min_delta=-Inf],[max_delta=Inf])

Creates an adapter that estimates the desired response threshold using
a bayesian approach, selecting the delta to be the best estimate of this
threshold. This is a modified version of the approach described in
Kontsevich & Tyler 1999.

This estimator is designed to find, in a reasonably short time, a good estimate
of the threshold. While past approaches have generally sought to select a delta
quite possibly far from the threshold (to better estiamte the overall
psychometric function), in practice this can lead to a less efficient estimate
of the threshold itself.

For stability and robustness, this adapter begins by repeating the same delta
multiple times and only begins quickly changing deltas trial-by-trial when the
ratio of standard deviation to the mean is small.

# Keyword Arugments

TODO...
"""
function bayesian_adapter(;first_delta=0.1,
                          n_samples=1000,miss=0.01,threshold=0.79,
                          thresh_d=Normal(0,1),slope_d=Normal(1,0.5),
                          repeat3_thresh=0.1,repeat2_thresh=0.01)
  delta = next_delta = first_delta
  delta_repeat = 0
  resp = Dict{Float64,Int}()
  N = Dict{Float64,Int}()
  ImportanceSampler(miss,threshold,n_samples,thresh_d,slope_d,delta,
                    delta_repeat,resp,N)
end

const sqrt_2 = sqrt(2)
phi_approx(x) = 1 / (1 + exp(-(0.07056x^3 + 1.5976x)))
function sample(adapter::ImportanceSampler)
  theta = rand(a.thresh_d,a.n_samples)
  slope = randn(a.slope_d,a.n_samples)
  q_log_prob = logpdf(a.thresh_d,theta) .+ logpdf(a.slope_d,theta)

  udeltas = collect(keys(a.resp))
  diffs = theta .- udeltas'
  p = (a.miss/2) + (1-a.miss)*phi_approx(exp(diffs.*slope)/sqrt_2)
  log_prob = sum(enumerate(udeltas)) do x
    i,delta = x
    logpdf.(Binom.(a.N[delta],p[:,i]),a.resp[delta])
  end

  lweights = log_prob - q_log_prob
  weights = exp.(lweights - max.(lweights))
  weights = sum(weights) / length(weights)
  ess = 1 / sum(weights.^2)

  if ess / length(weights) < 0.1
    warn("Effective sampling size of importance samples is low ",
         "($(round(ess,1))). Consider adjusting `thresh_mean` ",
         "`thresh_sd`, `slope_mean` and/or `slope_sd`.")
    record("poor_adaptor_ess",value=ess)
  end

  dprime = invlogcdf(Normal(),log((a.threshold-a.miss/2)/(1-a.miss)))
  thresh_off = -log(dprime)./slope
  thresh = theta + thresh_off
end

function update(adapter::ImportanceSampler,response,correct)
  a = track.adapter
  a.resp[track.next_delta] = get(a.resp,track.next_delta,0) +
    response==correct
  a.N[track.next_delta] = get(a.N,track.next_delta,0) + 1

  thresh,weights = sample(adapter)
  mean,sd = estimate(adapter)

  sd_ratio = sd / mean
  if sd_ratio > repeat3_thresh
    repeats = 2
  elseif sd_ratio > repeat2_thresh
    repeats = 1
  else
    repeats = 0
  end

  if steps < a.delta_repeat
    a.delta_repeat += 1
  else
    a.delta_repeat = 0
    a.delta = mean(thresh .* weights)
  end
end

function estimate(adapter::ImportanceSampler)
  thresh,weights = samples(adapter)
  μ = mean(thresh .* weights)
  M = weights .> 0
  σ = sqrt(sum(((μ .- thresh) .* weights).^2) /
           ((M-1)/M)*sum(weights))

  μ,σ
end

delta(adapter::ImportanceSampler) = bound(adapter.delta,adapter.min_delta,
adapter.max_delta)
