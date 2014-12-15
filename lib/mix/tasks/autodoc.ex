defmodule Mix.Tasks.Autodoc do
  use Mix.Task

  alias Autodoc.Scanner
  alias Autodoc.Render

  @doc """
  ## CLI Usage
  {: data-path=autodoc.usage #autodoc.usage }

  **Usage:**

  ```
  $ autodoc <opts> [source1, source2, ...]
  ```

  ### Arguments
  {: #cli-arguments}

  Source files are specified as one or more wildcard patterns. These
  will be globbed and sent the correct scanner.

  ### Options
  {: #cli-opts }

    * `--output <dir>` - The output directory _(default: `./docs/`)_
    * `--css <file1> [<file2> <file3> ...]` - List of stylesheets to include
    * `--scripts <file1> [<file2> <file3> ...]` - List of scripts to include
    * `--template [tag:]<file>` - the file used for `[tag]` (`tag` defaults to `layout`)
    * `--renderer <module>` - The module mapping the doctree tree to template
    * `--version <vsn>` - The doc version (default: taken from mix if applicable)
    * `--title <title>` - The title of the docs

  ## Mix usage

  **Usage:**

  ```
  $ mix autodoc <opts> [source1, source2, ...]
  ```

  Options are the same as in [CLI Opts](#cli-opts)
  """

  @args [
      output: :string,
      css: [:string, :keep],
      scripts: [:string, :keep],
      template: [:string, :keep],
      renderer: :string
    ]

  def run(args) do
    {opts, argv, _error} = OptionParser.parse(args, switches: @args)
      |> normalize_opts
      |> parse_opts

    sources = case argv do
      [] -> ["lib/**/*.ex"]
      argv -> argv end

    render = opts[:render] || &Render.render/2
    case Scanner.scan(sources, opts) do
      {:error, err} ->
        (Mix.shell).error err
        System.halt 1

      {:ok, tree} ->
        render.(tree, opts)
    end
  end

  defp normalize_opts({opts, argv, errors}), do:
    {aggregateopts(opts, []), argv, errors}

  defp aggregateopts([], acc), do: acc
  defp aggregateopts([{k, v} | rest], acc) do
    multiple? = :keep in List.wrap(@args[k])
    case acc[k] do
      nil when multiple? -> aggregateopts rest, [{k, [v]} | acc]
      nil -> aggregateopts rest, [{k, v} | acc]
      val -> aggregateopts rest, Dict.put(acc, k, [v | val])
    end
  end

  defp parse_opts({opts, argv, errors}) do
    case parse_opt(opts, []) do
      {:error, err} ->
        (Mix.shell).error err
        System.halt 1

      newopts ->
        {newopts, argv, errors}
    end
  end
  defp parse_opt([], acc), do: acc
  defp parse_opt([{:output, dir} | rest], acc) do
    parse_opt rest, [{:output, dir} | acc]
  end
  defp parse_opt([{tag, files} | rest], acc) when tag in [:scripts, :css] do
    res = Enum.reduce files, [], fn
      (file, {:error, _file} = err) -> err
      (file, acc) ->
        cond do
          File.exists? file ->
            [file | acc]

          true ->
            {:error, "#{tag}: file \"#{file}\" does not exists"}
        end
    end

    case res do
      {:error, _err} = err -> err
      res -> parse_opt rest, [{tag, res} | acc]
    end
  end
  defp parse_opt([{:template, files} | rest], acc) do
    res = Enum.reduce files, [], fn
      (file, {:error, _file} = err) -> err
      (file, acc) ->
        {tag, file} = case String.split file, ":" do
          [file] -> {:layout, file}
          [tag, file] -> {String.to_atom(tag), file}
        end
        cond do
          File.exists? file ->
            Dict.put(acc, tag, file)

          true ->
            {:error, "template: file \"#{file}\" does not exists"}
        end
    end

    case res do
      {:error, _err} = err -> err
      res -> parse_opt rest, [{:template, res} | acc]
    end
  end
  defp parse_opt([{:renderer, mod} | rest], acc) do
    mod = String.to_atom "Elixir." <> mod
    parse_opt rest, [{:renderer, &mod.render/2} | acc]
  end
end
