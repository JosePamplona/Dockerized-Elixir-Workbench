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

  test "archived: the console does not force it, and says the line that does" do
    box = Map.put(@box, "archived", "2026-09-20: chiefs_setup's collection covers it")
    html = screen(box, %{"exists" => true, "git" => %{"repo" => true, "clean" => true}})

    # The command the reader would have to run is the honest one, flag
    # included; the button beside it is unlit, with the reason.
    assert html =~ "./wb.sh add --archived ecto"
    assert html =~ "Archived"
    assert html =~ "chiefs_setup&#39;s collection covers it"
    assert html =~ "retired: not offered for new projects"
    refute html =~ ~s(phx-value-args="add ecto")
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

  test "a default is the field's placeholder, never its value" do
    box = %{
      "name" => "exdoc",
      "options" => [
        %{"name" => "minimum", "type" => "string", "default" => "80"},
        %{"name" => "repo_url", "type" => "string", "detected" => true},
        %{"name" => "homepage_url", "type" => "string"}
      ]
    }

    html = screen(box, %{"exists" => true, "project" => %{"cartridges" => []}})

    # Empty, showing what an empty field means: the default, where it
    # comes from when the installer reads it off the project, or the type.
    assert html =~ ~r{id="opt-minimum"[^>]*placeholder="80"}
    refute html =~ ~r{id="opt-minimum"[^>]*value=}
    assert html =~ ~r{id="opt-repo_url"[^>]*placeholder="read off the project"}
    assert html =~ ~r{id="opt-homepage_url"[^>]*placeholder="string"}
    # And an empty field leaves its flag out of the line.
    assert Box.argv(box, %{"minimum" => ""}) == []
    assert Box.argv(box, %{"minimum" => "90"}) == ["--minimum", "90"]
  end

  test "with nothing to read the line is the bare verb" do
    # Born with the project, or inserted by a hand that left no commit.
    assert Box.line_argv(@box, %{}, nil, true) == []
  end

  test "a value the project's database does not serve is unlit, and says the state it needs" do
    box = %{
      "name" => "db_admin",
      "options" => [
        %{
          "name" => "admin",
          "type" => "csv",
          "multiple" => true,
          "choices" => [
            %{
              "value" => "pgadmin",
              "requires" => ["ecto"],
              "conditions" => %{"ecto" => %{"database" => "postgres"}}
            },
            %{
              "value" => "phpmyadmin",
              "requires" => ["ecto"],
              "conditions" => %{"ecto" => %{"database" => "mysql"}}
            },
            %{"value" => "adminer", "requires" => [], "conditions" => %{}}
          ]
        }
      ]
    }

    status = %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true},
      "project" => %{
        "cartridges" => [
          %{"name" => "ecto", "installed" => true, "state" => %{"database" => "postgres"}}
        ]
      }
    }

    html = screen(box, status)
    assert html =~ "needs ecto with database mysql"
    refute html =~ "needs ecto with database postgres"
    refute html =~ ~r/needs ecto</
  end

  @db_admin %{
    "name" => "db_admin",
    "rerun" => "adds",
    "requires" => ["ecto"],
    "options" => [
      %{
        "name" => "admin",
        "type" => "csv",
        "multiple" => true,
        "choices" => [
          %{
            "value" => "pgadmin",
            "requires" => ["ecto"],
            "conditions" => %{"ecto" => %{"database" => "postgres"}}
          },
          %{
            "value" => "phpmyadmin",
            "requires" => ["ecto"],
            "conditions" => %{"ecto" => %{"database" => "mysql"}}
          },
          %{"value" => "adminer", "requires" => [], "conditions" => %{}}
        ]
      }
    ]
  }

  defp with_admins(admins) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "project" => %{
        "cartridges" => [
          %{"name" => "ecto", "installed" => true, "state" => %{"database" => "postgres"}},
          %{"name" => "db_admin", "installed" => true, "state" => %{"admin" => admins}}
        ]
      }
    }
  end

  test "what is in is said by the box checked and shut, with no tag beside it" do
    html = screen(@db_admin, with_admins(["pgadmin"]))
    assert html =~ ~r{value="pgadmin"[^>]*checked[^>]*disabled}
    refute html =~ ~s(class="in">in<)
    # The one the database does not serve says why, in its own class —
    # not the need paper's, whose panel it used to borrow.
    assert html =~ ~s(class="lacks")
    assert html =~ ~s(class="in lacks")
    refute html =~ ~s(<label class="need")
  end

  # credo's --githook writes into the hook precommit owns.
  @credo %{
    "name" => "credo",
    "rerun" => "adds",
    "requires" => [],
    "options" => [
      %{
        "name" => "githook",
        "type" => "boolean",
        "default" => false,
        "choices" => nil,
        "requires" => ["precommit"],
        "conditions" => %{}
      }
    ]
  }

  defp with_cartridges(cartridges) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "project" => %{"cartridges" => cartridges}
    }
  end

  test "a switch that builds on a cartridge the project lacks is unlit, and says why" do
    html = screen(@credo, with_cartridges([%{"name" => "precommit", "installed" => false}]))
    assert html =~ ~r{id="opt-githook"[^>]*disabled}
    assert html =~ ~s(class="in lacks")
    assert html =~ "needs precommit"
  end

  test "with the cartridge in, the switch is lit" do
    html =
      screen(
        @credo,
        with_cartridges([%{"name" => "precommit", "installed" => true, "state" => %{}}])
      )

    refute html =~ ~r{id="opt-githook"[^>]*disabled}
    refute html =~ "needs precommit"
  end

  test "a switch turned on names what it builds on" do
    assert ConsoleWeb.Box.value_requires(@credo, %{"githook" => "on"}, %{}) ==
             [{"--githook", ["precommit"], %{}}]

    assert ConsoleWeb.Box.value_requires(@credo, %{"githook" => "off"}, %{}) == []
  end

  test "rerunnable with a value still free: Add to cartridge, lit" do
    html = screen(@db_admin, with_admins(["pgadmin"]))
    assert html =~ "Add to cartridge"
    refute html =~ "nothing left to add"
  end

  test "rerunnable with every value in or out of reach: the add is unlit, and says why" do
    html = screen(@db_admin, with_admins(["pgadmin", "adminer"]))
    assert html =~ "nothing left to add"
    assert html =~ ~r{class="btn primary unlit"}
  end

  test "a need in the specs is the cartridge alone, not the need paper's panel" do
    html =
      render_component(&ConsoleWeb.Box.box/1,
        box: @db_admin,
        status: with_admins(["pgadmin"]),
        catalog: [@db_admin],
        screen: "box",
        paper: "readme",
        papers: [],
        args: %{}
      )

    assert html =~ ~s(class="req")
    refute html =~ ~s(<span class="need")
  end
end
