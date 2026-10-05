defmodule WorkbenchIgniter.Features.MessageBroker do
  @moduledoc """
  A message broker in the workspace, and the pipeline that publishes to
  it and consumes from it: two parts of a system that talk without
  waiting for each other.

  Pending: a manifest only — the need is written (`NEED.md`) and the
  README says what the box is expected to bring, but nothing is
  designed and the installer is not written, so the catalog shows the
  box as pending and nothing can insert it. When it is done, fill this
  directory in like any other cartridge (see the checklist in the
  package README), its `DESIGN.md` first.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.message_broker"

  @impl true
  def pending?, do: true

  # Nothing installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}
end
