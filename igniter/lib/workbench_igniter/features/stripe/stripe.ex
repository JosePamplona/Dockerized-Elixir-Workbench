defmodule WorkbenchIgniter.Features.Stripe do
  @moduledoc """
  Stripe subscriptions. Requires auth0 (subscriptions belong to users), so
  enabling it forces `--auth0` on.

  Pending: documented in the generated README.md and .env, but the
  installer is not ported yet — setup surfaces a notice instead of
  composing it. When ported, it should be created directly as a cartridge
  (see the checklist in the package README).
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.stripe"

  @impl true
  def flag, do: :stripe

  @impl true
  def implies, do: [:auth0]

  @impl true
  def pending?, do: true
end
