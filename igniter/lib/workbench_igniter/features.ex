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
    Features.VersionManager,
    Features.Toolchain,
    Features.Changelog,
    # Trivial dep-only group.
    Features.DashboardExtras,
    Features.Credo,
    Features.Mock,
    Features.TestDoubles,
    Features.Exdebug,
    # API interface (mutually exclusive: chiefs_setup inserts one).
    Features.Rest,
    Features.Graphql,
    Features.Coverage,
    Features.Exdoc,
    Features.Dbschema,
    Features.Guidelines,
    Features.Enhancements,
    Features.Auth0,
    Features.Openai,
    Features.HealthEndpoint,
    Features.Stripe,
    Features.Precommit,
    Features.TestData,
    Features.Clustering,
    Features.HealthProbe,
    Features.Ash,
    Features.Specdd,
    # Services of the workspace, declared for the compose (WorkbenchIgniter.Compose).
    Features.DbAdmin,
    Features.K6,
    Features.Monitoring,
    # The base cartridges: capabilities phx.new decides at generation
    # time, added after the fact (WorkbenchIgniter.PhxDelta).
    Features.Mailer,
    Features.Gettext,
    Features.Ecto,
    Features.Esbuild,
    Features.Tailwind,
    Features.Html,
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
      # What a second insert can still put in (`adds/0`): "none",
      # "all", or the options it still adds while the rest were fixed
      # when the box went in — what a form in a project that carries
      # the box may still be asked.
      adds: adds(feature.adds()),
      requires: WorkbenchIgniter.Feature.requires_names(feature),
      # The state a requirement asks for, by name (ecto with database
      # postgres); `%{}` when the names are enough.
      conditions: WorkbenchIgniter.Feature.conditions(feature),
      # What it puts in the project's mix.exs, every package it may
      # bring (`deps/1` with `:any`): the shelf shows it before anybody
      # inserts anything.
      deps: Enum.map(feature.deps(:any), &dep/1),
      # The cartridges its installer inserts along, off the `composes`
      # its `info/2` declares to Igniter (health_endpoint brings mock in for
      # its tests): the other way a cartridge stands on another, and
      # the one `requires` does not say. `workbench.dependents` reads
      # both. A collection's members are its recipe, not this.
      composes: composes(info) -- Enum.map(members, & &1.name),
      afterwards: feature.afterwards(),
      console: console(feature.console()),
      # The compose services it brings whatever the project carries of
      # it — each with the port it listens on and the ones it publishes
      # (`Compose.brought/2`). The ones that hang on its state (ecto's
      # database, by engine) are in the status of a project that has it.
      compose: WorkbenchIgniter.Compose.brought(feature, feature.services(%{})),
      # The whole menu: every service it could bring, whatever is
      # chosen (`services(:any)`), each with the choices it comes
      # `with` — `[]` for one that comes whatever you pick. `compose`
      # is what a project with nothing chosen gets; this is what the
      # shelf can promise before anything is, and what lets a reader
      # holding a half-filled form be told which of them that form
      # brings. Same faces, so one reader draws both.
      offers: offers(feature, info),
      # A base cartridge: a phx.new capability, in a default project
      # from birth and left out with its --no-* flag.
      base: String.to_atom(feature.name()) in WorkbenchIgniter.PhxDelta.capabilities(),
      # A collection: a cartridge whose installer inserts other
      # cartridges. `members` is the recipe its default choices give —
      # each one with the argv its installer gets.
      collection: members != [],
      members: members,
      pending: feature.pending?(),
      # Retired: why it was, in one line, or nil while it is current.
      # The box stays on the shelf whole — the papers are the log of the
      # reasoning — and only stops being offered for new projects.
      archived: feature.archived(),
      example: info && info.example,
      options: options(info, feature)
    }
  end

  # The recipe a collection's default choices give, for the catalog:
  # each member with the argv its installer gets. [] for a plain
  # cartridge.
  # `adds/0` as a reader downstream takes it: a word, or the option
  # names as the form knows them.
  defp adds(:none), do: "none"
  defp adds(:all), do: "all"
  defp adds(keys) when is_list(keys), do: Enum.map(keys, &to_string/1)

  defp members(_feature, nil), do: []

  defp members(feature, %Igniter.Mix.Task.Info{defaults: defaults}) do
    for {name, argv} <- feature.members(defaults || []), do: %{name: name, argv: argv}
  end

  # Every service the cartridge promises, drawn as the compose draws
  # one, each told the choices it comes `with` — `[]` for one that
  # comes whatever you pick. Enough for a reader holding a half-filled
  # form to say which of them it is about to get.
  #
  # Asked whole and then one at a time, as `Compose.images/0` asks: the
  # menu is not a project anyone could have — ecto refuses four
  # databases at once — so a cartridge that turns the whole list down
  # still answers for each of its own alone. First answer per service
  # wins, so the order is the compose's where there is one.
  defp offers(feature, info) do
    by = brought_by(feature, info)
    names = feature.services(:any)

    # What it brings with nothing chosen at all comes whatever you
    # choose: no list of choices to wait for.
    always =
      MapSet.new(WorkbenchIgniter.Compose.brought(feature, feature.services(%{})), & &1.service)

    faces =
      for asked <- [names | Enum.map(names, &[&1])],
          service <- WorkbenchIgniter.Compose.brought(feature, asked),
          do: service

    faces
    |> Enum.group_by(& &1.service)
    |> Enum.map(fn {name, [first | _] = drawn} ->
      first
      # What the choice decides and the service does not: ecto's one
      # `database` is a different repository on a different port per
      # engine. The menu says these only where every choice agrees;
      # where they disagree it says nothing rather than the first
      # engine's, and the project that has the cartridge says it (the
      # status' own `compose`).
      |> Map.put(:image, agreed(drawn, & &1.image))
      |> Map.put(:listens, agreed(drawn, & &1.listens))
      |> Map.put(:published, agreed(drawn, & &1.published) || [])
      |> Map.put(:with, if(MapSet.member?(always, name), do: [], else: by[name] || []))
    end)
    |> Enum.sort_by(& &1.position)
  end

  defp agreed(faces, field) do
    case faces |> Enum.map(field) |> Enum.uniq() do
      [one] -> one
      _ -> nil
    end
  end

  # Which choices bring which service, asked of the cartridge one
  # choice at a time: a state holding a single value, and the compose
  # it gives. Asked, never guessed — the name in the file is the
  # compose's, not the choice's (ecto's four engines all come as one
  # `database`), and no rule over the words would know it.
  #
  # All of them per service, not one: ecto's `database` comes with any
  # of four engines and its `create` with mssql alone, and a reader
  # that only knew the first could not tell those apart.
  defp brought_by(_feature, nil), do: %{}

  defp brought_by(feature, %Igniter.Mix.Task.Info{schema: schema}) do
    choices = feature.choices()

    for {key, type} <- schema || [],
        value <- choice_values(Keyword.get(choices, key)),
        state = if(type == :csv, do: %{key => [value]}, else: %{key => value}),
        service <- WorkbenchIgniter.Compose.brought(feature, feature.services(state)) do
      {service.service, %{option: key, value: value}}
    end
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {name, brings_it} -> {name, Enum.uniq(brings_it)} end)
  end

  # The values of one option, flat: the sections opened out, the
  # open-ended list read through, each value by itself.
  defp choice_values(nil), do: []
  defp choice_values({:open, values}), do: choice_values(values)

  defp choice_values(values) do
    values
    |> choice_list()
    |> Enum.flat_map(fn
      %{group: _, values: grouped} -> grouped
      value -> [value]
    end)
    |> Enum.map(& &1.value)
  end

  @doc """
  Every catalog entry with `installed`: whether the given project
  carries the cartridge, asked of the cartridge itself (`installed?/1`)
  — and, when it does, `state`: what it carries of the options
  (`state/1`, meaningful for an `:adds` cartridge) — and `detected`:
  the defaults it would read off this project (`detect/1`). Returns the
  igniter too, as the checks include files in it.
  """
  @spec status(Igniter.t()) :: {[map()], Igniter.t()}
  def status(igniter) do
    Enum.map_reduce(catalog(), igniter, fn feature, igniter ->
      {installed?, igniter} = feature.installed?(igniter)
      {state, igniter} = if installed?, do: feature.state(igniter), else: {%{}, igniter}
      {detected, igniter} = feature.detect(igniter)

      {entry(feature)
       |> Map.put(:installed, installed?)
       |> Map.put(:state, state)
       |> Map.put(:detected, detected), igniter}
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

  @doc """
  What the cartridges' services contribute to a compose file rendered
  from `context` (`WorkbenchIgniter.Compose.context/1`): every
  cartridge's `compose/1`, in catalog order. Each cartridge answers for
  the names of its own that `context.services` asks for; a name no
  cartridge answers for contributes nothing. A cartridge may refuse the
  set instead — two databases — and its reason is the answer.
  """
  @spec compose(map()) ::
          {:ok, [WorkbenchIgniter.ComposeFile.Service.t()]} | {:error, String.t()}
  def compose(context) do
    Enum.reduce_while(catalog(), {:ok, []}, fn feature, {:ok, acc} ->
      case feature.compose(context) do
        {:error, reason} -> {:halt, {:error, reason}}
        services -> {:cont, {:ok, acc ++ services}}
      end
    end)
  end

  defp composes(nil), do: []

  defp composes(info) do
    for task <- info.composes || [],
        feature = Enum.find(catalog(), &(&1.task() == task)),
        do: feature.name()
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
  # their condition (or nil).
  defp console(spec) do
    %{doors: for(d <- Keyword.get(spec, :doors, []), do: door(d))}
  end

  defp door({label, path}), do: door({label, path, []})

  defp door({label, path, opts}) do
    when_ = condition(Keyword.get(opts, :when))

    case path do
      {:output, dir, index} ->
        %{
          label: label,
          path: dir <> "/",
          output: %{dir: dir, index: index, build: build(Keyword.get(opts, :build))},
          when: when_
        }

      path ->
        %{label: label, path: path, when: when_}
    end
  end

  defp format(nil), do: nil
  defp format({:integer, %Range{first: first, last: last}}), do: "integer #{first}..#{last}"
  defp format(name) when is_atom(name), do: to_string(name)

  # A dependency as the catalog carries it: the package, what it is
  # pinned to, and the options the tuple gives (`only`, `runtime`).
  defp dep({name, requirement}), do: %{name: to_string(name), requirement: requirement, opts: %{}}

  defp dep({name, requirement, opts}),
    do: %{
      name: to_string(name),
      requirement: requirement,
      opts: Map.new(opts, fn {k, v} -> {k, inspect(v)} end)
    }

  defp condition(nil), do: nil
  defp condition({:option, key}), do: %{option: to_string(key)}
  defp condition({:option, key, value}), do: %{option: to_string(key), value: value}
  defp condition({:cartridge, name}), do: %{cartridge: name}

  # How a page on disk is made: the project's Mix tasks that write it,
  # in the order they are tried, each with the condition that makes it
  # the one. `[]` for a page the cartridge does not say how to build.
  defp build(nil), do: []
  defp build(task) when is_binary(task), do: [%{task: task, when: nil}]
  defp build(candidates) when is_list(candidates), do: Enum.map(candidates, &candidate/1)

  defp candidate(task) when is_binary(task), do: %{task: task, when: nil}
  defp candidate({task, opts}), do: %{task: task, when: condition(Keyword.get(opts, :when))}

  defp options(nil, _feature), do: []

  defp options(%Igniter.Mix.Task.Info{schema: schema, defaults: defaults}, feature) do
    choices = feature.choices()
    docs = feature.option_docs()
    notes = feature.option_notes()
    formats = feature.formats()

    for {key, type} <- schema || [] do
      {open, values} =
        case Keyword.get(choices, key) do
          nil -> {false, nil}
          {:open, values} -> {true, values}
          values -> {false, values}
        end

      # A boolean's one declared value is what turning it on builds on,
      # the option's own `requires` and not a list to choose from.
      {values, on} =
        case {type, values} do
          {:boolean, [{true, _doc, _requires} = on]} -> {nil, choice_value(on)}
          _ -> {values, %{requires: [], conditions: %{}}}
        end

      %{
        name: key,
        type: type,
        default: Keyword.get(defaults || [], key),
        multiple: type == :csv,
        choices: choice_list(values),
        requires: on.requires,
        conditions: on.conditions,
        advises: advice(Keyword.get(feature.advises(), key)),
        open: open,
        detected: key in feature.detected(),
        # The shape the value has to have, where the type does not say
        # it: a form asks for that shape and says which it is.
        format: format(Keyword.get(formats, key)),
        doc: Keyword.get(docs, key),
        # What the option says that none of its values can.
        note: Keyword.get(notes, key)
      }
    end
  end

  # What a switch works fully only with, as a value's requirements are
  # carried, and why: nil for a switch with none.
  defp advice(nil), do: nil

  defp advice({requires, why}) do
    %{choice_value({true, nil, requires}) | doc: why}
    |> Map.delete(:value)
  end

  # Every value as %{value, doc, requires}, doc nil when the cartridge
  # gave none, requires the cartridges choosing it builds on (mostly
  # none); sections as %{group, values}.
  defp choice_list(nil), do: nil

  defp choice_list([{g, v} | _] = groups) when is_atom(g) and is_list(v),
    do: for({g, v} <- groups, do: %{group: g, values: choice_list(v)})

  defp choice_list(values), do: Enum.map(values, &choice_value/1)

  # A value's requirements as the cartridge's: the names as `requires`,
  # the states as `conditions` (ash's `--auth password` on html with live).
  defp choice_value({value, doc, requires}) do
    %{
      value: value,
      doc: doc,
      requires: Enum.map(requires, &requirement_name/1),
      conditions:
        for({name, state} <- requires, state != [], into: %{}, do: {name, Map.new(state)})
    }
  end

  defp choice_value({value, doc}), do: %{value: value, doc: doc, requires: [], conditions: %{}}
  defp choice_value(value), do: %{value: value, doc: nil, requires: [], conditions: %{}}

  defp requirement_name({name, _state}), do: name
  defp requirement_name(name) when is_binary(name), do: name

  @doc """
  The registered cartridge named `name`, or `nil`. The name is the one
  everything outside the package knows the cartridge by (`wb.sh add
  <name>`): its directory under `features/`.
  """
  @spec named(String.t()) :: module() | nil
  def named(name), do: Enum.find(@cartridges, &(&1.name() == name))
end
