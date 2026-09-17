defmodule WorkbenchIgniter.Features.MonitoringTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Monitoring

  defp install(project \\ phx_test_project()),
    do: Igniter.compose_task(project, "workbench.install.monitoring", [])

  describe "mix workbench.install.monitoring" do
    test "adds prom_ex and the PromEx module, with the plugins the project's shape calls for" do
      install()
      |> assert_has_patch("mix.exs", """
      + | {:prom_ex, "~> 1.12"},
      """)
      |> assert_creates("lib/test/prom_ex.ex", fn content ->
        assert content =~ "defmodule Test.PromEx do"
        assert content =~ "use PromEx, otp_app: :test"
        assert content =~ "Plugins.Application,"
        assert content =~ "Plugins.Beam,"
        assert content =~ "{Plugins.Phoenix, router: TestWeb.Router, endpoint: TestWeb.Endpoint},"
        assert content =~ "{Plugins.Ecto, repos: [Test.Repo]},"
        assert content =~ "Plugins.PhoenixLiveView\n"
        assert content =~ ~s|datasource_id: "prometheus"|
        assert content =~ ~s|{:prom_ex, "ecto.json"},|
        assert content =~ ~s|{:prom_ex, "phoenix_live_view.json"}\n|
        assert content =~ "# Plugins.Oban,"
      end)
    end

    test "leaves Ecto and LiveView out of a project without them" do
      project =
        phx_test_project()
        |> Igniter.Project.Deps.remove_dep(:phoenix_live_view)
        |> Igniter.rm("lib/test/repo.ex")
        |> apply_igniter!()

      install(project)
      |> assert_creates("lib/test/prom_ex.ex", fn content ->
        assert content =~
                 "{Plugins.Phoenix, router: TestWeb.Router, endpoint: TestWeb.Endpoint}\n"

        refute content =~ "Plugins.Ecto"
        refute content =~ "Plugins.PhoenixLiveView"
        refute content =~ "ecto.json"
        refute content =~ "phoenix_live_view.json"
      end)
    end

    test "configures PromEx: its own settings, off in test, Grafana at runtime" do
      install()
      |> assert_has_patch("config/config.exs", """
      + | config :test, Test.PromEx,
      + |   disabled: false,
      + |   manual_metrics_start_delay: :no_delay,
      + |   drop_metrics_groups: [],
      + |   metrics_server: :disabled
      + |
        | import_config "\#{config_env()}.exs"
      """)
      |> assert_has_patch("config/test.exs", """
      + | config :test, Test.PromEx, disabled: true
      """)
      |> assert_has_patch("config/runtime.exs", """
      + | config :test, Test.PromEx,
      + |   grafana: [
      + |     host: System.get_env("GRAFANA_HOST", "http://localhost:3000"),
      + |     username: "admin",
      + |     password: "admin",
      + |     upload_dashboards_on_start: true
      + |   ]
      """)
    end

    test "starts PromEx first, and serves the metrics before the telemetry" do
      install()
      |> assert_has_patch("lib/test/application.ex", """
      + | Test.PromEx,
        | TestWeb.Telemetry,
      """)
      |> assert_has_patch("lib/test_web/endpoint.ex", """
      + | plug PromEx.Plug, prom_ex_module: Test.PromEx
        | plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])
      """)
    end

    test "writes the two files the containers open with" do
      install()
      |> assert_creates("monitoring/prometheus.yml", fn content ->
        assert content =~ "job_name: app"
        assert content =~ "- /etc/prometheus/targets.yml"
      end)
      |> assert_creates("monitoring/grafana/datasource.yml", fn content ->
        assert content =~ "name: prometheus"
        assert content =~ "url: ${PROMETHEUS_URL}"
      end)
    end

    test "the PromEx module is the mark" do
      assert {false, _} = Monitoring.installed?(phx_test_project())
      assert {true, _} = install() |> apply_igniter!() |> Monitoring.installed?()
    end

    test "is a no-op when the module is there" do
      install() |> apply_igniter!() |> install() |> assert_unchanged()
    end
  end

  describe "the manifest" do
    test "asks the workspace for Prometheus and Grafana, whatever its state" do
      assert Monitoring.services(%{}) == ["prometheus", "grafana"]
      assert Monitoring.requires() == []
    end

    test "opens the metrics as a door" do
      assert Monitoring.console() == [doors: [{"metrics", "/metrics"}]]
    end
  end
end
