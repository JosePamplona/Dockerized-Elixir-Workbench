defmodule WorkbenchIgniter.Features.EctoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp no_ecto_project,
    do: WorkbenchIgniter.TestProject.new(~w(--no-ecto), %{".env" => "PORT=\"4000\"\n"})

  test "a --no-ecto project has no Ecto, a default one has" do
    assert {false, _} = WorkbenchIgniter.Features.Ecto.installed?(no_ecto_project())
    assert {true, _} = WorkbenchIgniter.Features.Ecto.installed?(phx_test_project())
  end

  test "puts in what phx.new generates for Ecto with Postgres, and the database URL" do
    igniter = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", [])

    igniter
    |> assert_creates("lib/test/repo.ex", fn content ->
      assert content =~ "adapter: Ecto.Adapters.Postgres"
    end)
    |> assert_creates("test/support/data_case.ex")
    |> assert_creates("priv/repo/seeds.exs")
    # What phx.gen.release writes with Ecto in, at birth: the Release
    # module and bin/migrate, the one the pod compose runs.
    |> assert_creates("lib/test/release.ex", fn content ->
      assert content =~ "defmodule Test.Release do"
    end)
    |> assert_creates("rel/overlays/bin/migrate", fn content ->
      assert content =~ "exec ./test eval Test.Release.migrate"
    end)
    |> assert_creates("rel/overlays/bin/migrate.bat")
    |> assert_has_patch("mix.exs", """
    + | {:ecto_sql, "~> 
    """)
    |> assert_has_patch("mix.exs", """
    + | {:postgrex, ">= 0.0.0"}
    """)
    |> assert_has_patch("lib/test/application.ex", """
    + | Test.Repo,
    """)
    |> assert_has_patch("config/config.exs", """
    + | ecto_repos: [Test.Repo],
    """)

    assert igniter.issues == []

    # The scripts run the release: executable once written.
    assert {"workbench.executable", ["rel/overlays/bin/migrate", "rel/overlays/bin/migrate.bat"]} in igniter.tasks

    files = apply_igniter!(igniter).assigns[:test_files]
    assert files["config/runtime.exs"] =~ ~s|System.get_env("DATABASE_URL")|
    assert files[".env"] =~ ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|
    assert files[".env.sample"] =~ "DATABASE_URL="
  end

  test "reports both of its options as the project carries them" do
    with_id =
      no_ecto_project()
      |> Igniter.compose_task("workbench.install.ecto", ~w(--database mysql --binary-id))
      |> apply_igniter!()

    assert {%{database: "mysql", binary_id: true}, _} =
             WorkbenchIgniter.Features.Ecto.state(with_id)

    plain =
      no_ecto_project()
      |> Igniter.compose_task("workbench.install.ecto", [])
      |> apply_igniter!()

    assert {%{database: "postgres", binary_id: false}, _} =
             WorkbenchIgniter.Features.Ecto.state(plain)
  end

  # Every option, measured with the one rod there is: the project
  # phx.new makes with that same flag. `add ecto --database mysql
  # --binary-id` onto a project without Ecto is the project born with
  # `--database mysql --binary-id` — whole, file by file, not the three
  # strings someone thought of looking for.
  describe "every option is phx.new's own flag" do
    alias WorkbenchIgniter.Grown

    @databases ~w(postgres mysql mssql sqlite3)
    @others ~w(mailer gettext esbuild tailwind html live dashboard)

    for database <- @databases, binary_id <- [false, true], shape <- [:whole, :bare] do
      argv = ["--database", database] ++ if(binary_id, do: ["--binary-id"], else: [])

      test "#{Enum.join(argv, " ")}, onto a #{shape} project" do
        argv = unquote(argv)
        others = if unquote(shape) == :whole, do: @others, else: []

        assert {:ok, grown} = Grown.add(Grown.born(others), "ecto", argv)
        assert Grown.differences(Grown.born(others ++ ["ecto"], argv), grown) == []
      end
    end

    test "no option at all is phx.new's default: Postgres, integer ids" do
      assert {:ok, grown} = Grown.add(Grown.born(@others), "ecto")
      assert Grown.differences(Grown.born(@others ++ ["ecto"]), grown) == []

      assert {:ok, said} =
               Grown.add(Grown.born(@others), "ecto", ~w(--database postgres --no-binary-id))

      assert Grown.differences(grown, said) == []
    end
  end

  # And what the option means to the workbench, which phx.new knows
  # nothing of: what the project reports, the service it asks the
  # workspace for, what that service is, and where the release finds it.
  describe "every --database, to the workbench" do
    alias WorkbenchIgniter.Compose
    alias WorkbenchIgniter.Features
    alias WorkbenchIgniter.Grown

    @expected [
      {"postgres",
       %{
         asks: ["postgres"],
         env: ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|,
         image: "postgres",
         listens: 5432,
         shell: "psql",
         dependency: ":postgrex"
       }},
      {"mysql",
       %{
         asks: ["mysql"],
         env: ~s|DATABASE_URL="ecto://root:@localhost:3306/test_prod"|,
         image: "mysql",
         listens: 3306,
         shell: "mysql",
         dependency: ":myxql"
       }},
      {"mssql",
       %{
         asks: ["mssql"],
         env: ~s|DATABASE_URL="ecto://sa:some!Password@localhost:1433/test_prod"|,
         image: "mcr.microsoft.com/mssql/server",
         listens: 1433,
         shell: "sqlcmd",
         dependency: ":tds"
       }}
    ]

    for {database, expected} <- @expected do
      test "--database #{database}: reported, asked for, defined and found" do
        expected = unquote(Macro.escape(expected))
        database = unquote(database)
        {:ok, grown} = Grown.add(Grown.born([]), "ecto", ["--database", database])
        files = grown.assigns[:test_files]

        # The project says which it has, off its own dependency.
        assert {%{database: ^database, binary_id: false}, _} = Features.Ecto.state(grown)
        assert files["mix.exs"] =~ expected.dependency

        # The workspace is asked for that server, and no other.
        assert {asks, _} = Features.services(grown)
        assert asks == expected.asks

        # What the server is, in a compose file: its image, its port, its own client first.
        assert [%{service: "database"} = service | _] =
                 Enum.filter(Compose.brought(Features.Ecto, asks), &(&1.service == "database"))

        assert service.image == expected.image
        assert service.listens == expected.listens
        assert [%{label: label}, %{label: "bash"}] = service.shells
        assert label == expected.shell

        # Where the release finds it: the same credentials the compose gives the server.
        assert files[".env"] =~ expected.env
        assert files[".env.sample"] =~ expected.env

        # And the dev compose has it, the app waiting for it to be healthy.
        {:ok, plan} =
          Compose.plan_from_argv(
            ~w(--deploy dev --app-name test --image test:local --dockerfile Dockerfile.local
               --uid 1000 --gid 1000 --app-port 4000),
            fn -> asks end
          )

        compose = Compose.render(plan)
        assert compose =~ "  database:\n    image: #{expected.image}:"
        assert compose =~ "    depends_on:\n      database:\n        condition: service_healthy"
      end
    end

    test "--database sqlite3: no server — a path, and a volume for the file in a release" do
      {:ok, grown} = Grown.add(Grown.born([]), "ecto", ~w(--database sqlite3))
      files = grown.assigns[:test_files]

      assert {%{database: "sqlite3"}, _} = Features.Ecto.state(grown)
      assert {["sqlite"], _} = Features.services(grown)
      assert files[".env"] =~ ~s|DATABASE_PATH="/app/data/test_prod.db"|
      refute files[".env"] =~ "DATABASE_URL"

      # Nothing runs beside the app in dev; a release has the migration and the volume's one-shot.
      brought = Compose.brought(Features.Ecto, ["sqlite"])
      assert Enum.map(brought, & &1.service) == ~w(migrate data_init)
      assert Enum.all?(brought, &(&1.deploys == ["prod"]))
    end

    test "--binary-id changes nothing of that: it is the project's, not the workspace's" do
      {:ok, plain} = Grown.add(Grown.born([]), "ecto", ~w(--database mysql))
      {:ok, with_id} = Grown.add(Grown.born([]), "ecto", ~w(--database mysql --binary-id))

      assert {%{database: "mysql", binary_id: true}, _} = Features.Ecto.state(with_id)
      assert Features.services(with_id) |> elem(0) == Features.services(plain) |> elem(0)
      assert with_id.assigns[:test_files][".env"] == plain.assigns[:test_files][".env"]
    end
  end

  test "rejects a database phx.new does not know" do
    igniter =
      no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", ~w(--database oracle))

    assert Enum.any?(igniter.issues, &(&1 =~ "Unknown --database"))
  end

  test "is a no-op with a notice when Ecto is in" do
    phx_test_project() |> Igniter.compose_task("workbench.install.ecto", []) |> assert_unchanged()
  end
end
