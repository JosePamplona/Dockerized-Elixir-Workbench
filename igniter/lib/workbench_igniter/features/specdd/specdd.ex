defmodule WorkbenchIgniter.Features.Specdd do
  @moduledoc """
  SpecDD — spec-driven development with `.sdd` files beside the code —
  on a stock `phx.new` project: what `specdd init` writes, plus a
  `bootstrap.project.md` and three starting specs that know they are
  in a Phoenix project.

  Pending: a manifest only — the design is settled (`DESIGN.md`, and
  the templates and assets under `priv/features/specdd/`), the
  installer is not written yet, so the catalog shows the box as
  pending and nothing can insert it. When it is done, fill this
  directory in like any other cartridge (see the checklist in the
  package README); the README here already says what it installs and
  the mark it reads.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.specdd"

  @impl true
  def pending?, do: true

  # The mark, when the installer exists, is `.specdd/bootstrap.md` —
  # the same file `specdd init` refuses on and `specdd update` reads —
  # so the CLI, the installer and `mix workbench.status` agree. Nothing
  # installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}

  @impl true
  def afterwards do
    "Deploy the SpecDD Agent Skills when your agent reads them: " <>
      ~s|docker run --rm -v "$PWD:/workspace" ghcr.io/specdd/cli:latest agentskills deploy|
  end
end
