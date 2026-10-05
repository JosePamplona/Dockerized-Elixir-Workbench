defmodule WorkbenchIgniter.Features.Stripe do
  @moduledoc """
  Stripe subscriptions. Requires auth0: subscriptions belong to users.

  Pending: a manifest only — the installer is not done yet, so the
  catalog shows the box as pending and nothing can insert it. When it
  is done, it should be created directly as a cartridge (see the
  checklist in the package README).
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.stripe"

  @impl true
  def requires, do: ["auth0"]

  @impl true
  def pending?, do: true

  # Nothing installs it yet, so no project carries it.
  @impl true
  def installed?(igniter), do: {false, igniter}
end
