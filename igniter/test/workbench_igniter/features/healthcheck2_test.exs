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
        + | plug TestWeb.Plugs.Health
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

  # No phx.new to measure this one against, so the rod is what the
  # cartridge is for: the plug it writes is compiled and called. An
  # option is tested by what the plug then answers, not by the strings
  # it left in a file.
  describe "the plug it writes, run" do
    alias WorkbenchIgniter.Grown

    defmodule UpRepo do
      @moduledoc false
      def query("SELECT 1", [], timeout: 1_000), do: {:ok, %{rows: [[1]]}}
    end

    defmodule DownRepo do
      @moduledoc false
      def query(_sql, _params, _opts), do: {:error, :down}
    end

    defmodule CrashingRepo do
      @moduledoc false
      def query(_sql, _params, _opts), do: raise("pool exhausted")
    end

    defmodule GoneRepo do
      @moduledoc false
      def query(_sql, _params, _opts), do: exit(:noproc)
    end

    # The plug as the installer wrote it, compiled under a name of its
    # own so the tests can run side by side.
    defp plug(project, argv) do
      {:ok, grown} = Grown.add(project, "healthcheck2", argv)
      source = grown.assigns[:test_files]["lib/test_web/plugs/health.ex"]
      name = "TestWeb.Plugs.Health#{System.unique_integer([:positive])}"

      [{module, _}] =
        source |> String.replace("TestWeb.Plugs.Health", name) |> Code.compile_string()

      {module, grown}
    end

    defp call(module, method, path, opts \\ []),
      do: method |> Plug.Test.conn(path) |> module.call(module.init(opts))

    # Every way of spelling a prefix, and the one it means.
    @spellings [
      {[], "/health"},
      {~w(--path /health), "/health"},
      {~w(--path /status/), "/status"},
      {~w(--path status), "/status"},
      {~w(--path /api/v1/healthz), "/api/v1/healthz"},
      {~w(--path //up//), "/up"},
      # The root: the probes are /live and /ready.
      {~w(--path /), ""}
    ]

    for {argv, prefix} <- @spellings do
      test "#{inspect(Enum.join(argv, " "))}: the probes answer at #{prefix}/live and #{prefix}/ready, and nowhere else" do
        {argv, prefix} = {unquote(argv), unquote(prefix)}
        {plug, grown} = plug(Grown.born(~w(ecto)), argv)

        live = call(plug, :get, prefix <> "/live")
        assert {live.status, live.resp_body, live.halted} == {200, "ok", true}
        assert Plug.Conn.get_resp_header(live, "cache-control") == ["no-store"]

        ready = call(plug, :get, prefix <> "/ready", repo: UpRepo)
        assert {ready.status, ready.resp_body, ready.halted} == {200, "ok", true}

        # Nothing else is a probe: another prefix, a deeper path, another verb.
        for path <- ~w(/ /live/x /other/live) ++ [prefix <> "/live/", prefix <> "/liveness"],
            path not in [prefix <> "/live", prefix <> "/ready"] do
          passed = call(plug, :get, path)
          refute passed.halted, "GET #{path} was answered as a probe"
          assert passed.state == :unset
        end

        refute call(plug, :post, prefix <> "/live").halted
        if prefix != "/health", do: refute(call(plug, :get, "/health/live").halted)

        # Whoever reads the prefix back reads the same one: the project's
        # state (the console's doors are filled from it), the plug's own
        # words, and the test the project is given.
        assert {%{path: ^prefix}, _} = WorkbenchIgniter.Features.Healthcheck2.state(grown)
        files = grown.assigns[:test_files]
        assert files["lib/test_web/plugs/health.ex"] =~ "`GET #{prefix}/live`"
        assert files["test/test_web/plugs/health_test.exs"] =~ ~s|get(conn, "#{prefix}/live")|
        assert files["test/test_web/plugs/health_test.exs"] =~ ~s|probe("#{prefix}/ready"|
        refute files["test/test_web/plugs/health_test.exs"] =~ "//"
      end
    end

    test "readiness is the repo's answer: 503 when it fails, crashes or is gone — never a raise" do
      {plug, _} = plug(Grown.born(~w(ecto)), [])

      for repo <- [DownRepo, CrashingRepo, GoneRepo] do
        conn = call(plug, :get, "/health/ready", repo: repo)
        assert {conn.status, conn.resp_body, conn.halted} == {503, "unavailable", true}
        refute plug.ready?(repo)
      end

      assert plug.ready?(UpRepo)
      # Liveness looks at nothing: the database being down does not restart the container.
      assert call(plug, :get, "/health/live", repo: DownRepo).status == 200
    end

    test "on a project with Ecto the repo checked is the project's own; without Ecto, none" do
      {with_repo, grown} = plug(Grown.born(~w(ecto)), [])
      assert with_repo.init([]).repo == Test.Repo
      assert grown.assigns[:test_files]["test/test_web/plugs/health_test.exs"] =~ "DownRepo"

      {without, grown} = plug(Grown.born([]), [])
      assert without.init([]).repo == nil
      # Nothing to check: ready like live.
      assert call(without, :get, "/health/ready").status == 200
      refute grown.assigns[:test_files]["test/test_web/plugs/health_test.exs"] =~ "DownRepo"

      assert grown.assigns[:test_files]["lib/test_web/plugs/health.ex"] =~
               ~r/has no\s+repo to check/
    end

    test "the test it gives the project is Elixir, on every shape and prefix" do
      for shape <- [[], ~w(ecto)], argv <- [[], ~w(--path /), ~w(--path /api/v1/healthz)] do
        {:ok, grown} = Grown.add(Grown.born(shape), "healthcheck2", argv)
        test = grown.assigns[:test_files]["test/test_web/plugs/health_test.exs"]
        assert {:ok, _} = Code.string_to_quoted(test), "#{inspect(shape)} #{inspect(argv)}"
      end
    end

    test "a second insert, with another prefix, leaves the first: the mark is the plug" do
      {:ok, grown} = Grown.add(Grown.born(~w(ecto)), "healthcheck2", ~w(--path /status))

      again = Igniter.compose_task(grown, "workbench.install.healthcheck2", ~w(--path /other))
      assert_unchanged(again)
      assert_has_notice(again, &(&1 =~ "already installed"))
      assert {%{path: "/status"}, _} = WorkbenchIgniter.Features.Healthcheck2.state(again)
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
