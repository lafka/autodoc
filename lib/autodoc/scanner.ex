defmodule Autodoc.Scanner do

  defmodule Tree do
    defstruct path:  [], attrs: %{}, text: "", title: nil, link: nil
  end

  @parsers [Autodoc.Scanner.Elixir,
            Autodoc.Scanner.Markdown]

  @doc """
  ## Finding sources
  {: path=autodoc.sourcefiles #sourcefiles }

  Sources can be either a plain markdown file or elixir source file
  with markdown documentation inline.

  When a source file is scanned, we look for all the headings. The
  block is then injected into the tree at the level specified by the
  heading. This way of looking up elements means that each block must
  start with a heading, or an element that specifies a path attribute.
  """
  def scan(files, opts) do
    res = Enum.flat_map(files, &Path.wildcard/1)
    |> Enum.reduce [], fn

      (file, {:error, _} = err) ->
        err

      (file, doc) ->

        case guess_parser(file, @parsers) do
          [parser|_] ->
            struct = File.read!(file) |> parser.parse opts
            [struct | doc]

          [] ->
            {:error, "can't find scanner for `#{file}`, tried: #{inspect @parsers}"}
        end
    end

    case res do
      {:error, _err} = err -> err
      res -> {:ok, res}
    end
  end

  def tokenize(buf) do
    buf
      |> String.downcase
      |> String.replace(~r/ /, "_")
      |> String.replace(~r/[\/-]/, "-")
      |> String.replace ~r/[^a-z0-9_-]/, ""
  end

  defp guess_parser(file, parsers) do
    Enum.filter parsers, fn(parser) ->
      parser.handles? file
    end
  end

  defmodule Elixir do
    alias Autodoc.Scanner.Markdown

    def handles?(file), do: Regex.match?(~r/\.ex$/, file)

    def parse(buf, _opts) do
      mod = modulename buf
      doc = Code.get_docs mod, :all
      {_line?, moddoc} = doc[:moduledoc]

      moddoc = Markdown.to_doc moddoc

      partials = Enum.reduce doc[:docs], List.wrap(moddoc), fn
        ({_fa, _line, _, _, nil}, acc) -> acc
        ({_fa, _line, _, _, doc}, acc) ->
          [Markdown.to_doc(doc) | acc]
      end

    end

    defp modulename(buf) do
      case Regex.run(~r/defmodule ([^ ]*) do/, buf) do
        [_, mod] ->
          String.to_atom("Elixir." <> mod)

        arg ->
          raise ArgumentError, message: "files must contain exactly one module", term: arg
      end
    end
  end

  defmodule Markdown do
    alias Earmark.Options
    alias Autodoc.Scanner.Tree

    def handles?(file), do: Regex.match?(~r/\.md$/, file)

    def to_doc(nil), do: nil
    def to_doc(buf) do
      lines = String.split(buf, ~r{\r\n?|\n})
      { blocks, links } = Earmark.Parser.parse(lines, %Options{smartypants: false})

      case blocks do
        [%Earmark.Block.Heading{attrs: attrs, content: heading, level: lvl} = e | _] ->
          path = findpath(attrs) || construct_path(heading, lvl)
          id = findid(attrs)
              text = maybe_prefix_id(Earmark.to_html(buf, %Earmark.Options{smartypants: false}), id, path)
          %Tree{:path => path, :link => id, title: heading, text: text}

        [%{attrs: attrs} | _] ->
          case findpath attrs do
            nil ->
              nil

            path ->
              id = findid(attrs)
              text = maybe_prefix_id(Earmark.to_html(buf, %Earmark.Options{smartypants: false}), id, path)
              %Tree{:path => path, :link => id, text: text}
          end

        _ ->
          nil
      end
    end

    defp maybe_prefix_id(buf, nil, nil), do: buf
    defp maybe_prefix_id(buf, nil, path), do: "<span class=\"hidden\" id=\"#{Enum.join(path, "-")}\"></span>" <> buf
    defp maybe_prefix_id(buf, id, _), do: "<span class=\"hidden\" id=\"#{id}\"></span>" <> buf

    defp findpath(nil), do: nil
    defp findpath(buf) do
      case Regex.scan ~r/path=([^ ]*)/, buf do
        [] ->
          nil

        [[_, path]] ->
          String.split path, "."
      end
    end

    defp findid(nil), do: nil
    defp findid(buf) do
      case Regex.scan ~r/#([^ ]*)/, buf do
        [] -> nil
        [[_, id]] -> id
      end
    end

    defp construct_path(content, 1), do: [Autodoc.Scanner.tokenize(content)]
    defp construct_path(content, lvl) do
      Enum.reverse [Autodoc.Scanner.tokenize(content) | for(_ <- 1..1, do: nil)]
    end
  end
end
