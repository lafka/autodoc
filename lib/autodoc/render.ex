defmodule Autodoc.Render do

  alias Autodoc.Scanner
  alias Autodoc.Scanner.Tree

  def render(tree, opts) do
    output = opts[:output] || "./docs"
    vsn = opts[:version] || Mix.Project.get!.project[:version]
    versions = [vsn | File.ls!(output)] |> Enum.uniq
    cssout = Path.join  [output, vsn, "style.css"]


    File.mkdir_p! Path.join output, vsn

    File.rm cssout
    Enum.each opts[:css] || ["./autodoc/assets/style.css"], fn(file) ->
      Mix.shell.info "appending #{file} to #{cssout}"
      File.write! cssout, File.read!(file), [:append]
    end

    layout = opts[:template][:layout] || "./autodoc/assets/index.tpl"

    docs = buildtree(tree)
    buf = EEx.eval_file layout, [
      content: flatten(docs),
      docs: docs,
      opts: opts,
      versions: versions,
      version: vsn
    ]

    buf = Regex.replace(~r/\[\[([^\]]*)\]\]/,
      buf,
      fn(_, link) -> "<a href=\"##{Scanner.tokenize(link)}\">#{link}</a>" end)

    index = Path.join([output, vsn, "index.html"])
    Mix.shell.info "writing #{index} to #{cssout}"
    File.write! index, buf
  end

  def buildtree(tree) do
    Enum.reduce tree, %Tree{}, fn
      ([_ |_] = elems, acc) ->
        Enum.reduce elems, acc, fn(elem, acc) ->
          in_path acc, elem.path, elem
        end

      ([] , acc) ->
        acc
    end
  end

  defp in_path(acc, [], obj) do
    path = Enum.join obj.path, "."
    %{obj | :children => acc.children}
  end

  defp in_path(acc, [k|rest], obj) do
    children = Dict.put acc.children, k, in_path(acc.children[k] || %Tree{}, rest, obj)
    %{acc | :children => children}
  end
  defp in_path(acc, nil, obj) do
    Mix.shell.info "failed to render obj: no path, #{inspect obj}"
    System.halt 1
  end

  # flatten into a sorted tree
  defp flatten(%{children: tree}) do
    Enum.into tree, %{}, fn({k,v}) -> {k, [v | flatten2(v)]} end
  end
  defp flatten2(%{children: tree}) do
    Enum.flat_map tree, fn({_, item}) ->
      [item | flatten2 item]
    end
  end
end
