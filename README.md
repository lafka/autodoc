# Autodoc

Builds pretty pages from source code comments. This project is NOT
meant as a replacement for ex_doc (which is awesome for producing Elixir
API docs), instead it aims at producing custom documentation for REST API's,
protocols etc. It was made specifically to pull out information about
HTTP Endpoints and different packet formats and put them on a nicely styled page.


**Documentation http://lafka.github.io/autodoc/0.0.1/**

## Usage (mix)

```
mix autodoc
```

## Usage (CLI)

```
# Generate from specified sources
mix autodoc ~/src/project-a ~/src/project-b
```

# How it works

Scans the `./lib` and `./autodoc/docs/**/*` under the specified paths
for some tokens. It builds a tree from all the headlines and gives you
that structure to render a page.

