defmodule Autodoc.Render do
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

    buf = EEx.eval_file layout, [
      docs: Enum.sort(tree, fn(a, b) -> a[:path] < b[:path] end),
      opts: opts,
      versions: versions,
      version: vsn,
      sitemap: IO.inspect buildnav(tree)
    ]

    buf = Regex.replace(~r/\[\[([^\]]*)\]\]/,
      buf,
      fn(_, link) -> "<a href=\"##{Autodoc.Scanner.tokenize(link)}\">#{link}</a>" end)

    index = Path.join([output, vsn, "index.html"])
    Mix.shell.info "writing #{index} to #{cssout}"
    File.write! index, buf
  end

  defp buildnav(tree) do
    Enum.reduce tree, %{}, fn
      ([%{title: title, path: path} = elem |_], acc) ->
        in_path acc, path, {elem.link, title}

      ([], acc) ->
        acc
    end
  end

  defp in_path(acc, [k], {link, title}) do
    Dict.put acc, k, (acc[k] || %{})
      |> Dict.put(:title, title)
      |> Dict.put(:link, link)
  end

  defp in_path(acc, [k|rest], title) do
    case acc[k] do
      nil ->
        Dict.put acc, k, %{:children => in_path(acc[k] || %{}, rest, title)}

      %{:children => children} = elem ->
        Dict.put acc, k, %{elem | :children => in_path(children, rest, title)}

      %{} ->
        Dict.put acc, k, %{:children => in_path(%{}, rest, title)}
    end
  end
end
