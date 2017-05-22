using Documenter, Weber, Colors
makedocs(modules = [Weber])
deploydocs(
  deps = Deps.pip("mkdocs","python-markdown-math","pygments"),
  repo = "github.com/haberdashPI/Weber.jl.git",
  julia = "0.6",
  osname = "osx"
)
