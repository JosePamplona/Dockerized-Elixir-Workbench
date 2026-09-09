defmodule ConsoleWeb.RecordTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Record

  # A status as `wb.sh status --json` answers it, with what
  # `mix workbench.status` publishes: ecto born with postgres and mailer
  # out, mailer brought in by its cartridge since; healthcheck2 by
  # commit; dev up, prod baked with a service left behind.
  @status %{
    "exists" => true,
    "workspace" => "/nowhere/test_x",
    "compose_project" => "lorem_ipsum",
    "ports" => %{"app" => 4001, "pgadmin" => nil, "grafana" => nil},
    "baked" => %{"dev" => true, "prod" => true, "scaled" => false},
    "deployment" => "dev",
    "containers" => [
      %{
        "Service" => "app",
        "State" => "running",
        "Health" => "healthy",
        "Image" => "lorem-ipsum:local"
      },
      %{
        "Service" => "database",
        "State" => "running",
        "Health" => "healthy",
        "Image" => "postgres:latest"
      },
      %{"Service" => "network", "State" => "running", "Health" => "", "Image" => "pause"}
    ],
    "git" => %{
      "repo" => true,
      "clean" => true,
      "head" => "1be24b2 Revert",
      "inserts" => [
        %{
          "sha" => "fcb1afa3bf",
          "feature" => "healthcheck2",
          "subject" => "Insert healthcheck2 --path /probe",
          "date" => "2026-09-08",
          "argv" => ["--path", "/probe"]
        }
      ]
    },
    "project" => %{
      "app" => "lorem_ipsum",
      "services" => ["postgres"],
      "phx" => %{
        "app" => "lorem_ipsum",
        "module" => "LoremIpsum",
        "database" => "postgres",
        "adapter" => "bandit",
        "binary_id" => true,
        "ecto" => true,
        "html" => true,
        "live" => true,
        "dashboard" => true,
        "mailer" => true,
        "gettext" => true,
        "esbuild" => true,
        "tailwind" => true,
        "agents_md" => true,
        "generator" => %{
          "project" => "1.8.13",
          "installer" => "1.8.14",
          "source" => "Dockerfile.local"
        }
      },
      "birth" => %{
        "sha" => "1a0546c1234567890",
        "date" => "2026-09-08 07:44:49 +0000",
        "subject" => "New project: lorem_ipsum",
        "phx" => %{
          "app" => "lorem_ipsum",
          "module" => "LoremIpsum",
          "database" => "postgres",
          "adapter" => "bandit",
          "binary_id" => true,
          "ecto" => true,
          "html" => true,
          "live" => true,
          "dashboard" => true,
          "mailer" => false,
          "gettext" => true,
          "esbuild" => true,
          "tailwind" => true,
          "agents_md" => true,
          "flags" =>
            ~w(--app lorem_ipsum --module LoremIpsum --database postgres --adapter bandit --no-mailer --binary-id)
        },
        "dockerfile" => %{
          "ELIXIR" => "1.19.6",
          "OTP" => "28.5.0.6",
          "DEBIAN" => "trixie",
          "PHX_NEW" => "1.8.13"
        }
      },
      "deployments" => %{
        "dev" => %{
          "baked" => true,
          "in_sync" => true,
          "stray" => [],
          "missing" => [],
          "services" => ~w(network app database)
        },
        "prod" => %{
          "baked" => true,
          "in_sync" => false,
          "stray" => ["grafana"],
          "missing" => [],
          "services" => ~w(network app migrate database grafana)
        },
        "scaled" => %{
          "baked" => false,
          "in_sync" => nil,
          "stray" => [],
          "missing" => [],
          "services" => []
        }
      },
      "cartridges" => [
        %{
          "name" => "ecto",
          "installed" => true,
          "base" => true,
          "state" => %{"database" => "postgres"},
          "options" => [
            %{"name" => "database", "type" => "string", "default" => "postgres"},
            %{"name" => "binary_id", "type" => "boolean", "default" => false}
          ]
        },
        %{"name" => "mailer", "installed" => true, "base" => true, "state" => %{}},
        %{
          "name" => "healthcheck2",
          "installed" => true,
          "base" => false,
          "state" => %{"path" => "/probe"},
          "options" => [%{"name" => "path", "type" => "string", "default" => "/health"}]
        },
        %{"name" => "exdoc", "installed" => false}
      ]
    }
  }
  @catalog [
    %{
      "name" => "ecto",
      "base" => true,
      "version" => %{"version" => "0.2.0", "date" => "2026-08-30"}
    },
    %{
      "name" => "mailer",
      "base" => true,
      "console" => %{"doors" => [%{"label" => "mailbox", "path" => "/dev/mailbox"}]}
    },
    %{
      "name" => "healthcheck2",
      "console" => %{
        "doors" => [
          %{"label" => "live", "path" => "{path}/live"},
          %{"label" => "ready", "path" => "{path}/ready"}
        ]
      }
    },
    %{"name" => "exdoc", "console" => %{"doors" => [%{"label" => "docs", "path" => "/dev/docs"}]}}
  ]

  test "the birth against today: what moved carries what it is now" do
    page = Record.page(@status, @catalog)

    assert page.name == "lorem_ipsum" and page.up and page.port == 4001
    assert %{sha: "1a0546c1234567890", subject: "New project: lorem_ipsum"} = page.birth

    assert page.birth.command ==
             "mix phx.new . --app lorem_ipsum --module LoremIpsum --database postgres --adapter bandit --no-mailer --binary-id"

    # mailer was out at birth, and is in now: the flag was used, and the fact moved.
    assert %{name: "no-mailer", used: true, now: "in", cartridge: "mailer"} =
             Enum.find(page.birth.flags, &(&1.name == "no-mailer"))

    assert %{name: "database", used: true, arg: "postgres", default: true, now: nil} =
             Enum.find(page.birth.flags, &(&1.name == "database"))

    # The cartridge beside a flag wears what the project carries, not a dot for everyone.
    assert %{cartridge: "ecto", installed: true} =
             Enum.find(page.birth.flags, &(&1.name == "no-ecto"))

    assert %{cartridge: "esbuild", installed: false} =
             Enum.find(page.birth.flags, &(&1.name == "no-esbuild"))

    # A flag another flag makes moot is marked, with the reason: the
    # database and the ids without Ecto, --no-live without HTML views.
    refute Enum.any?(page.birth.flags, & &1.moot)
    no_ecto = put_in(@status, ["project", "birth", "phx", "ecto"], false)

    moot = Record.page(no_ecto, @catalog).birth.flags |> Enum.filter(& &1.moot)
    assert Enum.map(moot, & &1.name) == ["database", "binary-id"]
    # Moot: not given, and nothing to say.
    assert Enum.all?(moot, &(&1.used == false and is_nil(&1.arg)))

    no_html = put_in(@status, ["project", "birth", "phx", "html"], false)

    assert Record.page(no_html, @catalog).birth.flags
           |> Enum.filter(& &1.moot)
           |> Enum.map(& &1.name) ==
             ["no-live"]

    # The toolchain's phx_new moved past the generator: said, with the remedy in the sheet.
    assert %{born: "1.8.13", at_hand: "1.8.14", in_sync: false} = page.birth.installer
    assert page.birth.moved == 1
  end

  test "the cartridges: the shelf's row, the parameters as flags, every address with its reading" do
    reads = %{
      "http://localhost:4001/probe/live" => {"200", "good"},
      "http://localhost:4001/dev/mailbox" => {"200", "good"}
    }

    page = Record.page(@status, @catalog, reads)

    # Inserted first, born second.
    assert Enum.map(page.cartridges, & &1.c["name"]) == ~w(healthcheck2 ecto mailer)

    hc = Enum.at(page.cartridges, 0)
    assert elem(hc.origin, 0) == "by commit"
    assert hc.params == [{"--path /probe", false}]

    assert [
             %{
               label: "live",
               path: "/probe/live",
               kind: "route",
               port: 4001,
               read: {"200", "good"}
             },
             %{label: "ready", path: "/probe/ready", kind: "route", read: nil}
           ] = hc.addresses

    ecto = Enum.at(page.cartridges, 1)
    assert elem(ecto.origin, 0) == "from birth"
    assert ecto.params == [{"--database postgres", true}]
    # The database's port, with what docker compose ps says of its container.
    assert [%{label: "database", path: ":5432", kind: "port", read: {"healthy", "good"}}] =
             ecto.addresses

    assert Record.hrefs(page) == [
             "http://localhost:4001/probe/live",
             "http://localhost:4001/probe/ready",
             "http://localhost:4001/dev/mailbox"
           ]
  end

  test "the deployments: each file, in sync or with its drift, up or down, its services as ports" do
    page = Record.page(@status, @catalog)

    [dev, prod, scaled] = page.deployments
    assert %{deploy: "dev", baked: true, in_sync: true, status: "up", present: true} = dev

    assert Enum.map(dev.services, &{&1.label, &1.path, &1.read}) == [
             {"network", "", {"running", "good"}},
             {"app", ":4000", {"healthy", "good"}},
             {"database", ":5432", {"healthy", "good"}}
           ]

    assert %{deploy: "prod", in_sync: false, stray: ["grafana"], status: "down", present: false} =
             prod

    assert Enum.all?(prod.services, &(&1.why == "the deployment is down" and is_nil(&1.read)))
    assert %{deploy: "scaled", baked: false, status: nil, services: []} = scaled
  end

  test "with nothing up every route is shut by that, and nothing is called" do
    page = Record.page(Map.put(@status, "deployment", nil), @catalog)
    assert Enum.all?(page.cartridges, fn row -> Enum.all?(row.addresses, &(&1.why != nil)) end)
    assert Record.hrefs(page) == []
  end

  test "no project, no plan" do
    assert Record.page(nil, @catalog) == nil
    assert Record.page(%{"exists" => false}, @catalog) == nil
  end

  test "params/2: a boolean is its flag when on, a list is comma-joined, a default is marked" do
    e = %{
      "options" => [
        %{"name" => "with", "type" => "csv"},
        %{"name" => "example", "type" => "boolean", "default" => false},
        %{"name" => "path", "type" => "string", "default" => "/health"}
      ]
    }

    assert Record.params(
             %{
               "state" => %{
                 "with" => ["ash_admin", "ash_oban"],
                 "example" => true,
                 "path" => "/health"
               }
             },
             e
           ) ==
             [
               {"--example", false},
               {"--path /health", true},
               {"--with ash_admin,ash_oban", false}
             ]

    assert Record.params(%{"state" => %{"example" => false}}, e) == []
  end
end
