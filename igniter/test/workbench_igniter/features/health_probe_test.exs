defmodule WorkbenchIgniter.Features.HealthProbeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  # Every test runs against an in-memory Phoenix project (app: :test,
  # modules Test / TestWeb) — no files are written to disk.

  defp install(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.health_probe", argv)
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
        + | # Workbench health probe: answer the probes before anything else runs.
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
        |> Igniter.compose_task("workbench.install.health_probe", [])
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
      def query("SELECT 1", [], timeout: 500), do: {:ok, %{rows: [[1]]}}
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

    # A pool with no connection to give: the caller waits in its queue.
    defmodule HangingRepo do
      @moduledoc false
      def query(_sql, _params, _opts), do: Process.sleep(:infinity)
    end

    # The plug as the installer wrote it, compiled under a name of its
    # own so the tests can run side by side.
    defp plug(project, argv) do
      {:ok, grown} = Grown.add(project, "health_probe", argv)
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
        assert {%{path: ^prefix}, _} = WorkbenchIgniter.Features.HealthProbe.state(grown)
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

      # Bounded as a whole: a check that never returns is a 503 at the
      # timeout, not a probe the platform abandons.
      {micros, conn} = :timer.tc(fn -> call(plug, :get, "/health/ready", repo: HangingRepo) end)
      assert {conn.status, conn.halted} == {503, true}
      assert micros in 450_000..900_000

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
        {:ok, grown} = Grown.add(Grown.born(shape), "health_probe", argv)
        test = grown.assigns[:test_files]["test/test_web/plugs/health_test.exs"]
        assert {:ok, _} = Code.string_to_quoted(test), "#{inspect(shape)} #{inspect(argv)}"
      end
    end

    test "a second insert, with another prefix, leaves the first: the mark is the plug" do
      {:ok, grown} = Grown.add(Grown.born(~w(ecto)), "health_probe", ~w(--path /status))

      again = Igniter.compose_task(grown, "workbench.install.health_probe", ~w(--path /other))
      assert_unchanged(again)
      assert_has_notice(again, &(&1 =~ "already installed"))
      assert {%{path: "/status"}, _} = WorkbenchIgniter.Features.HealthProbe.state(again)
    end
  end

  # phx.new turns force_ssl on in prod.exs (Phoenix 1.8.2), and Phoenix
  # plugs Plug.SSL inside `use Phoenix.Endpoint`, before every plug of
  # the project's: mounted first is not enough. The rod is Plug.SSL
  # itself, built from the prod.exs the cartridge leaves, and a probe as
  # a kubelet or a balancer sends it: plain HTTP to the pod's address.
  describe "force_ssl" do
    alias WorkbenchIgniter.Grown

    defp prod_exs(igniter), do: igniter.assigns[:test_files]["config/prod.exs"]

    defp with_prod_exs(igniter, fun),
      do: update_in(igniter.assigns[:test_files]["config/prod.exs"], fun)

    defp force_ssl(prod_exs) do
      config = Config.Reader.eval!("config/prod.exs", prod_exs, env: :prod)
      config[:test][TestWeb.Endpoint][:force_ssl]
    end

    defp redirected?(force_ssl, url) do
      conn = Plug.Test.conn(:get, url)
      Plug.SSL.call(conn, Plug.SSL.init(Keyword.put(force_ssl, :log, false))).status == 301
    end

    # Without assets prod.exs has one `config` for the endpoint; with
    # them, two — `cache_static_manifest` first, `force_ssl` second.
    @shapes [~w(ecto), ~w(ecto esbuild tailwind html)]

    test "phx.new's prod.exs redirects a plain-HTTP probe; the cartridge's does not" do
      born = Grown.born(~w(ecto))
      assert born |> prod_exs() |> force_ssl() |> redirected?("http://10.0.0.7/health/live")

      for shape <- @shapes,
          {argv, prefix} <- [{[], "/health"}, {~w(--path /status), "/status"}, {~w(--path /), ""}] do
        {:ok, grown} = Grown.add(Grown.born(shape), "health_probe", argv)
        force_ssl = grown |> prod_exs() |> force_ssl()

        refute redirected?(force_ssl, "http://10.0.0.7#{prefix}/live")
        refute redirected?(force_ssl, "http://10.0.0.7#{prefix}/ready")
        # Only the probes: the rest of the site still goes to HTTPS, a
        # path is matched whole, and localhost is still spared.
        assert redirected?(force_ssl, "http://10.0.0.7/")
        assert redirected?(force_ssl, "http://10.0.0.7#{prefix}/live/x")
        refute redirected?(force_ssl, "http://localhost/")
      end
    end

    test "the probes go into the block that holds force_ssl, with or without assets" do
      for shape <- @shapes do
        born = Grown.born(shape)
        blocks = length(Regex.scan(~r/^config :test, TestWeb\.Endpoint/m, prod_exs(born)))
        assert blocks == if("esbuild" in shape, do: 2, else: 1)

        {:ok, grown} = Grown.add(born, "health_probe", [])
        prod = prod_exs(grown)

        # One force_ssl, the phx.new one, and the paths inside its exclude.
        assert length(Regex.scan(~r/force_ssl:/, prod)) == 1

        assert prod =~
                 ~r/force_ssl: \[\n\s+rewrite_on: \[:x_forwarded_proto\],\n\s+exclude: \[\n\s+# paths: \["\/health"\],\n\s+hosts: \["localhost", "127\.0\.0\.1"\],\n\s+paths: \["\/health\/live", "\/health\/ready"\]\n\s+\]/

        if blocks == 2 do
          assert prod =~
                   ~s|config :test, TestWeb.Endpoint, cache_static_manifest: "priv/static/cache_manifest.json"\n|
        end
      end
    end

    test "phx.new's commented hint is left where it is" do
      {:ok, grown} = Grown.add(Grown.born(~w(ecto)), "health_probe", [])
      assert prod_exs(grown) =~ ~s|# paths: ["/health"],|
    end

    test "an exclude list the project already has keeps its entries" do
      born =
        with_prod_exs(
          Grown.born(~w(ecto)),
          &String.replace(&1, ~s|# paths: ["/health"],|, ~s|paths: ["/metrics"],|)
        )

      {:ok, grown} = Grown.add(born, "health_probe", [])
      exclude = grown |> prod_exs() |> force_ssl() |> Keyword.fetch!(:exclude)

      assert exclude[:paths] == ["/metrics", "/health/live", "/health/ready"]
      assert exclude[:hosts] == ["localhost", "127.0.0.1"]
    end

    test "without an exclude list, Plug.SSL's default hosts are written beside the probes" do
      born =
        with_prod_exs(
          Grown.born(~w(ecto)),
          &Regex.replace(~r/,\n    exclude: \[.*?\n    \]/s, &1, "")
        )

      assert force_ssl(prod_exs(born))[:rewrite_on] == [:x_forwarded_proto]
      refute force_ssl(prod_exs(born))[:exclude]

      {:ok, grown} = Grown.add(born, "health_probe", [])
      force_ssl = grown |> prod_exs() |> force_ssl()

      assert force_ssl[:exclude][:paths] == ["/health/live", "/health/ready"]
      assert force_ssl[:exclude][:hosts] == ["localhost", "127.0.0.1"]
      refute redirected?(force_ssl, "http://localhost/")
    end

    test "without force_ssl, prod.exs is left as it is" do
      born =
        with_prod_exs(
          Grown.born(~w(ecto)),
          &Regex.replace(
            ~r/config :test, TestWeb\.Endpoint,\n  force_ssl: \[.*?\n  \]\n/s,
            &1,
            ""
          )
        )

      refute prod_exs(born) =~ "force_ssl:"
      {:ok, grown} = Grown.add(born, "health_probe", [])
      assert prod_exs(grown) == prod_exs(born)
    end
  end

  test "running it twice changes nothing" do
    install()
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.health_probe", [])
    |> assert_unchanged()
    |> assert_has_notice(&(&1 =~ "already installed"))
  end
end
