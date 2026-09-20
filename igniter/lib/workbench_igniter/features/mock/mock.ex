defmodule WorkbenchIgniter.Features.Mock do
  @moduledoc """
  Mock library for tests — a dep-only cartridge. Also composed directly
  by features whose generated tests use it (healthcheck, coveralls).
  """
  use WorkbenchIgniter.Feature

  # PENDING: migrate to Mox. mock sits on meck, whose latest release
  # (0.9.2) fails to compile on OTP >= 29 (old-style `(catch ...)` is
  # deprecated and meck builds with warnings-as-errors), breaking the
  # generated project's test compile on that stack. The migration also
  # reworks the healthcheck controller tests, which `import Mock`.
  # See features/README.md.
  @dep {:mock, "~> 0.3", only: :test}

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def archived,
    do:
      "2026-09-20: test_doubles' box covers it, and the last two cartridges that composed it are retired beside it"

  @impl true
  def task, do: "workbench.install.mock"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # The mark: the dependency itself.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, elem(@dep, 0))

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    Igniter.Project.Deps.add_dep(igniter, @dep, on_exists: :skip)
  end
end
