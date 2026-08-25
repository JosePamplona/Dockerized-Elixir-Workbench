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
  end

  test "running it twice changes nothing" do
    files = %{".env" => "PORT=\"4000\"\n", ".env.sample" => "PORT=\"4000\"\n"}

    install([], files)
    |> apply_igniter!()
    |> Igniter.compose_task("workbench.install.clustering", [])
    |> assert_unchanged()
  end
end
