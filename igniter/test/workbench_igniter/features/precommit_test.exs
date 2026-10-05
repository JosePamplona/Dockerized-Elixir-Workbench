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

    # Igniter's own place is right under `import Config`: the project's
    # dev.exs would open with a library it met last.
    test "writes the configuration at the end of dev.exs, after what was there" do
      config =
        test_project(
          files: %{
            "config/dev.exs" => """
            import Config

            config :test, TestWeb.Endpoint, http: [port: 4000]

            config :phoenix_live_view, debug_heex_annotations: true
            """
          }
        )
        |> Igniter.compose_task("workbench.install.precommit", [])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, "config/dev.exs"])

      [before, git_hooks] = String.split(config, "config :git_hooks", parts: 2)

      assert before =~ "config :test, TestWeb.Endpoint"
      assert before =~ "config :phoenix_live_view"
      refute git_hooks =~ ~r/^config /m
      assert git_hooks =~ ~s(tasks: [{:cmd, "sh .githooks/pre-commit"}])
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

    # check/4 places a block by its stage only when it is born: one
    # already in the file is replaced where it stands, so the suite a
    # second run adds joins the block above the divider, not below it.
    test "a slow check added to a block born fast stays in the block, above the divider" do
      hook =
        install()
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.precommit", ~w(--checks test))
        |> apply_igniter!()
        |> hook()

      [before_slow, after_slow] = String.split(hook, "# --- slow:")

      assert before_slow =~ """
             mix format --check-formatted
             mix test
             # <<< precommit
             """

      refute after_slow =~ "precommit"
      refute after_slow =~ "mix test"
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

  # The hook lives in .git/hooks, which no commit carries: the revert
  # leaves it, calling a .githooks/mix that is gone.
  describe "ejected/1" do
    @shim """
    #!/bin/sh
    cd_path="."
    [ -n "$cd_path" ] && cd "$cd_path"
    sh .githooks/mix git_hooks.run pre_commit "$@"
    """

    setup %{tmp_dir: root} do
      {_, 0} = System.cmd("git", ["init", "-q"], cd: root)
      hooks = Path.join(root, ".git/hooks")
      File.mkdir_p!(hooks)
      %{hooks: hooks}
    end

    defp installed(hooks, hook \\ @shim) do
      File.write!(Path.join(hooks, "pre-commit"), hook)
      File.write!(Path.join(hooks, "git_hooks.db"), "pre_commit")
    end

    @tag :tmp_dir
    test "takes away the hook git_hooks installed, and its record", %{tmp_dir: root, hooks: hooks} do
      installed(hooks)

      assert Precommit.ejected(root) == [
               "removed .git/hooks/pre-commit",
               "removed .git/hooks/git_hooks.db"
             ]

      refute File.exists?(Path.join(hooks, "pre-commit"))
      refute File.exists?(Path.join(hooks, "git_hooks.db"))
    end

    @tag :tmp_dir
    test "puts back the hook it had replaced", %{tmp_dir: root, hooks: hooks} do
      installed(hooks)
      File.write!(Path.join(hooks, "pre-commit.pre_git_hooks_backup"), "#!/bin/sh\necho mine\n")

      assert "restored .git/hooks/pre-commit, the hook it had replaced" in Precommit.ejected(root)
      assert File.read!(Path.join(hooks, "pre-commit")) =~ "echo mine"
    end

    # git_hooks backs up whatever it finds, its own shim included when
    # it installs twice: putting that back would put back the fault.
    @tag :tmp_dir
    test "a backup that is its own shim goes too", %{tmp_dir: root, hooks: hooks} do
      installed(hooks)
      File.write!(Path.join(hooks, "pre-commit.pre_git_hooks_backup"), @shim)

      assert "removed .git/hooks/pre-commit.pre_git_hooks_backup" in Precommit.ejected(root)
      refute File.exists?(Path.join(hooks, "pre-commit"))
    end

    @tag :tmp_dir
    test "leaves a hook that is not git_hooks'", %{tmp_dir: root, hooks: hooks} do
      installed(hooks, "#!/bin/sh\necho mine\n")

      assert Precommit.ejected(root) == ["removed .git/hooks/git_hooks.db"]
      assert File.read!(Path.join(hooks, "pre-commit")) =~ "echo mine"
    end

    @tag :tmp_dir
    test "a second run finds nothing to do", %{tmp_dir: root, hooks: hooks} do
      installed(hooks)
      Precommit.ejected(root)

      assert Precommit.ejected(root) == []
    end

    @tag :tmp_dir
    test "outside a repository, nothing", %{tmp_dir: root} do
      File.rm_rf!(Path.join(root, ".git"))

      assert Precommit.ejected(root) == []
    end
  end
end
