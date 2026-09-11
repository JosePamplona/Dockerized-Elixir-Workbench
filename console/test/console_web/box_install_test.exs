defmodule ConsoleWeb.BoxInstallTest do
  @moduledoc """
  The box's Installation screen keeps what the cartridge went in with:
  the line says it, and the fields start from it — locked, and open
  again for the cartridges that can be run to add (`rerun: adds`),
  which used to fall back to their defaults and so forget.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias ConsoleWeb.Box

  @box %{
    "name" => "ecto",
    "options" => [
      %{
        "name" => "database",
        "choices" => [%{"value" => "postgres"}, %{"value" => "mysql"}],
        "default" => "postgres",
        "type" => "string"
      },
      %{"name" => "binary_id", "type" => "boolean", "default" => false}
    ]
  }

  test "locked, the line is the insert's own argv" do
    insert = %{"argv" => ["--database", "mysql", "--binary-id"]}
    assert Box.line_argv(@box, %{}, insert, true) == ["--database", "mysql", "--binary-id"]
  end

  test "open, the line is what the form says" do
    insert = %{"argv" => ["--database", "mysql"]}
    # The reader is looking at sqlite3 now, whatever it went in with.
    assert Box.line_argv(@box, %{"database" => "sqlite3"}, insert, false) ==
             ["--database", "sqlite3"]
  end

  defp screen(box, status, opts \\ []) do
    render_component(&ConsoleWeb.Box.box/1,
      box: box,
      status: status,
      catalog: [box],
      screen: "install",
      paper: "readme",
      papers: [],
      args: Keyword.get(opts, :args, %{}),
      recipe: opts[:recipe]
    )
  end

  defp in_project(name, opts \\ []) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => opts[:inserts] || []},
      "project" => %{"cartridges" => [%{"name" => name, "installed" => true}]}
    }
  end

  test "not in: the insert foot alone" do
    html = screen(@box, %{"exists" => true, "git" => %{"repo" => true, "clean" => true}})
    assert html =~ "./wb.sh add ecto"
    assert html =~ "Insert cartridge"
    refute html =~ "Eject"
  end

  test "in and done: the eject foot alone, with the line it is" do
    html = screen(@box, in_project("ecto"))
    assert html =~ "./wb.sh eject ecto"
    assert html =~ ">Eject</button>"
    # A button that says "already inserted" is a state, not an action.
    refute html =~ "Already inserted"
    refute html =~ "./wb.sh add ecto"
  end

  test "in and rerunnable: both feet, each with its own line" do
    box = Map.put(@box, "rerun", "adds")
    html = screen(box, in_project("ecto"))
    assert html =~ "./wb.sh add ecto"
    assert html =~ "./wb.sh eject ecto"
    assert html =~ "Add to cartridge"
    assert html =~ ">Eject</button>"
  end

  test "in from birth, with no Insert commit, the fields read what the project reports" do
    status =
      put_in(in_project("ecto"), ["project", "cartridges"], [
        %{
          "name" => "ecto",
          "installed" => true,
          "state" => %{"database" => "mysql", "binary_id" => true}
        }
      ])

    html = screen(@box, status)
    assert html =~ ~r{name="opt\[binary_id\]"[^>]*checked}
    assert html =~ ~r{value="mysql"[^>]*checked}
    refute html =~ ~r{value="postgres"[^>]*checked}
  end

  test "with nothing to read the line is the bare verb" do
    # Born with the project, or inserted by a hand that left no commit.
    assert Box.line_argv(@box, %{}, nil, true) == []
  end
end
