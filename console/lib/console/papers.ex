defmodule Console.Papers do
  @moduledoc """
  The papers a box carries — README, DESIGN, CHANGELOG — read off the
  mounted workbench and rendered into a booklet: the article, a table
  of contents from its h2s when there are enough, and every relative
  link rewritten to what the console can open (another box, another
  paper) or sent to the repository on GitHub. A figure goes in an
  `<img>` served by `ConsoleWeb.FiguresController`, never inline.

  The renderer is MDEx, which leaves raw HTML out of the output: a
  README carrying `<img onerror=…>` comes out as a comment. That is
  the one setting here nothing may turn off (console/README.md).
  """

  alias Console.Workbench

  @papers [{"readme", "README", "README.md"}, {"design", "Design", "DESIGN.md"}, {"changelog", "Changelog", "CHANGELOG.md"}]
  @github "https://github.com/JosePamplona/Dockerized-Elixir-Workbench/blob/main/"

  def papers, do: @papers

  def features_dir, do: Path.join(Workbench.dir(), "igniter/lib/workbench_igniter/features")

  @doc "Which papers a cartridge carries, by key."
  def carried(name) do
    for {key, _, file} <- @papers, File.regular?(Path.join([features_dir(), name, file])), do: key
  end

  @doc "The paper's HTML: `%{html, toc, title}`, or nil when the box does not carry it."
  def render(name, key) do
    with {_, _, file} <- Enum.find(@papers, &(elem(&1, 0) == key)),
         path = Path.join([features_dir(), name, file]),
         {:ok, md} <- File.read(path) do
      html =
        md
        |> to_html()
        |> rewrite_links(name)
        |> rewrite_images(name)
        |> mark_revisions()

      {html, heads} = head_ids(html, "h-")
      title = Regex.run(~r/<h1[^>]*>(.*?)<\/h1>/s, html) |> then(&(&1 && Enum.at(&1, 1))) || file
      %{html: html, toc: if(length(heads) >= 3, do: heads, else: []), title: title}
    else
      _ -> nil
    end
  end

  @doc """
  The workbench's own papers — its README and CHANGELOG at the root —
  rendered like a box's: the figures they reference under `assets/`
  through the figures route, a link to the changelog to its tab.
  """
  def render_workbench(key) when key in ["readme", "changelog"] do
    file = if key == "readme", do: "README.md", else: "CHANGELOG.md"

    case File.read(Path.join(Workbench.dir(), file)) do
      {:ok, md} ->
        html =
          md
          |> to_html()
          |> then(&Regex.replace(~r/<img src="(assets\/[^"]+)"/, &1, ~s(<img src="/figures/\\1" loading="lazy")))
          |> then(&Regex.replace(~r/<a href="CHANGELOG\.md[^"]*"/, &1, ~s(<a href="?wb=changelog" data-patch)))
          |> then(&Regex.replace(~r/<a href="(https?:[^"]*)"/, &1, ~s(<a href="\\1" target="_blank" rel="noopener")))

        {html, heads} = head_ids(html, "w-")
        title = Regex.run(~r/<h1[^>]*>(.*?)<\/h1>/s, html) |> then(&(&1 && Enum.at(&1, 1))) || file
        %{html: html, toc: if(length(heads) >= 3, do: heads, else: []), title: title}

      _ ->
        nil
    end
  end

  @doc "Markdown to HTML with GFM tables and the HTML in it left out."
  def to_html(md) do
    MDEx.to_html!(md, extension: [table: true, strikethrough: true, autolink: true, tasklist: true], render: [unsafe: false])
  end

  # A relative link goes to what the console can open — another box's
  # paper, a paper of this box — and the rest to the repository.
  defp rewrite_links(html, name) do
    Regex.replace(~r/<a href="([^"]*)"/, html, fn whole, href ->
      cond do
        Regex.match?(~r/^(https?:|mailto:|#)/, href) ->
          if String.starts_with?(href, "#"), do: whole, else: ~s(<a href="#{href}" target="_blank" rel="noopener")

        m = Regex.run(~r/^(README|DESIGN|CHANGELOG|NEED)\.md(#.*)?$/i, href) ->
          key = m |> Enum.at(1) |> String.downcase()
          if key == "need", do: ~s(<a href="?box=#{name}&screen=box" data-patch), else: ~s(<a href="?box=#{name}&screen=manual&paper=#{key}" data-patch)

        m = Regex.run(~r/^\.\.\/([a-z0-9_]+)\/?(README|DESIGN|CHANGELOG)?(\.md)?(#.*)?$/, href) ->
          other = Enum.at(m, 1)
          paper = (Enum.at(m, 2) || "README") |> String.downcase()
          ~s(<a href="?box=#{other}&screen=manual&paper=#{paper}" data-patch data-box="#{other}" class="cart-ref")

        true ->
          rel = Path.expand(Path.join("igniter/lib/workbench_igniter/features/#{name}", href), "/") |> String.trim_leading("/")
          ~s(<a href="#{@github}#{rel}" target="_blank" rel="noopener")
      end
    end)
  end

  # A figure's path, resolved from the paper's directory to the
  # workbench's root, served by the figures route.
  defp rewrite_images(html, name) do
    Regex.replace(~r/<img src="([^"]*)"/, html, fn whole, src ->
      if Regex.match?(~r/^(https?:|data:)/, src) do
        whole
      else
        rel = Path.expand(Path.join("igniter/lib/workbench_igniter/features/#{name}", src), "/") |> String.trim_leading("/")
        ~s(<img src="/figures/#{rel}" loading="lazy")
      end
    end)
  end

  defp mark_revisions(html), do: String.replace(html, ~r/<p>(Revision:)/, ~s(<p class="revision">\\1))

  @doc "An id on every h2, and the list of them for the index."
  def head_ids(html, prefix) do
    {html, heads} =
      Regex.scan(~r/<h2>(.*?)<\/h2>/s, html)
      |> Enum.with_index()
      |> Enum.reduce({html, []}, fn {[whole, inner], i}, {html, heads} ->
        id = "#{prefix}#{i}"
        text = inner |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/^\d+\.\s*/, "")
        {String.replace(html, whole, ~s(<h2 id="#{id}">#{inner}</h2>), global: false), [{id, text} | heads]}
      end)

    {html, Enum.reverse(heads)}
  end
end
