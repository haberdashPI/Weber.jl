

poll_events{T <: BaseExperiment{NullWindow}}(callback,exp::T,time::Float64) = nothing

const SDL_KEYDOWN = 0x00000300
const SDL_KEYUP = 0x00000301
const SDL_WINDOWEVENT = 0x00000200
const SDL_QUIT = 0x00000100

const SDL_WINDOWEVENT_FOCUS_GAINED = 0x0000000c
const SDL_WINDOWEVENT_FOCUS_LOST = 0x0000000d

const type_ptr = 0x0000000000000000       # offsetof(SDL_Event,type)
const keysym_ptr = 0x0000000000000010     # offsetof(SDL_KeyboardEvent,keysym)
const sym_ptr = 0x0000000000000004        # offsetof(SDL_Keysym,sym)
const mod_ptr = 0x0000000000000008        # offsetof(SDL_Keysym,mod)
const win_event_ptr = 0x000000000000000c  # offsetof(SDL_WindowEvent,event)
const event_size = 0x0000000000000038     # sizeof(SDL_Event)

function poll_events(callback,exp::ExtendedExperiment,time::Float64)
  poll_events(callback,next(exp),time)
end

"""
     Weber.poll_events(callback,experiment,time)

Call the function `callback`, possibility multiple times, passing it an event
object each time. The time at which the events are polled is passed,
allowing this time to be stored with the event.

!!! warning

    This function should never be called directly by user code. A new
    method of this function can be implemented to extend Weber,
    allowing it to report new kinds events.

"""
function poll_events{T <: BaseExperiment{SDLWindow}}(callback,exp::T,time::Float64)
  event_bytes = Array{Int8}(event_size)
  event = reinterpret(Ptr{Void},pointer(event_bytes))

  while ccall((:SDL_PollEvent,weber_SDL2),Cint,(Ptr{Void},),event) != 0
    etype = at(event,UInt32,type_ptr)
    if etype == SDL_KEYDOWN
      code = at(event,UInt32,keysym_ptr + sym_ptr)
      mod = at(event,UInt16,keysym_ptr + mod_ptr)
      callback(exp,KeyDownEvent(code,mod,time))
    elseif etype == SDL_KEYUP
      code = at(event,UInt32,keysym_ptr + sym_ptr)
      mod = at(event,UInt16,keysym_ptr + mod_ptr)
      callback(exp,KeyUpEvent(code,mod,time))
    elseif etype == SDL_WINDOWEVENT
      wevent = at(event,UInt8,win_event_ptr)
      if wevent == SDL_WINDOWEVENT_FOCUS_GAINED
        callback(exp,WindowFocused(time))
      elseif wevent == SDL_WINDOWEVENT_FOCUS_LOST
        callback(exp,WindowUnfocused(time))
      end
    elseif etype == SDL_QUIT
      callback(exp,QuitEvent())
    end
  end
end
