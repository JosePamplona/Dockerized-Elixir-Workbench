defmodule WorkbenchIgniter.Features.Credo do
  @moduledoc """
  Credo static code analysis — the dependency, and the check before the
  commit.

  `--githook` puts `mix credo` in the project's pre-commit hook, in
  **this cartridge's own block** of it
  (`WorkbenchIgniter.Features.Precommit`): the hook, its host-side
  runner and the checks that come with Elixir are that box's, and what
  Credo adds to them is this one's. Ejecting either leaves the other's
  checks standing.

  The line is `mix credo`, not `mix credo --strict`: a hook that
  refuses the first commit after it is inserted is a hook the developer
  turns off. `--strict` is one word away, in a file the project owns.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.Features.Precommit

  @dep {:credo, "~> 1.7", only: [:dev, :test], runtime: false}

  @check "mix credo"

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @doc "The line this cartridge puts in the pre-commit hook."
  def check_command, do: @check

  @impl true
  def task, do: "workbench.install.credo"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --githook",
      composes: ["workbench.install.precommit"],
      schema: [githook: :boolean],
      defaults: [githook: false]
    }
  end

  @impl true
  def option_docs do
    [
      githook:
        "Run `#{@check}` before every commit, in this cartridge's own block of `#{Precommit.hook()}` (the precommit cartridge, inserted with it). Default: off."
    ]
  end

  # The hook line is a piece the installer adds when missing.
  @impl true
  def rerun, do: :adds

  # The mark: the dependency itself.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, elem(@dep, 0))

  @doc "What the project carries: whether Credo runs before the commit."
  @impl true
  def state(igniter) do
    {checks, igniter} = Precommit.checks_of(igniter, name())

    {%{githook: @check in checks}, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep(@dep, on_exists: :skip)
    |> githook(igniter.args.options[:githook])
  end

  # `stage: :fast`: Credo reads the source and does not compile the
  # project, so its block is born above the hook's divider, among the
  # checks that refuse a commit in a second.
  defp githook(igniter, true) do
    igniter
    |> Igniter.compose_task("workbench.install.precommit", [])
    |> Precommit.check(name(), [@check], note: "the reviewer that never tires", stage: :fast)
  end

  defp githook(igniter, _off), do: igniter
end
