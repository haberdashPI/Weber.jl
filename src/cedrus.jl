module Cedrus
using PyCall
export CedrusXID, reset_response, response_time

using Weber
import Weber: keycode, iskeydown, iskeyup, addtrial, addpractice, poll_events
import Base: hash, isless, ==, show

type CedrusXID <: Weber.Extension
  devices::PyObject
end
"""
    CedrusXID()

Creates an extension for Weber experiments allowing an experiment to respond to
events from Cedrus response-pad hardware. You can use [`iskeydown`](@ref) and
[`iskeyup`](@ref) to check for events. To find the keycodes of the
buttons for your response pad, run the following code, and press each of the
buttons.

    run_keycode_helper(extensions=[CedrusXID()])
"""
function CedrusXID()
  pyxid = pyimport_conda("pyxid","pyxid","haberdashPI")
  CedrusXID(pyxid[:get_xid_devices]())
end

@Weber.event type CedrusDownEvent <: Weber.ExpEvent
  code::Int
  port::Int
  rt::Float64
  time::Float64
end


@Weber.event type CedrusUpEvent <: Weber.ExpEvent
  code::Int
  port::Int
  rt::Float64
  time::Float64
end

type CedrusKey <: Weber.Key
  code::Int
end

# make sure the cedrus keys have a well defined ordering
hash(x::CedrusKey,h::UInt) = hash(CedrusKey,hash(x.code,h))
==(x::CedrusKey,y::CedrusKey) = x.code == y.code
isless(x::CedrusKey,y::CedrusKey) = isless(x.code,y.code)

# make sure cedrus keys are displayed in a easily readable form
function show(io::IO,x::CedrusKey)
  if 0 <= x.code <= 19
    write(io,"key\":cedrus$(x.code):\"")
  else
    write(io,"Weber.CedrusKey($(x.code))")
  end
end

merge!(Weber.str_to_code,Dict(
  ":cedrus0:" => CedrusKey(0),
  ":cedrus1:" => CedrusKey(1),
  ":cedrus2:" => CedrusKey(2),
  ":cedrus3:" => CedrusKey(3),
  ":cedrus4:" => CedrusKey(4),
  ":cedrus5:" => CedrusKey(5),
  ":cedrus6:" => CedrusKey(6),
  ":cedrus7:" => CedrusKey(7),
  ":cedrus8:" => CedrusKey(8),
  ":cedrus9:" => CedrusKey(9),
  ":cedrus10:" => CedrusKey(10),
  ":cedrus11:" => CedrusKey(11),
  ":cedrus12:" => CedrusKey(12),
  ":cedrus13:" => CedrusKey(13),
  ":cedrus14:" => CedrusKey(14),
  ":cedrus15:" => CedrusKey(15),
  ":cedrus16:" => CedrusKey(16),
  ":cedrus17:" => CedrusKey(17),
  ":cedrus18:" => CedrusKey(18),
  ":cedrus19:" => CedrusKey(19)
))

keycode(e::CedrusDownEvent) = CedrusKey(e.code)
keycode(e::CedrusUpEvent) = CedrusKey(e.code)

iskeydown(event::CedrusDownEvent) = true
iskeydown(key::CedrusKey) = e -> iskeydown(e,key::CedrusKey)
iskeydown(event::CedrusDownEvent,key::CedrusKey) = event.code == key.code

iskeyup(event::CedrusUpEvent) = true
iskeyup(key::CedrusKey) = e -> iskeydown(e,key)
iskeyup(event::CedrusUpEvent,key::CedrusKey) = event.code == key.code

"""
    response_time(e::ExpEvent)

Get the response time an event occured at. Only meaningful for response pad
events (returns NaN in other cases). The response time is normally measured from
the start of a trial (see `reset_response`).
"""
response_time(e::Weber.ExpEvent) = NaN
response_time(e::CedrusUpEvent) = e.rt
response_time(e::CedrusDownEvent) = e.rt

"""
    reset_response(cedrus::CedrusXID)

Reset the response timer for all Cedrus response-pad devices.

This function will rarely need to be explicitly called. The response timer is
automatically reset at the start of each trial.
"""
function reset_response(cedrus::CedrusXID)
  for dev in cedrus.devices
    if dev[:is_response_device]()
      dev[:reset_base_timer]()
      dev[:reset_rt_timer]()
    end
  end
end

function addtrial(e::ExtendedExperiment{CedrusXID},moments...)
  addtrial(next(e),moment(reset_response,extension(e)),moments...)
end

function addpractice(e::ExtendedExperiment{CedrusXID},moments...)
  addpractice(next(e),moment(reset_response,extension(e)),moments...)
end

function poll_events(callback::Function,exp::ExtendedExperiment{CedrusXID},time::Float64)
  poll_events(callback,next(exp),time)
  for dev in extension(exp).devices
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

end
