defmodule ConsoleWeb.PkgRefTest do
  @moduledoc """
  The one way the console names a dependency of the Elixir ecosystem:
  hex's own mark, the name, and an address that leaves for hex — the
  package's page, or one version's documentation.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import ConsoleWeb.Refs

  defp ref(opts), do: render_component(&pkg_ref/1, opts)

  test "the name addresses the package's page, wearing hex's mark" do
    html = ref(name: "ex_doc")

    assert html =~ ~s(href="https://hex.pm/packages/ex_doc")
    assert html =~ ~s(class="pkg-ref )
    assert html =~ ~s(src="/images/vendor/hex.svg")
    assert html =~ ~s(title="ex_doc on hex.pm")
    assert html =~ ~s(target="_blank")
    assert html =~ ~s(rel="noopener noreferrer")
    assert html =~ "ex_doc"
  end

  test "a version addresses that version's documentation, and prints it" do
    html = ref(name: "ex_doc", version: "0.40.4")

    assert html =~ ~s(href="https://hexdocs.pm/ex_doc/0.40.4")
    assert html =~ "the documentation of ex_doc 0.40.4"
    assert html =~ "0.40.4"
  end

  test "a path goes under the package's page" do
    assert ref(name: "phx_new", path: "versions") =~
             ~s(href="https://hex.pm/packages/phx_new/versions")
  end

  test "where the line already wears a mark, the mention goes bare" do
    html = ref(name: "ex_doc", version: "0.40.4", mark: false)

    refute html =~ "hex.svg"
    assert html =~ "bare"
  end

  test "a label says what it prints, and never what it opens" do
    html = ref(name: "phx_new", label: "phx.new 1.8.14")

    assert html =~ "phx.new 1.8.14"
    assert html =~ ~s(href="https://hex.pm/packages/phx_new")
  end
end
