## Event.jl
for e in concrete_events
  precompile(response_time,(e,))
  precompile(time,(e,))
  precompile(isnull,(e,))
  precompile(iskeydown,(e,))
  precompile(iskeydown,(e,Int32))
  precompile(iskeyup,(e,))
  precompile(iskeyup,(e,Int32))
  precompile(ispad_down,(e,))
  precompile(ispad_down,(e,Int))
  precompile(ispad_up,(e,))
  precompile(ispad_up,(e,Int))
  precompile(isfocused,(e,))
  precompile(isunfocused,(e,))
end
precompile(event_streamer,(SDLWindow,Function))


## SoundUtil.jl
precompile(play,(Sound,))
precompile(play,(PlayingSound,))
precompile(pause,(PlayingSound,))
precompile(stop,(PlayingSound,))

## VideoUtil.jl
rendered_objects = [SDLClear,SDLTextured,SDLImage,SDLText,
                    EmptyRendered,DeleteRendered,
                    SDLCompound,RestoreDisplay]
for r in rendered_objects
  precompile(update_stack_helper,(SDLWindow,OrderedSet{SDLRendered},r))
end

precompile(handle_remove,(Signal,SDLRendered))
precompile(handle_remove,(Signal,SDLCompound))

precompile(update_stack,(SDLWindow,))

drawn_objects = [SDLClear,SDLTextured]
for r in drawn_objects
  precompile(draw,(SDLWindow,r))
end

precompile(display_stack,(SDLWindow,))

precompile(display,(SDLWindow,SDLRendered))

## Trial.jl
precompile(update_last,(ResponseMoment,))
precompile(update_last,(Moment,))
precompile(time,())
for typ in [Deque,MomentQueue]
  precompile(isempty,(typ,))
  precompile(dequeue!,(typ,))
  precompile(front,(typ,))
end
for m in [Moment,TimedMoment,OffsetStartMoment,FinalMoment]
  precompile(delta_t,(m,))
end
for m in [Moment,TimedMoment,OffsetStartMoment,FinalMoment]
  precompile(run,(m,Float64))
end
precompile(keep_skipping,(ExperimentState,Moment))
precompile(keep_skipping,(ExperimentState,OffsetStartMoment))
precompile(keep_skipping,(ExperimentState,ExpandingMoment))
precompile(keep_skipping,(ExperimentState,FinalMoment))
precompile(skip_offsets,(ExperimentState,MomentQueue))
for m in [ExpandingMoment,CompoundMoment,ResponseMoment,AbstractTimedMoment]
  for typ in [Float64,ExpEvent]
    precompile(handle,(ExperimentState,m,typ))
  end
end
precompile(process,(ExperimentState,MomentQueue,Float64))
precompile(process,(ExperimentState,MomentQueue,ExpEvent))
precompile(process,(ExperimentState,Array{MomentQueue},Any))
