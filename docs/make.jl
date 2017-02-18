using Documenter, Weber, Colors, Weber.Cedrus
makedocs(modules = [Weber,Weber.Cedrus])
deploydocs(
  deps = Deps.pip("mkdocs","python-markdown-math","pygments"),
  repo = "github.com/haberdashPI/Weber.jl.git",
  julia = "release",
  osname = "osx"
)
