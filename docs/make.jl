using Documenter, Weber, Colors, Weber.Cedrus
makedocs(modules = [Weber,Weber.Cedrus])
deploydocs(
  deps = Deps.pip("mkdocs","python-markdown-math"),
  repo = "github.com/haberdashPI/Weber.jl.git",
  julia = "0.5",
  osname = "osx"
)
