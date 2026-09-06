defmodule WorkbenchIgniter.Features.ToolchainTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Toolchain

  defp installed(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.toolchain", argv)
    |> apply_igniter!()
  end

  describe "mix workbench.install.toolchain" do
    test "writes the versions running the installer" do
      file = installed().assigns[:test_files][".tool-versions"]

      assert file =~ "elixir #{System.version()}\n"
      assert file =~ ~r/^erlang \d/m
    end

    test "--elixir and --erlang pin something else" do
      file =
        installed(["--elixir", "1.18.4", "--erlang", "27.3"]).assigns[:test_files][
          ".tool-versions"
        ]

      assert file == "erlang 27.3\nelixir 1.18.4\n"
    end

    test "keeps the language server's cache out of git" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.toolchain", [])
      |> assert_has_patch(".gitignore", """
      + |# Elixir Language Server directory.
      + |/.elixir_ls/
      """)
    end

    test "is a no-op on a second run, and never overwrites an existing pin" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.toolchain", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.toolchain", ["--elixir", "1.0.0"])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "the pin is in"))
    end
  end

  describe "state/1" do
    test "reads the versions back off the file" do
      {state, _} = Toolchain.state(installed(["--elixir", "1.18.4", "--erlang", "27.3"]))
      assert state == %{elixir: "1.18.4", erlang: "27.3"}

      assert {%{}, _} = Toolchain.state(phx_test_project())
    end
  end
end
