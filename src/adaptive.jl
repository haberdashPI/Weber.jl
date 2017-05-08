using Distributions
export levitt_adapter, bayesian_adapter, constant_adapter, delta, estimate,
  update!

abstract type Adapter end

"""
    update!(adapter,response,correct)

Updates any internal state for the adapter when the listener responds with
`response` and the correct response is `correct`. Usually not called directly,
but instead called within `response`, when the adapter is passed as the first
argument. May take a while to run.
"""
function update!(adapter,response,correct)
end

"""
    estimate(adapter)

Returns the mean and error of the adapters threshold estimate. May take some
time to run.
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
    response([fn],adapter,[key1] => ["resp1"],...;correct=[resp],
             [show_feedback=true],
             [feedback=Dict(true=>"Correct",false=>"Wrong!")]
             keys...)

Record a response in a n-alternative forced choice task and update
an adapter.

The first response recieved is interpreted as the actual response. Subsequent
responses will be recorded, without a delta or correct value set, and appending
"late_" to the specified response string.

# Function Callback

Optionally, upon participant response, `fn` receives two arguments: the
provided response, and the correct response.

# Keyword Arguments

- `correct` the response string corresponding to the correct response
- `show_feedback` (default = true): whether to show feedback to the
  participant after they respond.
- `feedback` the text to display to a participant when they are correct
  (for the true key, defaults to "Correct!") or incorrect (for the false key,
  defaults to "Wrong!").

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

mutable struct ConstantStimulus
  stimuli::Vector{Float64}
  index::Int
  correct::Vector{Int}
  response::Vector{Int}
end

"""
    constant_adapter(stimuli)

An adapter that can be used to implement the method of constant stimuli: the
specified sequence of stimulus deltas is presented in order to participants.

Strictly speaking, this is not an adaptive tracking procedure. However,
it can be convienient to have the same programming interface for this method as
for adaptive methods. In this way you can easily select between the method of
constant stimuli or some kind of adaptive procedure.
"""
constant_adapter(stimuli) = ConstantStimulus(stimuli,1,Int[],Int[])
delta(adapter::ConstantStimulus) = adapter.stimuli[adapter.index]
function update!(adapter::ConstantStimulus,response,correct)
  adapte.index += 1
  nothing
  # push!(adapter.correct,correct)
  # push!(adapter.response,response)
end
function estimate(adapter::ConstantStimulus)
  error("The `estimate` method for `ConstantStimulus` is not implemented!")
  # TODO: fit a curve to the responses to estimate the threshold???
end

"""
    levitt_adapter([first_delta=0.1],[down=3],[up=1],
                   [big_reverse=3],[big=0.01],[little=0.005],
                   [min_reversals=7],[min_delta=-Inf],[max_delta=Inf],
                   [mult=false])

An adapter that finds a threshold according to a non-parametric statistical
procedure. This approach makes fewer explicit assumptions than
[`bayesian_adapter`](@ref) but may be slower to converge to a threshold.

This finds a threshold by moving the delta down after three correct responses
and up after one incorrect response (these default up and down counts can be
changed). This is the same approach described in Levitt (1971).

# Keyword Arguments

- `first_delta`: the delta that the first trial should present.
- `up`: how many incorrect responses in a row must occur for the delta
  to move up
- `down`: how many correct responses in a row must occur for the delta
  to move down.
- `big`: the amount delta changes by (up or down) at first
- `big_reverse`: how many reveresals (up to down or down to up) must
  occur before `little` is used instead of `big`
- `little`: the amount delta changes by (up or down) after
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

estimate_helper(a::Levitt{:add},rev) = mean(rev),std(rev)
estimate_helper(a::Levitt{:mult},rev) =
  exp(mean(log(rev))),exp(mean(log(rev)))*(1-exp(-std(log(rev))))

function estimate(adapter::Levitt)
  if length(adapter.reversals) < adapter.min_reversals
    NaN,NaN
  else
    if isodd(length(adapter.reversals))
      estimate_helper(adapter,adapter.reversals[adapter.drop_reversals:end])
    else
      estimate_helper(adapter,adapter.reversals[adapter.drop_reversals+1:end])
    end
  end
end

type ImportanceSampler <: Adapter
  miss::Float64
  threshold::Float64
  thresh_d::UnivariateDistribution
  inv_slope_d::UnivariateDistribution
  n_samples::Int

  theta_prior::UnivariateDistribution
  inv_slope_prior::UnivariateDistribution

  delta::Float64
  min_delta::Float64
  max_delta::Float64
  delta_repeat::Int

  resp::Dict{Float64,Int}
  N::Dict{Float64,Int}
  thresh_samples::Vector{Float64}
  theta_samples::Vector{Float64}
  inv_slope_samples::Vector{Float64}
  thresh_weights::Vector{Float64}

  repeat2_thresh::Float64
  repeat3_thresh::Float64
end

# TODO: prior is working, but improve it to make the
# parameters easy to specify???

"""
    bayesian_adapter(;first_delta=0.1,
                     n_samples=1000,miss=0.01,threshold=0.79,
                     min_delta=0,max_delta=1,
                     min_plausible_delta = 0.0001,
                     max_plausible_delta = 0.2,
                     repeat3_thresh=1.0,repeat2_thresh=0.1,
                     thresh_prior=
                     Truncated(LogNormal(log(min_plausible_delta),
                                         log(max_plausible_delta/
                                             min_plausible_delta/2)),
                               min_delta,max_delta),
                          inv_slope_prior=TruncatedNormal(0,0.25,0,Inf),
                          thresh_d=thresh_prior,
                          inv_slope_d=inv_slope_prior)

An adapter that finds a threshold according to a parametric statistical
model. This makes more explicit assumptions than the [`levitt_adapter`](@ref)
but will normally find a threshold faster.

The psychometric curve is estimated from user responses using a bayesian
approach. After estimation, each new delta is selected in a greedy fashion,
picking the response that best minimizes entropy according to this psychometric
function. This is a modified version of the approach described in Kontsevich &
Tyler 1999. Specifically, the approach here uses importance sampling instead of
sampling parmeters over a deterministic, uniform grid. This should increase
measurement efficiency if the priors are chosen well.

This algorithm assumes the following functional form for the psychometric
response as a function of the stimulus difference ``Δ``.

``
f(Δ) = λ/2 + (1-λ) Φ((Δ - θ)⋅σ/√2)
``

In the above ``Φ`` is the cumulative distribution function of a normal
distribution, ``λ`` is the miss-rate parameter, indicating the rate at which
listeners make a mistake, even when the delta is large and easily heard, ``θ``
is the 50%-correct threshold, and ``σ`` is the psychometric slope.

For stability and robustness, this adapter begins by repeating the same delta
multiple times and only begins quickly changing deltas trial-by-trial when the
ratio of estiamted standard deviation to mean is small. This functionality can
be adjusted using `repeat3_thresh` and `repeat2_thresh`, or, if you do not wish
to have any repeats, both values can be set to Inf.

# Keyword Arugments

- **first_delta**: the delta to start measuring with
- **n_samples** the number of samples to use during importance sampling.
  The algorithm for selecting new deltas is O(n²).
- **miss** the expected rate at which listeners will make mistakes
  even for easy to percieve differences.
- **threshold** the %-response threshold to be estimated
- **min_delta** the smallest possible delta
- **max_delta** the largest possible delta
- **min_plausible_delta** the smallest plausible delta, should be > 0.
  Used to define a reasonable value for thresh_prior and inv_slope_prior.
- **max_plausible_delta** the largest plausible delta, should be < max_delta.
  Used to define a reasonable value for thresh_prior and inv_slope_prior.
- **thresh_prior** the prior probability distribution across thresholds.
  This influence the way the delta is adapted. By default this is defined in
  terms of min_plausible_delta and max_plausible_delta.
- **inv_slope_prior** the prior probability distribution across inverse slopes.
  By default this is defined in terms of min_plausible_delta and
  max_plausible_delta.
- **thresh_d** the distribution over-which to draw samples for the threshold
  during importance sampling. This defaults to thresh_prior
- **inv_slope_d** the distribution over-which to draw samples for the inverse slope
  during importance sampling. This defaults to inv_slope_prior.
- **repeat2_thresh** the ratio of sd / mean for theta must suprass
  to repeat each delta twice.
- **repeat3_thresh** the ratio of sd / mean for theta must surpass
  to repeat each delta thrice.
"""
function bayesian_adapter(;first_delta=0.1,
                          n_samples=1000,miss=0.01,threshold=0.79,
                          min_delta=0,max_delta=1,
                          min_plausible_delta = 0.0001,
                          max_plausible_delta = 0.2,
                          repeat3_thresh=1.0,repeat2_thresh=0.1,
                          thresh_prior=
                          Truncated(LogNormal(log(min_plausible_delta),
                                              log(max_plausible_delta/
                                                  min_plausible_delta/2)),
                                    min_delta,max_delta),
                          inv_slope_prior=
                          TruncatedNormal(0,2max_plausible_delta,0,Inf),
                          thresh_d=thresh_prior,
                          inv_slope_d=inv_slope_prior)
  delta = first_delta
  delta_repeat = 0
  resp = Dict{Float64,Int}()
  N = Dict{Float64,Int}()
  samples = ones(0)
  weights = ones(0)
  ImportanceSampler(miss,threshold,thresh_d,inv_slope_d,n_samples,
                    thresh_prior,inv_slope_prior,
                    delta,min_delta,max_delta,delta_repeat,
                    resp,N,samples,samples,samples,weights,
                    repeat3_thresh,repeat2_thresh)
end

const sqrt_2 = sqrt(2)
function sample(a::ImportanceSampler)
  if length(a.thresh_samples) == 0
    theta = rand(a.thresh_d,a.n_samples)
    inv_slope = rand(a.inv_slope_d,a.n_samples)
    q_log_prob = logpdf(a.thresh_d,theta) .+ logpdf(a.inv_slope_d,inv_slope)

    udeltas = collect(keys(a.resp))
    x = exp((udeltas' .- theta)./inv_slope)/sqrt_2
    p = (a.miss/2) + (1-a.miss)*cdf(Normal(),x)
    log_prob = sum(enumerate(udeltas)) do x
      i,delta = x
      logpdf.(Binomial.(a.N[delta],p[:,i]),a.resp[delta])
    end + logpdf(a.theta_prior,theta) + logpdf(a.inv_slope_prior,inv_slope)

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
    thresh_off = -log(dprime).*inv_slope
    a.theta_samples = theta
    a.inv_slope_samples = inv_slope
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

    # TODO: sample these differences to make sure this is a reasonably
    # sized array
    # TODO: debug selection

    entropies = -sum(1:adapter.n_samples) do i
      diff = adapter.thresh_samples[i] .- adapter.theta_samples
      dprime = exp(diff./adapter.inv_slope_samples)/sqrt_2
      p = ((adapter.miss/2) + (1-adapter.miss)*cdf(Normal(),dprime))
      (p .* log(p) + (1-p) .* log(1-p)) .* weights
    end

    _,i = findmax(entropies)

    adapter.delta = adapter.thresh_samples[i]
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
