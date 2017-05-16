So far we have seen several examples of how to generate sounds and simple images (text). Here we'll cover stimulus generation in more detail.

# Sounds

Weber's primary focus is on psychoacoustics, so there are many methods for generating and manipulation sounds. There are two primary ways to create sound stimuli: loading a file and sound primitives.

## Loading a file

Generating stimuli by loading a file is easy. You simply play the given file, like so.

```julia
addtrial(moment(play,"mysound_file.wav"))
```

!!! note "Sounds are cached"

    You can safely play the same file multiple times: the sound is cached, and will only load into memory once.

If you need to manipulate the sound before playing it, you can load it using [`sound`](@ref).  For example, to remove any frequencies from `"mysound_file.wav"` above 400Hz before playing the sound, you could do the following.

```julia
mysound = lowpass(sound("mysound_file.wav"),400Hz)
addtrial(moment(play,mysound))
```

## Sound Primivites

There are several primitives you can use to generate simple sounds directly in Weber. They are [`tone`](@ref) (to create pure tones), [`noise`](@ref) (to generate white noise), [`silence`](@ref) (for a silent period) and [`harmonic_complex`](@ref), (to create multiple pure tones with integer frequency ratios).

These primitives can then be combined and manipuliated to generate more interesting sounds. You can filter sounds ([`bandpass`](@ref), [`bandstop`](@ref), [`lowpass`](@ref), [`highpass`](@ref) and [`lowpass`](@ref)), mix them together ([`mix`](@ref)) and set an appropriate decibel level ([`attenuate`](@ref)). You can also manipulate the envelope of the sound ([`ramp`](@ref), [`rampon`](@ref), [`rampoff`](@ref), [`fadeto`](@ref), [`envelope`](@ref) and [`mult`](@ref)).

For instance, to play a 1 kHz tone for 1 second inside of a noise with a notch from 0.5 to 1.5 kHz, with 5 dB SNR you could call the following.

```julia
mysound = tone(1kHz,1s)
mysound = ramp(mysound)
mysound = attenuate(mysound,20)

mynoise = noise(1s)
mynoise = bandstop(mynoise,0.5kHz,1.5kHz)
mynoise = attenuate(mynoise,25)

addtrial(moment(play,mix(mysound,mynoise))
```

Weber exports the macro `@>` (from [Lazy.jl](https://github.com/MikeInnes/Lazy.jl)) to simplify this pattern. It is easiest to understand the macro by example: the below code yields the same result as the code above.

```juila
mytone = @> tone(1kHz,1s) ramp attenuate(20)
mynoise = @> noise(1s) bandstop(0.5kHz,1.5kHz) attenuate(25)
addtrial(moment(play, mix(bandstop(noise(1s),0.5kHz,1.5kHz))))
```

Weber also exports `@>>`, and `@_` (refer to the Lazy.jl's README.md for details).

## Sounds are arrays
Sounds can be manipulated in the same way that any array can be manipulated in Julia, with some additional support for indexing sounds using time units. For instance, to get the first 5 seconds of a sound you can do the following.

```julia
mytone = tone(1kHz,10s)
mytone[0s .. 5s]
```

Furthermore, we can concatentate multiple sounds, to play them in sequence. The following code plays two tones in sequence, with 100ms gap between them.

```julia
interval = [tone(400Hz,50ms); silence(100ms); tone(400Hz * 2^(5/12),50ms)]
addtrial(moment(play,interval))
```

## Stereo Sounds

You can create sounds with using [`leftright`](@ref), and reference the left and right channel of a sound using `:left` or `:right` as a second index, like so.

```julia
stereo_sound = leftright(tone(1kHz,2s),tone(2kHz,2s))
addtrial(moment(play,stereo_sound[:,:left],
         moment(2s,play,stereo_sound[:,:right]))
```

The functions [`left`](@ref) and [`right`](@ref) serve the same purpose, but can also operate on streams.

## Streams

In addition to the discrete sounds that have been discussed so far, Weber also supports sound streams. Streams are aribtrarily long: you need not decide when they should stop until after they start playing. All of the primitives described so far can apply to streams, except that streams cannot be indexed. To create a stream you can use one of the standard primitives, leaving out the length parameter. For example, the following will play a 1kHz pure tone until Weber quits.

```julia
addtrial(moment(play,tone(1kHz)))
```

Streams always play on a specific stream channel, so if you want to stop the stream at some point you can request that the channel stop. The following plays a pure tone until the experiment participant hits space.

```julia
addtrial(moment(play,tone(1kHz),channel=1),
         await_response(iskeydown(key":space:")),
         moment(stop,1))
```

Streams can be manipulated as they are playing as well, so if you wanted to have a ramp at the start and end of the stream to avoid clicks, you could change the example above, to the following.

```julia
ongoing_tone = @> tone(1kHz) rampon
addtrial(moment(play,ongoing_tone,channel=1),
         await_response(iskeydown(key":space:")),
         moment(play,rampoff(ongoing_tone),channel=1))
```

Just as with any moment, these manipulations to streams can be precisely timed. The following will turn the sound off precisely 1 second after the space key is pressed.


```julia
ongoing_tone = @> tone(1kHz) rampon
addtrial(moment(play,ongoing_tone,channel=1),
         await_response(iskeydown(key":space:")),
         moment(1s,play,rampoff(ongoing_tone),channel=1))
```

If you wish to turn the entirety of a finite stream into a sound, you can use [`sound`](@ref). You can also grab the next section of an infinite stream using [`sound`](@ref) if you provide a second parameter specifying the length of the stream you want to turn into a sound.

Some manipulations of streams require that the stream be treated as a sound. You can have  small segments of the stream be manipulated, just before they play, by calling [`audiofn`](@ref) which will apply the given function to each segment of sound extracted from the stream, just as it is about to be played. (Calling [`audiofn`](@ref) on a sound, rather than a stream, is the same as applying the given function to the sound directly).

## Low-level Sound/Stream Generation

Finally, if none of the functions above suit your purposes for generating sounds or streams, you can use the function [`audible`](@ref), which can be used to generate any arbitrary sound or stream you want. Please refer to the source code for [`tone`](@ref) and [`noise`](@ref) to see examples of the two ways to use this function.

# Images

Images can also be generated by either displaying a file or generating image primitves.

## Loading a file

Displaying an image file is a simple matter of calling display on that file.

```julia
addtrial(moment(display,"myimage.png"))
```

!!! note "Images are cached"

    You can safely display the same file multiple times: the image is cached, and will only load into memory once.

Analogous to sounds, if you need to manipulate the image before displaying it you can load it using [`visual`](@ref). For example, the following displays the upper quarter of an image.

```julia
myimage = visual("myimage.png")
addtrial(moment(display,myimage[1:div(end,2),1:div(end,2)]))
```

Note that displaying a string can also result in that string being printed to the screen. Weber determines the difference between a string you want to display and a string referring to an image file by looking at the end of the string. If the string ends in a file type (.bmp, .jpeg, .png, etc...), Weber assumes it is an image file you want to load, otherwise it assumes it is a string you want to print to the screen. 

## Image Primitives

Support for generating images in Weber comes from [Images.jl](https://github.com/JuliaImages/Images.jl). In this package, images are represented as arrays. For instance, to display a white 100x100 pixel box next to a black 100x100 pixel box, we could do the following.

```julia
addtrial(moment(display,[ones(100,100); zeros(100,100)]))
```

For more information about generating images please refer to the [JuliaImages](http://juliaimages.github.io/latest/) documentation.
