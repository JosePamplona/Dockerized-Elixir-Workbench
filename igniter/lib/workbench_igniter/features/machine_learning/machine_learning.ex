defmodule WorkbenchIgniter.Features.MachineLearning do
  @moduledoc """
  A model served from inside the application: Nx in the project, and a
  serving in its supervision tree, instead of a second service in
  another language beside it.

  Pending: a manifest only — the need is written (`NEED.md`) and the
  README says what the box is expected to bring, but nothing is
  designed and the installer is not written, so the catalog shows the
  box as pending and nothing can insert it. When it is done, fill this
  directory in like any other cartridge (see the checklist in the
  package README), its `DESIGN.md` first.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.machine_learning"

  @impl true
  def pending?, do: true

  # Nothing installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}
end
