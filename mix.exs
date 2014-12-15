defmodule Autodoc.Mixfile do
  use Mix.Project

  def project do
    [ app: :autodoc,
      version: "0.0.1",
      elixir: "~> 1.0",
      deps: deps,
      escript: [
        main_module: Autodoc,
        path: "./autodoc/autodoc"
      ]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:earmark, "~> 0.1"}]
  end
end
