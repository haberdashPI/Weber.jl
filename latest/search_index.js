var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Introduction",
    "title": "Introduction",
    "category": "page",
    "text": ""
},

{
    "location": "#About-1",
    "page": "Introduction",
    "title": "About",
    "category": "section",
    "text": "Weber is a Julia package that can be used to generate simple psychology experiments that present visual and auditory stimuli at precise times. Weber's emphasis is currently on auditory psychophysics, but the package has the features necessary to generate most visual stimuli one would desire as well, thanks to Images.jl. It is named after Ernst Weber. Weber runs on Windows and Mac OS X. Additional functionality can be added through extensions"
},

{
    "location": "#install-1",
    "page": "Introduction",
    "title": "Installation",
    "category": "section",
    "text": "The following instructions are designed for those new to Julia, and coding in general."
},

{
    "location": "#.-Install-Julia-and-Juno-1",
    "page": "Introduction",
    "title": "1. Install Julia and Juno",
    "category": "section",
    "text": "To use Weber you will need to have Julia, and an appropriate code editor installed. Follow these instructions to install Julia and the Juno IDE. Juno is an extension for the code editor Atom (which these instructions will also ask you to download)."
},

{
    "location": "#.-Install-Weber-1",
    "page": "Introduction",
    "title": "2. Install Weber",
    "category": "section",
    "text": "Once Julia and Juno are installed, open Atom. Go to \"Open Console\" under the Julia menu.(Image: Image of \"Open Console\" in Menu)A console window will appear. Type Pkg.add(\"Weber\") in the console and hit enter.(Image: Image of `Pkg.add(\"Weber\")` in Console)"
},

{
    "location": "start/#",
    "page": "Getting Started",
    "title": "Getting Started",
    "category": "page",
    "text": "In the following example, we'll run through all the basics of how to create an experiment in Weber. It's assumed you have already followed the directions for installing Julia and Juno. First, open Atom.You may want to familiarize yourself with the basics of Julia. There are a number of useful resources available to learn Julia."
},

{
    "location": "start/#Creating-a-simple-program-1",
    "page": "Getting Started",
    "title": "Creating a simple program",
    "category": "section",
    "text": "First, open the Julia console, and enter the following lines of code.using Weber\ncreate_new_project(\"simple\")This will create a set of files in your current directory to get you started creating your experiment. Open the file called run_simple.jl in Atom.Remove all text in run_simple.jl and replace it with the following.using Weber\nsid,skip = @read_args(\"A simple frequency discrimination experiment.\")\n\nconst low = ramp(tone(1kHz,0.5s))\nconst high = ramp(tone(1.1kHz,0.5s))\n\nfunction one_trial()\n  if rand(Bool)\n    stim1 = moment(0.5s,play,low)\n	stim2 = moment(0.5s,play,high)\n    resp = response(key\"q\" => \"low_first\", key\"p\" => \"low_second\",correct = \"low_first\")\n  else\n	stim1 = moment(0.5s,play,high)\n	stim2 = moment(0.5s,play,low)\n    resp = response(key\"q\" => \"low_first\", key\"p\" => \"low_second\",correct = \"low_second\")	\n  end\n  return [show_cross(),stim1,stim2,resp,await_response(iskeydown)]\nend\n\nexp = Experiment(columns = [:sid => sid,condition => \"ConditionA\",:correct],skip=skip)\nsetup(exp) do\n  addbreak(instruct(\"Press 'q' when you hear the low tone first and 'p' otherwise.\"))\n  for trial in 1:10\n    addtrial(one_trial())\n  end\nend\n\nrun(exp)"
},

{
    "location": "start/#Running-the-program-1",
    "page": "Getting Started",
    "title": "Running the program",
    "category": "section",
    "text": "Now, open the julia console, and enter the following:include(\"run_simple.jl\")note: Make sure you're in the correct directory\nYou may get an error that looks like \"could not open file [file name here]\". This probably means Julia's working directory is not set correctly. Open run_simple.jl in Atom, make sure you are focused on this file (by clicking inside the file), and then, in the menu, click \"Julia\" > \"Working Directory\" > \"Current File's Folder\". This will set Julia's working directory to run_simple.jl's directory.note: You can exit at any time\nTo prematurely end the experiment hit the escape key."
},

{
    "location": "start/#Code-Walk-through-1",
    "page": "Getting Started",
    "title": "Code Walk-through",
    "category": "section",
    "text": "After running the experiment on yourself, let's walk through the parts of this experiment piece-by-piece."
},

{
    "location": "start/#Read-Experiment-Parameters-1",
    "page": "Getting Started",
    "title": "Read Experiment Parameters",
    "category": "section",
    "text": "using Weber\nsid,skip = @read_args(\"A simple frequency discrimination experiment.\")The first line loads Weber. Then, when the script is run, the second line will read two important experimental parameters from the user: their subject ID, and an offset.Don't worry about the offset right now. (If you wish to learn more you can read about the Weber.offset function)."
},

{
    "location": "start/#Stimulus-Generation-1",
    "page": "Getting Started",
    "title": "Stimulus Generation",
    "category": "section",
    "text": "const low = ramp(tone(1kHz,0.5s))\nconst high = ramp(tone(1.1kHz,0.5s))These next two lines create two stimuli. A 1000 Hz tone (low) and a 1100 Hz tone (high) each 0.5 seconds long. The ramp function tapers the start and end of a sound to avoid click sounds.You can generate many simple stimuli in Weber, or you can use load(\"sound.wav\") to open a sound file on your computer. Refer to the documentation in Sound."
},

{
    "location": "start/#Creating-a-trial-1",
    "page": "Getting Started",
    "title": "Creating a trial",
    "category": "section",
    "text": "function one_trial()\n  if rand(Bool)\n    stim1 = moment(0.5s,play,low)\n	stim2 = moment(0.5s,play,high)\n    resp = response(key\"q\" => \"low_first\", key\"p\" => \"low_second\",correct = \"low_first\")\n  else\n	stim1 = moment(0.5s,play,high)\n	stim2 = moment(0.5s,play,low)\n    resp = response(key\"q\" => \"low_first\", key\"p\" => \"low_second\",correct = \"low_second\")	\n  end\n  return [show_cross(),stim1,stim2,resp,await_response(iskeydown)]\nendThese lines define a function that is used to create a single trial of the experiment. To create a trial, a random boolean value (true or false) is produced. When true, the low stimulus is presented first, when false, the high stimulus is presented first. There are two basic components of trial creation: trial moments and trial events."
},

{
    "location": "start/#Trial-Moments-1",
    "page": "Getting Started",
    "title": "Trial Moments",
    "category": "section",
    "text": "Each trial is composed of a sequence of moments. Most moments just run a short function at some well defined point in time. For example, during the experiment, the moment moment(0.5,play,low) will call the function play on the low stimulus, doing so 0.5 seconds after the onset of the previous moment. All moments running at a specified time do so in reference to the onset of the prior moment.There are two other moments created in this function: show_cross–which simply displays a \"+\" symbol in the middle of the screen–and await_response–which is a moment that begins only once a key is pressed, and then immediately ends.Once all of the moments have been defined, they are returned in an array and will be run in sequence during the experiment.For more details on how to create trial moments you can refer to the Trial Creation section of the user guide and the Trials section of the reference."
},

{
    "location": "start/#Trial-Events-1",
    "page": "Getting Started",
    "title": "Trial Events",
    "category": "section",
    "text": "The response function also creates a moment. It's purpose is to record the keyboard presses to q or p. It works a little differently than other moments. Rather than running once after a specified time, it runs anytime an event occurs.Events indicate that something has changed: e.g. a key has been pressed, a key has been released, the experiment has been paused. Keyboard events signal a particular code, referring to the key the experiment participant pressed. In the code above key\"p\" and key\"q\" are used to indicate the 'q' and 'p' keys on the keyboard. For details on how events work you can refer to the reference section on Events. The response moment listens for events with the 'p' or 'q' key codes, and records those events."
},

{
    "location": "start/#Experiment-Definition-1",
    "page": "Getting Started",
    "title": "Experiment Definition",
    "category": "section",
    "text": "exp = Experiment(columns = [:sid => sid,condition => \"ConditionA\",:correct],skip=skip) This line creates the actual experiment. It creates a datafile with an appropriate name, and opens a window for the experiment to be displayed in.The code columns creates a number of columns. Some of these columns have fixed values, that are the same for each row of the data (e.g. :sid => sid) but one of them, :correct, is different on each line. Note that in the call to response in one_trial, the value of correct is set to the response listeners should have pressed during a trial.You can add as many columns as you want, either when you first create an experiment, as above, or using addcolumn. Trying to record values to a column you haven't added results in an error."
},

{
    "location": "start/#Experiment-Setup-1",
    "page": "Getting Started",
    "title": "Experiment Setup",
    "category": "section",
    "text": "setup(exp) do\n  addbreak(instruct(\"Press 'q' when you hear the low tone first and 'p' otherwise.\"))\n  for trial in 1:10\n    addtrial(one_trial())\n  end\nendOnce the experiment is defined, you can setup any trials and instructions that you want the experiment to have. The above code adds a break providing instructions for the listeners, and 10 trials, created using the one_trial function we defined above. Please refer to the Trial Creation section of the user guide for more details on how to add trials."
},

{
    "location": "start/#setup_time-1",
    "page": "Getting Started",
    "title": "Setup- vs. run-time",
    "category": "section",
    "text": "run(exp)This final part of the code actually runs the experiment. Note that almost none of the code in setup actually runs during the experiment. This is _important_! Weber is designed to run as much code as possible before the experiment starts, during setup. This is called setup-time. This ensures that code which does run during the experiment, during run-time, can do so in a timely manner. The only code that actually runs during the experiment is the behavior defined within each moment (e.g. playing sounds, displaying text, etc...)."
},

{
    "location": "start/#Where-to-go-from-here-1",
    "page": "Getting Started",
    "title": "Where to go from here",
    "category": "section",
    "text": "From here you can begin writing your own simple experiments. Take a look at some of the example experiments under Weber's example directory to see what you can do. You can find the location of this directory by typing Pkg.dir(\"Weber\",\"examples\") in the julia console. To further your understanding of the details of Weber, you can also read through the rest of the user guide. Topics in the guide have been organized from simplest, and most useful, to the more advanced, least-frequently-necessary features."
},

{
    "location": "trial_guide/#",
    "page": "Trial Creation",
    "title": "Trial Creation",
    "category": "page",
    "text": "We'll look in detail at how to create trials of an experiment. For a broad overview of trial creation refer to Getting Started. The two basic steps to creating a trial are (1) defining a set of moments and (2) add moments to a trial. "
},

{
    "location": "trial_guide/#Defining-Moments-1",
    "page": "Trial Creation",
    "title": "Defining Moments",
    "category": "section",
    "text": "Trials are composed of moments. There are several types of moments: timed moments, compound moments, watcher moments, and conditional moments."
},

{
    "location": "trial_guide/#Timed-Moments-1",
    "page": "Trial Creation",
    "title": "Timed Moments",
    "category": "section",
    "text": "Timed moments are the simplest kind of moment. They are are normally created by calling moment.moment([delta_t],[fn],args...;keys...)A timed moment waits delta_t seconds after the onset of the previous moment, and then runs the specified function (fn), if any, passing it any args and keys provided. Below is an example of creating a timed moment.moment(0.5s,play,mysound)This moment plays mysound 0.5 seconds after the onset of the previous moment.There are several other kinds of timed moments, other than those created by calling moment. Specifically, timeout and await_response wait for a particular event to occur (such as a key press) before they begin."
},

{
    "location": "trial_guide/#Guidlines-for-low-latency-moments-1",
    "page": "Trial Creation",
    "title": "Guidlines for low-latency moments",
    "category": "section",
    "text": "Weber aims to present moments at low latencies for accurate experiments.To maintain low latency, as much of the experimental logic as possible should be precomputed, outside of trial moments, during setup-time. The following operations are definitely safe to perform during a moment:Calls to play to present a sound\nCalls to display to present a visual.\nCalls to record to save something to a data file (usually after any calls to play or display)Note that Julia compiles functions on demand (known as just-in-time or JIT compilation), which can lead to very slow runtimes the first time a function runs.  To minimize JIT compilation during an experiment, any functions called directly by a moment are first precompiled.warning: Keep Moments Short\nLong running moments will lead to latency issues. Make sure all functions that run in a moment terminate relatively quickly.warning: Sync visuals to the refresh rate.\nVisuals synchronize to the screen refresh rate. You can  find more details about this in the documentation of display"
},

{
    "location": "trial_guide/#Compound-Moments-1",
    "page": "Trial Creation",
    "title": "Compound Moments",
    "category": "section",
    "text": "You can create more complicated moments by concatenating simpler moments together using the >> operator or moment(momoment1,moment2,...).A concatenation of moments starts immediately, proceeding through each of the moments in order. This allows for a more complex relationship in inter-moment timing. For example, the following code will present two sounds, one at 100 ms, the other 200 ms after the start of the trial. It will also display \"Too Late!\" on the screen if no keyboard key is pressed 150 ms after the start of the trial. addtrial(moment(100ms,play,soundA) >> moment(100ms,play,soundB),\n         timeout(() -> display(\"Too Late!\"),iskeydown,150ms))This exact sequence of timing would not be possible withou using the >> operator because the timing of the timeout moment depends on user input, while we want soundB to be played at a reliable time."
},

{
    "location": "trial_guide/#Watcher-Moments-1",
    "page": "Trial Creation",
    "title": "Watcher Moments",
    "category": "section",
    "text": "Watcher moments are used to respond to events. Often, watcher moments need not be directly used. Instead, the higher level response method can be used.As long as a watcher moment is active it occurs any time an event is triggered. A watcher moment becomes active at the start of the preceding moment, or at the start of a trial (if it's the first moment in a trial). This latter form is most common, since generally one wishes to listen to all events during a trial. A watcher moments is simply a function that takes one argument: the event to be processed.If the watcher is the first moment in a trial, the convenient do block syntax is possible.message = visual(\"You hit spacebar!\")\naddtrial(moment2,moment3) do event\n  if iskeydown(key\":space:\")\n    display(message,duration=500ms)\n    record()\n  end\nendIn the above example, \"You hit spacebar!\" is displayed for 500 ms every time the spacebar is hit.Refer to the documentation for Events for full details on how to respond to events."
},

{
    "location": "trial_guide/#Conditional-Moments-1",
    "page": "Trial Creation",
    "title": "Conditional Moments",
    "category": "section",
    "text": "Conditional moments are a more advanced technique for creating moments and aren't normally necessary. They run a function only when a certain condition is true (the when moment) or repeat a function until a condition is false (the looping moment). They require a good understanding of the difference between setup- and run-time, anonymous functions, and scoping rules in julia."
},

{
    "location": "trial_guide/#Adding-Trials-1",
    "page": "Trial Creation",
    "title": "Adding Trials",
    "category": "section",
    "text": "Normally, to add moments to a trial you simply call addtrial. There is also addpractice, and addbreak. These functions are nearly identical to addtrial but differ in how they update the trial and offset counters, and what they automatically record to a data file.All of these functions take a series of iterable objects of moments. The moments of all arguments are added in sequence. For convience these iterables can be nested, allowing functions that return multiple moments themselves to be easily passed to addtrial."
},

{
    "location": "stimulus/#",
    "page": "Stimulus Generation",
    "title": "Stimulus Generation",
    "category": "page",
    "text": "So far we have seen several examples of how to generate sounds and simple images (text). Here we'll cover stimulus generation in more detail."
},

{
    "location": "stimulus/#Sounds-1",
    "page": "Stimulus Generation",
    "title": "Sounds",
    "category": "section",
    "text": "Weber's primary focus is on psychoacoustics, so there are many methods for generating and manipulating sounds. There are two primary ways to create sound stimuli: loading a file and composing sound primitives."
},

{
    "location": "stimulus/#Loading-a-file-1",
    "page": "Stimulus Generation",
    "title": "Loading a file",
    "category": "section",
    "text": "Generating stimuli by loading a file is easy. You simply play the given file, like so.addtrial(moment(play,\"mysound_file.wav\"))note: Sounds are cached\nYou can safely play the same file multiple times: the sound is cached, and will only load into memory once.If you need to manipulate the sound before playing it, you can load it using sound.  For example, to remove any frequencies from \"mysound_file.wav\" above 400Hz before playing the sound, you could do the following.mysound = lowpass(sound(\"mysound_file.wav\"),400Hz)\naddtrial(moment(play,mysound))"
},

{
    "location": "stimulus/#Sound-Primitives-1",
    "page": "Stimulus Generation",
    "title": "Sound Primitives",
    "category": "section",
    "text": "There are several primitives you can use to generate simple sounds directly in Weber. They are tone (to create pure tones), noise (to generate white noise), silence (for a silent period) and harmonic_complex (to create multiple pure tones with integer frequency ratios).These primitives can then be combined and manipulated to generate more interesting sounds. You can filter sounds (bandpass, bandstop, lowpass, highpass and lowpass), mix them together (mix) and set an appropriate decibel level (attenuate). You can also manipulate the envelope of the sound (ramp, rampon, rampoff, fadeto, envelope and mult).For instance, to play a 1 kHz tone for 1 second inside of a noise with a notch from 0.5 to 1.5 kHz, with 5 dB SNR you could call the following.mysound = tone(1kHz,1s)\nmysound = ramp(mysound)\nmysound = attenuate(mysound,20)\n\nmynoise = noise(1s)\nmynoise = bandstop(mynoise,0.5kHz,1.5kHz)\nmynoise = attenuate(mynoise,25)\n\naddtrial(moment(play,mix(mysound,mynoise))Weber exports the macro @> (from Lazy.jl) to simplify this pattern. It is easiest to understand the macro by example: the below code yields the same result as the code above.mytone = @> tone(1kHz,1s) ramp attenuate(20)\nmynoise = @> noise(1s) bandstop(0.5kHz,1.5kHz) attenuate(25)\naddtrial(moment(play, mix(mytone,mynoise)))Weber also exports @>>, and @_ (refer to Lazy.jl for details)."
},

{
    "location": "stimulus/#Sounds-are-arrays-1",
    "page": "Stimulus Generation",
    "title": "Sounds are arrays",
    "category": "section",
    "text": "Sounds can be manipulated in the same way that any array can be manipulated in Julia, with some additional support for indexing sounds using time units. For instance, to get the first 5 seconds of a sound you can do the following.mytone = tone(1kHz,10s)\nmytone[0s .. 5s]Furthermore, we can concatenate multiple sounds, to play them in sequence. The following code plays two tones in sequence, with a 100 ms gap between them.interval = [tone(400Hz,50ms); silence(100ms); tone(400Hz * 2^(5/12),50ms)]\naddtrial(moment(play,interval))"
},

{
    "location": "stimulus/#Stereo-Sounds-1",
    "page": "Stimulus Generation",
    "title": "Stereo Sounds",
    "category": "section",
    "text": "You can create stereo sounds with using leftright, and reference their left and right channel sound using :left or :right as a second index, like so.stereo_sound = leftright(tone(1kHz,2s),tone(2kHz,2s))\naddtrial(moment(play,stereo_sound[:,:left],\n         moment(2s,play,stereo_sound[:,:right]))The functions left and right serve the same purpose, but can also operate on streams."
},

{
    "location": "stimulus/#Streams-1",
    "page": "Stimulus Generation",
    "title": "Streams",
    "category": "section",
    "text": "In addition to the discrete sounds that have been discussed so far, Weber also supports sound streams. Streams are arbitrarily long: you need not decide when they should stop until after they start playing. All of the primitives described so far can apply to streams, except that streams cannot be indexed.note: Streaming operations are lazy\nAll manipulations of streams are lazy: they are applied just as the stream is played. The more operators you apply to a stream the more processing that has to occur during playback. If you have a particularly complicated stream you may have to increase streaming latency by changing the stream_unit parameter of setup_sound, or consider an alternative approach (e.g. audible).To create a stream you can use one of the standard primitives, leaving out the length parameter. For example, the following will play a 1 kHz pure tone until Weber quits.addtrial(moment(play,tone(1kHz)))Streams always play on a specific stream channel, so if you want to stop the stream at some point you can request that the channel stop. The following plays a pure tone until the experiment participant hits spacebar.addtrial(moment(play,tone(1kHz),channel=1),\n         await_response(iskeydown(key\":space:\")),\n         moment(stop,1))Streams can be manipulated as they are playing as well, so if you wanted to have a ramp at the start and end of the stream to avoid clicks, you could change the example above, to the following.ongoing_tone = @> tone(1kHz) rampon\naddtrial(moment(play,ongoing_tone,channel=1),\n         await_response(iskeydown(key\":space:\")),\n         moment(play,rampoff(ongoing_tone),channel=1))warning: Streams are stateful\nThis example also demonstrates the stateful nature of streams. Once some part of a stream has been played it is forever consumed, and cannot be played again. After the stream is played, subsequent modifications only apply to unplayed frames of the stream. BEWARE: this means that you cannot play two different modifications of the same stream.Just as with any moment, these manipulations to streams can be precisely timed. The following will turn the sound off precisely 1 second after the space key is pressed.ongoing_tone = @> tone(1kHz) rampon\naddtrial(moment(play,ongoing_tone,channel=1),\n         await_response(iskeydown(key\":space:\")),\n         moment(1s,play,rampoff(ongoing_tone),channel=1))If you wish to turn the entirety of a finite stream into a sound, you can use sound. You can also grab the next section of an infinite stream using sound if you provide a second parameter specifying the length of the stream you want to turn into a sound.Some manipulations of streams require that the stream be treated as a sound. You can modify individual sound segments as they play from the stream using audiofn. (Calling audiofn on a sound, rather than a stream, is the same as applying the given function to the sound directly)."
},

{
    "location": "stimulus/#Low-level-Sound/Stream-Generation-1",
    "page": "Stimulus Generation",
    "title": "Low-level Sound/Stream Generation",
    "category": "section",
    "text": "Finally, if none of the functions above suit your purposes for generating sounds or streams, you can use the function audible, which can be used to generate any arbitrary sound or stream you want. Please refer to the source code for tone and noise to see examples of the two ways to use this function."
},

{
    "location": "stimulus/#Images-1",
    "page": "Stimulus Generation",
    "title": "Images",
    "category": "section",
    "text": "Images can also be generated by either displaying a file or generating image primitives."
},

{
    "location": "stimulus/#Loading-a-file-2",
    "page": "Stimulus Generation",
    "title": "Loading a file",
    "category": "section",
    "text": "Displaying an image file is a simple matter of calling display on that file.addtrial(moment(display,\"myimage.png\"))note: Images are cached\nYou can safely display the same file multiple times: the image is cached, and will only load into memory once.Analogous to sounds, if you need to manipulate the image before displaying it you can load it using visual. For example, the following displays the upper quarter of an image.myimage = visual(\"myimage.png\")\naddtrial(moment(display,myimage[1:div(end,2),1:div(end,2)]))Note that displaying a string can also result in that string being printed to the screen. Weber determines the difference between a string you want to display and a string referring to an image file by looking at the end of the string. If the string ends in a file type (.bmp, .jpeg, .png, etc...), Weber assumes it is an image file you want to load, otherwise it assumes it is a string you want to print to the screen. "
},

{
    "location": "stimulus/#Image-Primitives-1",
    "page": "Stimulus Generation",
    "title": "Image Primitives",
    "category": "section",
    "text": "Support for generating images in Weber comes from Images.jl. In this package, images are represented as arrays. For instance, to display a white 100x100 pixel box next to a black 100x100 pixel box, we could do the following.addtrial(moment(display,[ones(100,100); zeros(100,100)]))For more information about generating images please refer to the JuliaImages documentation."
},

{
    "location": "adaptive/#",
    "page": "Adaptive Tracks",
    "title": "Adaptive Tracks",
    "category": "page",
    "text": "Some experiments require the use of an adaptive adjustment of a stimulus based on participant responses. There are several basic adaptive tracking algorithms built into Weber, and you can also implement your own as well."
},

{
    "location": "adaptive/#Using-an-Adaptive-Track-1",
    "page": "Adaptive Tracks",
    "title": "Using an Adaptive Track",
    "category": "section",
    "text": "To use an adaptive track in your experiment, you need to make use of some of the advanced features of Weber. In this section we'll walk through the necessary steps, using a simple frequency discrimination experiment.In this experiment, on each trial, listeners hear a low and a high tone, separated in frequency by an adaptively adjusted delta. Their task is to indicate which tone is lower, and the delta is adjusted to determine the difference in frequency at which listeners respond with 79% accuracy. The entire example code is provided below. using Weber\n\nversion = v\"0.0.2\"\nsid,trial_skip,adapt = @read_args(\"Frequency Discrimination ($version).\",\n                                  adapt=[:levitt,:bayes])\n\nconst atten_dB = 30\nconst n_trials = 60\nconst feedback_delay = 750ms\n\nisresponse(e) = iskeydown(e,key\"p\") || iskeydown(e,key\"q\")\n\nconst standard_freq = 1kHz\nconst standard = attenuate(ramp(tone(standard_freq,0.1)),atten_dB)\nfunction one_trial(adapter)\n  first_lower = rand(Bool)\n  resp = response(adapter,key\"q\" => \"first_lower\",key\"p\" => \"second_lower\",\n                  correct=(first_lower ? \"first_lower\" : \"second_lower\"))\n\n  signal() = attenuate(ramp(tone(standard_freq*(1-delta(adapter)),0.1s)),atten_dB)\n  stimuli = first_lower? [signal,standard] : [standard,signal]\n\n  [moment(feedback_delay,play,stimuli[1]),\n   show_cross(),\n   moment(0.9s,play,stimuli[2]),\n   moment(0.1s + 0.3s,display,\n          \"Was the first [Q] or second sound [P] lower in pitch?\"),\n   resp,await_response(isresponse)]\nend\n\nexperiment = Experiment(\n  skip=trial_skip,\n  columns = [\n    :sid => sid,\n    :condition => \"example\",\n    :version => version,\n    :standard => standard_freq\n  ]\n)\n\nsetup(experimerntent) do\n  addbreak(moment(record,\"start\"))\n\n  addbreak(instruct(\"\"\"\n\n    On each trial, you will hear two beeps. Indicate which of the two beeps you\nheard was lower in pitch. Hit 'Q' if the first beep was lower, and 'P' if the\nsecond beep was lower.\n\"\"\"))\n\n  if adapt == :levitt\n    adapter = levitt_adapter(down=3,up=1,min_delta=0,max_delta=1,\n                             big=2,little=sqrt(2),mult=true)\n  else\n    adapter = bayesian_adapter(min_delta = 0,max_delta = 0.95)\n  end\n\n  @addtrials let a = adapter\n    for trial in 1:n_trials\n      addtrial(one_trial(a))\n    end\n\n    # define this string during experiment setup\n    # when we know what block we're on...\n\n    function threshold_report()\n      mean,sd = estimate(adapter)\n      thresh = round(mean,3)*standard_freq\n      thresh_sd = round(sd,3)*standard_freq\n\n      # define this string during run time when we know\n      # what the threshold estimate is.\n      \"Threshold $(thresh)Hz (SD: $thresh_sd)\\n\"*\n      \"Hit spacebar to continue...\"\n    end\n\n    addbreak(moment(display,threshold_report,clean_whitespace=false),\n             await_response(iskeydown(key\":space:\")))\n  end\n\nend\n\nrun(experimerntent)In what follows we'll walk through the parts of this code unique to creating an adaptive track. For more details on the basics of creating an experiment see Getting Started."
},

{
    "location": "adaptive/#Creating-the-Adapter-1",
    "page": "Adaptive Tracks",
    "title": "Creating the Adapter",
    "category": "section",
    "text": "if adapt == :levitt\n  adapter = levitt_adapter(down=3,up=1,min_delta=0,max_delta=1,\n                           big=2,little=sqrt(2),mult=true)\nelse\n  adapter = bayesian_adapter(min_delta = 0,max_delta = 0.95)\nendThe present experiment can be run using either of two built-in adapters: levitt_adapter and bayesian_adapter. An adapter is the object you create to run an adaptive track, and defines the particular algorithm that will be used to select a new delta on each trial, based on the responses to previous deltas. "
},

{
    "location": "adaptive/#Generating-Stimuli-1",
    "page": "Adaptive Tracks",
    "title": "Generating Stimuli",
    "category": "section",
    "text": "const standard = attenuate(ramp(tone(standard_freq,0.1s)),atten_dB)\n...\nsignal() = attenuate(ramp(tone(standard_freq*(1-delta(adapter)),0.1s)),atten_dB)\nstimuli = first_lower? [signal,standard] : [standard,signal]The two stimuli presented to the listener are the standard (always at 1kHz) and the signal (1kHz - delta). The standard is always the same, and so can be generated in advance before the experiment begins. The signal must be generated during the experiment, on each trial. The next delta is queried from the adapter using delta. The signal is defined as a function that takes no arguments. When passed a function, play generates the stimulus defined by that function at runtime, rather than setup time, which is precisely what we want in this case."
},

{
    "location": "adaptive/#Collecting-Responses-1",
    "page": "Adaptive Tracks",
    "title": "Collecting Responses",
    "category": "section",
    "text": "resp = response(adapter,key\"q\" => \"first_lower\",key\"p\" => \"second_lower\",\n                  correct=(first_lower ? \"first_lower\" : \"second_lower\"))To update the adapter after each response, a special method of the response function is used, which takes the adapter as its first argument. We also must indicate which response is correct by setting correct appropriately."
},

{
    "location": "adaptive/#Generating-Trials-1",
    "page": "Adaptive Tracks",
    "title": "Generating Trials",
    "category": "section",
    "text": "@addtrials let a = adapter\n  for trial in 1:n_trials\n    addtrial(one_trial(a))\n  end\n  addbreak(moment(display,() -> \"Estimated threshold: $(estimate(adapter)[1])\\n\",\n                                \"Hit spacebar to exit.\"),\n           await_response(iskeydown(key\":space:\")))\nendTo generate the trials, which depend on the run-time state of the adapter, we use the @addtrials macro. Any time the behavior of listeners in one trial influences subsequent trials, this macro will be necessary. In this case it is used to signal to Weber that the trials added inside the loop depend on the run-time state of the adapter.After all trials have been run, we report the threshold estimated by the adapter using the estimate function, which returns both the mean and measurement error."
},

{
    "location": "adaptive/#Reporting-the-Threshold-1",
    "page": "Adaptive Tracks",
    "title": "Reporting the Threshold",
    "category": "section",
    "text": "# define this string during experiment setup\n# when we know what block we're on...\n\nfunction threshold_report()\n  mean,sd = estimate(adapter)\n  thresh = round(mean,3)*standard_freq\n  thresh_sd = round(sd,3)*standard_freq\n\n  # define this string during run time when we know\n  # what the threshold estimate is.\n  \"Threshold $(thresh)Hz (SD: $thresh_sd)\\n\"*\n  \"Hit spacebar to continue...\"\nend\n\naddbreak(moment(display,threshold_report,clean_whitespace=false),\n         await_response(iskeydown(key\":space:\")))You can report the threshold at the end of an experiment using estimate, as above, but this isn't strictly necessary. The tricky part is to make sure you find the estimate after trials have been run (during run time)."
},

{
    "location": "adaptive/#Custom-Adaptive-Tracking-Algorithms-1",
    "page": "Adaptive Tracks",
    "title": "Custom Adaptive Tracking Algorithms",
    "category": "section",
    "text": "You can define your own adaptive tracking algorithms by defining a new type that is a child of Adapter. You must define an appropriate function to generate the adapter, and methods of Weber.update!, estimate and delta for this type. Strictly speaking estimate need not be implemented, if you choose not to make use of this method in your experiment."
},

{
    "location": "advanced/#",
    "page": "Advanced Experiments",
    "title": "Advanced Experiments",
    "category": "page",
    "text": "There are several concepts and techniques best avoided unless they are really necessary. These generally complicate the creation of experiments. "
},

{
    "location": "advanced/#Stateful-Trials-1",
    "page": "Advanced Experiments",
    "title": "Stateful Trials",
    "category": "section",
    "text": "Some experiments require that what trials present depend on responses to previous trials. For instance, adaptive tracking to find a discrimination threshold.If your trials depend on experiment-changing state, you need to use the macro @addtrials.There are three kinds of trials you can add with this macro: blocks, conditionals and loops."
},

{
    "location": "advanced/#Blocks-of-Trials-1",
    "page": "Advanced Experiments",
    "title": "Blocks of Trials",
    "category": "section",
    "text": "@addtrials let [assignments]\n  body...\nendBlocks of trials are useful for setting up state that will change during the trials. Such state can then be used in a subsequent @addtrials expression. In fact all other types of @addtrials expression will likely be nested inside blocks. The main reason to use such a block is to ensure that  Weber.offset is well defined.The offset counter is used to fast-forward through the expeirment by specifying an offset greater than 0.  However, if there is state that changes throughout the course of several trials, those trials cannot reliably be reproduced when only some of them are skipped. Either all or none of the trials that depend on one another should be skipped.Anytime you have a series of trials, some of which depend on what happens earlier in an expeirment, such trials should be placed inside of an @addtrials let block. Otherwise experiment fast forwarding will result in unexpected behaviors."
},

{
    "location": "advanced/#Conditional-Trials-1",
    "page": "Advanced Experiments",
    "title": "Conditional Trials",
    "category": "section",
    "text": "@addtrials if [cond1]\n  body...\nelseif [cond2]\n  body...\n...\nelseif [condN]\n  body...\nelse\n  body...\nendAdds one or mores trials that are presented only if the given conditions are met. The expressions cond1 through condN are evaluted during the experiment, but each body is executed before the experiment begins, and is used to indicate the set of trials (and breaks or practice trials) that will be run for a given condition.For example, the following code only runs the second trial if the user hits the \"y\" key.@addtrials let y_hit = false\n  isresponse(e) = iskeydown(e,key\"y\") || iskeydown(e,key\"n\")\n  addtrial(moment(display,\"Hit Y or N.\"),await_response(isresponse)) do event\n    if iskeydown(event,key\"y\")\n      y_hit = true\n    end\n  end\n\n  @addtrials if !y_hit\n    addtrial(moment(display,\"You did not hit Y!\"),await_response(iskeydown))\n  end\nendIf @addtrials if !y_hit was replaced with if !y_hit in the above example, the second trial would always run. This is because the if expression would be run during setup-time, before any trials were run (when y_hit is false)."
},

{
    "location": "advanced/#Looping-Trials-1",
    "page": "Advanced Experiments",
    "title": "Looping Trials",
    "category": "section",
    "text": "@addtrials while expr\n  body...\nendAdd some number of trials that repeat as long as expr evalutes to true. For example the follow code runs as long as the user hits the \"y\" key.@addtrials let y_hit = true\n  @addtrials while y_hit\n    message = moment(display,\"Hit Y if you want to continue\")\n    addtrial(message,await_response(iskeydown)) do event\n      y_hit = iskeydown(event,key\"y\")\n    end\n  end\nendIf @addtrials while y_hit was replaced with while y_hit in the above example, the while loop would never terminate, running an infinite loop, because y_hit is true before the experiment starts."
},

{
    "location": "advanced/#Run-time-stimulus-generation-1",
    "page": "Advanced Experiments",
    "title": "Run-time stimulus generation",
    "category": "section",
    "text": "When stimuli need to be generated during an experiment the normal approach will not work. For instance, if you want a tone's frequency to depend on some delta value that changes during the experimrent the following will not work.# THIS WILL NOT WORK!!!\nmoment(play,tone(1kHz+my_delta,1s))The basic problem here is that tone is used to generate a sound at setup-time. What we want is for the run-time value of my_delta to be used. To do this you can pass a function to play. This function will be used to generate a sound during runtime.moment(play,() -> tone(1kHz+my_delta,1s))Similarly, we can use a runtime value in display by passing a function to display.moment(display,() -> \"hello $my_name.\")When moments are created this way, the sound or visual is generated before the moment even begins, to eliminate any latency that would be introduced by loading the sound or visual into memory. Specifically, the stimulus is generated during the most recent non-zero pause occuring before a moment. So for instance, in the following example, mysound will be generated ~0.5 seconds before play is called right after \"Get ready!\" is displayed.addtrial(moment(display,\"Get ready!\"),moment(0.5s),\n         moment(display,\"Here we go!\"),moment(play,mysound))"
},

{
    "location": "extend/#",
    "page": "Extending Weber",
    "title": "Extending Weber",
    "category": "page",
    "text": "Functionality can be added to Weber via extensions. You can add multiple extensions to the same experiment. The reference provides a list of available extensions. Here we'll cover how to create new extensions.Extensions can create new methods of existing Weber functions on custom types, just like any Julia package, and this may be all that's necessary to extend Weber.However, extensions also have several ways to insert additional behavior into a number of methods via special extension machinery.CurrentModule = Weberaddcolumn\nsetup\nrun\nrecord\naddtrial\naddpractice\naddbreak\npoll_eventsTo extend one of these functions you first define an extension type. For example:type MyExtension <: Weber.Extension\n  my_value::String\nendFor all of the public functions above (everything but poll_events), you can then define a new method of these functions that includes one additional argument beyond that listed in its documentation, located before all other arguments. This argument should be of type ExtendedExperiment{MyExtension}. To extend the private poll_events function, replace the Experiment argument with an ExtendedExperiment{MyExtension} argument.warning: Don't extend unlisted functions\nThese functions have specific machinery setup to make extension possible. Don't use this same approach with other functions and expect your extension to work.As an example, record could be extended as follows.function record(experiment::ExtendedExperiment{MyExtension},code;keys...)\n  record(next(experiment),code;my_extension=extension(experiment).my_value,keys...)\nendThere are a few things to note about this implementation. First,  the extension object is accessed using extension.Second, record is called on the next extension.  All extended functions should follow this pattern. Each experiment can have multiple extensions, and each pairing of an experiment with a particular extension is called an experiment version. These are ordered from top-most to bottom-most version. The top-most version is paired with the first extension in the list specified during the call to Experiment. Subsequent versions are accessed in this same order, using next, until the bottom-most version, which is the experiment without any paired extension.For the extension to record to actually work, setup must also be extended to add the column :my_extension to the data file.function setup(fn::Function,experiment::ExtendedExperiment{MyExtension})\n  setup(next(experiment)) do\n    addcolumn(top(experiment),:my_extension)\n    fn()\n  end\nendThis demonstrates one last important concept. When calling addcolumn, the function top is called on the experiment to get the top-most version of the experiment. This is done so that any functionality of versions above the current one will be utilized in the call to addcolumn.note: When to use `next` and `top`\nAs a general rule, inside an extended method, when you dispatch over the same function which that method implements, you should pass it next(experiment) while all other functions taking an experiment argument should be passed top(experiment)."
},

{
    "location": "extend/#The-private-interface-of-run-time-objects.-1",
    "page": "Extending Weber",
    "title": "The private interface of run-time objects.",
    "category": "section",
    "text": "Most of the functionality above is for the extension of setup-time behavior. However, there are two ways to implement new run-time behavior: the generation of custom events and custom moments."
},

{
    "location": "extend/#Custom-Events-1",
    "page": "Extending Weber",
    "title": "Custom Events",
    "category": "section",
    "text": "Extensions to poll_events can be used to notify watcher functions of new kinds of events. An event is an object that inherits from Weber.ExpEvent and which is tagged with the @event macro. Custom events can implement new methods for the existing public functions on events or their own new functions.If you define new functions, instead of leveraging the existing ones, they should generally have some default behavior for all ExpEvent objects, so it is easy to call the method on any event a watcher moment receives."
},

{
    "location": "extend/#Event-Timing-1",
    "page": "Extending Weber",
    "title": "Event Timing",
    "category": "section",
    "text": "To specify event timing, you must define a time method for your custom event. You can simply store the time passed to poll_events in your custom event, or, if you have more precise timing information for your hardware you can store it here. Internally, the value returend by time is used to determine when to run the next moment when a prior moment triggers on the event."
},

{
    "location": "extend/#Custom-Key-Events-1",
    "page": "Extending Weber",
    "title": "Custom Key Events",
    "category": "section",
    "text": "One approach, if you are implementing events for a hardware input device, is to implement methods for iskeydown. You can define your own type of keycode (which should be of some new custom type <: Weber.Key). Then, you can make use of the @key_str macro by adding entries to the Weber.str_to_code dictionary (a private global constant). So for example, you could add the following to the module implementing your extension.Weber.str_to_code[\"my_button1\"] = MyHardwareKey(1)\nWeber.str_to_code[\"my_button1\"] = MyHardwareKey(2)Such key types should implement ==, hash and isless so that key events can be ordered. This allows them to be displayed in an organized fashion when printed using listkeys.Once these events are defined you can extend poll_events so that it generates events that return true for iskeydown(myevent,key\"my_button1\") (and a corresponding method for iskeyup). How this happens will depend on the specific hardware you are supporting. These new events could then be used in an experiment as follows.response(key\"my_button1\" => \"button1_pressed\",\n         key\"my_button2\" => \"button2_pressed\")"
},

{
    "location": "extend/#Custom-Moments-1",
    "page": "Extending Weber",
    "title": "Custom Moments",
    "category": "section",
    "text": "You can create your own moment types, which must be children of Weber.SimpleMoment. These new moments will have to be generated using some newly defined function, or added automatically by extending addtrial. Once created, and added to trials, these moments will be processed at run-time using the function handle, which should define the moment's run-time behavior. Such a moment must also define moment_trace.A moment can also define delta_t–to define when it occurs–or prepare!–to have some kind of initialization occur before its onset–but these both have default implementations.Methods of handle should not make use of the extension machinery described above. What this means is that methods of handle should never dispatch on an extended experiment, and no calls to top, next or extension should occur on the experiment object. Further, each moment should belong to one specific extension, in which all functionality for that custom moment should be implemented."
},

{
    "location": "extend/#Registering-Your-Extension-1",
    "page": "Extending Weber",
    "title": "Registering Your Extension",
    "category": "section",
    "text": "Optionally, you can make it possible for users to extend Weber without ever having to manually download or import your extension.To do so you register your extension using the @Weber.extension macro. This macro is not exported and should not be called within your extensions module. Instead you should submit a pull request to Weber with your new extension defintion added to extensions.jl. Once your extension is also a registered package with METADATA.jl it can be downloaded the first time a user initializes your extension using its corresponding macro."
},

{
    "location": "experiment/#Weber.Experiment",
    "page": "Experiments",
    "title": "Weber.Experiment",
    "category": "Type",
    "text": "Experiment([skip=0],[columns=[symbols...]],[debug=false],\n           [moment_resolution=0.0015],[data_dir=\"data\"],\n           [width=1024],[height=768],[warn_on_trials_only=true],[extensions=[]])\n\nPrepares a new experiment to be run.\n\nKeyword Arguments\n\nskip the number of offsets to skip. Allows restarting of an experiment somewhere in the middle. When an experiment is terminated, the most recent offset is reported. The offset is also recorded in each row of the resulting data file (also reported on exit).\ncolumns the names (as symbols) of columns that will be recorded during the experiment (using record). These can be set to fixed values (using :name => value), or be filled in during a call to record (:name). The column :value is always included here, even if not specified, since there are number of events recorded automatically which make use of this column.\ndebug if true, experiment will show in a windowed view\nmoment_resolution the desired precision that moments should be presented at. Warnings will be printed for moments that lack this precision.\ndata_dir the directory where data files should be stored (can be set to nothing to prevent a file from being created)\nwidth and height specified the screen resolution during the experiment\nextensions an array of Weber.Extension objects, which extend the behavior of an experiment.\nwarn_on_trials_only when true, latency warnings are only displayed when the trial count is greater than 0. Thus, practice and breaks that occur before the first trial do not raise latency warnings.\n\n\n\n"
},

{
    "location": "experiment/#Weber.addcolumn",
    "page": "Experiments",
    "title": "Weber.addcolumn",
    "category": "Function",
    "text": "addcolumn(column::Symbol)\n\nAdds a column to be recorded in the data file.\n\nThis function must be called during setup.  It cannot be called once the experiment has begun. Repeatedly adding the same column only adds the column once. After adding a column you can include that column as a keyword argument to record. You need not write to the column for every record. If left out, the column will be empty in the resulting row of the data file.\n\n\n\n"
},

{
    "location": "experiment/#Weber.setup",
    "page": "Experiments",
    "title": "Weber.setup",
    "category": "Function",
    "text": "setup(fn,experiment)\n\nSetup the experiment, adding breaks, practice, and trials.\n\nSetup creates the context necessary to generate elements of an experiment. All calls to addtrial, addbreak and addpractice must be called inside of fn. This function must be called before run.\n\n\n\n"
},

{
    "location": "experiment/#Base.run",
    "page": "Experiments",
    "title": "Base.run",
    "category": "Function",
    "text": "run(experiment;await_input=true)\n\nRuns an experiment. You must call setup first.\n\nBy default, on windows, this function waits for user input before returning. This prevents a console from closing at the end of an experiment, preventing the user from viewing important messages. The exception is if run is called form within Juno: await_input should never be set to true in this case.\n\n\n\n"
},

{
    "location": "experiment/#Weber.randomize_by",
    "page": "Experiments",
    "title": "Weber.randomize_by",
    "category": "Function",
    "text": "randomize_by(itr)\n\nRandomize by a given iterable object, usually a string (e.g. the subject id.)\n\nIf the same iterable is given, calls to random functions (e.g. rand, randn and shuffle) will result in the same output.\n\n\n\n"
},

{
    "location": "experiment/#Weber.@read_args",
    "page": "Experiments",
    "title": "Weber.@read_args",
    "category": "Macro",
    "text": "@read_args(description,[keyword args...])\n\nReads experimental parameters from the user.\n\nWith no additional keyword arguments this requests the subject id, and an optional skip parameter (defaults to 0) from the user, and then returns them both in a tuple. The skip can be used to restart an experiment by passing it as the skip keyword argument to the Experiment constructor.\n\nYou can specify additional keyword arguments to request additional values from the user. Arguments that are a type will yield a request for textual input, and will verify that that input can be parsed as the given type. Arguments whose values are a list of symbols yield a request that the user select one of the specified values.\n\nArguments are requested from the user either as command-line arguments, or, if no command-line arguments were specified, interactively. Interactive arguments work both in the terminal or in Juno. This macro also generates useful help text that will be displayed to the user when they give a single command-line \"-h\" argument. This help text will include the desecription string.\n\nExample\n\nsubject_id,skip,condition,block = @read_args(\"A simple experiment\",\n  condition=[:red,:green,:blue],block=Int)\n\n\n\n"
},

{
    "location": "experiment/#Weber.@read_debug_args",
    "page": "Experiments",
    "title": "Weber.@read_debug_args",
    "category": "Macro",
    "text": "@read_debug_args(description,[keyword args...])\n\nSame as @read_args, but better suited to debugging errors in your program when running the experiment in Juno.\n\nSpecifically, this verison will never spawn a new process to run the experiment. This means that you can safely step through the code using debugging tools. In this case, you will also likely want to set debug=true when defining your Experiment object.\n\n\n\n"
},

{
    "location": "experiment/#Weber.create_new_project",
    "page": "Experiments",
    "title": "Weber.create_new_project",
    "category": "Function",
    "text": "create_new_project(name,dir=\".\")\n\nCreates a set of files to help you get started on a new experiment.\n\nThis creates a file called run_[name].jl, and a README.md and setup.jl file for your experiment. The readme provides useful information for running the experiment that is common across all experiments. The run file provides some guidelines to get you started creating an experiment and the setup file is a script that can be used to install Weber and any additional dependencies for the project, for anyone who wants to download and run your experiment.\n\n\n\n"
},

{
    "location": "experiment/#Weber.trial",
    "page": "Experiments",
    "title": "Weber.trial",
    "category": "Function",
    "text": "Weber.trial()\n\nReturns the current trial of the experiment.\n\n\n\n"
},

{
    "location": "experiment/#Weber.offset",
    "page": "Experiments",
    "title": "Weber.offset",
    "category": "Function",
    "text": "Weber.offset()\n\nReturns the current offset. The offset represents a well defined time in the experiment. The offset is typically incremented once for every call to addpractice addtrial and addbreak, unless you use @addtrials. You can use the offset to restart the experiment from a well defined location.\n\nwarning: Warning\nFor offsets to be well defined, all calls to moment and @addtrials must follow the guidlines in the user guide. In particular, moments should not rely on state that changes during the experiment unless they are wrapped in an @addtrials macro.\n\n\n\n"
},

{
    "location": "experiment/#Weber.tick",
    "page": "Experiments",
    "title": "Weber.tick",
    "category": "Function",
    "text": "Weber.tick()\n\nWith microsecond precision, this returns the number of elapsed seconds from the start of the experiment to the start of the most recent moment.\n\nIf there is no experiment running, this returns the time since epoch with microsecond precision.\n\n\n\n"
},

{
    "location": "experiment/#Weber.metadata",
    "page": "Experiments",
    "title": "Weber.metadata",
    "category": "Function",
    "text": "Weber.metadata() = Dict{Symbol,Any}()\n\nReturns metadata for this experiment. You can store global state, specific to this experiment, in this dictionary.\n\n\n\n"
},

{
    "location": "experiment/#",
    "page": "Experiments",
    "title": "Experiments",
    "category": "page",
    "text": "Experiment\naddcolumn\nsetup\nrun\nrandomize_by\n@read_args\n@read_debug_args\ncreate_new_project\nWeber.trial\nWeber.offset\nWeber.tick\nWeber.metadata"
},

{
    "location": "trials/#Weber.addtrial",
    "page": "Trials",
    "title": "Weber.addtrial",
    "category": "Function",
    "text": "addtrial(moments...)\n\nAdds a trial to the experiment, consisting of the specified moments.\n\nEach trial records a \"trial_start\" code, and increments a counter tracking the number of trials, and (normally) an offset counter. These two numbers are reported on every line of the resulting data file (see record). They can be retrieved using Weber.trial() and Weber.offset().\n\n\n\n"
},

{
    "location": "trials/#Weber.addbreak",
    "page": "Trials",
    "title": "Weber.addbreak",
    "category": "Function",
    "text": "addbreak(moments...)\n\nIdentical to addpractice, but records \"break_start\" instead of \"practice_start\".\n\n\n\n"
},

{
    "location": "trials/#Weber.addbreak_every",
    "page": "Trials",
    "title": "Weber.addbreak_every",
    "category": "Function",
    "text": "addbreak_every(n,total,\n               [response=key\":space:\"],[response_str=\"the spacebar\"])\n\nAdds a break every n times this event is added given a known number of total such events.\n\nBy default this waits for the user to hit spacebar to move on.\n\n\n\n"
},

{
    "location": "trials/#Weber.addpractice",
    "page": "Trials",
    "title": "Weber.addpractice",
    "category": "Function",
    "text": "addpractice(moments...)\n\nIdentical to addtrial, except that it does not incriment the trial count, and records a \"practice_start\" instead of \"trial_start\" code.\n\n\n\n"
},

{
    "location": "trials/#Weber.moment",
    "page": "Trials",
    "title": "Weber.moment",
    "category": "Function",
    "text": "moment([delta_t],[fn],args...;keys...)\n\nCreate a moment that occurs delta_t (default 0) seconds after the onset of the previous moment, running the specified function.\n\nThe function fn is passed the arguments specified in args and keys.\n\n\n\nmoment(moments...)\nmoment(moments::Array)\n\nCreate a single, compound moment by concatentating several moments togethor.\n\n\n\n"
},

{
    "location": "trials/#Weber.response",
    "page": "Trials",
    "title": "Weber.response",
    "category": "Function",
    "text": "response(key1 => response1,key2 => response2,...;kwds...)\n\nCreate a watcher moment that records press of key[n] as record(response[n];kwds...).\n\nSee record for more details on how events are recorded.\n\nWhen a key is pressed down, the record event occurs. Key releases are also recorded, but are suffixed, by default, with \"_up\". This suffix can be changed using the keyup_suffix keyword argument.\n\n\n\nresponse([fn],adapter,[key1] => [\"resp1\"],...;correct=[resp],\n         [show_feedback=true],\n         [feedback=Dict(true=>\"Correct\",false=>\"Wrong!\")]\n         keys...)\n\nRecord a response in a n-alternative forced choice task and update an adapter.\n\nThe first response recieved is interpreted as the actual response. Subsequent responses will be recorded, without a delta or correct value set, and appending \"late_\" to the specified response string.\n\nFunction Callback\n\nOptionally, upon participant response, fn receives two arguments: the provided response, and the correct response.\n\nKeyword Arguments\n\ncorrect the response string corresponding to the correct response\nshow_feedback (default = true): whether to show feedback to the participant after they respond.\nfeedback the text to display to a participant when they are correct (for the true key, defaults to \"Correct!\") or incorrect (for the false key, defaults to \"Wrong!\").\n\nAny additional keyword arguments are added as column values when the response is recorded.\n\n\n\n"
},

{
    "location": "trials/#Weber.await_response",
    "page": "Trials",
    "title": "Weber.await_response",
    "category": "Function",
    "text": "await_response(isresponse;[atleast=0.0])\n\nThis moment starts when the isresponse function evaluates to true.\n\nThe isresponse function will be called anytime an event occurs. It should take one parameter (the event that just occured).\n\nIf the response is provided before atleast seconds, the moment does not start until atleast seconds have passed.\n\n\n\n"
},

{
    "location": "trials/#Weber.record",
    "page": "Trials",
    "title": "Weber.record",
    "category": "Function",
    "text": "record(code;keys...)\n\nRecord a row to the experiment data file using a given code.\n\nEach event has a code which identifies it as being a particular type of experiment event. This is normally a string. Each keyword argument is the value of a column (with the same name). By convention when you record something with the same code you should specify the same set of columns.\n\nAll calls to record also result in many additional values being written to the data file. The start time and date of the experiment, the trial and offset number, the version of Weber, and the time at which the last moment started are all stored.  Additional information can be added during creation of the experiment (see Experiment).\n\nEach call to record writes a new row to the data file used for the experiment, so there should be no loss of data if the program is terminated prematurely for some reason.\n\nnote: Automatically Recorded Codes\nThere are several codes that are automatically recorded by Weber. They include:trial_start - recorded at the start of moments added by addtrial\npractice_start - recorded at the start of moments added by addpractice\nbreak_start - recorded at the start of moments added by addbreak\nhigh_latency - recorded whenever a high latency warning is triggered. The \"value\" column is set to the error between the actual and the desired timing of a moment, in seconds.\npaused - recorded when user hits 'escape' and the experiment is paused.\nunpaused - recorded when the user ends the pause, continuuing the experiment.\nterminated - recorded when the user manually terminates the experiment (via 'escape')\nclosed - recorded just before the experiment window closes\n\n\n\n"
},

{
    "location": "trials/#Weber.timeout",
    "page": "Trials",
    "title": "Weber.timeout",
    "category": "Function",
    "text": "timeout(fn,isresponse,timeout,[atleast=0.0])\n\nThis moment starts when either isresponse evaluates to true or timeout time (in seconds) passes.\n\nThe isresponse function will be called anytime an event occurs. It should take one parameter (the event that just occured).\n\nIf the moment times out, the function fn (with no arguments) will be called.\n\nIf the response is provided before atleast seconds, the moment does not begin until atleast seconds (fn will not be called).\n\n\n\n"
},

{
    "location": "trials/#Weber.show_cross",
    "page": "Trials",
    "title": "Weber.show_cross",
    "category": "Function",
    "text": "show_cross([delta_t])\n\nCreates a moment that shows a cross hair delta_t seconds after the start of the previous moment (defaults to 0 seconds).\n\n\n\n"
},

{
    "location": "trials/#Weber.when",
    "page": "Trials",
    "title": "Weber.when",
    "category": "Function",
    "text": "when(condition,moments...)\n\nThis moment will begin at the start of the previous moment, and presents the following moments (possibly in nested iterable objects) if the condition function (which takes no arguments) evaluates to true.\n\n\n\n"
},

{
    "location": "trials/#Weber.looping",
    "page": "Trials",
    "title": "Weber.looping",
    "category": "Function",
    "text": "looping(when=fn,moments...)\n\nThis moment will begin at the start of the previous moment, and repeats the listed moments (possibly in nested iterable objects) until the when function (which takes no arguments) evaluates to false.\n\n\n\n"
},

{
    "location": "trials/#Weber.@addtrials",
    "page": "Trials",
    "title": "Weber.@addtrials",
    "category": "Macro",
    "text": "@addtrials expr...\n\nMarks a let block, a for loop, or an if expression as dependent on experiment run-time state, leaving the offset counter unincremented within that block.  The immediately proceeding loop or conditional logic will be run during experiment run-time rather than setup-time.\n\nRefer to the Advanced Topics of the manual section for more details.\n\n\n\n"
},

{
    "location": "trials/#Weber.update!",
    "page": "Trials",
    "title": "Weber.update!",
    "category": "Function",
    "text": "update!(adapter,response,correct)\n\nUpdates any internal state for the adapter when the listener responds with response and the correct response is correct. Usually not called directly, but instead called within response, when the adapter is passed as the first argument. May take a while to run.\n\n\n\n"
},

{
    "location": "trials/#Weber.estimate",
    "page": "Trials",
    "title": "Weber.estimate",
    "category": "Function",
    "text": "estimate(adapter)\n\nReturns the mean and error of the adapters threshold estimate. May take some time to run.\n\n\n\n"
},

{
    "location": "trials/#Weber.delta",
    "page": "Trials",
    "title": "Weber.delta",
    "category": "Function",
    "text": "delta(adapter)\n\nReturns the next delta that should be tested to help estimate the threshold.\n\n\n\n"
},

{
    "location": "trials/#Weber.oddball_paradigm",
    "page": "Trials",
    "title": "Weber.oddball_paradigm",
    "category": "Function",
    "text": "oddball_paradigm(trial_body_fn,n_oddballs,n_standards;\n                 lead=20,no_oddball_repeats=true)\n\nHelper to generate trials for an oddball paradigm.\n\nThe trial_body_fn should setup stimulus presentation: it takes one argument, indicating if the stimulus should be a standard (false) or oddball (true) stimulus.\n\nIt is usually best to use oddball_paradigm with a do block syntax. For instance, the following code sets up 20 oddball and 150 standard trials.\n\noddball_paradigm(20,150) do isoddball\n  if isoddball\n    addtrial(...create oddball trial here...)\n  else\n    addtrial(...create standard trial here...)\n  end\nend\n\nKeyword arguments\n\nlead: determines the number of standards that repeat before any oddballs get presented\nno_oddball_repeats: determines if at least one standard must occur between each oddball (true) or not (false).\n\n\n\n"
},

{
    "location": "trials/#Weber.levitt_adapter",
    "page": "Trials",
    "title": "Weber.levitt_adapter",
    "category": "Function",
    "text": "levitt_adapter([first_delta=0.1],[down=3],[up=1],\n               [big_reverse=3],[big=0.01],[little=0.005],\n               [min_reversals=7],[min_delta=-Inf],[max_delta=Inf],\n               [mult=false])\n\nAn adapter that finds a threshold according to a non-parametric statistical procedure. This approach makes fewer explicit assumptions than bayesian_adapter but may be slower to converge to a threshold.\n\nThis finds a threshold by moving the delta down after three correct responses and up after one incorrect response (these default up and down counts can be changed). This is the same approach described in Levitt (1971).\n\nKeyword Arguments\n\nfirst_delta: the delta that the first trial should present.\nup: how many incorrect responses in a row must occur for the delta to move up\ndown: how many correct responses in a row must occur for the delta to move down.\nbig: the amount delta changes by (up or down) at first\nbig_reverse: how many reveresals (up to down or down to up) must occur before little is used instead of big\nlittle: the amount delta changes by (up or down) after big_reverse reversals.\nmin_reversals: the smallest number of reversals that can be used to estimate a threshold.\nmin_delta: the smallest delta allowed\nmax_delta: the largest delta allowed\nmult: whether the delta change should be additive (false) or  multiplicative (true).\n\n\n\n"
},

{
    "location": "trials/#Weber.bayesian_adapter",
    "page": "Trials",
    "title": "Weber.bayesian_adapter",
    "category": "Function",
    "text": "bayesian_adapter(;first_delta=0.1,\n                 n_samples=1000,miss=0.01,threshold=0.79,\n                 min_delta=0,max_delta=1,\n                 min_plausible_delta = 0.0001,\n                 max_plausible_delta = 0.2,\n                 repeat3_thresh=1.0,repeat2_thresh=0.1,\n                 thresh_prior=\n                 Truncated(LogNormal(log(min_plausible_delta),\n                                     log(max_plausible_delta/\n                                         min_plausible_delta/2)),\n                           min_delta,max_delta),\n                      inv_slope_prior=TruncatedNormal(0,0.25,0,Inf),\n                      thresh_d=thresh_prior,\n                      inv_slope_d=inv_slope_prior)\n\nAn adapter that finds a threshold according to a parametric statistical model. This makes more explicit assumptions than the levitt_adapter but will normally find a threshold faster.\n\nThe psychometric curve is estimated from user responses using a bayesian approach. After estimation, each new delta is selected in a greedy fashion, picking the response that best minimizes entropy according to this psychometric function. This is a modified version of the approach described in Kontsevich & Tyler 1999. Specifically, the approach here uses importance sampling instead of sampling parmeters over a deterministic, uniform grid. This should increase measurement efficiency if the priors are chosen well.\n\nThis algorithm assumes the following functional form for the psychometric response as a function of the stimulus difference .\n\nf() = 2 + (1-) (( - )2)\n\nIn the above  is the cumulative distribution function of a normal distribution,  is the miss-rate parameter, indicating the rate at which listeners make a mistake, even when the delta is large and easily heard,  is the 50%-correct threshold, and  is the psychometric slope.\n\nFor stability and robustness, this adapter begins by repeating the same delta multiple times and only begins quickly changing deltas trial-by-trial when the ratio of estiamted standard deviation to mean is small. This functionality can be adjusted using repeat3_thresh and repeat2_thresh, or, if you do not wish to have any repeats, both values can be set to Inf.\n\nKeyword Arugments\n\nfirst_delta: the delta to start measuring with\nn_samples the number of samples to use during importance sampling. The algorithm for selecting new deltas is O(n²).\nmiss the expected rate at which listeners will make mistakes even for easy to percieve differences.\nthreshold the %-response threshold to be estimated\nmin_delta the smallest possible delta\nmax_delta the largest possible delta\nmin_plausible_delta the smallest plausible delta, should be > 0. Used to define a reasonable value for thresh_prior and inv_slope_prior.\nmax_plausible_delta the largest plausible delta, should be < max_delta. Used to define a reasonable value for thresh_prior and inv_slope_prior.\nthresh_prior the prior probability distribution across thresholds. This influence the way the delta is adapted. By default this is defined in terms of min_plausible_delta and max_plausible_delta.\ninv_slope_prior the prior probability distribution across inverse slopes. By default this is defined in terms of min_plausible_delta and max_plausible_delta.\nthresh_d the distribution over-which to draw samples for the threshold during importance sampling. This defaults to thresh_prior\ninv_slope_d the distribution over-which to draw samples for the inverse slope during importance sampling. This defaults to inv_slope_prior.\nrepeat2_thresh the ratio of sd / mean for theta must suprass to repeat each delta twice.\nrepeat3_thresh the ratio of sd / mean for theta must surpass to repeat each delta thrice.\n\n\n\n"
},

{
    "location": "trials/#Weber.constant_adapter",
    "page": "Trials",
    "title": "Weber.constant_adapter",
    "category": "Function",
    "text": "constant_adapter(stimuli)\n\nAn adapter that can be used to implement the method of constant stimuli: the specified sequence of stimulus deltas is presented in order to participants.\n\nStrictly speaking, this is not an adaptive tracking procedure. However, it can be convienient to have the same programming interface for this method as for adaptive methods. In this way you can easily select between the method of constant stimuli or some kind of adaptive procedure.\n\n\n\n"
},

{
    "location": "trials/#",
    "page": "Trials",
    "title": "Trials",
    "category": "page",
    "text": "addtrial\naddbreak\naddbreak_every\naddpractice\nmoment\nresponse\nawait_response\nrecord\ntimeout\nshow_cross\nwhen\nlooping\n@addtrials\nWeber.update!\nestimate\ndelta\noddball_paradigm\nlevitt_adapter\nbayesian_adapter\nconstant_adapter"
},

{
    "location": "sound/#",
    "page": "Sound",
    "title": "Sound",
    "category": "page",
    "text": ""
},

{
    "location": "sound/#Weber.sound",
    "page": "Sound",
    "title": "Weber.sound",
    "category": "Function",
    "text": "sound(x::Array,[cache=true];[sample_rate=samplerate()])\n\nCreates a sound object from an arbitrary array.\n\nAssumes 1 is the loudest and -1 the softest. The array should be 1d for mono signals, or an array of size (N,2) for stereo sounds.\n\nWhen cache is set to true, sound will cache its results thus avoiding repeatedly creating a new sound for the same object.\n\nnote: Called Implicitly\nThis function is normally called implicitly in a call to play(x), so it need not normally be called directly.\n\n\n\nsound(file,[cache=true];[sample_rate=samplerate(file)])\n\nLoad a specified file as a sound.\n\n\n\nsound(stream,[len])\n\nConsume some amount of the stream, converting it to a finite sound.\n\nIf left unspecified, the entire stream is consumed.  Infinite streams throw an error.\n\n\n\n"
},

{
    "location": "sound/#Weber.tone",
    "page": "Sound",
    "title": "Weber.tone",
    "category": "Function",
    "text": "tone(freq,length;[sample_rate=samplerate()],[phase=0])\n\nCreates a pure tone of the given frequency and length (in seconds).\n\nYou can create an infinitely long tone by passing a length of Inf, or leaving out the length entirely.\n\n\n\n"
},

{
    "location": "sound/#Weber.noise",
    "page": "Sound",
    "title": "Weber.noise",
    "category": "Function",
    "text": "noise(length=Inf;[sample_rate_Hz=44100],[rng=global RNG])\n\nCreates a period of white noise of the given length (in seconds).\n\nYou can create an infinite stream of noise by passing a length of Inf, or leaving out the length entirely.\n\n\n\n"
},

{
    "location": "sound/#Weber.silence",
    "page": "Sound",
    "title": "Weber.silence",
    "category": "Function",
    "text": "silence(length;[sample_rate=samplerate()])\n\nCreates period of silence of the given length (in seconds).\n\n\n\n"
},

{
    "location": "sound/#Weber.harmonic_complex",
    "page": "Sound",
    "title": "Weber.harmonic_complex",
    "category": "Function",
    "text": "harmonic_complex(f0,harmonics,amps,length,\n                 [sample_rate=samplerate()],[phases=zeros(length(harmonics))])\n\nCreates a harmonic complex of the given length, with the specified harmonics at the given amplitudes. This implementation is somewhat superior to simply summing a number of pure tones generated using tone, because it avoids beating in the sound that may occur due floating point errors.\n\nYou can create an infinitely long complex by passing a length of Inf, or leaving out the length entirely.\n\n\n\n"
},

{
    "location": "sound/#Weber.audible",
    "page": "Sound",
    "title": "Weber.audible",
    "category": "Function",
    "text": "audible(fn,len=Inf,asseconds=true;[sample_rate=samplerate(),eltype=Float64])\n\nCreates monaural sound where fn(t) returns the amplitudes for a given Range of time points.\n\nIf asseconds is false, audible creates a monaural sound where fn(i) returns the amplitudes for a given Range of sample indices.\n\nThe function fn should always return elements of type eltype.\n\nIf an infinite length is specified, a stream is created rather than a sound.\n\nThe function fn need not be pure and it can be safely assumed that fn will only be called for a given range of indices once. While indices and times passed to fn normally begin from 0 and 1, respectively, this is not always the case.\n\n\n\n"
},

{
    "location": "sound/#Sound-Creation-1",
    "page": "Sound",
    "title": "Sound Creation",
    "category": "section",
    "text": "sound\ntone\nnoise\nsilence\nharmonic_complex\naudible"
},

{
    "location": "sound/#Weber.highpass",
    "page": "Sound",
    "title": "Weber.highpass",
    "category": "Function",
    "text": "highpass(x,high,[order=5],[sample_rate_Hz=samplerate(x)])\n\nHigh-pass filter the sound (or stream) at the specified frequency.\n\nFiltering uses a butterworth filter of the given order.\n\n\n\n"
},

{
    "location": "sound/#Weber.lowpass",
    "page": "Sound",
    "title": "Weber.lowpass",
    "category": "Function",
    "text": "lowpass(x,low,[order=5],[sample_rate_Hz=samplerate(x)])\n\nLow-pass filter the sound (or stream) at the specified frequency.\n\nFiltering uses a butterworth filter of the given order.\n\n\n\n"
},

{
    "location": "sound/#Weber.bandpass",
    "page": "Sound",
    "title": "Weber.bandpass",
    "category": "Function",
    "text": "bandpass(x,low,high;[order=5])\n\nBand-pass filter the sound (or stream) at the specified frequencies.\n\nFiltering uses a butterworth filter of the given order.\n\n\n\n"
},

{
    "location": "sound/#Weber.bandstop",
    "page": "Sound",
    "title": "Weber.bandstop",
    "category": "Function",
    "text": "bandstop(x,low,high,[order=5],[sample_rate_Hz=samplerate(x)])\n\nBand-stop filter of the sound (or stream) at the specified frequencies.\n\nFiltering uses a butterworth filter of the given order.\n\n\n\n"
},

{
    "location": "sound/#Weber.ramp",
    "page": "Sound",
    "title": "Weber.ramp",
    "category": "Function",
    "text": "ramp(x,[length=5ms])\n\nApplies a half cosine ramp to start and end of the sound.\n\nRamps prevent clicks at the start and end of sounds.\n\n\n\n"
},

{
    "location": "sound/#Weber.rampon",
    "page": "Sound",
    "title": "Weber.rampon",
    "category": "Function",
    "text": "rampon(stream,[len=5ms])\n\nApplies a half consine ramp to start of the sound or stream.\n\n\n\n"
},

{
    "location": "sound/#Weber.rampoff",
    "page": "Sound",
    "title": "Weber.rampoff",
    "category": "Function",
    "text": "rampoff(stream,[len=5ms],[after=0s])\n\nApplies a half consine ramp to the end sound, or to a stream.\n\nFor streams, you may specify how many seconds after the call to rampff the stream should end.\n\n\n\n"
},

{
    "location": "sound/#Weber.fadeto",
    "page": "Sound",
    "title": "Weber.fadeto",
    "category": "Function",
    "text": "fadeto(stream,channel=1,transition=0.05)\n\nA smooth transition from the currently playing stream to another stream.\n\n\n\nfadeto(sound1,sound2,overlap=0.05)\n\nA smooth transition from sound1 to sound2, overlapping the end of sound1 and the start of sound2 by overlap (in seconds).\n\n\n\n"
},

{
    "location": "sound/#Weber.attenuate",
    "page": "Sound",
    "title": "Weber.attenuate",
    "category": "Function",
    "text": "attenuate(x,atten_dB;[time_constant])\n\nApply the given decibels of attenuation to the sound (or stream) relative to a power level of 1.\n\nThis function normalizes the sound to have a root mean squared value of 1 and then reduces the sound by a factor of 10^-a20, where a = atten_dB.\n\nThe keyword argument time_constant determines the time across which the sound is normalized to power 1, which, for sounds, defaults to the entire sound and, for streams, defaults to 1 second.\n\n\n\n"
},

{
    "location": "sound/#Weber.mix",
    "page": "Sound",
    "title": "Weber.mix",
    "category": "Function",
    "text": "mix(x,y,...)\n\nmix several sounds (or streams) together so that they play at the same time.\n\nUnlike normal addition, this acts as if each sound is padded with zeros at the end so that the lengths of all sounds match.\n\n\n\n"
},

{
    "location": "sound/#Weber.mult",
    "page": "Sound",
    "title": "Weber.mult",
    "category": "Function",
    "text": "mult(x,y,...)\n\nMutliply several sounds (or streams) together. Typically used to apply an amplitude envelope.\n\nUnlike normal multiplication, this acts as if each sound is padded with ones at the end so that the lengths of all sounds match.\n\n\n\n"
},

{
    "location": "sound/#Weber.envelope",
    "page": "Sound",
    "title": "Weber.envelope",
    "category": "Function",
    "text": "envelope(mult,length;[sample_rate_Hz=44100])\n\ncreates an envelope of a given multiplier and length (in seconds).\n\nIf mult = 0 this is the same as calling silence. This function is useful in conjunction with fadeto and mult when defining an envelope that changes in level. For example, the following will play a 1kHz tone for 1 second, which changes in volume halfway through to a softer level.\n\nmult(tone(1000,1),fadeto(envelope(1,0.5),envelope(0.1,0.5)))\n\n\n\n"
},

{
    "location": "sound/#Weber.duration",
    "page": "Sound",
    "title": "Weber.duration",
    "category": "Function",
    "text": "duration(x)\n\nGet the duration of the given sound in seconds.\n\n\n\n"
},

{
    "location": "sound/#Weber.nchannels-Tuple{Weber.Sound}",
    "page": "Sound",
    "title": "Weber.nchannels",
    "category": "Method",
    "text": "nchannels(sound)\n\nReturn the number of channels (1 for mono, 2 for stereo) in this sound.\n\n\n\n"
},

{
    "location": "sound/#Distributions.nsamples-Tuple{Weber.Sound}",
    "page": "Sound",
    "title": "Distributions.nsamples",
    "category": "Method",
    "text": "nsamples(sound::Sound)\n\nReturns the number of samples in the sound.\n\n\n\n"
},

{
    "location": "sound/#Weber.audiofn",
    "page": "Sound",
    "title": "Weber.audiofn",
    "category": "Function",
    "text": "audiofn(fn,x)\n\nApply fn to x for both sounds and streams.\n\nFor a sound this is the same as calling fn(x).\n\n\n\nFor a stream, fn will be applied to each unit of sound as it is requested from the stream.\n\n\n\n"
},

{
    "location": "sound/#Weber.leftright",
    "page": "Sound",
    "title": "Weber.leftright",
    "category": "Function",
    "text": "leftright(left,right)\n\nCreate a stereo sound from two vectors or two monaural sounds.\n\nFor vectors, one can specify a sample_rate other than the default, if desired.\n\n\n\n"
},

{
    "location": "sound/#Weber.left",
    "page": "Sound",
    "title": "Weber.left",
    "category": "Function",
    "text": "left(sound::Sound)\n\nExtract the left channel a stereo sound or stream.\n\n\n\n"
},

{
    "location": "sound/#Weber.right",
    "page": "Sound",
    "title": "Weber.right",
    "category": "Function",
    "text": "right(sound::Sound)\n\nExtract the right channel of a stereo sound or stream.\n\n\n\n"
},

{
    "location": "sound/#Sound-Manipulation-1",
    "page": "Sound",
    "title": "Sound Manipulation",
    "category": "section",
    "text": "highpass\nlowpass\nbandpass\nbandstop\nramp\nrampon\nrampoff\nfadeto\nattenuate\nmix\nmult\nenvelope\nduration\nnchannels(::Weber.Sound)\nnsamples(::Weber.Sound)\naudiofn\nleftright\nleft\nright"
},

{
    "location": "sound/#Weber.play",
    "page": "Sound",
    "title": "Weber.play",
    "category": "Function",
    "text": "play(x;[channel=0])\n\nPlays a sound (created via sound).\n\nFor convenience, play can also can be called on any object that can be turned into a sound (via sound).\n\nThis function returns immediately with the channel the sound is playing on. You may provide a specific channel that the sound plays on: only one sound can be played per channel. Normally it is unecessary to specify a channel, because an appropriate channel is selected for you. However, pausing and resuming of sounds occurs on a per channel basis, so if you plan to pause a specific sound, you can do so by specifying its channel.\n\nStreams\n\nPlay can also be used to present a continuous stream of sound.  In this case, the channel defaults to channel 1 (there is no automatic selection of channels for streams). Streams are usually created by specifying an infinite length during sound generation using tone, noise, harmonic_complex or audible.\n\n\n\nplay(fn::Function)\n\nPlay the sound that's returned by calling fn.\n\n\n\n"
},

{
    "location": "sound/#Weber.setup_sound",
    "page": "Sound",
    "title": "Weber.setup_sound",
    "category": "Function",
    "text": "setup_sound(;[sample_rate=samplerate()],[num_channels=8],[queue_size=8],\n            [stream_unit=2^11])\n\nInitialize format and capacity of audio playback.\n\nThis function is called automatically (using the default settings) the first time a Sound object is created (e.g. during play).  It need not normally be called explicitly, unless you wish to change one of the default settings.\n\nSample Rate\n\nSample rate determines the maximum playable frequency (max freq is ≈ sample_rate/2). Changing the sample rate from the default 44100 to a new value will also change the default sample rate sounds will be created at, to match this new sample rate.\n\nChannel Number\n\nThe number of channels determines the number of sounds and streams that can be played concurrently. Note that discrete sounds and streams use a distinct set of channels.\n\nQueue Size\n\nSounds can be queued to play ahead of time (using the time parameter of play). When you request that a sound be played it may be queued to play on a channel where a sound is already playing. The number of sounds that can be queued to play at once is determined by queue size. The number of channels times the queue size determines the number of sounds that you can queue up to play ahead of time.\n\nStream Unit\n\nThe stream unit determines the number of samples that are streamed at one time. If this value is too small for your hardware, streams will sound jumpy. However the latency of streams will increase as the stream unit increases.\n\n\n\n"
},

{
    "location": "sound/#Weber.playable",
    "page": "Sound",
    "title": "Weber.playable",
    "category": "Function",
    "text": "playable(x,[cache=true],[sample_rate=samplerate()])\n\nPrepare a sound or stream to be played.\n\nA call to playable will ensure the sound is in the format required by play.  This automatically calls sound on x if it does not appear to already be a sound or a stream.\n\nnote: Called Implicitly\nThis need not be called explicitly, as play will call it for you, if need be.\n\n\n\n"
},

{
    "location": "sound/#DSP.Filters.resample-Tuple{Weber.Sound,Any}",
    "page": "Sound",
    "title": "DSP.Filters.resample",
    "category": "Method",
    "text": "resample(x::Sound,samplerate)\n\nReturns a new sound representing the sound x at the given sampling rate.\n\nYou will loose all frequencies in the sound above samplerate/2. Resampling occurs automatically when you call sound–which is called inside play–anytime the sampling rate of the sound and the current audio playback settings (determined by setup_sound) are not the same.\n\nTo avoid automatic resampling you can either create sounds at the appropriate sampling rate, as determined by samplerate (recommended), or change the sampling rate initialized during setup_sound (not recommended).\n\n\n\n"
},

{
    "location": "sound/#Weber.stop",
    "page": "Sound",
    "title": "Weber.stop",
    "category": "Function",
    "text": "stop(channel)\n\nStop the stream that is playing on the given channel.\n\n\n\n"
},

{
    "location": "sound/#SampledSignals.samplerate",
    "page": "Sound",
    "title": "SampledSignals.samplerate",
    "category": "Function",
    "text": "samplerate([sound])\n\nReport the sampling rate of the sound or of any object that can be turned into a sound.\n\nThe sampling rate of an object determines how many samples per second are used to represent the sound. Objects that can be converted to sounds are assumed to be at the sampling rate of the current hardware settings as defined by setup_sound.\n\n\n\nWith no argument samplerate reports the current playback sample rate, as defined by setup_sound.\n\n\n\n"
},

{
    "location": "sound/#Weber.current_sound_latency",
    "page": "Sound",
    "title": "Weber.current_sound_latency",
    "category": "Function",
    "text": "current_sound_latency()\n\nReports the current, minimum latency of audio playback.\n\nThe current latency depends on your hardware and software drivers. This estimate does not include the time it takes for a sound to travel from your sound card to speakers or headphones. This latency estimate is used internally by play to present sounds at accurate times.\n\n\n\n"
},

{
    "location": "sound/#Weber.pause_sounds",
    "page": "Sound",
    "title": "Weber.pause_sounds",
    "category": "Function",
    "text": "pause_sounds([channel],[isstream])\n\nPause all sounds (or a stream) playing on a given channel.\n\nIf no channel is specified, then all sounds are paused.\n\n\n\n"
},

{
    "location": "sound/#Weber.resume_sounds",
    "page": "Sound",
    "title": "Weber.resume_sounds",
    "category": "Function",
    "text": "resume_sounds([channel],[isstream])\n\nResume all sounds (or a stream) playing on a given channel.\n\nIf no channel is specified, then all sounds are resumed.\n\n\n\n"
},

{
    "location": "sound/#Weber.run_calibrate",
    "page": "Sound",
    "title": "Weber.run_calibrate",
    "category": "Function",
    "text": "run_calibrate()\n\nRuns a program that will allow you to play pure tones and adjust their level.\n\nThis program provides one means of calibrating the levels of sound in your experiment. Using a sound-level meter you can determine the dB SPL of each tone, and adjust the attenuation to achieve a desired sound level.\n\n\n\n"
},

{
    "location": "sound/#Playback-1",
    "page": "Sound",
    "title": "Playback",
    "category": "section",
    "text": "play \nsetup_sound \nplayable\nDSP.Filters.resample(::Weber.Sound,::Any)\nstop\nsamplerate\ncurrent_sound_latency\npause_sounds\nresume_sounds\nrun_calibrate"
},

{
    "location": "video/#Base.Multimedia.display",
    "page": "Video",
    "title": "Base.Multimedia.display",
    "category": "Function",
    "text": "display(r::SDLRendered;kwds...)\n\nDisplays anything rendered by visual onto the current experiment window.\n\nAny keyword arguments, available from visual are also available here. They overload the arguments as specified during visual (but do not change them).\n\ndisplay(x;kwds...)\n\nShort-hand for display(visual(x);kwds...). This is the most common way to use display. For example:\n\nmoment(0.5s,display,\"Hello, World!\")\n\nThis code will show the text \"Hello, World!\" on the screen 0.5 seconds after the start of the previous moment.\n\nwarning: Warning\nAssuming your hardware and video drivers permit it, display sycnrhonizes to the screen refresh rate so long as the experiment window uses accelerated graphics (true by default). The display of a visual can be no more accurate than that permitted by this refresh rate. In particular, display can block for up to the length of an entire refresh cycle. If you want accurate timing in your experiment, make sure that there is nothing you want to occur immediately after calling display. If you want to display multiple visuals at once remember that you can compose visuals using the + operator, do not call display multiple times and expect these visual to all display at the same time (also note that the default behavior of visuals is to disappear when the next visual is shown).\n\n\n\ndisplay(fn::Function;kwds...)\n\nDisplay the visual returned by calling fn.\n\n\n\n"
},

{
    "location": "video/#Weber.visual",
    "page": "Video",
    "title": "Weber.visual",
    "category": "Function",
    "text": "visual(obj,[duration=0s],[priority=0],keys...)\n\nRender an object, allowing display to show the object in current experiment's window.\n\nArguments\n\nduration: A positive duration means the object is displayed for the given duration, otherwise the object displays until a new object is displayed.\npriority: Higher priority objects are always visible above lower priority ones. Newer objects display over same-priority older objects.\n\nIf coordinates are used they are in units of half screen widths (for x) and heights (for y), with (0,0) at the center of the screen.\n\nnote: Note\nBy using using the + operator, multiple visual objects can be composed into one object, so that they are displayed together\n\n\n\nvisual(color,[duration=0s],[priority=0])\n\nRender a color, across the entire screen.\n\n\n\nvisual(str::String, [font=nothing], [font_name=\"arial\"], [size=32],\n       [color=colorant\"white\"],\n       [wrap_width=0.8],[clean_whitespace=true],[x=0],[y=0],[duration=0s],\n       [priority=0])\n\nRender the given string as an image that can be displayed. An optional second argument can specify a font, loaded using the font function.\n\nnote: Strings treated as files...\nIf the string passed refers to an image file–becasue the string ends in a file type, like .bmp or .png–-it will be treated as an image to be loaded and displayed, rather than as a string to be printed to the screen. Refer to the documentation of visual for image objects.\n\nArguments\n\nwrap_width: the proporition of the screen that the text can utilize before wrapping.\nclean_whitespace: if true, replace all consecutive white space with a single space.\n\n\n\nvisual(img, [x=0],[y=0],[duration=0s],[priority=0])\n\nPrepare the color or gray scale image to be displayed to the screen.\n\nFor a string or file reference, this loads and prepares for display the given image file. For an array this utilizes all the conventions in the Images package for representing images. Internally, real-number 2d arrays are interpreted as gray scale images, and real-number 3d arrays as an RGB image or RGBA image, depending on whether size(img,1) is of size 3 or 4. A 3d array with a size(img,1) ∉ [3,4] results in an error.\n\n\n\n"
},

{
    "location": "video/#Weber.instruct",
    "page": "Video",
    "title": "Weber.instruct",
    "category": "Function",
    "text": "instruct(str;keys...)\n\nPresents some instructions to the participant.\n\nThis adds \"(Hit spacebar to continue...)\" to the end of the text, and waits for the participant to press spacebar to move on. It records an \"instructions\" event to the data file.\n\nAny keyword arguments are passed onto to visual, which can be used to adjust how the instructions are displayed.\n\n\n\n"
},

{
    "location": "video/#Weber.font",
    "page": "Video",
    "title": "Weber.font",
    "category": "Function",
    "text": "font(name,size,[dirs=os_default],[color=colorant\"white\"])\n\nCreates an SDLFont object to be used for for rendering text as an image.\n\nBy default this function looks in the current directory and then an os specific default font directory for a font with the given name (case insensitive). You can specify a different list of directories using the dirs parameter.\n\n\n\n"
},

{
    "location": "video/#Weber.window",
    "page": "Video",
    "title": "Weber.window",
    "category": "Function",
    "text": "window([width=1024],[height=768];[fullscreen=true],[title=\"Experiment\"],\n       [accel=true])\n\nCreate a window to which various objects can be rendered. See the visual method.\n\n\n\n"
},

{
    "location": "video/#Base.close",
    "page": "Video",
    "title": "Base.close",
    "category": "Function",
    "text": "close(win::SDLWindow)\n\nCloses a visible SDLWindow window.\n\n\n\n"
},

{
    "location": "video/#",
    "page": "Video",
    "title": "Video",
    "category": "page",
    "text": "Visual display is largely handled by the methods defined in Images. However, this objects must be prepared by Weber using visual and then a call to display is made to show the visual. The call to visual is normally handled automatically for you when you call moment.display\nvisual\ninstruct\nfont\nwindow\nclose"
},

{
    "location": "event/#Weber.@event",
    "page": "Events",
    "title": "Weber.@event",
    "category": "Macro",
    "text": "@Weber.event type [name] <: [ExpEvent or ExpEvent child]\n  [fields...]\nend\n\nMarks a concrete type as being an experiment event.\n\nThis tag is necessary to ensure that all watcher moments are properly precompiled. This macro adds the event to a list of concrete events for which each watcher method must have a precompiled method.\n\n\n\n"
},

{
    "location": "event/#Weber.@key_str",
    "page": "Events",
    "title": "Weber.@key_str",
    "category": "Macro",
    "text": "key\"keyname\"\n\nGenerate a key code, using a single character (e.g. key\"q\" or key\"]\"), or some special key name surrounded by colons (e.g. :escape:).\n\nNote that keys are orderd and you can list all implemented keys in order, using listkeys. If you want to quickly see the name for a given button you can use run_keycode_helper().\n\nnote: Creating Custom Keycodes\nExtensions to Weber can define their own keycodes. Such codes must but of some new type inheriting from Weber.Key, and can be added to the list of codes this macro can generate by updating the private constant Weber.str_to_code. See the section in the user guide on extensions for more details.\n\n\n\n"
},

{
    "location": "event/#Base.Libc.time-Tuple{Weber.ExpEvent}",
    "page": "Events",
    "title": "Base.Libc.time",
    "category": "Method",
    "text": "time(e::ExpEvent)\n\nGet the time an event occured relative to the start of the experiment. Resolution is limited by an experiment's input_resolution (which can be specified upon initialization), and the response rate of the device. For instance, keyboards usually have a latency on the order of 20-30ms.\n\n\n\n"
},

{
    "location": "event/#Weber.keycode",
    "page": "Events",
    "title": "Weber.keycode",
    "category": "Function",
    "text": "keycode(e::ExpEvent)\n\nReport the key code for this event, if there is one.\n\n\n\n"
},

{
    "location": "event/#Weber.iskeydown",
    "page": "Events",
    "title": "Weber.iskeydown",
    "category": "Function",
    "text": "iskeydown(event,[key])\n\nEvalutes to true if the event indicates that the given key (or any key) was pressed down. (See @key_str)\n\niskeydown(key)\n\nReturns a function which tests if an event indicates the given key was pressed down.\n\n\n\n"
},

{
    "location": "event/#Weber.modifiedby",
    "page": "Events",
    "title": "Weber.modifiedby",
    "category": "Function",
    "text": "modifiedby([event],[modifier = :shift,:ctrl,:alt or :gui])\n\nReturns true if the given event represents a keydown event modified by a given modifier key.\n\nWithout the first argument, returns a function that tests if the given event is a keydown event modified by a given modifier key.\n\n\n\n"
},

{
    "location": "event/#Weber.iskeyup",
    "page": "Events",
    "title": "Weber.iskeyup",
    "category": "Function",
    "text": "iskeyup(event,[key])\n\nEvalutes to true if the event indicates that the given keyboard key (or any key) was released.  (See @key_str)\n\niskeyup(key)\n\nReturns a function which tests if an event indicates the given key was released.\n\n\n\n"
},

{
    "location": "event/#Weber.listkeys",
    "page": "Events",
    "title": "Weber.listkeys",
    "category": "Function",
    "text": "listkeys()\n\nLists all available key codes in order.\n\nAlso see @key_str.\n\n\n\n"
},

{
    "location": "event/#Weber.run_keycode_helper",
    "page": "Events",
    "title": "Weber.run_keycode_helper",
    "category": "Function",
    "text": "run_keycode_helper(;extensions=[])\n\nRuns a program that will display the keycode for each key that you press.\n\n\n\n"
},

{
    "location": "event/#Weber.endofpause",
    "page": "Events",
    "title": "Weber.endofpause",
    "category": "Function",
    "text": "endofpause(event)\n\nEvaluates to true if the event indicates the end of a pause requested by the user.\n\n\n\n"
},

{
    "location": "event/#",
    "page": "Events",
    "title": "Events",
    "category": "page",
    "text": "CurrentModule = Weber@event\n@key_str\ntime(::ExpEvent)\nkeycode\niskeydown\nmodifiedby\niskeyup\nlistkeys\nrun_keycode_helper\nendofpause"
},

{
    "location": "extend_ref/#",
    "page": "Extensions",
    "title": "Extensions",
    "category": "page",
    "text": ""
},

{
    "location": "extend_ref/#Weber.@Cedrus",
    "page": "Extensions",
    "title": "Weber.@Cedrus",
    "category": "Macro",
    "text": "Extension Website\n\n@Cedrus()\n\nCreates an extension for Weber allowing experiments to respond to events from Cedrus response-pad hardware. You can use iskeydown and iskeyup to check for events. To find the keycodes of the buttons for your response pad, run the following code, and press each of the buttons on the response pad.\n\nrun_keycode_helper(extensions=[@Cedrus()])\n\nwarning: Do not call inside a package\nDo not call @Cedrus inside of a package or in tests. It should only be used in one-off scripts. If WeberCedrus is not currently installed it will be installed by this macro using Pkg.add which can lead to problems when called in packages or tests.If you want to include an extension without this behavior you can call @Cedrus_safe which mimics @Cedrus except that it will never call Pkg.add.\n\n\n\n"
},

{
    "location": "extend_ref/#Weber.@DAQmx",
    "page": "Extensions",
    "title": "Weber.@DAQmx",
    "category": "Macro",
    "text": "Extension Website\n\n@DAQmx(port;eeg_sample_rate,[codes])\n\nCreate a Weber extension that writes record events to a digital out line via the DAQmx API. This can be used to send trigger codes during eeg recording.\n\nArguments\n\nport: should be nothing, to disable the extension, or the port name for the digital output line.\neeg_sample_rate: should be set to the sampling rate for eeg recording. This calibrates the code length for triggers.\ncodes: a Dict that maps record event codes (a string) to a number. This should be an Integer less than 256. Any codes not specified here will be automatically set, based on the order in which codes are recieved.\n\nExample\n\nThe following experiment sends the code 0x01 to port0 on TestDevice.\n\nport = \"/TestDevice/port0/line0:7\"\nexperiment = Experiment(extensions=[\n  @DAQmx(port;eeg_sample_rate=512,codes=Dict(\"test\" => 0x01))])\nsetup(experiment) do\n  addtrial(moment(record,\"test\"))\nend\nrun(experiment)\n\nwarning: Do not call inside a package\nDo not call @DAQmx inside of a package or in tests. It should only be used in one-off scripts. If WeberDAQmx is not currently installed it will be installed by this macro using Pkg.add which can lead to problems when called in packages or tests.If you want to include an extension without this behavior you can call @DAQmx_safe which mimics @DAQmx except that it will never call Pkg.add.\n\n\n\n"
},

{
    "location": "extend_ref/#Available-Extensions-1",
    "page": "Extensions",
    "title": "Available Extensions",
    "category": "section",
    "text": "Extensions provide additional functionality for Weber. Currently there are two extensions availble:@Cedrus\n@DAQmx"
},

{
    "location": "extend_ref/#Weber.@extension",
    "page": "Extensions",
    "title": "Weber.@extension",
    "category": "Macro",
    "text": "@extension [Symbol] begin\n  [docstring...]\nend\n\nRegisters a given Weber extension. This creates a macro called @[Symbol] which imports Weber[Symbol] and calls Weber[Symbol].InitExtension, with the given arguments. InitExtension should return either nothing or an extension object.\n\nThe doc string is used to document the usage of the extension, and should normally include a link to the website of a julia package for the extension.\n\n\n\n"
},

{
    "location": "extend_ref/#Creating-Extensions-1",
    "page": "Extensions",
    "title": "Creating Extensions",
    "category": "section",
    "text": "The following functions are used when extending experiments.To register your extension within Weber, so users can import your extension with ease, you use can use the @extension macro.Weber.@extension"
},

{
    "location": "extend_ref/#Base.next-Tuple{Weber.ExtendedExperiment}",
    "page": "Extensions",
    "title": "Base.next",
    "category": "Method",
    "text": " next(experiment::ExtendedExperiment)\n\nGet the next extended version of this experiment.\n\n\n\n"
},

{
    "location": "extend_ref/#DataStructures.top-Tuple{Weber.Experiment}",
    "page": "Extensions",
    "title": "DataStructures.top",
    "category": "Method",
    "text": "top(experiment::Experiment)\n\nGet the the top-most extended verison for this experiment, if any.\n\n\n\n"
},

{
    "location": "extend_ref/#Weber.extension-Tuple{Weber.ExtendedExperiment}",
    "page": "Extensions",
    "title": "Weber.extension",
    "category": "Method",
    "text": "extension(experiment::ExtendedExperiment)\n\nGet the extension object for this extended expeirment\n\n\n\n"
},

{
    "location": "extend_ref/#Functions-operating-over-extensions-1",
    "page": "Extensions",
    "title": "Functions operating over extensions",
    "category": "section",
    "text": "These functions operate directly on an ExtendedExperiment.next(::ExtendedExperiment)\ntop(::Experiment)\nextension(::ExtendedExperiment)"
},

{
    "location": "extend_ref/#Weber.poll_events",
    "page": "Extensions",
    "title": "Weber.poll_events",
    "category": "Function",
    "text": " Weber.poll_events(callback,experiment,time)\n\nCall the function callback, possibility multiple times, passing it an event object each time. The time at which the events are polled is passed, allowing this time to be stored with the event.\n\nwarning: Warning\nThis function should never be called directly by user code. A new method of this function can be implemented to extend Weber, allowing it to report new kinds events.\n\n\n\n"
},

{
    "location": "extend_ref/#Extendable-Private-Functions-1",
    "page": "Extensions",
    "title": "Extendable Private Functions",
    "category": "section",
    "text": "Weber.poll_events"
},

{
    "location": "extend_ref/#Weber.prepare!",
    "page": "Extensions",
    "title": "Weber.prepare!",
    "category": "Function",
    "text": "Weber.prepare!(m,[onset_s])\n\nIf there is anything the moment needs to do before it occurs, it is done during prepare!. Prepare can be used to set up precise timing even when hardware latency is high, if that latency can be predicted, and accounted for. A moment's prepare! method is called just before the first non-zero pause between moments that occurs before this moment: in the simplest case, when this moment has a non-zero value for delta_t, preapre! will occur delta_t seconds before this moment. However, if several moments with no pause occur, prepare! will occur before all of those moments as well.\n\nPrepare accepts an optional second argument used to indicate the time, in seconds from the start of the experiemnt when this moment will begin (as a Float64).  This argument may be Inf, indicating that it is not possible to predict when the moment will occur at this point, because the timing depends on some stateful information (e.g. a participant's response). It is accetable in this case to throw an error, explaining that this kind of moment must be able to know precisely when it occurs to be prepared.\n\nnote: Note\nThis method is part of the private interface for moments. It should not be called directly, but implemented as part of an extension. You need only extend the method taking a single arugment unless you intend to use this information during prepartion.\n\n\n\n"
},

{
    "location": "extend_ref/#Weber.handle",
    "page": "Extensions",
    "title": "Weber.handle",
    "category": "Function",
    "text": "handle(exp,queue,moment,to_handle)\n\nInternal method to handle the given moment object in a manner specific to its type.\n\nThe function handle is only called when the appropriate time has been reached for the next moment to be presented (according to delta_t) or when an event occurs.\n\nThe to_handle object is either a Float64, indicating the current experiment time, or it is an ExpEvent indicating the event that just occured. As an example, a timed moment, will run when it recieves any Float64 value, but nothing occurs when passed an event.\n\nThe queue is a MomentQueue object, which has the same interface as the Dequeue object (from the DataStructures package) but it is also iterable. Upon calling handle, top(queue) == moment.\n\nHandle should return a boolean indicating whether the event was \"handled\" or not. If unhandled, the moment should remain on top of the queue. If returning true, handle should normally remove the top moment from the queue. Exceptions exist (for instance, to allow for loops), but one does not normally need to implement custom moments that have such behavior.\n\nnote: Note\nThis method is part of the private interface for moments. It should not be called directly, but implemented as part of an extension. It is called during the course of running an experiment.\n\n\n\n"
},

{
    "location": "extend_ref/#Weber.moment_trace",
    "page": "Extensions",
    "title": "Weber.moment_trace",
    "category": "Function",
    "text": "moment_trace(m)\n\nReturns the stacktrace indicating where this moment was defined.\n\nnote: Note\nThis method is part of the private interface for moments. It should not be called directly, but implemented as part of an extension.  You can get a stacktrace inside the function you define that constructs your custom moment using stacktrace()[2:end].\n\n\n\n"
},

{
    "location": "extend_ref/#Weber.delta_t",
    "page": "Extensions",
    "title": "Weber.delta_t",
    "category": "Function",
    "text": "delta_t(m::AbstractMoment)\n\nReturns the time, since the start of the previous moment, at which this moment should begin. The default implementation returns zero.\n\nnote: Note\nThis method is part of the private interface for moments. It should not be called directly, but implemented as part of an extension.\n\n\n\n"
},

{
    "location": "extend_ref/#Private-Moment-Functions-1",
    "page": "Extensions",
    "title": "Private Moment Functions",
    "category": "section",
    "text": "New Weber.SimpleMoment subtypes can define methods for the following functions to extend the runtime behavior of Weber.Weber.prepare!\nWeber.handle\nWeber.moment_trace\nWeber.delta_t"
},

]}
