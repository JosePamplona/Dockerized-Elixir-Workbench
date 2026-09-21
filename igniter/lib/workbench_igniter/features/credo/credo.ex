defmodule WorkbenchIgniter.Features.Credo do
  @moduledoc """
  Credo static code analysis — the dependency, and the check before the
  commit.

  `--githook` puts `mix credo` in the project's pre-commit hook, in
  **this cartridge's own block** of it
  (`WorkbenchIgniter.Features.Precommit`): the hook, its host-side
  runner and the checks that come with Elixir are that box's, and what
  Credo adds to them is this one's. So `--githook` builds on precommit
  being in, and refuses while it is not — never inserts it along: that
  would be two cartridges in one commit, and an eject of this one that
  takes the other's hook with it. Ejecting either leaves the other's
  checks standing; precommit's eject waits until this block is gone.

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
      schema: [githook: :boolean],
      defaults: [githook: false]
    }
  end

  @impl true
  def option_docs do
    [
      githook:
        "Run `#{@check}` before every commit, in this cartridge's own block of `#{Precommit.hook()}`. Builds on the precommit cartridge, which owns the hook: insert it first. Default: off."
    ]
  end

  @impl true
  def choices, do: [githook: [{true, "the check before the commit", ["precommit"]}]]

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
    githook? = igniter.args.options[:githook]

    case WorkbenchIgniter.Feature.missing_option_requirements(igniter, __MODULE__,
           githook: githook?
         ) do
      {[], igniter} ->
        igniter
        |> Igniter.Project.Deps.add_dep(@dep, on_exists: :skip)
        |> githook(githook?)

      {missing, igniter} ->
        WorkbenchIgniter.Feature.refuse_values(igniter, missing)
    end
  end

  # `stage: :fast`: Credo reads the source and does not compile the
  # project, so its block is born above the hook's divider, among the
  # checks that refuse a commit in a second.
  defp githook(igniter, true) do
    Precommit.check(igniter, name(), [@check], note: "the reviewer that never tires", stage: :fast)
  end

  defp githook(igniter, _off), do: igniter
end
