defmodule Console.Papers do
  @moduledoc """
  The papers a box carries — README, DESIGN, CHANGELOG — read off the
  mounted workbench and rendered into a booklet: the article, an index
  of its h2s whenever it has any (`booklet/3`), and every relative
  link rewritten to what the console can open (another box, another
  paper) or sent to the repository on GitHub. A figure goes in an
  `<img>` served by `ConsoleWeb.FiguresController`, never inline.

  The renderer is MDEx, which leaves raw HTML out of the output: a
  README carrying `<img onerror=…>` comes out as a comment. That is
  the one setting here nothing may turn off (console/README.md).
  """

  alias Console.Workbench

  @papers [
    {"readme", "README", "README.md"},
    {"design", "Design", "DESIGN.md"},
    {"changelog", "Changelog", "CHANGELOG.md"}
  ]
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

      booklet(html, file)
    else
      _ -> nil
    end
  end

  @doc """
  The booklet a paper is read in: the article with its headings given
  ids, the index of its h2s, and the document's title. One shape for every
  paper the console shows — a cartridge's, the workbench's, the
  project's — so the rule of the index lives here and nowhere else.

  The index is there whenever the paper has a section. It used to want
  three: with fewer, the paper was read full-width, without the column
  — and a changelog, whose h2s are its versions, has one or two for
  most of its life, so the same kind of document took two shapes beside
  a README that always had its index. A document with no h2 at all is
  the one that reads full-width; there is nothing to index.
  """
  def booklet(html, file) do
    {html, heads} = head_ids(html)
    %{html: html, toc: heads, title: doc_title(html, file)}
  end

  @doc """
  A document's title: the words of its `h1`, and the file's name when it
  has none. The words and not the markup — a heading carries whatever
  the writer put in it, and `# Dockerized Elixir Workbench <!-- omit in
  toc -->` reached the index reading *DOCKERIZED ELIXIR WORKBENCH
  &lt;!-- RAW HTML OMITTED --&gt;*, which is the renderer talking to
  itself out loud.
  """
  def doc_title(html, file) do
    case Regex.run(~r/<h1[^>]*>(.*?)<\/h1>/s, html) do
      [_, inner] ->
        inner
        |> String.replace(~r/<!--.*?-->/s, "")
        |> String.replace(~r/<[^>]*>/, "")
        |> String.trim()
        |> case do
          "" -> file
          words -> words
        end

      _ ->
        file
    end
  end

  @doc """
  The workbench's own papers, the way a cartridge's `papers/0` names its
  own: the drawer's Manual is a group over these two, as the box's is
  over its three.
  """
  def workbench_papers,
    do: [{"readme", "README", "README.md"}, {"changelog", "CHANGELOG", "CHANGELOG.md"}]

  @doc """
  One of them rendered like a box's: the figures it references under
  `assets/` through the figures route, and a link to the changelog to
  the paper it is now.
  """
  def render_workbench(key) when key in ["readme", "changelog"] do
    file = if key == "readme", do: "README.md", else: "CHANGELOG.md"

    case File.read(Path.join(Workbench.dir(), file)) do
      {:ok, md} ->
        {md, tags} = house_tags(md)

        html =
          md
          |> to_html()
          |> put_house_tags(tags)
          |> then(
            &Regex.replace(
              ~r/<img src="(assets\/[^"]+)"/,
              &1,
              ~s(<img src="/figures/\\1" loading="lazy")
            )
          )
          |> then(
            &Regex.replace(
              ~r/<a href="CHANGELOG\.md[^"]*"/,
              &1,
              ~s(<a href="?wb=manual&amp;paper=changelog" data-patch)
            )
          )
          |> then(
            &Regex.replace(
              ~r/<a href="(https?:[^"]*)"/,
              &1,
              ~s(<a href="\\1" target="_blank" rel="noopener")
            )
          )

        booklet(html, file)

      _ ->
        nil
    end
  end

  @doc """
  The two tags the workbench's own README may carry, taken out of the
  Markdown before it is rendered: `{markdown, tags}`, each tag replaced
  by a word the renderer passes through, and `tags` what to write back
  where each word lands (`put_house_tags/2`).

  The README is Markdown with two exceptions, each for what Markdown
  cannot say: an `<img>`, for a width or a side, and a `<br>`, the one
  way to a second line inside a table's cell (2026-10-04). The renderer
  leaves raw HTML out, and that stays: nothing here turns it on. A tag
  is not let through, it is read and written again — the image's source
  when it is a picture under `assets/`, a width in digits, a side, and
  its `alt` escaped; whatever else the tag carried, an `onerror` first
  of all, is not copied. A tag that does not read that way is left
  where it was, for the renderer to leave out.

  For the workbench's README alone. A cartridge's papers are foreign
  content (console/README.md) and are never passed through here.
  """
  def house_tags(md) do
    {md, tags} =
      Regex.scan(~r/<img\s[^<>]*>|<br>/, md)
      |> Enum.map(&hd/1)
      |> Enum.uniq()
      |> Enum.reduce({md, []}, fn tag, {md, tags} ->
        case house_tag(tag) do
          nil ->
            {md, tags}

          html ->
            word = "dewhousetag#{length(tags)}x"
            {String.replace(md, tag, word), [{word, html} | tags]}
        end
      end)

    {md, Enum.reverse(tags)}
  end

  @doc "The rendered page with each word of `house_tags/1` given its tag back."
  def put_house_tags(html, tags),
    do: Enum.reduce(tags, html, fn {word, tag}, html -> String.replace(html, word, tag) end)

  defp house_tag("<br>"), do: "<br>"

  defp house_tag(tag) do
    src = tag_attr(tag, "src")

    if house_picture?(src) do
      alt =
        (tag_attr(tag, "alt") || "")
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      ~s(<img src="#{src}"#{house_width(tag)}#{house_side(tag)} alt="#{alt}">)
    end
  end

  defp tag_attr(tag, name) do
    case Regex.run(~r/\s#{name}="([^"]*)"/, tag) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp house_picture?(nil), do: false

  defp house_picture?(src),
    do:
      Regex.match?(~r/^assets\/[\w.\/-]+\.(png|jpe?g|gif|webp|svg)$/, src) and
        not String.contains?(src, "..")

  defp house_width(tag) do
    width = tag_attr(tag, "width")
    if width && Regex.match?(~r/^\d{1,4}$/, width), do: ~s( width="#{width}"), else: ""
  end

  defp house_side(tag) do
    side = tag_attr(tag, "align")
    if side in ["left", "right"], do: ~s( align="#{side}"), else: ""
  end

  @doc """
  Markdown to HTML with GFM tables and the HTML in it left out, and the
  images from outside read, not loaded (`outside_images/1`).
  """
  def to_html(md) do
    md
    |> MDEx.to_html!(
      extension: [table: true, strikethrough: true, autolink: true, tasklist: true],
      render: [unsafe: false]
    )
    |> colour_fences()
    |> box_blocks()
    |> outside_images()
    |> mark_trees()
  end

  @doc """
  Every block the renderer wrote bare wears the house's terminal box —
  a fence named nothing, one no lexer answers to, an indented block —
  the way a coloured fence already does. The ground of what came out
  of a file is `.term-box` (components.css), declared once and named
  here, never by a stylesheet rule on a bare `pre`.
  """
  def box_blocks(html), do: String.replace(html, "<pre>", ~s(<pre class="term-box">))

  @doc """
  A fenced block whose language the Files sheet colours is coloured
  the same way, with the same lexer and the reader's palette for it
  (`Console.Highlight.fenced/2`): `pre.src[data-lang]`, as the sheet
  draws a file. The renderer writes a fence as `<pre><code
  class="language-NAME">` with the text escaped and nothing else inside,
  so the block is read back off the page, unescaped, lexed, and put
  back as spans of escaped text — the raw HTML a paper carried never
  comes near this, having been left out before. A fence named nothing,
  or a name no lexer answers to, stays as it came.
  """
  def colour_fences(html) do
    Regex.replace(
      ~r{<pre><code class="language-([^"]*)">(.*?)</code></pre>}s,
      html,
      fn whole, info, escaped ->
        case Console.Highlight.fenced(info, unescape_text(escaped)) do
          {:ok, lang, inner} ->
            ~s(<pre class="src term-box" data-lang="#{lang}"><code>#{inner}</code></pre>)

          :plain ->
            whole
        end
      end
    )
  end

  # The four the renderer escapes in text, `&amp;` last so a literal
  # `&lt;` in the source (written `&amp;lt;`) comes back as itself.
  defp unescape_text(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
  end

  @doc """
  A table drawn as a file tree — a cartridge's Contents, one file per
  row, its branch (`├── 📄 task.ex`) in code in the first cell — is
  told apart by what the cell opens with, and its cells get `tree`:
  the stylesheet keeps their spaces, drops the code's chip and closes
  the rows up, so the branches read as one drawing down the column.
  """
  def mark_trees(html),
    do: String.replace(html, ~r/<td>(<code>\x{00A0}*(?:📁|📄|│|├|└))/u, ~s(<td class="tree">\\1))

  @doc """
  An image from another origin never loads here — the policy's
  `img-src` is this origin, `data:` and `blob:`, and a paper is foreign
  content — so left as it came it is a broken picture with its alt
  beside it. Until 2026-09-19 that is what the version badge the
  changelog cartridge puts under a README's title looked like.

  A shields.io static badge says everything in its own address, and
  `Console.Shields` draws it from there: the SVG the service would
  have sent, to the byte, put in the `<img>` as its own text — a
  `data:` address, which the policy allows and which asks nobody. Any
  other outside image — a dynamic badge, a logo'd one, a picture — is a
  link to itself wearing its alt, which is the honest reading of a
  picture not shown.
  """
  def outside_images(html) do
    Regex.replace(~r/<img src="(https?:[^"]+)"([^>]*?)\s*\/?>/, html, fn _whole, src, rest ->
      alt = alt(rest)

      case Console.Shields.badge(unescape(src)) do
        {:ok, badge} ->
          ~s(<img class="shield" src="data:image/svg+xml;base64,#{Base.encode64(badge.svg)}" ) <>
            ~s(alt="#{escape(badge.alt)}" width="#{ceil(badge.width)}" height="#{badge.height}" ) <>
            ~s(title="#{escape(badge.alt)} — a shields.io badge, drawn here from its own address: the console loads no image from outside" />)

        :error ->
          outside_link(src, alt)
      end
    end)
  end

  # An outside image not loaded: a link to it, wearing its alt.
  defp outside_link(src, alt) do
    host = URI.parse(unescape(src)).host || "outside"

    ~s(<a class="outside-img" href="#{src}" target="_blank" rel="noopener noreferrer" ) <>
      ~s(title="an image at #{escape(host)}, not loaded: the console loads no image from outside">) <>
      "#{if alt == "", do: escape(host), else: alt}</a>"
  end

  defp alt(attrs) do
    case Regex.run(~r/alt="([^"]*)"/, attrs) do
      [_, alt] -> alt
      _ -> ""
    end
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  # The renderer escaped the address for its attribute; parsing wants it plain.
  defp unescape(text),
    do: text |> String.replace("&amp;", "&") |> String.replace("&quot;", "\"")

  # A relative link goes to what the console can open — another box's
  # paper, a paper of this box — and the rest to the repository.
  defp rewrite_links(html, name),
    do: Regex.replace(~r/<a href="([^"]*)"/, html, &link_tag(&1, &2, name))

  # The opening tag a link gets, by where its href points.
  defp link_tag(whole, href, name) do
    cond do
      Regex.match?(~r/^(https?:|mailto:|#)/, href) ->
        if String.starts_with?(href, "#"),
          do: whole,
          else: ~s(<a href="#{href}" target="_blank" rel="noopener")

      m = Regex.run(~r/^(README|DESIGN|CHANGELOG|NEED)\.md(#.*)?$/i, href) ->
        key = m |> Enum.at(1) |> String.downcase()

        if key == "need",
          do: ~s(<a href="?box=#{name}&screen=box" data-patch),
          else: ~s(<a href="?box=#{name}&screen=manual&paper=#{key}" data-patch)

      m = Regex.run(~r/^\.\.\/([a-z0-9_]+)\/?(README|DESIGN|CHANGELOG)?(\.md)?(#.*)?$/, href) ->
        other = Enum.at(m, 1)
        paper = (Enum.at(m, 2) || "README") |> String.downcase()

        ~s(<a href="?box=#{other}&screen=manual&paper=#{paper}" data-patch data-box="#{other}" class="cart-ref")

      true ->
        rel =
          Path.expand(Path.join("igniter/lib/workbench_igniter/features/#{name}", href), "/")
          |> String.trim_leading("/")

        ~s(<a href="#{@github}#{rel}" target="_blank" rel="noopener")
    end
  end

  # A figure's path, resolved from the paper's directory to the
  # workbench's root, served by the figures route.
  defp rewrite_images(html, name) do
    Regex.replace(~r/<img src="([^"]*)"/, html, fn whole, src ->
      if Regex.match?(~r/^(https?:|data:)/, src) do
        whole
      else
        rel =
          Path.expand(Path.join("igniter/lib/workbench_igniter/features/#{name}", src), "/")
          |> String.trim_leading("/")

        ~s(<img src="/figures/#{rel}" loading="lazy")
      end
    end)
  end

  defp mark_revisions(html),
    do: String.replace(html, ~r/<p>(Revision:)/, ~s(<p class="revision">\\1))

  @doc """
  An anchor on every heading, `h1` to `h4`, and the `h2`s for the index.

  It is written as `data-anchor`, not as an `id`: a paper's headings are
  whatever its writer called them, and the page has ids of its own. The
  workbench's README has a *Deployments* and a *Logs*, and so has the
  console — the rail's table, the logs' pane — so as ids the two met
  the day that README was read in the drawer (2026-10-04). The booklet's
  hook is what follows a link to a section, and it looks for the anchor.

  The anchor is the heading's words as GitHub writes them (`MDEx.anchorize/1`,
  GFM's algorithm: lower case, punctuation out, a hyphen a space), and a
  repeated one counts from the second on — `repeated`, `repeated-1`,
  `repeated-2` — so a link an author wrote for the repository,
  `(#what-it-installs)`, lands on the same section here, and a link to
  a section here is a link on GitHub. Until 2026-09-29 the h2s alone
  were numbered, `h-0`, `w-0`, `p-0`, and the papers' own anchors led
  nowhere. Two papers can be on the page at once (a box's manual under
  the drawer's), each with its *What it installs*: the booklet's hook
  looks for a target inside its own article first.
  """
  def head_ids(html) do
    {html, heads, _seen} =
      Regex.scan(~r/<(h[1-4])>(.*?)<\/\1>/s, html)
      |> Enum.reduce({html, [], %{}}, fn [whole, tag, inner], {html, heads, seen} ->
        text =
          inner
          |> String.replace(~r/<!--.*?-->/s, "")
          |> String.replace(~r/<[^>]+>/, "")
          |> unescaped()

        {id, seen} = unique_id(MDEx.anchorize(text), seen)

        html =
          String.replace(html, whole, ~s(<#{tag} data-anchor="#{id}">#{inner}</#{tag}>),
            global: false
          )

        heads =
          if tag == "h2", do: [{id, String.replace(text, ~r/^\d+\.\s*/, "")} | heads], else: heads

        {html, heads, seen}
      end)

    {html, Enum.reverse(heads)}
  end

  # A heading's words as written, not as the renderer escaped them: the
  # index escapes what it is given, and "Workbench &amp; its Workspace"
  # reached it reading *&AMP;*, with an id no link written for GitHub
  # (`#the-workbench--its-workspace`) could land on (2026-10-04).
  defp unescaped(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
  end

  # GitHub's count: the first bare, then -1, -2 — and a counted one that
  # collides with a heading really named so counts on.
  defp unique_id(base, seen) do
    case Map.get(seen, base) do
      nil ->
        {base, Map.put(seen, base, 0)}

      n ->
        id = "#{base}-#{n + 1}"

        if Map.has_key?(seen, id),
          do: unique_id(base, Map.put(seen, base, n + 1)),
          else: {id, seen |> Map.put(base, n + 1) |> Map.put(id, 0)}
    end
  end
end
