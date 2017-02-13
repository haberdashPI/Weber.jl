using PyCall
export reset_response

# called by __init__ in Weber.jl
function init_events()
  global const pyxid = pyimport_conda("pyxid","pyxid","haberdashPI")
  global const pyxid_devices = pyxid[:get_xid_devices]()
end

"""
      reset_resposne()

  Reset the response timer for all Cedrus response-pad devices.

  This function will rarely need to be explicitly called. The response timer is
  automatically reset at the start of each trial.
  """
function reset_response()
  for dev in pyxid_devices
    if dev[:is_response_device]()
      dev[:reset_base_timer]()
      dev[:reset_rt_timer]()
    end
  end
end


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
const win_event_ptr = 0x000000000000000c  # offsetof(SDL_WindowEvent,event)
const event_size = 0x0000000000000038     # sizeof(SDL_Event)

function poll_events(callback,exp::ExtendedExperiment,time::Float64)
  poll_events(callback,next(exp),time)
end

function poll_events{T <: BaseExperiment{SDLWindow}}(callback,exp::T,time::Float64)
  event_bytes = Array{Int8}(event_size)
  event = reinterpret(Ptr{Void},pointer(event_bytes))

  while ccall((:SDL_PollEvent,_psycho_SDL2),Cint,(Ptr{Void},),event) != 0
    etype = at(event,UInt32,type_ptr)
    if etype == SDL_KEYDOWN
      code = at(event,UInt32,keysym_ptr + sym_ptr)
      callback(exp,KeyDownEvent(code,time))
    elseif etype == SDL_KEYUP
      code = at(event,UInt32,keysym_ptr + sym_ptr)
      callback(exp,KeyUpEvent(code,time))
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

  for dev in pyxid_devices
    if dev[:is_response_device]()
      dev[:poll_for_response]()
      while dev[:response_queue_size]() > 0
        resp = dev[:get_next_response]()
        if resp["pressed"]
          callback(exp,CedrusDownEvent(resp["key"],resp["port"],
                                       resp["time"],time))
        else
          callback(exp,CedrusUpEvent(resp["key"],resp["port"],
                                     resp["time"],time))
        end
      end
    end
  end
end
