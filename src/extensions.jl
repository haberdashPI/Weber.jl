@extension Cedrus begin
"""
[Extension Website](https://github.com/haberdashPI/WeberCedrus.jl)

    @Cedrus()

Creates an extension for Weber allowing experiments to respond to events from
Cedrus response-pad hardware. You can use [`iskeydown`](@ref) and
[`iskeyup`](@ref) to check for events. To find the keycodes of the buttons for
your response pad, run the following code, and press each of the buttons on the
response pad.

    run_keycode_helper(extensions=[@Cedrus()])

"""
end

@extension DAQmx begin
"""
[Extension Website](https://github.com/haberdashPI/WeberDAQmx.jl)

    @DAQmx(port;eeg_sample_rate,[codes])

Create a Weber extension that writes `record` events to a digital
out line via the DAQmx API. This can be used to send trigger
codes during eeg recording.

# Arguments

* port: should be `nothing`, to disable the extension, or
  the port name for the digital output line.
* eeg_sample_rate: should be set to the sampling rate for
  eeg recording. This calibrates the code length for triggers.
* codes: a Dict that maps record event codes (a string) to a number.
  This should be an Integer less than 256. Any codes not
  specified here will be automatically set, based on the order
  in which codes are recieved.

# Example

The following experiment sends the code 0x01 to port0 on TestDevice.

    port = "/TestDevice/port0/line0:7"
    experiment = Experiment(extensions=[
      @DAQmx(port;eeg_sample_rate=512,codes=Dict("test" => 0x01))])
    setup(experiment) do
      addtrial(moment(record,"test"))
    end
    run(experiment)
"""
end
