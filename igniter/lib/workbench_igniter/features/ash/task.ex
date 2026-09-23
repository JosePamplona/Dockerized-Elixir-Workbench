defmodule Mix.Tasks.Workbench.Install.Ash do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Ash

  @shortdoc "Installs the Ash framework, configured like ash-hq.org's installer for an existing app"

  @moduledoc """
  #{@shortdoc}

  Turns the options below — the choices of the *Get Your Installer*
  section on ash-hq.org, *Existing App* tab — into the command that
  site generates, and queues it to run once this patch set is applied:

      mix igniter.install ash ash_postgres ash_phoenix ... --yes

  Igniter adds the packages to `mix.exs`, fetches and compiles them and
  runs each package's own installer (`ash.install`,
  `ash_postgres.install`, `ash_authentication.install`, …).
  What Ash writes — domain, resources, config, migrations — shows up in
  that command's output, not in this task's diff.

  `ash` and `ash_phoenix` are always installed. Packages the project
  already declares are left out of the command; when none is left,
  nothing is queued and a notice says so. With `--auth`, the task also
  appends `TOKEN_SIGNING_SECRET` to `.env` (generated) and `.env.sample`
  (blank) — `ash_authentication` makes `config/runtime.exs` require it
  in `:prod`, and the workbench's prod compose reads `.env`.

  ## Example

      #{Ash.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Ash)}

  ## Requirements

  The Ash installers need the network (Hex) and a Postgres the
  `ash_postgres` repo can reach when `mix ash.setup` runs afterwards —
  which is what `./wb.sh setup` does.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Ash.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Ash, igniter)
end
