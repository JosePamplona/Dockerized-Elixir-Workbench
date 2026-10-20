defmodule Mix.Tasks.Workbench.Install.ClusteringTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp install(argv \\ [], files \\ %{}) do
    phx_test_project(files: files)
    |> Igniter.compose_task("workbench.install.clustering", argv)
  end

  defp files(igniter), do: igniter.assigns[:test_files]

  describe "rel templates" do
    test "creates the four release.init files" do
      install()
      |> assert_creates("rel/vm.args.eex")
      |> assert_creates("rel/remote.vm.args.eex")
      |> assert_creates("rel/env.bat.eex")
      |> assert_creates("rel/env.sh.eex")
    end

    test "the templates match the running Elixir defaults" do
      files = install() |> apply_igniter!() |> files()

      assert files["rel/vm.args.eex"] == Mix.Tasks.Release.Init.vm_args_text(false)
      assert files["rel/remote.vm.args.eex"] == Mix.Tasks.Release.Init.vm_args_text(true)
      assert files["rel/env.bat.eex"] == Mix.Tasks.Release.Init.env_bat_text()
      # env.sh carries the distributed block on top of the default text.
      assert files["rel/env.sh.eex"] =~ Mix.Tasks.Release.Init.env_text()
    end

    test "existing rel files are kept" do
      files = %{"rel/vm.args.eex" => "## mine\n"}
      igniter = install([], files) |> apply_igniter!()

      assert igniter.assigns[:test_files]["rel/vm.args.eex"] == "## mine\n"
    end
  end

  describe "distributed mode" do
    test "env.sh exports the distribution variables" do
      env_sh = install() |> apply_igniter!() |> files() |> Map.get("rel/env.sh.eex")

      assert env_sh =~ "export RELEASE_DISTRIBUTION=name"
      assert env_sh =~ ~s|export RELEASE_NODE="$RELEASE_NAME@${RELEASE_NODE_IP:-127.0.0.1}"|
      # An externally provided node name always wins.
      assert env_sh =~ ~s|if [ -z "$RELEASE_NODE" ]; then|
    end

    # The release script is `#!/bin/sh` and sources env.sh with `.`: on
    # the Debian runner, and on CI's Ubuntu, that is dash, whatever else
    # the image carries. Run, not parsed: `dash -n` lets `[[ … ]]` and
    # `${v//a/b}` through, and they fail only when executed.
    dash = System.find_executable("dash")
    if !dash, do: @tag(skip: "dash is not installed")

    test "env.sh runs under dash, the sh of the release's runner image" do
      dash = unquote(dash)
      env_sh = install() |> apply_igniter!() |> files() |> Map.get("rel/env.sh.eex")
      script = EEx.eval_string(env_sh, assigns: [release: %{name: :test}])
      print = ~s|\nprintf '%s %s' "$RELEASE_DISTRIBUTION" "$RELEASE_NODE"|

      run = fn env ->
        System.cmd(dash, ["-e", "-c", script <> print], env: env, stderr_to_stdout: true)
      end

      # Named after the release and the container's address; nothing on stderr.
      assert {out, 0} = run.([{"RELEASE_NAME", "test"}, {"RELEASE_NODE", nil}])
      assert out =~ ~r/\Aname test@[0-9a-f.:]+\z/

      # A name given from outside is kept.
      assert {"name app@10.0.0.9", 0} =
               run.([{"RELEASE_NAME", "test"}, {"RELEASE_NODE", "app@10.0.0.9"}])
    end

    test "appends to an env.sh left by mix release.init" do
      files = %{"rel/env.sh.eex" => "#!/bin/sh\n\n# handmade\n"}

      env_sh = install([], files) |> apply_igniter!() |> files() |> Map.get("rel/env.sh.eex")

      assert env_sh =~ "# handmade"
      assert env_sh =~ "export RELEASE_DISTRIBUTION=name"
    end
  end

  describe "environment files" do
    test "declares DNS_CLUSTER_QUERY in .env and .env.sample" do
      files = %{".env" => "PORT=\"4000\"\n", ".env.sample" => "PORT=\"4000\"\n"}
      igniter = install([], files) |> apply_igniter!()

      for path <- [".env", ".env.sample"] do
        content = igniter.assigns[:test_files][path]

        assert content =~ "# Cluster discovery, queried by DNSCluster (:prod only)."
        assert content =~ ~s|DNS_CLUSTER_QUERY="test.default.svc.cluster.local"|
      end
    end

    test "--dns-query overrides the value" do
      files = %{".env" => "PORT=\"4000\"\n"}

      env =
        install(["--dns-query", "demo.internal"], files)
        |> apply_igniter!()
        |> files()
        |> Map.get(".env")

      assert env =~ ~s|DNS_CLUSTER_QUERY="demo.internal"|
    end

    test "an empty --dns-query is a field left blank: the default goes in" do
      files = %{".env" => "PORT=\"4000\"\n"}

      env =
        install(["--dns-query", ""], files)
        |> apply_igniter!()
        |> files()
        |> Map.get(".env")

      refute env =~ ~s|DNS_CLUSTER_QUERY=""|
      assert env =~ ~s|DNS_CLUSTER_QUERY="test.default.svc.cluster.local"|
    end

    test "a --dns-query with a quote is refused, and nothing is written" do
      igniter =
        install(["--dns-query", ~s|demo"internal|], %{".env" => "PORT=\"4000\"\n"})

      # Between a .env line's quotes, it would end the value early.
      assert_has_issue(igniter, &(&1 =~ "--dns-query takes a DNS name"))
      refute Igniter.exists?(igniter, "rel/env.sh.eex")
      assert_unchanged(igniter, ".env")
    end
  end

  test "running it twice changes nothing" do
    files = %{".env" => "PORT=\"4000\"\n", ".env.sample" => "PORT=\"4000\"\n"}

    install([], files)
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.clustering", [])
    |> assert_unchanged()
  end
end
