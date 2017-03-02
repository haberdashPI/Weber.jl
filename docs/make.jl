using Documenter, Weber, Colors
makedocs(modules = [Weber])
deploydocs(
  deps = Deps.pip("mkdocs","python-markdown-math","pygments"),
  repo = "github.com/haberdashPI/Weber.jl.git",
  julia = "release",
  osname = "osx"
)
