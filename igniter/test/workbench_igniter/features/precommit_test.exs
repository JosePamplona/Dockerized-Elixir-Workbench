defmodule WorkbenchIgniter.Features.PrecommitTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Precommit

  defp install(argv \\ []) do
    test_project() |> Igniter.compose_task("workbench.install.precommit", argv)
  end

  defp hook(igniter), do: igniter.assigns[:test_files][Precommit.hook()]

  describe "mix workbench.install.precommit" do
    test "adds the dependency, the configuration and the two files" do
      igniter = install()

      assert_has_patch(igniter, "mix.exs", """
      + | {:git_hooks, "~> 0.7", only: :dev, runtime: false}
      """)

      assert_creates(igniter, ".githooks/mix")
      assert_creates(igniter, Precommit.hook())
    end

    # The library's own install runs while the dependency compiles, from
    # `deps/git_hooks` — a volume in a workspace, where git cannot see
    # the project's `.git`. The task runs from the project's root.
    test "installs the hook itself, not when the dependency compiles" do
      igniter = install()

      assert {"git_hooks.install", []} in igniter.tasks
    end

    test "points git_hooks at the host's way in, and at the hook file" do
      config =
        install()
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, "config/dev.exs"])

      assert config =~ "auto_install: false"
      assert config =~ ~s(mix_path: "sh .githooks/mix")
      assert config =~ ~s(project_path: ".")
      assert config =~ ~s(tasks: [{:cmd, "sh .githooks/pre-commit"}])
    end

    test "writes the default check into the cartridge's own block" do
      hook = install() |> apply_igniter!() |> hook()

      assert hook =~ "set -e"

      assert hook =~ """
             # >>> precommit — the checks that come with Elixir, not with a cartridge
             mix format --check-formatted
             # <<< precommit
             """
    end

    test "takes the checks asked for, in the order they run" do
      hook = install(~w(--checks test,format,compile)) |> apply_igniter!() |> hook()

      assert hook =~ """
             mix format --check-formatted
             mix compile --warnings-as-errors
             mix test
             """
    end

    test "the box's own block stands above the slow section" do
      hook = install() |> apply_igniter!() |> hook()

      assert hook |> String.split("# >>> precommit") |> hd() |> String.contains?("# --- slow:") ==
               false
    end

    test "a block is born where its slowest check belongs" do
      hook = install(~w(--checks format,test)) |> apply_igniter!() |> hook()

      [before_slow, after_slow] = String.split(hook, "# --- slow:")
      refute before_slow =~ "mix format --check-formatted"
      assert after_slow =~ "mix test"
    end

    test "refuses a check it does not have" do
      assert_has_issue(install(~w(--checks format,dialyzer)), fn issue ->
        issue =~ "--checks must be one of" and issue =~ "dialyzer"
      end)
    end

    test "a second run adds the check the first left out, in place" do
      hook =
        install()
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.precommit", ~w(--checks unused_deps))
        |> apply_igniter!()
        |> hook()

      assert hook =~ """
             mix format --check-formatted
             mix deps.unlock --check-unused
             """

      # One block, not two.
      assert hook |> String.split("# >>> precommit") |> length() == 2
    end

    test "says back the checks the project carries" do
      {state, _igniter} =
        install(~w(--checks compile,unused_deps)) |> apply_igniter!() |> Precommit.state()

      assert state == %{checks: ~w(unused_deps compile)}
    end

    test "is a no-op when the hook is already there" do
      install()
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.precommit", [])
      |> assert_unchanged()
    end
  end

  describe "check/4: the way in for a cartridge with a check of its own" do
    test "gives each cartridge its own block, the slow ones last" do
      hook =
        install()
        |> apply_igniter!()
        |> Precommit.check("credo", ["mix credo --strict"], note: "the reviewer")
        |> apply_igniter!()
        |> hook()

      assert hook =~ "# >>> credo — the reviewer\nmix credo --strict\n# <<< credo"

      [before_slow, after_slow] = String.split(hook, "# --- slow:")
      assert before_slow =~ "mix format --check-formatted"
      assert after_slow =~ "mix credo --strict"
    end

    test "a fast check is born above the slow section" do
      hook =
        install()
        |> apply_igniter!()
        |> Precommit.check("credo", ["mix credo --strict"], stage: :fast)
        |> apply_igniter!()
        |> hook()

      [before_slow, _after] = String.split(hook, "# --- slow:")
      assert before_slow =~ "mix credo --strict"
    end

    test "does not write the same command twice" do
      hook =
        install()
        |> apply_igniter!()
        |> Precommit.check("credo", ["mix credo --strict"])
        |> apply_igniter!()
        |> Precommit.check("credo", ["mix credo --strict"])
        |> apply_igniter!()
        |> hook()

      assert hook |> String.split("mix credo --strict") |> length() == 2
    end

    test "forget/2 takes one cartridge's checks away and leaves the rest" do
      hook =
        install()
        |> apply_igniter!()
        |> Precommit.check("credo", ["mix credo --strict"])
        |> apply_igniter!()
        |> Precommit.forget("credo")
        |> apply_igniter!()
        |> hook()

      refute hook =~ "credo"
      assert hook =~ "mix format --check-formatted"
    end
  end
end
