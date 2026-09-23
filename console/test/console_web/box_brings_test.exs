defmodule ConsoleWeb.BoxBringsTest do
  @moduledoc """
  The box's Brings row: the containers the cartridge raises.

  Where it reads them from is the whole of it. Once the cartridge is in,
  the project says what it has and the row repeats it. While it is on
  the shelf there is no project to ask, so the row reads the manifest's
  menu (`offers`) and lights what the form is holding — which is why
  the row moves with the switches instead of promising all four
  databases to a reader who has picked one.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  # What every catalog entry carries and no test here is about.
  @manifest %{
    "requires" => [],
    "conditions" => %{},
    "members" => [],
    "compose" => [],
    "offers" => [],
    "options" => [],
    "console" => %{"doors" => [], "tabs" => []}
  }

  defp box(fields), do: Map.merge(@manifest, fields)

  # A cartridge shaped like db_admin: two containers, one per choice,
  # and it can be run again to add another (`rerun: adds`).
  @box %{
    "name" => "db_admin",
    "rerun" => "adds",
    "adds" => ["admin"],
    "summary" => "the database admin in the browser",
    "options" => [
      %{
        "name" => "admin",
        "type" => "csv",
        "multiple" => true,
        "choices" => [%{"value" => "adminer"}, %{"value" => "pgadmin"}]
      }
    ],
    "offers" => [
      %{
        "service" => "adminer",
        "with" => [%{"option" => "admin", "value" => "adminer"}],
        "listens" => 8080,
        "deploys" => ["dev", "prod"],
        "role" => "devtools"
      },
      %{
        "service" => "pgadmin",
        "with" => [%{"option" => "admin", "value" => "pgadmin"}],
        "listens" => 5050,
        "deploys" => ["dev", "prod"],
        "role" => "devtools"
      }
    ]
  }

  # A cartridge whose one container comes whatever you choose.
  @always %{
    "name" => "monitoring",
    "offers" => [
      %{
        "service" => "grafana",
        "with" => [],
        "listens" => 3000,
        "deploys" => ["dev", "prod", "scaled"],
        "role" => "observability"
      }
    ]
  }

  defp sheet(fields, status, args \\ %{}) do
    box = box(fields)

    render_component(&ConsoleWeb.Box.box/1,
      box: box,
      status: status,
      catalog: [box],
      screen: "box",
      paper: "readme",
      papers: [],
      args: args,
      recipe: nil
    )
  end

  defp on_shelf, do: %{"exists" => true, "git" => %{"repo" => true, "clean" => true}}

  defp carrying(name, services, opts \\ []) do
    %{
      "exists" => true,
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "project" => %{
        "cartridges" => [
          %{
            "name" => name,
            "installed" => true,
            "rerun" => opts[:rerun],
            "state" => opts[:state] || %{},
            "compose" =>
              for(s <- services, do: %{"service" => s, "listens" => nil, "deploys" => ["dev"]})
          }
        ]
      }
    }
  end

  # The row as the reader meets it: each container by name, `:lit` or
  # unlit with the reason it wears. Read off the markup and not off the
  # assigns, because the unlit rule is a thing the page says.
  defp lit(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(".specs .req")
    |> Enum.flat_map(fn item ->
      case item |> LazyHTML.query(".svc") |> LazyHTML.text() |> String.trim() do
        "" -> []
        name -> [{name, state(item)}]
      end
    end)
    |> Map.new()
  end

  defp state(item) do
    if "unlit" in (item |> LazyHTML.attribute("class") |> List.first("") |> String.split()),
      do: {:unlit, item |> LazyHTML.attribute("title") |> List.first()},
      else: :lit
  end

  describe "on the shelf" do
    test "lights what the form is holding and says the switch for the rest" do
      html = sheet(@box, on_shelf(), %{"admin" => ["adminer"]})

      assert lit(html) == %{
               "adminer" => :lit,
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end

    test "moves when the switch moves" do
      html = sheet(@box, on_shelf(), %{"admin" => ["pgadmin"]})

      assert lit(html) == %{
               "adminer" => {:unlit, "only with --admin adminer"},
               "pgadmin" => :lit
             }
    end

    test "with nothing chosen, offers the whole menu unlit" do
      assert lit(sheet(@box, on_shelf())) == %{
               "adminer" => {:unlit, "only with --admin adminer"},
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end

    test "a container that waits on no choice is lit from the start" do
      assert lit(sheet(@always, on_shelf())) == %{"grafana" => :lit}
    end

    test "says the port and the deployments it enters" do
      html = sheet(@always, on_shelf())
      assert html =~ ":3000"
      assert html =~ "dev · prod · scaled"
    end

    test "wears its own role's colour, which no project is there to say" do
      # The role travels with the offer, so the shelf draws it right.
      # Asked of the project instead, every one of these would come
      # back the plainest: the project carries none of them.
      assert sheet(@always, on_shelf()) =~ "--svc:var(--svc-observability)"
      assert sheet(@box, on_shelf()) =~ "--svc:var(--svc-devtools)"
    end
  end

  describe "once it is in" do
    test "repeats what the project has, whatever the manifest promised" do
      # The project carries one admin; the other is still addable, so
      # it stays in the row wearing its switch.
      html = sheet(@box, carrying("db_admin", ["adminer"], rerun: "adds"))

      assert lit(html) == %{
               "adminer" => :lit,
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end

    test "a locked cartridge blames the state it went in with, not a switch" do
      # ecto's own case: the project is on SQLite, which is a file, so
      # there is no database container — and no switch here can bring
      # one, because the form is locked until it is ejected.
      ecto = %{
        "name" => "ecto",
        "options" => [
          %{
            "name" => "database",
            "type" => "string",
            "choices" => [%{"value" => "postgres"}, %{"value" => "sqlite3"}]
          }
        ],
        "offers" => [
          %{
            "service" => "database",
            "with" => [%{"option" => "database", "value" => "postgres"}],
            "listens" => nil,
            "deploys" => ["dev", "prod"],
            "role" => "database"
          },
          %{
            "service" => "volume_init",
            "with" => [%{"option" => "database", "value" => "sqlite3"}],
            "listens" => nil,
            "deploys" => ["prod"],
            "role" => "job"
          }
        ]
      }

      status = carrying("ecto", ["volume_init"], state: %{"database" => "sqlite3"})

      assert lit(sheet(ecto, status)) == %{
               "volume_init" => :lit,
               "database" => {:unlit, "ecto is in with database sqlite3"}
             }
    end

    test "a locked cartridge falls back to the switch when it carries no such state" do
      locked = Map.put(@box, "rerun", "nothing")
      html = sheet(locked, carrying("db_admin", ["adminer"]))

      assert lit(html) == %{
               "adminer" => :lit,
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end
  end

  test "a box that raises nothing has no row" do
    refute sheet(%{"name" => "credo"}, on_shelf()) =~ "Brings"
  end
end
