defmodule Autodoc do
  @moduledoc """
  # Autodoc

  Tool to build a complete documentation from various sources.
  """

  def main(args) do
    Mix.Tasks.Autodoc.run args
  end
end
