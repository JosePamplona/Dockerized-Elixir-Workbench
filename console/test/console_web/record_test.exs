defmodule ConsoleWeb.RecordTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Record

  # A status as `wb.sh status --json` answers it, with what
  # `mix workbench.status` publishes: ecto born with postgres and mailer
  # out, mailer brought in by its cartridge since; health_probe by
  # commit; dev up, prod baked with a service left behind.
  @status %{
    "exists" => true,
    "workspace" => "/nowhere/test_x",
    "compose_project" => "lorem_ipsum",
    "ports" => %{"app" => 4001, "published" => %{}},
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
      %{"Service" => "pod", "State" => "running", "Health" => "", "Image" => "pause"}
    ],
    "git" => %{
      "repo" => true,
      "clean" => true,
      "head" => "1be24b2 Revert",
      "inserts" => [
        %{
          "sha" => "fcb1afa3bf",
          "feature" => "health_probe",
          "subject" => "Insert health_probe --path /probe",
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
          "services" => ~w(pod app database)
        },
        "prod" => %{
          "baked" => true,
          "in_sync" => false,
          "stray" => ["grafana"],
          "missing" => [],
          "services" => ~w(pod app migrate database grafana)
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
          # What the cartridge brings to the compose, as the status says it.
          "compose" => [%{"service" => "database", "listens" => 5432, "published" => []}],
          "options" => [
            %{"name" => "database", "type" => "string", "default" => "postgres"},
            %{"name" => "binary_id", "type" => "boolean", "default" => false}
          ]
        },
        %{"name" => "mailer", "installed" => true, "base" => true, "state" => %{}},
        %{
          "name" => "health_probe",
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
      "name" => "health_probe",
      "console" => %{
        "doors" => [
          %{"label" => "live", "path" => "{path}/live"},
          %{"label" => "ready", "path" => "{path}/ready"}
        ]
      }
    },
    %{
      "name" => "exdoc",
      "console" => %{
        "doors" => [
          %{
            "label" => "docs",
            "path" => "doc/",
            "output" => %{
              "dir" => "doc",
              "index" => "index.html",
              "build" => [%{"task" => "docs", "when" => nil}]
            }
          }
        ]
      }
    }
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

    # The rows in reading order: Ecto's flag before the two that only mean something with it.
    assert Enum.map(page.birth.flags, & &1.name) |> Enum.take(6) ==
             ~w(app module adapter no-ecto database binary-id)

    # LiveView is html's --live: the row points at html, not at a box that is gone.
    assert %{cartridge: "html"} = Enum.find(page.birth.flags, &(&1.name == "no-live"))

    # A flag another flag makes moot is marked, with the reason: the
    # database and the ids without Ecto, --no-live without HTML views.
    refute Enum.any?(page.birth.flags, & &1.moot)

    no_ecto =
      @status
      |> put_in(["project", "birth", "phx", "ecto"], false)
      |> put_in(["project", "phx", "ecto"], false)

    moot = Record.page(no_ecto, @catalog).birth.flags |> Enum.filter(& &1.moot)
    assert Enum.map(moot, & &1.name) == ["database", "binary-id"]
    # Moot: not given, and nothing to say.
    assert Enum.all?(moot, &(&1.used == false and is_nil(&1.arg) and is_nil(&1.now)))

    no_html =
      @status
      |> put_in(["project", "birth", "phx", "html"], false)
      |> put_in(["project", "phx", "html"], false)

    assert Record.page(no_html, @catalog).birth.flags
           |> Enum.filter(& &1.moot)
           |> Enum.map(& &1.name) ==
             ["no-live"]

    # The docs column's source: phx.new's page at the version that generated the project.
    assert page.birth.docs == "https://hexdocs.pm/phoenix/1.8.13/Mix.Tasks.Phx.New.html"

    unstamped = update_in(@status, ["project", "birth", "dockerfile"], &Map.delete(&1, "PHX_NEW"))

    assert Record.page(unstamped, @catalog).birth.docs ==
             "https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html"

    # The toolchain's phx_new moved past the generator: said, with the remedy in the sheet.
    assert %{born: "1.8.13", at_hand: "1.8.14", in_sync: false} = page.birth.installer
    assert page.birth.moved == 1
  end

  # Born minimal, the base cartridges added afterwards: what made a flag
  # moot came in, and its row speaks again — not given, and what it is now.
  test "a flag moot at birth says what it is now once its cartridge came in" do
    born_minimal =
      @status
      |> update_in(["project", "birth", "phx"], fn phx ->
        # phx.new's reading under --no-ecto --no-html: the default database, no ids, no live.
        Map.merge(phx, %{"ecto" => false, "binary_id" => false, "html" => false, "live" => false})
      end)

    flags = Record.page(born_minimal, @catalog).birth.flags
    row = fn name -> Enum.find(flags, &(&1.name == name)) end

    refute Enum.any?(flags, & &1.moot)
    # The born "postgres" was the default of a database that was not there: today's is the news.
    assert %{used: false, arg: nil, now: "postgres"} = row.("database")
    assert %{used: false, now: "in"} = row.("binary-id")
    assert %{used: false, now: "in"} = row.("no-live")
    assert %{used: true, now: "in"} = row.("no-ecto")

    # Ecto came in with integer ids, the views without LiveView: nothing moved on those two.
    plain =
      born_minimal
      |> put_in(["project", "phx", "binary_id"], false)
      |> put_in(["project", "phx", "live"], false)

    flags = Record.page(plain, @catalog).birth.flags
    assert %{used: false, now: nil, moot: nil} = Enum.find(flags, &(&1.name == "binary-id"))
    assert %{used: false, now: nil, moot: nil} = Enum.find(flags, &(&1.name == "no-live"))
  end

  test "the cartridges: the shelf's row, the parameters as flags, every address with its reading" do
    reads = %{
      "http://localhost:4001/probe/live" => {"200", "good"},
      "http://localhost:4001/dev/mailbox" => {"200", "good"}
    }

    page = Record.page(@status, @catalog, reads)

    # Inserted first, born second.
    assert Enum.map(page.cartridges, & &1.c["name"]) == ~w(health_probe ecto mailer)

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
    assert [%{label: "database", path: ":5432", kind: "inside", read: {"healthy", "good"}}] =
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
             {"pod", "", {"running", "good"}},
             {"app", ":4000", {"healthy", "good"}},
             {"database", ":5432", {"healthy", "good"}}
           ]

    assert %{deploy: "prod", in_sync: false, stray: ["grafana"], status: "down", present: false} =
             prod

    # A published port goes to the service that listens on it: the pod
    # container declares 4001:4000 and 5433:5432, app and the
    # database wear them; one no service claims stays with its publisher.
    ws = Path.join(System.tmp_dir!(), "record_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(ws)

    File.write!(Path.join(ws, "docker-compose.yml"), """
    services:
      pod:
        image: pause
        ports:
          - 4001:4000
          - 5433:5432
          - 9999:7777
      app:
        network_mode: service:pod
      database:
        network_mode: service:pod
    """)

    [dev | _] = Record.deployments(Map.put(@status, "workspace", ws))

    assert Enum.map(dev.services, &{&1.label, &1.path, &1.kind, &1.href}) == [
             {"pod", "localhost:9999", "port", "http://localhost:9999"},
             {"app", "localhost:4001", "port", "http://localhost:4001"},
             {"database", "localhost:5433", "port", "http://localhost:5433"}
           ]

    File.rm_rf!(ws)

    # Stopped: the containers are there, none running — dev after a Stop.
    stopped = Map.put(@status, "deployment", nil)
    assert %{status: "stopped", present: true} = Enum.at(Record.deployments(stopped), 0)

    assert Enum.all?(prod.services, &(&1.why == "the deployment is down" and is_nil(&1.read)))
    assert %{deploy: "scaled", baked: false, status: nil, services: []} = scaled
  end

  test "a service's port published on the host is a door: opened, and knocked" do
    # pgAdmin in, its container up, the compose publishing 5050.
    status =
      @status
      |> put_in(["ports", "published"], %{"5050" => 5050})
      |> update_in(
        ["containers"],
        &[
          %{
            "Service" => "pgadmin",
            "State" => "running",
            "Health" => "",
            "Image" => "dpage/pgadmin4"
          }
          | &1
        ]
      )
      |> update_in(
        ["project", "cartridges"],
        &[
          %{
            "name" => "db_admin",
            "installed" => true,
            "base" => false,
            "state" => %{"admin" => ["pgadmin"]},
            "compose" => [%{"service" => "pgadmin", "listens" => 5050, "published" => [5050]}]
          }
          | &1
        ]
      )

    page = Record.page(status, @catalog, %{"http://localhost:5050/" => {"302", "good"}})
    pg = Enum.find(page.cartridges, &(&1.c["name"] == "db_admin"))

    assert [
             %{
               label: "pgadmin",
               path: "/",
               kind: "route",
               port: 5050,
               href: "http://localhost:5050/",
               read: {"302", "good"}
             }
           ] =
             pg.addresses

    assert "http://localhost:5050/" in Record.hrefs(page)

    # Its container stopped: the door is shut by that, and not called.
    stopped =
      update_in(status, ["containers"], fn cs ->
        for c <- cs, do: if(c["Service"] == "pgadmin", do: Map.put(c, "State", "exited"), else: c)
      end)

    assert [%{why: "the pgadmin container is exited", href: nil}] =
             Enum.find(Record.page(stopped, @catalog).cartridges, &(&1.c["name"] == "db_admin")).addresses

    # Not published — the status says no port — it is the service's port, read off docker compose ps.
    unpublished = put_in(status, ["ports", "published"], %{})

    assert [%{label: "pgadmin", path: ":5050", kind: "inside", read: {"running", "good"}}] =
             Enum.find(
               Record.page(unpublished, @catalog).cartridges,
               &(&1.c["name"] == "db_admin")
             ).addresses
  end

  test "with nothing up every route is shut by that, and nothing is called" do
    page = Record.page(Map.put(@status, "deployment", nil), @catalog)
    assert Enum.all?(page.cartridges, fn row -> Enum.all?(row.addresses, &(&1.why != nil)) end)
    assert Record.hrefs(page) == []
  end

  @tag :tmp_dir
  test "a page on disk is a door of its own: green, read off its build, never called", %{
    tmp_dir: ws
  } do
    System.put_env("REPORTS_PUBLIC_PORT", "4101")
    on_exit(fn -> System.delete_env("REPORTS_PUBLIC_PORT") end)

    with_exdoc =
      @status
      |> Map.put("workspace", ws)
      |> update_in(["project", "cartridges"], fn cs ->
        Enum.map(cs, &if(&1["name"] == "exdoc", do: Map.put(&1, "installed", true), else: &1))
      end)

    docs = fn status ->
      Enum.find(Record.page(status, @catalog).cartridges, &(&1.c["name"] == "exdoc")).addresses
    end

    # Nothing built: shut, with the reason, and not for the app — with
    # the command that would write it, which the cartridge names.
    assert [
             %{
               kind: "output",
               path: "doc/",
               href: nil,
               why: "nothing built in doc/ yet",
               build: "docs"
             }
           ] = docs.(with_exdoc)

    File.mkdir_p!(Path.join(ws, "doc"))
    File.write!(Path.join(ws, "doc/index.html"), "")

    # Built: open on the pages' own port, its reading when it was built —
    # with the app down as much as up, and no knock calls it.
    for status <- [with_exdoc, Map.put(with_exdoc, "deployment", nil)] do
      assert [%{href: "http://localhost:4101/docs/", why: nil, read: {stamp, ""}, build: nil}] =
               docs.(status)

      # The whole stamp and nothing else: which project wrote it, and on
      # whose clock — the offset the machine read it in. That there is
      # one is what says it was built.
      assert stamp =~ ~r/^\d{4}-\d{2}-\d{2} \d{2}:\d{2} [+-]\d{4}$/
    end

    refute "http://localhost:4101/docs/" in Record.hrefs(Record.page(with_exdoc, @catalog))

    # The bell rings for it with the app down: the knock reads it again.
    down = Record.page(Map.put(with_exdoc, "deployment", nil), @catalog)
    assert Record.knockable?(false, Enum.flat_map(down.cartridges, & &1.addresses))
    refute Record.knockable?(false, [%{kind: "route"}])
    assert Record.knockable?(true, [])

    # Not inserted, it is offered shut, green all the same.
    assert %{addresses: [%{kind: "output", path: "doc/", why: "not inserted"}]} =
             Record.offered(Enum.find(@catalog, &(&1["name"] == "exdoc")))
  end

  test "a door behind an option's value is shut with the flag that opens it" do
    ash = %{
      "name" => "ash",
      "installed" => true,
      "base" => false,
      "state" => %{"api" => ["graphql"], "auth" => ["api_key"]}
    }

    status = update_in(@status, ["project", "cartridges"], &[ash | &1])

    catalog = [
      %{
        "name" => "ash",
        "console" => %{
          "doors" => [
            %{
              "label" => "graphiql",
              "path" => "/gql/playground",
              "when" => %{"option" => "api", "value" => "graphql"}
            },
            %{
              "label" => "swagger",
              "path" => "/api/json/swaggerui",
              "when" => %{"option" => "api", "value" => "json_api"}
            },
            %{
              "label" => "sign in",
              "path" => "/sign-in",
              "when" => %{"option" => "auth", "value" => ~w(password magic_link otp totp)}
            }
          ]
        }
      }
      | @catalog
    ]

    row = Enum.find(Record.page(status, catalog, %{}).cartridges, &(&1.c["name"] == "ash"))

    assert [
             %{label: "graphiql", why: nil, href: "http://localhost:4001/gql/playground"},
             %{label: "swagger", why: "only with --api json_api", href: nil},
             %{label: "sign in", why: "only with --auth password, magic_link, otp, …"}
           ] = row.addresses
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
