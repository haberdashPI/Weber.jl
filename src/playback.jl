export play, stream, stop, setup_sound, current_sound_latency, resume_sounds,
  pause_sounds, stream_unit
const weber_sound_version = 2

let
  version_in_file =
    match(r"libweber-sound\.([0-9]+)\.(dylib|dll)",weber_sound).captures[1]
  if parse(Int,version_in_file) != weber_sound_version
    error("Versions for weber sound driver do not match. Please run ",
          "Pkg.build(\"Weber\").")
  end
end

const default_sample_rate = 44100Hz

type SoundSetupState
  samplerate::Freq{Int}
  playing::Dict{Sound,Float64}
  state::Ptr{Void}
  num_channels::Int
  queue_size::Int
  stream_unit::Int
end
const default_stream_unit = 2^11
const sound_setup_state = SoundSetupState(0Hz,Dict(),C_NULL,0,0,default_stream_unit)
isready(s::SoundSetupState) = s.samplerate != 0Hz

"""
    stream_unit()

Report the length in samples of each unit that all sound streams should generate.
"""
stream_unit(s::SoundSetupState=sound_setup_state) = s.stream_unit

"""
With no argument samplerate reports the current playback sample rate, as
defined by [`setup_sound`](@ref).
"""
function samplerate(s::SoundSetupState=sound_setup_state)
  if s.samplerate == 0Hz
    default_sample_rate
  else
    s.samplerate
  end
end



# Give some time after the sound stops playing to clean it up.
# This ensures that even when there is some latency
# the sound will not be GC'ed until it is done playing.
const sound_cleanup_wait = 2

# register_sound: ensures that sounds are not GC'ed while they are
# playing. Whenever a new sound is registered it removes sounds that are no
# longer playing. This is called internally by all methods that send requests to
# play sounds to the weber-sound library (implemented in weber_sound.c)
function register_sound(current::Sound,done_at::Float64)
  setstate = sound_setup_state
  setstate.playing[current] = done_at
  for s in keys(setstate.playing)
    done_at = setstate.playing[s]
    if done_at > Weber.tick() + sound_cleanup_wait
      delete!(setstate.playing,s)
    end
  end
end

function ws_if_error(msg)
  if sound_setup_state.state != C_NULL
    str = unsafe_string(ccall((:ws_error_str,weber_sound),Cstring,
                              (Ptr{Void},),sound_setup_state.state))
    if !isempty(str) error(msg*" - "*str) end

    str = unsafe_string(ccall((:ws_warn_str,weber_sound),Cstring,
                              (Ptr{Void},),sound_setup_state.state))
    if !isempty(str) && show_latency_warnings()
      warn(msg*" - "*str*moment_trace_string())
    end
  end
end

"""
    setup_sound(;[sample_rate=samplerate()],[num_channels=8],[queue_size=8],
                [stream_unit=2^11])

Initialize format and capacity of audio playback.

This function is called automatically (using the default settings) the first
time a `Sound` object is created (normally during [`play`](@ref) or
[`stream`](@ref)).  It need not normally be called explicitly, unless you wish
to change one of the default settings.

# Sample Rate

Sample rate determines the maximum playable frequency (max freq is ≈
sample_rate/2). Changing the sample rate from the default 44100 to a new value
will also change the default sample rate sounds will be created at, to match
this new sample rate.

# Channel Number

The number of channels determines the number of sounds and streams that can be
played concurrently. Note that discrete sounds and streams use a distinct set of
channels.

# Queue Size

Sounds can be queued to play ahead of time (using the `time` parameter of
[`play`](@ref)). When you request that a sound be played it may be queued to
play on a channel where a sound is already playing. The number of sounds that
can be queued to play at once is determined by queue size. The number of
channels times the queue size determines the number of sounds that you can queue
up to play ahead of time.

# Stream Unit

The stream unit determines the number of samples that are streamed at one time.
Iterators to be used as streams should generate this many samples at a time.  If
this value is too small for your hardware, streams will sound jumpy. However the
latency of streams will increase as the stream unit increases. Future versions
of Weber will likely improve the latency of stream playback.

"""
function setup_sound(;sample_rate=samplerate(),
                     buffer_size=nothing,queue_size=8,num_channels=8,
                     stream_unit=default_stream_unit)
  sample_rate_Hz = inHz(Int,sample_rate)
  empty!(sound_cache)

  if isready(sound_setup_state)
    ccall((:ws_close,weber_sound),Void,(Ptr{Void},),sound_setup_state.state)
    ws_if_error("While closing old audio stream during setup")
    ccall((:ws_free,weber_sound),Void,(Ptr{Void},),sound_setup_state.state)
  else

    if !weber_sound_is_setup[]
      weber_sound_is_setup[] = true
      atexit() do
        sleep(0.1)
        ccall((:ws_close,weber_sound),Void,
              (Ptr{Void},),sound_setup_state.state)
        ws_if_error("While closing audio stream at exit.")
        ccall((:ws_free,weber_sound),Void,
              (Ptr{Void},),sound_setup_state.state)
      end
    end
  end
  if samplerate() != sample_rate_Hz
    warn(cleanstr("The sample rate is being changed from "*
         "$(samplerate()) to $(sample_rate_Hz)"*
         "Sounds you've created that do not share this new sample rate may "*
         "not play correctly."))
  end

  sound_setup_state.samplerate = sample_rate_Hz
  sound_setup_state.state = ccall((:ws_setup,weber_sound),Ptr{Void},
                                  (Cint,Cint,Cint,),ustrip(sample_rate_Hz),
                                  num_channels,queue_size)
  sound_setup_state.num_channels = num_channels
  sound_setup_state.queue_size = queue_size
  sound_setup_state.stream_unit = stream_unit
  ws_if_error("While trying to initialize sound")
end

"""
    current_sound_latency()

Reports the current, minimum latency of audio playback.

The current latency depends on your hardware and software drivers. This
estimate does not include the time it takes for a sound to travel from
your sound card to speakers or headphones. This latency estimate is used
internally by [`play`](@ref) to present sounds at accurate times.
"""
function current_sound_latency()
  ccall((:ws_cur_latency,weber_sound),Cdouble,
        (Ptr{Void},),sound_setup_state.state)
end

"""
    play(x;[time=0.0],[channel=0])

Plays a sound (created via [`sound`](@ref)).

For convenience, play can also can be called on any object that can be turned
into a sound (via `sound`).

This function returns immediately with the channel the sound is playing on. You
may provide a specific channel that the sound plays on: only one sound can be
played per channel. Normally it is unecessary to specify a channel, because an
appropriate channel is selected for you. However, pausing and resuming of
sounds occurs on a per channel basis, so if you plan to pause a specific
sound, you can do so by specifying its channel.

If `time > 0`, the sound plays at the given time (in seconds from epoch, or
seconds from experiment start if an experiment is running), otherwise the sound
plays as close to right now as is possible.
"""
function play(x;time=0.0,channel=0)
  if !isready(sound_setup_state)
    setup_sound()
  end

  if in_experiment() && !experiment_running()
    error("You cannot call `play` during experiment `setup`. During `setup`",
          " you should add play to a trial (e.g. ",
          "`addtrial(moment(play,my_sound))`).")
  end
  warn("Calling play outside of an experiment moment.")
  _play(x,time,channel)
end

function _play(x,time=0.0,channel=0)
  play(sound(x),time,channel)
end

immutable WS_Sound
  buffer::Ptr{Void}
  len::Cint
end

function play{R}(x::Sound{R,Q0f15,2},time::Float64=0.0,channel::Int=0)
  if R != ustrip(samplerate())
    error("Sample rate of sound ($(R*Hz)) and audio playback ($(samplerate()))",
          " do not match. Please resample this sound by calling `resample` ",
          "or `sound`.")
  end
  if !(1 <= channel <= sound_setup_state.num_channels || channel <= 0)
    error("Channel $channel does not exist. Must fall between 1 and",
          " $(sound_setup_state.num_channels)")
  end

  # first, verify the sound can be played when we want to
  if time > 0.0
    latency = current_sound_latency()
    now = Weber.tick()
    if now + latency > time && show_latency_warnings()
      if latency > 0
        warn("Requested timing of sound cannot be achieved. ",
             "With your hardware you cannot request the playback of a sound ",
             "< $(round(1000*latency,2))ms before it begins.",
             moment_trace_string())
      else
        warn("Requested timing of sound cannot be achieved. ",
             "Give more time for the sound to be played.",
             moment_trace_string())
      end
      if experiment_running()
        record("high_latency",value=(now + latency) - time)
      end
    end
  elseif experiment_running() && show_latency_warnings()
    warn("Cannot guarantee the timing of a sound. Add a delay before playing the",
         " sound if precise timing is required.",moment_trace_string())
  end

  # play the sound
  channel = ccall((:ws_play,weber_sound),Cint,
                  (Cdouble,Cdouble,Cint,Ref{WS_Sound},Ptr{Void}),
                  Weber.tick(),time,channel-1,
                  WS_Sound(pointer(x.data),size(x,1)),
                  sound_setup_state.state) + 1
  ws_if_error("While playing sound")
  register_sound(x,(time > 0.0 ? time : Weber.tick()) + ustrip(duration(x)))

  channel
end

type Streamer
  next_stream::Float64
  channel::Int
  itr_state
  itr
end
show(stream::IO,streamer::Streamer) =
  write(stream,"<Streamer channel: $(streamer.channel)>")

# function setup_streamers()
#   streamers[-1] = Streamer(0.0,0,nothing,nothing)
#   Timer(1/60,1/60) do timer
#     for streamer in values(streamers)
#       if streamer.itr != nothing
#         process(streamer)
#       end
#     end
#   end
# end

# const num_channels = 8
# const streamers = Dict{Int,Streamer}()
# """
#     stream([itr | fn],channel=1)

# Plays sounds continuously on a given channel by reading from the iterator `itr`
# whenever more data is required. The iterator should return objects that can be
# turned into sounds (via [`sound`](@ref)). The number of available streaming
# channels is determined by [`setup_sound`](@ref). The size, in samples, of each
# sound returned by this iterator should be equal to [`stream_unit`](@ref).

# Alternatively a `fn` can be streamed: this transforms a previously streamed itr
# into a new iterator by calling `fn(itr)`. If no stream already exists on the
# given channel, `fn` is passed the result of `countfrom()`.

# A stream stops playing if the iterator is finished. There can only be one stream
# per channel.  Streaming a new iterator on the same channel as another stream
# stops the older stream. The channels for `stream` are separate from the channels
# for `play`. That is, `play(mysound,channel=1)` plays a sound on a channel
# separate from `stream(mystream,1)`.

# !!! warning "Streams are not precisely timed"

#     Streams cannot occur at a precise time. Their latency is variable and
#     depends on the value of `stream_unit()`. Future versions of Weber will
#     likely allow for precisely timed audio streams.

# """

# function stream(itr,channel::Int=1)
#   !isready(sound_setup_state) ? setup_sound() : nothing
#   @assert 1 <= channel <= sound_setup_state.num_channels
#   itr_state = start(itr)
#   stop(channel)

#   if in_experiment()
#     data(get_experiment()).streamers[channel] =
#       Streamer(tick(),channel,itr_state,itr)
#   else
#     if isempty(streamers)
#       setup_streamers()
#     end
#     streamers[channel] = Streamer(tick(),channel,itr_state,itr)
#   end
# end

# function stream(fn::Function,channel::Int)
#   !isready(sound_setup_state) ? setup_sound() : nothing
#   @assert 1 <= channel <= sound_setup_state.num_channels
#   dict = in_experiment() ? data(get_experiment()).streamers : streamers
#   itr = if channel in keys(dict)
#     streamer = dict[channel]
#     delete!(dict,channel)
#     rest(streamer.itr,streamer.itr_state)
#   else
#     countfrom()
#   end

#   stream(fn(itr),channel)
# end

"""
    stop(channel)

Stop the stream that is playing on the given channel.
"""
function stop(channel::Int)
  @assert 1 <= channel <= sound_setup_state.num_channels
  if in_experiment()
    delete!(data(get_experiment()).streamers,channel)
  else
    delete!(streamers,channel)
  end
  nothing
end

function process(streamer::Streamer)
  nothing
end

#   if !done(streamer.itr,streamer.itr_state)
#     obj, next_state = next(streamer.itr,streamer.itr_state)
#     x = sound(obj,false)
#     @assert samplerate(x) == samplerate()

#     done_at = -1.0

#     done_at = ccall((:ws_play_next,weber_sound),Cdouble,
#                     (Cdouble,Cint,Ref{WS_Sound},Ptr{Void}),
#                     tick(),streamer.channel-1,x.chunk,
#                     sound_setup_state.state)
#     ws_if_error("While playing sound")
#     if done_at < 0
#       # sound not ready to be queued for playing, wait a bit and try again
#       streamer.next_stream += 0.05duration(x)
#     else
#       # sound was queued to play, wait until this queued sound actually
#       # starts playing to queue the next stream unit
#       register_sound(x,done_at)
#       streamer.next_stream += 0.75duration(x)
#       streamer.itr_state = next_state
#     end
#   else stop(streamer.channel) end
# end

"""
    play(fn::Function)

Play the sound that's returned by calling `fn`.
"""
function play(fn::Function;keys...)
  play(fn();keys...)
end

"""
    pause_sounds([channel],[isstream])

Pause all sounds (or a stream) playing on a given channel.

If no channel is specified, then all sounds are paused.
"""
function pause_sounds(channel=-1,isstream=false)
  if isready(sound_setup_state)
    @assert 1 <= channel <= sound_setup_state.num_channels || channel <= 0
    ccall((:ws_pause,weber_sound),Void,(Ptr{Void},Cint,Cint,Cint),
          sound_setup_state.state,channel-1,isstream,true)
    ws_if_error("While pausing sounds")
  end
end

"""
    resume_sounds([channel],[isstream])

Resume all sounds (or a stream) playing on a given channel.

If no channel is specified, then all sounds are resumed.
"""
function resume_sounds(channel=-1,isstream=false)
  if isready(sound_setup_state)
    @assert 1 <= channel <= sound_setup_state.num_channels || channel <= 0
    ccall((:ws_pause,weber_sound),Void,(Ptr{Void},Cint,Cint,Cint),
        sound_setup_state.state,channel-1,isstream,false)
    ws_if_error("While resuming audio playback")
  end
end
