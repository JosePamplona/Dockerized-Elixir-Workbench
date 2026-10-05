defmodule Mix.Tasks.Workbench.Install.Changelog do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Changelog

  @shortdoc "Starts versioning in the project: a changelog opened at the version it is on; the mix version task and the README badge on request"

  @moduledoc """
  #{@shortdoc}

  Every Mix project has a `version:`, and without a record of what
  changes between one number and the next it never moves. This creates
  the record: a `CHANGELOG.md` opened at the version `mix.exs` has —
  Keep a Changelog, with an `Unreleased` section to write into and a
  commented title line to uncomment when a release is cut. `mix.exs` is
  left as it is, so the project can be new or well under way; with
  `--init-version` the history opens at the version asked for, and
  `mix.exs` is written to say it.

  With `--mix-task`, a `mix version NEW` task that does the uncommenting
  for you, writes the number into `mix.exs` and updates the README
  badge when there is one; with `--readme-badge`, that badge under the
  README's title.

  Re-running it never moves the version: the mark is the changelog, and
  an existing one is never overwritten; the task and the badge are
  added when asked and missing.

  ## Example

      #{Changelog.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Changelog)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Changelog.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Changelog, igniter)
end
