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

  The standalone cartridges — installed by hand with `wb.sh add`, never
  composed — are listed apart, so that `catalog/0` names every cartridge
  there is while `all/0` stays the composition list. `entry/1` reads a
  cartridge's manifest into a plain map (what `mix workbench.catalog`
  prints) and `status/1` adds whether the target project carries it.
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

  # Standalone cartridges: no setup flag, never composed. In the order
  # they were written.
  @standalone [
    Features.Githooks,
    Features.Exmachina,
    Features.Clustering,
    Features.Healthcheck2,
    Features.Ash,
    # The base cartridges: capabilities phx.new decides at generation
    # time, added after the fact (WorkbenchIgniter.PhxDelta).
    Features.Mailer,
    Features.Gettext,
    Features.Ecto,
    Features.Esbuild,
    Features.Tailwind,
    Features.Html,
    Features.Live,
    Features.Dashboard
  ]

  @doc "All registered features, in composition order."
  @spec all() :: [module()]
  def all, do: @features

  @doc "The standalone cartridges: installed on demand, never composed."
  @spec standalone() :: [module()]
  def standalone, do: @standalone

  @doc "Every cartridge: the composed ones in composition order, then the standalone."
  @spec catalog() :: [module()]
  def catalog, do: @features ++ @standalone

  @doc "Whether the cartridge is a standalone one."
  @spec standalone?(module()) :: boolean()
  def standalone?(feature), do: feature in @standalone

  @doc """
  A cartridge's manifest as a plain map: what the catalog says about it
  without looking at any project. `options` are the installer's switches
  (its `info/2` schema with the defaults, and the values `choices/0`
  declares: `choices` as a list, or as `[%{group, values}]` when
  sectioned; `open` when other values are accepted too; `multiple` for
  the `:csv` type); a pending cartridge has none.
  """
  @spec entry(module()) :: map()
  def entry(feature) do
    info = if feature.pending?(), do: nil, else: feature.info([], nil)

    %{
      name: feature.name(),
      task: feature.task(),
      summary: feature.summary(),
      # The developer's need, off NEED.md: the one line the shelf shows
      # and the whole note the box carries.
      need: need(feature.need()),
      version: version(feature.version()),
      flag: feature.flag(),
      enabled_by: enabled_by(feature.enabled_by()),
      rerun: feature.rerun(),
      implies: feature.implies(),
      requires: feature.requires(),
      afterwards: feature.afterwards(),
      console: console(feature.console()),
      # A base cartridge: a phx.new capability, in a default project
      # from birth and left out with its --no-* flag.
      base: String.to_atom(feature.name()) in WorkbenchIgniter.PhxDelta.capabilities(),
      standalone: standalone?(feature),
      pending: feature.pending?(),
      example: info && info.example,
      options: options(info, feature)
    }
  end

  @doc """
  Every catalog entry with `installed`: whether the given project
  carries the cartridge, asked of the cartridge itself (`installed?/1`)
  — and, when it does, `state`: what it carries of the options
  (`state/1`, meaningful for an `:adds` cartridge). Returns the igniter
  too, as the checks include files in it.
  """
  @spec status(Igniter.t()) :: {[map()], Igniter.t()}
  def status(igniter) do
    Enum.map_reduce(catalog(), igniter, fn feature, igniter ->
      {installed?, igniter} = feature.installed?(igniter)
      {state, igniter} = if installed?, do: feature.state(igniter), else: {%{}, igniter}
      {entry(feature) |> Map.put(:installed, installed?) |> Map.put(:state, state), igniter}
    end)
  end

  defp enabled_by(nil), do: nil
  defp enabled_by({option, value}), do: %{option => value}
  defp enabled_by(flag), do: flag

  defp version(nil), do: nil
  defp version({version, date}), do: %{version: version, date: date}

  defp need(nil), do: nil
  defp need({line, body}), do: %{line: line, body: body}

  # What the cartridge adds to the console, as plain maps: doors with
  # their condition (or nil), probes, tabs.
  defp console(spec) do
    %{
      doors: for(d <- Keyword.get(spec, :doors, []), do: door(d)),
      probes: for({label, path} <- Keyword.get(spec, :probes, []), do: %{label: label, path: path}),
      tabs: Keyword.get(spec, :tabs, [])
    }
  end

  defp door({label, path}), do: %{label: label, path: path, when: nil}

  defp door({label, path, opts}) do
    when_ =
      case Keyword.fetch!(opts, :when) do
        {:with, value} -> %{with: value}
        {:cartridge, name} -> %{cartridge: name}
      end

    %{label: label, path: path, when: when_}
  end

  defp options(nil, _feature), do: []

  defp options(%Igniter.Mix.Task.Info{schema: schema, defaults: defaults}, feature) do
    choices = feature.choices()
    docs = feature.option_docs()

    for {key, type} <- schema || [] do
      {open, values} =
        case Keyword.get(choices, key) do
          nil -> {false, nil}
          {:open, values} -> {true, values}
          values -> {false, values}
        end

      %{
        name: key,
        type: type,
        default: Keyword.get(defaults || [], key),
        multiple: type == :csv,
        choices: choice_list(values),
        open: open,
        doc: Keyword.get(docs, key)
      }
    end
  end

  # Every value as %{value, doc, requires}, doc nil when the cartridge
  # gave none, requires the cartridges choosing it builds on (mostly
  # none); sections as %{group, values}.
  defp choice_list(nil), do: nil
  defp choice_list([{g, v} | _] = groups) when is_atom(g) and is_list(v),
    do: for({g, v} <- groups, do: %{group: g, values: choice_list(v)})
  defp choice_list(values), do: Enum.map(values, &choice_value/1)

  defp choice_value({value, doc, requires}), do: %{value: value, doc: doc, requires: requires}
  defp choice_value({value, doc}), do: %{value: value, doc: doc, requires: []}
  defp choice_value(value), do: %{value: value, doc: nil, requires: []}

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
