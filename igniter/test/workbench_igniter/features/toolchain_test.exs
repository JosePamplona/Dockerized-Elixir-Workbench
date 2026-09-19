defmodule WorkbenchIgniter.Features.ToolchainTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Toolchain

  describe "mix workbench.install.toolchain" do
    test "keeps the language server's directory out of git, and nothing else" do
      igniter = Igniter.compose_task(phx_test_project(), "workbench.install.toolchain", [])

      assert_has_patch(igniter, ".gitignore", """
      + |# Elixir Language Server directory.
      + |/.elixir_ls/
      """)

      # The pin is version_manager's since v0.2.0.
      refute Igniter.exists?(igniter, ".tool-versions")
    end

    test "is a no-op on a second run" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.toolchain", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.toolchain", [])
      |> assert_unchanged()
    end
  end

  describe "installed?/1" do
    test "reads the entry in .gitignore" do
      assert {false, _} = Toolchain.installed?(phx_test_project())

      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.toolchain", [])
        |> apply_igniter!()

      assert {true, _} = Toolchain.installed?(igniter)
    end
  end
end
