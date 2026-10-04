defmodule WorkbenchIgniter.Features.EventStream do
  @moduledoc """
  An event log in the workspace, and the pipeline that writes to it and
  reads from it: a record of events that several consumers read again,
  each from its own position.

  Pending: a manifest only — the need is written (`NEED.md`) and the
  README says what the box is expected to bring, but nothing is
  designed and the installer is not written, so the catalog shows the
  box as pending and nothing can insert it. When it is done, fill this
  directory in like any other cartridge (see the checklist in the
  package README), its `DESIGN.md` first.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.event_stream"

  @impl true
  def pending?, do: true

  # Nothing installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}
end
