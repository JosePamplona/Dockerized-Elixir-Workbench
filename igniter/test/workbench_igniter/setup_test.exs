defmodule Mix.Tasks.Workbench.SetupTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp setup_project(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.setup", argv)
  end

  describe "base configuration" do
    test "sets the initial version in mix.exs" do
      setup_project(["--version", "0.0.0"])
      |> assert_has_patch("mix.exs", """
      - | version: "0.1.0",
      + | version: "0.0.0",
      """)
    end

    test "enables ANSI colors and usec generators in config.exs" do
      setup_project()
      |> assert_has_patch("config/config.exs", """
      + |config :elixir, ansi_enabled: true
      """)
      |> assert_has_patch("config/config.exs", """
      - |  generators: [timestamp_type: :utc_datetime]
      + |  generators: [timestamp_type: :utc_datetime_usec]
      """)
    end

    test "configures migration key and timestamp types when given" do
      setup_project(["--id-type", "uuid", "--timestamps", "naive_datetime_usec"])
      |> assert_has_patch("config/config.exs", """
      + |config :test, Test.Repo,
      + |  migration_primary_key: [type: :uuid],
      + |  migration_timestamps: [type: :naive_datetime_usec]
      """)
    end

    test "binds the dev endpoint to all interfaces and enables test dev_routes" do
      setup_project()
      |> assert_has_patch("config/dev.exs", """
      - |  http: [ip: {127, 0, 0, 1}],
      + |  http: [ip: {0, 0, 0, 0}],
      """)
      |> assert_has_patch("config/test.exs", """
      + |config :test, dev_routes: true
      """)
    end

    test "prepends secrets and elixir_ls entries to .gitignore" do
      setup_project()
      |> assert_has_patch(".gitignore", """
      + |# Secrets required to configure the application.
      + |.env
      """)
    end
  end

  describe "text files" do
    test "creates the project text files" do
      igniter = setup_project(["--project-name", "Lorem Ipsum"])

      igniter
      |> assert_creates(".env")
      |> assert_creates(".env.sample")
      |> assert_creates("CHANGELOG.md")
      |> assert_creates(".tool-versions")
    end

    test "renders the README from the project data" do
      igniter =
        setup_project(["--project-name", "Lorem Ipsum", "--health"])
        |> apply_igniter!()

      readme = igniter.assigns[:test_files]["README.md"]

      assert readme =~ "# Lorem Ipsum"
      assert readme =~ "offers a REST API"
      assert readme =~ "Healthcheck endpoint"
      refute readme =~ "GraphQL endpoint"
      refute readme =~ "### Auth0"
      # The README points to .env.sample instead of embedding the .env
      # content — the generated secret must never land in the README.
      assert readme =~ "cp .env.sample .env"
      refute readme =~ "SECRET_KEY_BASE=\""
    end

    test "the .env.sample carries no secret while the .env does" do
      igniter = setup_project() |> apply_igniter!()

      env = igniter.assigns[:test_files][".env"]
      sample = igniter.assigns[:test_files][".env.sample"]

      assert [_, secret] = Regex.run(~r/SECRET_KEY_BASE="([^"]*)"/, env)
      assert String.length(secret) == 64
      assert sample =~ ~s|SECRET_KEY_BASE=""|
      assert sample =~ ~s|PHX_HOST="localhost"|
    end

    test "renders stack versions into .tool-versions" do
      igniter =
        setup_project([
          "--elixir-version",
          "1.19.5",
          "--erlang-version",
          "27.3",
          "--debian-version",
          "trixie-20260112-slim"
        ])
        |> apply_igniter!()

      tool_versions = igniter.assigns[:test_files][".tool-versions"]

      assert tool_versions == "elixir 1.19.5-otp-27\nerlang 27.3\n"
    end

    test "--stripe implies --auth0 in the generated .env" do
      igniter = setup_project(["--stripe"]) |> apply_igniter!()

      env = igniter.assigns[:test_files][".env"]

      assert env =~ "STRIPE_SECRET"
      assert env =~ "AUTH0_DOMAIN"
      refute env =~ "AI_ASSISTANT_API_URL"
    end

    test "an existing .env is never overwritten" do
      igniter =
        phx_test_project(files: %{".env" => "EXISTING=true\n"})
        |> Igniter.compose_task("workbench.setup", [])
        |> apply_igniter!()

      assert igniter.assigns[:test_files][".env"] == "EXISTING=true\n"
    end
  end

  describe "feature composition" do
    test "--coveralls --exdoc integrate the TESTING.md report" do
      igniter = setup_project(["--coveralls", "--exdoc"]) |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # Both .gitignore updates (setup's and coveralls') land in one patch
      # set; the doc/cover outputs are already in phx.new's stock entries.
      assert files[".gitignore"] =~ ".env"
      assert files[".gitignore"] =~ "/TESTING.md"
      assert files["TESTING.md"] =~ "mix cover"
      assert files["mix.exs"] =~ ~s|{"TESTING.md", [title: "Test Suite Report"]}|
      refute files["mix.exs"] =~ "COVERAGE.md"
    end

    test "--coverage-theme is forwarded to the coveralls installer" do
      igniter =
        setup_project(["--coveralls", "--coverage-theme", "custom"]) |> apply_igniter!()

      assert igniter.assigns[:test_files]["assets/cover/template/coverage.html.eex"] =~
               "Test Coverage Overview"
    end

    test "--version reaches the exdoc placeholders" do
      igniter = setup_project(["--exdoc", "--version", "2.0.0"]) |> apply_igniter!()

      assert igniter.assigns[:test_files]["doc/index.html"] =~ "v2.0.0 — Documentation"
    end

    test "--enhance composes the trivial installers group" do
      setup_project(["--enhance"])
      |> assert_has_patch("mix.exs", """
      + | {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      """)
      |> assert_has_patch("mix.exs", """
      + | {:ecto_psql_extras, "~> 0.8", only: :dev},
      """)
      |> assert_has_patch("mix.exs", """
      + | extra_applications: [:logger, :runtime_tools, :os_mon]
      """)
    end

    test "--health composes the healthcheck installer" do
      setup_project(["--health"])
      |> assert_creates("lib/test_web/controllers/healthcheck_controller.ex")
    end

    test "notifies about installers not yet ported" do
      setup_project(["--stripe"])
      |> assert_has_notice(&(&1 =~ "workbench.install.stripe"))
    end
  end
end
