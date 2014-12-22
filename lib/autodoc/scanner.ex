defmodule Autodoc.Scanner do

  defmodule Tree do
    defstruct path:  [], attrs: %{}, text: "", title: nil, link: nil, children: %{}
  end

  @parsers [Autodoc.Scanner.Elixir,
            Autodoc.Scanner.Markdown]

  @doc """
  ## Finding sources
  {: data-path=doc.autodoc.sourcefiles #sourcefiles }

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
            struct = parser.parse file, opts
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

    def parse(file, _opts) do
      Enum.reduce Code.load_file(file), [], fn({mod, _}, acc) ->
        doc = Code.get_docs mod, :all
        {_line?, moddoc} = doc[:moduledoc] || {-1, nil}

        moddoc = Markdown.to_doc moddoc

        partials = Enum.reduce doc[:docs] || [], acc ++ List.wrap(moddoc), fn
          ({_fa, _line, _, _, nil}, acc2) -> acc2
          ({_fa, _line, _, _, doc}, acc2) ->
            acc2 ++ List.wrap Markdown.to_doc(doc)
        end
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

    def parse(file, _opts) do
      List.wrap(File.read!(file) |> to_doc)
    end

    defp chunk_by(vals, callback) do
      {rest, res} =
        vals |> Enum.reduce {[], []}, fn
          (val, {[], []}) -> {[val], []}
          (val, {part, acc}) ->
            case callback.(val) do
              true  -> {[val], [Enum.reverse(part)|acc]}
              false -> {[val | part], acc}
            end
          end

      res = case rest do
        [] -> res
        vals -> [Enum.reverse(vals) | res]
      end
      Enum.reverse res
    end

    def to_doc(nil), do: nil
    def to_doc(buf) do
      lines = String.split(buf, ~r{\r\n?|\n})

      %{renderer: renderer, mapper: mapper} = options = %Options{smartypants: false}
      { blocks, links } = Earmark.Parser.parse(lines, options)
      context = %Earmark.Context{options: options, links: links }
        |> Earmark.Inline.update_context

      # Scan for all the elements containing a path and provide a
      # "document like" tree structure to work with
      (List.wrap(blocks)
        |> chunk_by fn(elem) -> nil !== findpath elem.attrs end)
        |> Enum.map fn([elem | _] = blks) ->
          path = findpath elem.attrs
          id = findid nil, path
          title = findtitle elem
          text = maybe_prefix_id(renderer.render(blks, context, mapper), id, path)
          %Tree{:text => text, path: path, title: title, link: id || Enum.join(path || [], "-")}
        end
    end

    defp maybe_prefix_id(buf, nil, nil), do: buf
    defp maybe_prefix_id(buf, nil, path), do: "<span class=\"hidden\" id=\"#{Enum.join(path, "-")}\"></span>" <> buf
    defp maybe_prefix_id(buf, id, _), do: "<span class=\"hidden\" id=\"#{id}\"></span>" <> buf

    defp findtitle(nil), do: nil
    defp findtitle(%Earmark.Block.Heading{content: buf}) do
      buf
    end
    defp findtitle(%{attrs: buf}) do
      case Regex.scan ~r/data-title="([^"]*)"/, buf do
        [] ->
          nil

        [[_, title]] ->
          title
      end
    end

    defp findpath(nil), do: nil
    defp findpath(buf) do
      case Regex.scan ~r/data-path=([^ ]*)/, buf do
        [] ->
          nil

        [[_, path]] ->
          String.split path, "."
      end
    end

    defp findid(nil, nil), do: nil
    defp findid(nil, path), do: Enum.join(path, "-")
    defp findid(buf, path) do
      case Regex.scan ~r/#([^ ]*)/, buf do
        [] -> Enum.join(path, "-")
        [[_, id]] -> id
      end
    end

    defp construct_path(content, 1), do: [Autodoc.Scanner.tokenize(content)]
    defp construct_path(content, lvl) do
      Enum.reverse [Autodoc.Scanner.tokenize(content) | for(_ <- 1..1, do: nil)]
    end
  end
end
