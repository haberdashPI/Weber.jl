using Documenter, Weber, Colors
makedocs(
  modules = [Weber],
  format = :html,
  sitename = "Weber.jl",
  html_prettyurls = true,
  pages = Any[
    "Introduction" => "index.md",
    "User guide" => Any[
      "Getting Started" => "start.md",
      "Trial Creation" => "trial_guide.md",
      "Stimulus Generation" => "stimulus.md",
      "Adaptive Tracks" => "adaptive.md",
      "Advanced Experiments" => "advanced.md",
      "Extending Weber" => "extend.md"
    ],
    "Reference" => Any[
      "Experiments" => "experiment.md",
      "Trials" => "trials.md",
      "Video" => "video.md",
      "Events" => "event.md",
      "Extensions" => "extend_ref.md"
    ]
  ]
)
deploydocs(
  repo = "github.com/haberdashPI/Weber.jl.git",
  julia = "0.6",
  osname = "osx",
  deps = nothing,
  make = nothing,
  target = "build"
)
