defmodule Mix.Tasks.Workbench.SetupTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp setup_project(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.setup", argv)
  end

  describe "workspace requirements" do
    test "binds the dev endpoint to all interfaces" do
      setup_project()
      |> assert_has_patch("config/dev.exs", """
      - |  http: [ip: {127, 0, 0, 1}],
      + |  http: [ip: {0, 0, 0, 0}],
      """)
    end

    test "adds the secrets entry to .gitignore" do
      setup_project()
      |> assert_has_patch(".gitignore", """
      + |# Secrets required to configure the application.
      + |.env
      """)
    end

    test "creates the env files and nothing else" do
      igniter = setup_project() |> apply_igniter!()

      env = igniter.assigns[:test_files][".env"]
      sample = igniter.assigns[:test_files][".env.sample"]

      assert [_, secret] = Regex.run(~r/SECRET_KEY_BASE="([^"]*)"/, env)
      assert String.length(secret) == 64
      assert sample =~ ~s|SECRET_KEY_BASE=""|
      assert env =~ ~s|PHX_HOST="localhost"|
      assert env =~ ~s|PORT="4000"|
      assert env =~ ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|

      refute igniter.assigns[:test_files]["CHANGELOG.md"]
      refute igniter.assigns[:test_files][".tool-versions"]
    end

    test "an existing .env is never overwritten" do
      igniter =
        phx_test_project(files: %{".env" => "EXISTING=true\n"})
        |> Igniter.compose_task("workbench.setup", [])
        |> apply_igniter!()

      assert igniter.assigns[:test_files][".env"] == "EXISTING=true\n"
    end

    test "writes the connection of the adapter the project was generated with" do
      igniter =
        WorkbenchIgniter.TestProject.new(
          ~w(--app test --module Test --database mysql --adapter bandit)
        )
        |> Igniter.compose_task("workbench.setup", [])
        |> apply_igniter!()

      assert igniter.assigns[:test_files][".env"] =~
               ~s|DATABASE_URL="ecto://root:@localhost:3306/test_prod"|

      igniter =
        WorkbenchIgniter.TestProject.new(
          ~w(--app test --module Test --database sqlite3 --adapter bandit)
        )
        |> Igniter.compose_task("workbench.setup", [])
        |> apply_igniter!()

      env = igniter.assigns[:test_files][".env"]
      assert env =~ ~s|DATABASE_PATH="/app/data/test_prod.db"|
      refute env =~ "DATABASE_URL"
    end

    test "--no-ecto drops the database entries from .env" do
      igniter = setup_project(["--no-ecto"]) |> apply_igniter!()

      env = igniter.assigns[:test_files][".env"]

      refute env =~ "DATABASE_URL"
      refute env =~ "POOL_SIZE"
      assert env =~ ~s|PORT="4000"|
    end
  end

  describe "no workbench opinions" do
    test "leaves mix.exs, config.exs and test.exs untouched" do
      igniter = setup_project()

      assert_unchanged(igniter, "mix.exs")
      assert_unchanged(igniter, "config/config.exs")
      assert_unchanged(igniter, "config/test.exs")
    end

    test "composes no feature installer" do
      igniter = setup_project(["--internal-port", "4001"]) |> apply_igniter!()

      files = igniter.assigns[:test_files]

      refute files["lib/test_web/controllers/healthcheck_controller.ex"]
      refute files["README.md"] =~ "Healthcheck endpoint"
      assert files[".env"] =~ ~s|PORT="4001"|
    end
  end
end
