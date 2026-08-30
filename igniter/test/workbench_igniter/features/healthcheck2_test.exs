defmodule WorkbenchIgniter.Features.Healthcheck2Test do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  # Every test runs against an in-memory Phoenix project (app: :test,
  # modules Test / TestWeb) — no files are written to disk.

  defp install(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.healthcheck2", argv)
  end

  defp files(igniter), do: igniter.assigns[:test_files]

  describe "the plug" do
    test "is created at its conventional path, checking the project repo" do
      install()
      |> assert_creates("lib/test_web/plugs/health.ex", fn content ->
        assert content =~ "defmodule TestWeb.Plugs.Health do"
        assert content =~ "@behaviour Plug"
        assert content =~ ~s|Keyword.get(opts, :path, "/health")|
        assert content =~ "Keyword.get(opts, :repo, Test.Repo)"
        assert content =~ ~s|repo.query("SELECT 1", [], timeout: @timeout)|
      end)
    end

    test "comes with its test" do
      install()
      |> assert_creates("test/test_web/plugs/health_test.exs", fn content ->
        assert content =~ "defmodule TestWeb.Plugs.HealthTest do"
        assert content =~ "use TestWeb.ConnCase, async: true"
        assert content =~ ~s|get(conn, "/health/live")|
        assert content =~ ~s|get(conn, "/health/ready")|
        assert content =~ "assert Health.ready?(Test.Repo)"
      end)
    end

    test "files stay at their paths once the patch set is applied" do
      files = install() |> apply_igniter!() |> files() |> Map.keys()

      assert "lib/test_web/plugs/health.ex" in files
      assert "test/test_web/plugs/health_test.exs" in files
    end
  end

  describe "the endpoint" do
    test "mounts the plug" do
      install()
      |> assert_has_patch(
        "lib/test_web/endpoint.ex",
        """
        + | # Workbench healthcheck: answer the probes before anything else runs.
        + | plug(TestWeb.Plugs.Health)
        """
      )
    end

    test "mounts it before every other plug" do
      endpoint = install() |> apply_igniter!() |> files() |> Map.get("lib/test_web/endpoint.ex")

      {health, _} = :binary.match(endpoint, "TestWeb.Plugs.Health")
      {static, _} = :binary.match(endpoint, "Plug.Static")
      {router, _} = :binary.match(endpoint, "TestWeb.Router")

      assert health < static
      assert health < router
    end
  end

  describe "--path" do
    test "changes the prefix of both probes" do
      igniter = install(["--path", "/status/"]) |> apply_igniter!()

      assert files(igniter)["lib/test_web/plugs/health.ex"] =~
               ~s|Keyword.get(opts, :path, "/status")|

      assert files(igniter)["test/test_web/plugs/health_test.exs"] =~
               ~s|get(conn, "/status/live")|
    end
  end

  describe "without a repo" do
    test "readiness answers like liveness" do
      igniter =
        phx_test_project()
        |> Igniter.rm("lib/test/repo.ex")
        |> Igniter.compose_task("workbench.install.healthcheck2", [])
        |> apply_igniter!()

      plug = files(igniter)["lib/test_web/plugs/health.ex"]
      test = files(igniter)["test/test_web/plugs/health_test.exs"]

      assert plug =~ "Keyword.get(opts, :repo, nil)"
      refute test =~ "DownRepo"
    end
  end

  test "running it twice changes nothing" do
    install()
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.healthcheck2", [])
    |> assert_unchanged()
    |> assert_has_notice(&(&1 =~ "already installed"))
  end
end
