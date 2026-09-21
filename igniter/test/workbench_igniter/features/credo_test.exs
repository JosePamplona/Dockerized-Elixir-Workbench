defmodule WorkbenchIgniter.Features.CredoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Credo
  alias WorkbenchIgniter.Features.Precommit

  describe "mix workbench.install.credo" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> assert_has_patch("mix.exs", """
      + | {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> assert_unchanged()
    end

    test "writes no hook without --githook" do
      igniter = test_project() |> Igniter.compose_task("workbench.install.credo", [])

      refute Igniter.exists?(igniter, Precommit.hook())
      assert {%{githook: false}, _} = igniter |> apply_igniter!() |> Credo.state()
    end
  end

  describe "--githook" do
    test "inserts the precommit cartridge and takes a block of its hook" do
      igniter =
        test_project()
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()

      hook = igniter.assigns[:test_files][Precommit.hook()]

      # The hook box came with it: its own block, and the way in.
      assert hook =~ "mix format --check-formatted"
      assert igniter.assigns[:test_files][".githooks/mix"] =~ "docker compose exec"

      assert hook =~ "# >>> credo — the reviewer that never tires\nmix credo\n# <<< credo"
      refute hook =~ "mix credo --strict"
    end

    test "the block is born above the divider: the reviewer reads source" do
      hook =
        test_project()
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      [fast, slow] = String.split(hook, "# --- slow:")

      assert fast =~ "mix credo"
      refute slow =~ "mix credo"
    end

    test "says back that the project carries it" do
      {state, _igniter} =
        test_project()
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()
        |> Credo.state()

      assert state == %{githook: true}
    end

    test "a second run adds the block to a project that took the dependency without it" do
      igniter =
        test_project()
        |> Igniter.compose_task("workbench.install.credo", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()

      assert igniter.assigns[:test_files][Precommit.hook()] =~ "mix credo"
    end

    test "ejecting credo leaves the rest of the hook standing" do
      hook =
        test_project()
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()
        |> Precommit.forget("credo")
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      refute hook =~ "credo"
      assert hook =~ "mix format --check-formatted"
    end
  end
end
