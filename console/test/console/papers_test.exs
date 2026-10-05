defmodule Console.PapersTest do
  use ExUnit.Case, async: true

  alias Console.Papers

  test "raw HTML in a paper never reaches the page" do
    html = Papers.to_html("hello <img src=x onerror=alert(1)> <svg onload=alert(2)></svg>")
    refute html =~ "onerror"
    refute html =~ "onload"
    refute html =~ "<img"
  end

  # The policy loads no image from another origin: a shields.io static
  # badge is drawn here (Console.Shields, which has its own tests) and
  # put in the <img> as its own text, and any other outside image is a
  # link wearing its alt — never a broken picture.
  test "an image from outside is drawn here or linked, never loaded" do
    html = Papers.to_html("![v1.4.2](https://img.shields.io/badge/version-1.4.2-white.svg)")

    assert [_, b64] =
             Regex.run(~r/<img class="shield" src="data:image\/svg\+xml;base64,([^"]+)"/, html)

    assert Base.decode64!(b64) == File.read!("test/fixtures/shields/version.svg")
    assert html =~ ~s(alt="version: 1.4.2" width="90" height="20")
    refute html =~ "https://img.shields.io"

    # The renderer escaped the address for its attribute: the query reaches the badge whole.
    html =
      Papers.to_html(
        "![x](https://img.shields.io/badge/a-b-red?style=for-the-badge&labelColor=abc)"
      )

    [_, b64] = Regex.run(~r/base64,([^"]+)"/, html)
    assert Base.decode64!(b64) == File.read!("test/fixtures/shields/ftb_label_colour.svg")

    # A badge that is not static says nothing in its address, and any other picture neither.
    html =
      Papers.to_html("![build](https://img.shields.io/github/actions/workflow/status/a/b/ci.yml)")

    refute html =~ "<img"
    assert html =~ ~s(<a class="outside-img" href="https://img.shields.io/github/actions/)
    assert html =~ ">build</a>"

    html = Papers.to_html("![](https://example.com/a.png?x=1&y=2)")
    assert html =~ ">example.com</a>"

    # What is this origin's stays an image.
    assert Papers.to_html("![d](assets/d.svg)") =~ ~s(<img src="assets/d.svg")
  end

  describe "the workbench README's two tags" do
    defp housed(md) do
      {md, tags} = Papers.house_tags(md)
      md |> Papers.to_html() |> Papers.put_house_tags(tags)
    end

    test "an image under assets/ keeps its source, width, side and alt" do
      html =
        housed(
          ~s(<img src="assets/readme/console/rail.png" alt="The rail" width="340" align="right">)
        )

      assert html =~
               ~s(<img src="assets/readme/console/rail.png" width="340" align="right" alt="The rail">)
    end

    test "it is written again, never passed through: what else it carried is gone" do
      html =
        housed(~s|<img src="assets/a.png" onerror="alert(1)" width="80" style="x" alt="a & b">|)

      assert html =~ ~s(<img src="assets/a.png" width="80" alt="a &amp; b">)
      refute html =~ "onerror"
      refute html =~ "style"
    end

    test "an image from anywhere else is left for the renderer to leave out" do
      for src <- [
            "https://evil.example/x.png",
            "assets/../config.conf",
            "assets/x.js",
            "/etc/passwd"
          ] do
        html = housed(~s(<img src="#{src}" width="80">))
        refute html =~ "<img", "#{src} got through"
      end
    end

    test "a line break inside a table's cell, and inside a link an image" do
      html =
        housed("""
        | a | b |
        | --- | --- |
        | [<img src="assets/c.jpg" width="80" alt="c">](dir/) | **one**<br>`two` |
        """)

      assert html =~ ~s(<strong>one</strong><br><code>two</code>)
      assert html =~ ~r{<a href="dir/"><img src="assets/c.jpg" width="80" alt="c"></a>}
    end

    test "no other tag is taken out" do
      html = housed(~s(<br clear="right">\n\n<svg onload="x"></svg>\n\n<b>b</b>))

      refute html =~ "<br"
      refute html =~ "<svg"
      refute html =~ "<b>"
    end
  end

  test "tables and code come through" do
    html = Papers.to_html("| a | b |\n|---|---|\n| 1 | 2 |\n\n`x`")
    assert html =~ "<table>" and html =~ "<code>x</code>"
  end

  test "every heading carries GitHub's id for its words, repeats counted from the second" do
    md =
      "# Some Title\n## v0.13.0 - (2026-09-28)\n## Repeated\n## Repeated\n### `code` in title\n#### 7. What it replaces\n"

    %{html: html, toc: toc, title: title} = md |> Papers.to_html() |> Papers.booklet("X.md")
    assert html =~ ~s(<h1 data-anchor="some-title">)
    assert html =~ ~s(<h2 data-anchor="v0130---2026-09-28">)

    assert html =~ ~s(<h2 data-anchor="repeated">Repeated</h2>) and
             html =~ ~s(<h2 data-anchor="repeated-1">Repeated</h2>)

    assert html =~ ~s(<h3 data-anchor="code-in-title"><code>code</code> in title</h3>)
    assert html =~ ~s(<h4 data-anchor="7-what-it-replaces">)

    assert toc == [
             {"v0130---2026-09-28", "v0.13.0 - (2026-09-28)"},
             {"repeated", "Repeated"},
             {"repeated-1", "Repeated"}
           ]

    assert title == "Some Title"
  end

  test "a heading with an ampersand keeps its words in the index and GitHub's id" do
    page = "## The Workbench & its Workspace\n" |> Papers.to_html() |> Papers.booklet("x.md")

    assert page.toc == [{"the-workbench--its-workspace", "The Workbench & its Workspace"}]

    assert page.html =~
             ~s(<h2 data-anchor="the-workbench--its-workspace">The Workbench &amp; its Workspace</h2>)
  end

  test "a heading really named like a counted repeat does not take its id" do
    %{html: html} = "## A\n## A\n## A-1\n" |> Papers.to_html() |> Papers.booklet("X.md")

    assert html =~ ~s(data-anchor="a">) and html =~ ~s(data-anchor="a-1">A</h2>) and
             html =~ ~s(data-anchor="a-1-1">A-1</h2>)
  end

  test "a fence the Files sheet has a lexer for is coloured with its palette" do
    html = Papers.to_html("```elixir\ndef a, do: :ok\n```\n\n```sh\nmix test | grep ok\n```\n")

    assert html =~
             ~s(<pre class="src term-box" data-lang="elixir"><code><span class="kd">def</span>)

    assert html =~ ~s(<pre class="src term-box" data-lang="shell"><code>)
    refute html =~ "language-"
  end

  test "a fence named nothing, or something no lexer answers to, stays as it came" do
    html = Papers.to_html("```\nplain\n```\n\n```text\nalso plain\n```\n")
    assert html =~ ~s(<pre class="term-box"><code>plain\n</code></pre>)
    assert html =~ ~s(<pre class="term-box"><code class="language-text">also plain\n</code></pre>)
    refute html =~ "src"
  end

  test "the HTML inside a coloured fence stays text" do
    html = Papers.to_html("```html\n<img src=x onerror=alert(1)>\n```\n")
    assert html =~ ~s(data-lang="html")
    refute html =~ "<img"
    assert html =~ "&lt;"
  end

  test "a table drawn as a file tree marks its branch cells, and no other table's" do
    html =
      Papers.to_html(
        "| File | Role |\n|---|---|\n| `├──\u00a0📄\u00a0task.ex` | shell |\n| `x` | y |"
      )

    assert html =~ ~s(<td class="tree"><code>├──)
    assert html =~ "<td><code>x</code>"
  end

  test "reads a cartridge's papers off the workbench and rewrites what they point to" do
    assert "readme" in Papers.carried("health_probe")
    page = Papers.render("clustering", "design")
    assert page.html =~ ~s(src="/figures/assets/diagrams/clustering/)
    refute page.html =~ "<svg"
    assert is_binary(page.title)
    page = Papers.render("mailer", "readme")
    refute page.html =~ ~s(href="../)
    assert Papers.render("nope", "readme") == nil
  end
end
