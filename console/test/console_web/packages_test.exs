defmodule ConsoleWeb.PackagesTest do
  @moduledoc """
  The marks of the cartridge column: a row read off an insert commit
  carries the number of the note that says where it came from, in the
  words of the box that brought it, and each note is said once under
  the table.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  defp row(name, note),
    do: ConsoleWeb.Packages.row(%{"name" => name, "read" => true, "note" => note}, %{}, nil, true)

  test "one number per origin, in the order the rows first carry them" do
    html =
      render_component(&ConsoleWeb.Packages.table/1,
        rows: [
          row("ash", "it runs `mix igniter.install ash`"),
          row("picosat_elixir", "an installer added it"),
          row("ash_phoenix", "it runs `mix igniter.install ash`")
        ]
      )

    assert html =~
             ~s(<sup class="fn" title="it runs `mix igniter.install ash`"><a href="#pkgs-note-1">1</a></sup>)

    assert html =~
             ~s(<sup class="fn" title="an installer added it"><a href="#pkgs-note-2">2</a></sup>)

    assert html =~ ~r{<code[^>]*>mix igniter.install ash</code>}
    # Each mark leads to its note.
    assert html =~ ~s(<p id="pkgs-note-1" class="fn-note">)
    assert html =~ ~s(<p id="pkgs-note-2" class="fn-note">)
    # Each note once, however many rows carry it.
    assert length(String.split(html, ~s(class="fn-note"))) == 3
  end

  test "a row not read off a commit carries no mark, and the table no note" do
    html =
      render_component(&ConsoleWeb.Packages.table/1,
        rows: [
          ConsoleWeb.Packages.row(%{"name" => "req", "declared" => "~> 0.5"}, %{}, nil, true)
        ]
      )

    refute html =~ ~s(class="fn")
    refute html =~ "fn-note"
  end
end
