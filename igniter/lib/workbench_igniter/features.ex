defmodule WorkbenchIgniter.Features do
  @moduledoc """
  Registry of workbench feature cartridges, in composition order.

  `workbench.setup` does not know individual features: it normalizes its
  options through `normalize/1` (applying each feature's implied flags) and
  then `compose/2` walks this list, composing the installer task of every
  enabled feature with the argv its manifest builds. Adding a feature means
  adding a `WorkbenchIgniter.Feature` module here — not editing setup.

  The list order *is* the composition order; ordering constraints between
  features are documented in each feature's `@moduledoc`.
  """

  alias WorkbenchIgniter.Features

  @features [
    # Trivial dep-only group, toggled together by --enhance.
    Features.Osmon,
    Features.PsqlExtras,
    Features.Credo,
    Features.Mock,
    Features.Exdebug,
    # API interface (mutually exclusive, keyed on --interface).
    Features.Rest,
    Features.Graphql,
    Features.Coveralls,
    Features.Exdoc,
    Features.Enhancements,
    Features.Auth0,
    Features.Openai,
    Features.Healthcheck,
    Features.Stripe
  ]

  @doc "All registered features, in composition order."
  @spec all() :: [module()]
  def all, do: @features

  @doc "Installer task names of the features already ported (for `composes:`)."
  @spec tasks() :: [String.t()]
  def tasks do
    for feature <- @features, not feature.pending?(), do: feature.task()
  end

  @doc """
  Turns on the flags implied by the enabled features (e.g. `--stripe` or
  `--openai` imply `--auth0`), iterating until the option set is stable so
  chained implications also resolve.
  """
  @spec normalize(keyword()) :: keyword()
  def normalize(opts) do
    implied =
      for feature <- @features, feature.enabled?(opts), flag <- feature.implies() do
        flag
      end

    normalized = Enum.reduce(implied, opts, &Keyword.put(&2, &1, true))

    if normalized == opts, do: opts, else: normalize(normalized)
  end

  @doc """
  Composes the installer of every enabled feature, in registry order, and
  adds a notice for the enabled features whose installer is not ported yet.
  """
  @spec compose(Igniter.t(), keyword()) :: Igniter.t()
  def compose(igniter, opts) do
    {pending, ready} =
      @features
      |> Enum.filter(& &1.enabled?(opts))
      |> Enum.split_with(& &1.pending?())

    ready
    |> Enum.reduce(igniter, fn feature, igniter ->
      Igniter.compose_task(igniter, feature.task(), feature.argv(opts))
    end)
    |> notice_pending(pending)
  end

  defp notice_pending(igniter, []), do: igniter

  defp notice_pending(igniter, pending) do
    tasks = Enum.map_join(pending, ", ", & &1.task())

    Igniter.add_notice(igniter, """
    The following features were documented in README.md and .env, but \
    their installers are not ported yet: #{tasks}.\
    """)
  end
end
