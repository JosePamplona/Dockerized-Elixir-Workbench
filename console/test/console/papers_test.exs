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

  test "tables and code come through" do
    html = Papers.to_html("| a | b |\n|---|---|\n| 1 | 2 |\n\n`x`")
    assert html =~ "<table>" and html =~ "<code>x</code>"
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
