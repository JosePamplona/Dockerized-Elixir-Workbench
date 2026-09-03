defmodule Console.PapersTest do
  use ExUnit.Case, async: true

  alias Console.Papers

  test "raw HTML in a paper never reaches the page" do
    html = Papers.to_html("hello <img src=x onerror=alert(1)> <svg onload=alert(2)></svg>")
    refute html =~ "onerror"
    refute html =~ "onload"
    refute html =~ "<img"
  end

  test "tables and code come through" do
    html = Papers.to_html("| a | b |\n|---|---|\n| 1 | 2 |\n\n`x`")
    assert html =~ "<table>" and html =~ "<code>x</code>"
  end

  test "reads a cartridge's papers off the workbench and rewrites what they point to" do
    assert "readme" in Papers.carried("healthcheck2")
    page = Papers.render("clustering", "design")
    assert page.html =~ ~s(src="/figures/assets/diagrams/clustering/)
    refute page.html =~ "<svg"
    assert is_binary(page.title)
    page = Papers.render("mailer", "readme")
    refute page.html =~ ~s(href="../)
    assert Papers.render("nope", "readme") == nil
  end
end
