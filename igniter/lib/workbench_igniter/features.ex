defmodule WorkbenchIgniter.Features do
  @moduledoc """
  Registry of workbench feature cartridges.

  There is one kind of cartridge: every one is installed on demand
  (`wb.sh add <name>`), and a *collection* is just a cartridge whose
  installer inserts other cartridges (`members/1` in its manifest —
  chiefs_setup is one). Adding a feature means adding a
  `WorkbenchIgniter.Feature` module here.

  The list order is the shelf's: the collections first, then the
  cartridges in the order they were written, then the base ones.
  Ordering constraints between cartridges live in each one's
  `requires/0`, and inside a collection, in its `members/1` order.

  `entry/1` reads a cartridge's manifest into a plain map (what
  `mix workbench.catalog` prints) and `status/1` adds whether the
  target project carries it.
  """

  alias WorkbenchIgniter.Features

  @cartridges [
    # The collection: the chief's picks, inserted one commit each.
    Features.ChiefsSetup,
    # The house's settings on a stock project: one decision each.
    Features.Ansi,
    Features.Toolchain,
    Features.Versioning,
    # Trivial dep-only group.
    Features.Osmon,
    Features.PsqlExtras,
    Features.Credo,
    Features.Mock,
    Features.Exdebug,
    # API interface (mutually exclusive: chiefs_setup inserts one).
    Features.Rest,
    Features.Graphql,
    Features.Coveralls,
    Features.Exdoc,
    Features.Guidelines,
    Features.Enhancements,
    Features.Auth0,
    Features.Openai,
    Features.Healthcheck,
    Features.Stripe,
    Features.Githooks,
    Features.Exmachina,
    Features.Clustering,
    Features.Healthcheck2,
    Features.Ash,
    Features.Specdd,
    # Services of the workspace, declared for the compose (scripts/PLAN.md).
    Features.Pgadmin,
    Features.K6,
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

  @doc "Every cartridge, in shelf order."
  @spec catalog() :: [module()]
  def catalog, do: @cartridges

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
    members = members(feature, info)

    %{
      name: feature.name(),
      task: feature.task(),
      summary: feature.summary(),
      # The developer's need, off NEED.md: the one line the shelf shows
      # and the whole note the box carries.
      need: need(feature.need()),
      version: version(feature.version()),
      rerun: feature.rerun(),
      requires: feature.requires(),
      afterwards: feature.afterwards(),
      console: console(feature.console()),
      # A base cartridge: a phx.new capability, in a default project
      # from birth and left out with its --no-* flag.
      base: String.to_atom(feature.name()) in WorkbenchIgniter.PhxDelta.capabilities(),
      # A collection: a cartridge whose installer inserts other
      # cartridges. `members` is the recipe its default choices give —
      # each one with the argv its installer gets.
      collection: members != [],
      members: members,
      pending: feature.pending?(),
      example: info && info.example,
      options: options(info, feature)
    }
  end

  # The recipe a collection's default choices give, for the catalog:
  # each member with the argv its installer gets. [] for a plain
  # cartridge.
  defp members(_feature, nil), do: []

  defp members(feature, %Igniter.Mix.Task.Info{defaults: defaults}) do
    for {name, argv} <- feature.members(defaults || []), do: %{name: name, argv: argv}
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

  @doc """
  The compose services the project asks for: what every installed
  cartridge declares (`services/1`, off its state), in catalog order,
  each name once. What `mix workbench.compose` bakes into the
  workspace's compose, and what `mix workbench.status` reports as
  `services`. Returns the igniter too, as `status/1` does.
  """
  @spec services(Igniter.t()) :: {[String.t()], Igniter.t()}
  def services(igniter) do
    {lists, igniter} =
      Enum.map_reduce(catalog(), igniter, fn feature, igniter ->
        case feature.installed?(igniter) do
          {true, igniter} ->
            {state, igniter} = feature.state(igniter)
            {feature.services(state), igniter}

          {false, igniter} ->
            {[], igniter}
        end
      end)

    {lists |> List.flatten() |> Enum.uniq(), igniter}
  end

  defp version(nil), do: nil
  defp version({version, date}), do: %{version: version, date: date}

  defp need(nil), do: nil

  # The four parts every NEED.md says in the same order (features/
  # README.md): the want — the line — then Before, After and Not for,
  # each as one line. Parsed here, once, so no reader of the catalog
  # has to find them in the body with regular expressions.
  defp need({line, body}) do
    part = fn label ->
      case Regex.run(~r/\*\*#{label}:\*\*\s*(.+?)(?=\n\s*\n|\z)/s, body) do
        [_, text] -> text |> String.split("\n") |> Enum.map_join(" ", &String.trim/1)
        nil -> nil
      end
    end

    %{
      line: line,
      body: body,
      before: part.("Before"),
      after: part.("After"),
      not_for: part.("Not for")
    }
  end

  # What the cartridge adds to the console, as plain maps: doors with
  # their condition (or nil), probes, tabs.
  defp console(spec) do
    %{
      doors: for(d <- Keyword.get(spec, :doors, []), do: door(d)),
      probes:
        for({label, path} <- Keyword.get(spec, :probes, []), do: %{label: label, path: path}),
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

  @doc """
  The registered cartridge named `name`, or `nil`. The name is the one
  everything outside the package knows the cartridge by (`wb.sh add
  <name>`): its directory under `features/`.
  """
  @spec named(String.t()) :: module() | nil
  def named(name), do: Enum.find(@cartridges, &(&1.name() == name))
end
