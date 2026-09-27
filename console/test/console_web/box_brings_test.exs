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
    "console" => %{"doors" => []}
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
  # assigns, because the unlit rule is a thing the page says. Each is
  # a plate, the one every address wears (2026-09-27), and the reason
  # is on its title after the address.
  defp plates(html),
    do:
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(".specs .req .door-ref")
      |> Enum.to_list()

  defp name(plate), do: plate |> LazyHTML.query("b") |> LazyHTML.text() |> String.trim()

  defp lit(html) do
    Map.new(plates(html), &{name(&1), state(&1)})
  end

  defp state(plate) do
    if "unlit" in (plate |> LazyHTML.attribute("class") |> List.first("") |> String.split()),
      do: {:unlit, plate |> LazyHTML.attribute("title") |> List.first() |> after_dash()},
      else: :lit
  end

  defp after_dash(title), do: title |> String.split("— ", parts: 2) |> List.last()

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

    test "wears the plate every address wears, by the door's rules" do
      # A port inside the pod, hollow: the menu publishes none of these
      # on the host. It wore its role's colour until 2026-09-27; the
      # plate has its own rules for colour, and this is the plate.
      html = sheet(@always, on_shelf())
      assert [plate] = plates(html)
      assert plate |> LazyHTML.attribute("class") |> List.first() =~ "door-inside"
      refute html =~ "--svc:"
    end

    test "a container the compose would publish is a door on the host, shut" do
      published = put_in(@always, ["offers", Access.at(0), "published"], [3000])
      assert [plate] = plates(sheet(published, on_shelf()))
      assert plate |> LazyHTML.attribute("class") |> List.first() =~ "door-port"
      assert plate |> LazyHTML.query("a") |> Enum.empty?()
    end
  end

  describe "once it is in" do
    # What the project has reads as the Inserted row reads it: with no
    # deployment up, shut because the deployment is down — the plate's
    # words, not the form's. The rest of the menu still wears its switch.
    test "repeats what the project has, whatever the manifest promised" do
      # The project carries one admin; the other is still addable, so
      # it stays in the row wearing its switch.
      html = sheet(@box, carrying("db_admin", ["adminer"], rerun: "adds"))

      assert lit(html) == %{
               "adminer" => {:unlit, "the deployment is down"},
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
               "volume_init" => {:unlit, "the deployment is down"},
               "database" => {:unlit, "ecto is in with database sqlite3"}
             }
    end

    test "a locked cartridge falls back to the switch when it carries no such state" do
      locked = Map.put(@box, "rerun", "nothing")
      html = sheet(locked, carrying("db_admin", ["adminer"]))

      assert lit(html) == %{
               "adminer" => {:unlit, "the deployment is down"},
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end
  end

  defp up_with(name, services, containers) do
    carrying(name, services)
    |> Map.merge(%{"deployment" => "dev", "containers" => containers})
  end

  defp reads(html) do
    html
    |> plates()
    |> Enum.flat_map(fn plate ->
      case plate |> LazyHTML.query(".read") |> LazyHTML.text() |> String.trim() do
        "" -> []
        words -> [{name(plate), words}]
      end
    end)
    |> Map.new()
  end

  test "a box that raises nothing has no row" do
    refute sheet(%{"name" => "credo"}, on_shelf()) =~ "Brings"
  end

  describe "what the container is doing" do
    # Since 2026-09-26 the row carries the reading the rail's Containers
    # table and a service's plate carry, in the one element all three
    # wear: the same words off the same function, so a reader learns the
    # vocabulary once.
    test "each container the box raised says what it is doing" do
      html =
        sheet(
          @box,
          up_with("db_admin", ["adminer", "pgadmin"], [
            %{
              "Service" => "adminer",
              "State" => "running",
              "Health" => "healthy",
              "Status" => "Up 2 hours (healthy)"
            },
            %{"Service" => "pgadmin", "State" => "exited", "ExitCode" => 1}
          ])
        )

      assert reads(html) == %{"adminer" => "healthy", "pgadmin" => "exited 1"}

      # Docker's own line comes with it, as it does on the rail.
      assert html =~ ~s|title="Up 2 hours (healthy)"|
    end

    test "with nothing up there is nothing to read: the containers are not this project's" do
      html = sheet(@box, carrying("db_admin", ["adminer"]))
      assert reads(html) == %{}

      assert lit(html) == %{
               "adminer" => {:unlit, "the deployment is down"},
               "pgadmin" => {:unlit, "only with --admin pgadmin"}
             }
    end

    test "a published container is the door the Inserted row opens, on the box too" do
      # The same plate as on the list: open on the host while its
      # container runs, its port the published one, its reading inside.
      status =
        up_with("db_admin", ["pgadmin"], [
          %{"Service" => "pgadmin", "State" => "running", "Health" => "healthy"}
        ])
        |> put_in(["project", "cartridges", Access.at(0), "compose"], [
          %{"service" => "pgadmin", "listens" => 80, "published" => [80], "deploys" => ["dev"]}
        ])
        |> Map.put("ports", %{"app" => 4001, "published" => %{"80" => 5051}})

      html = sheet(@box, status)
      assert [plate] = Enum.filter(plates(html), &(name(&1) == "pgadmin"))
      assert plate |> LazyHTML.attribute("class") |> List.first() =~ "door-port"

      assert plate |> LazyHTML.query("a") |> LazyHTML.attribute("href") == [
               "http://localhost:5051"
             ]

      assert html =~ "localhost:5051"
      assert reads(html) == %{"pgadmin" => "healthy"}
    end

    test "a one-shot of another deployment says so while dev is up" do
      status =
        up_with("ecto", ["volume_init"], [])
        |> put_in(["project", "cartridges", Access.at(0), "compose"], [
          %{"service" => "volume_init", "listens" => nil, "deploys" => ["prod"]}
        ])

      assert lit(sheet(%{"name" => "ecto"}, status)) == %{
               "volume_init" => {:unlit, "not in the dev deployment"}
             }
    end

    test "a box on the shelf has nothing running of its own" do
      html = sheet(@box, on_shelf())
      assert reads(html) == %{}
      # Its offers are still there, unlit with the reason.
      assert map_size(lit(html)) == 2
    end
  end
end
