defmodule Mix.Tasks.Workbench.Install.ChiefsSetup do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.ChiefsSetup

  @shortdoc "Outfits the project with the chief's picks"

  @moduledoc """
  #{@shortdoc}

  The collection cartridge: its installer inserts other cartridges — the
  trivial dep-only group (dashboard_extras, credo, mock, exdebug), the
  API interface `--interface` chooses (rest or graphql), coverage,
  exdoc, enhancements and health_endpoint — in the order their marks build
  on each other. Each member's own guard makes a re-run a no-op, so on a
  project that already carries some picks only the missing ones land.

  Run directly, this composes every member into one patch set.
  `wb.sh add chiefs_setup` does not: it expands the recipe
  (`mix workbench.expand chiefs_setup`) and inserts each missing member
  as its own commit, so `eject` keeps reverting one cartridge alone.

  ## Example

      #{ChiefsSetup.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(ChiefsSetup)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: ChiefsSetup.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(ChiefsSetup, igniter)
end
