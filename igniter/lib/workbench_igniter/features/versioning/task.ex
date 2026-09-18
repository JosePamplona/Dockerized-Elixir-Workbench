defmodule Mix.Tasks.Workbench.Install.Versioning do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Versioning

  @shortdoc "Sets the project's initial version and opens its changelog; the mix version task and the README badge on request"

  @moduledoc """
  #{@shortdoc}

  Writes the `version:` of `mix.exs` and creates a `CHANGELOG.md` opened
  at it — Keep a Changelog, with an `Unreleased` section to write into
  and a commented title line to uncomment when a release is cut. With
  `--task`, a `mix version NEW` task that does the uncommenting for you,
  writes the number into `mix.exs` and updates the README badge when
  there is one; with `--readme-badge`, that badge under the README's
  title.

  `phx.new` writes `0.1.0` because a generator has to write something;
  this makes the number a decision. Re-running it never moves the
  version: the mark is the changelog, and an existing one is never
  overwritten; the task and the badge are added when asked and missing.

  ## Example

      #{Versioning.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Versioning)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Versioning.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Versioning.install(igniter)
end
