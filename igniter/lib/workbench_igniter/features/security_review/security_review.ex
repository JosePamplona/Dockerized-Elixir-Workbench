defmodule WorkbenchIgniter.Features.SecurityReview do
  @moduledoc """
  A review of the project against the OWASP Top 10, kept in the
  repository, with the checks that can be automated run by one task.

  Pending: a manifest only — the need is written (`NEED.md`) and the
  README says what the box is expected to bring, but nothing is
  designed and the installer is not written, so the catalog shows the
  box as pending and nothing can insert it. When it is done, fill this
  directory in like any other cartridge (see the checklist in the
  package README), its `DESIGN.md` first.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.security_review"

  @impl true
  def pending?, do: true

  # Nothing installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}
end
