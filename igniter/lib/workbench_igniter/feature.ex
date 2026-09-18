defmodule WorkbenchIgniter.Feature do
  @moduledoc """
  Behaviour and conveniences for workbench feature cartridges.

  A *feature* is everything the workbench needs to know about one
  capability, declared in a single module — its manifest plus its
  install logic:

  * `task/0` - the `mix workbench.install.*` task that installs it.
  * `pending?/0` - documented, but its installer is not done yet.
  * `installed?/1` - whether the target project already carries it, read
    off the same mark the installer's guard reads.
  * `state/1` - what the project carries of its options, read off the
    project; required of every cartridge with options.
  * `members/1` - for a *collection* cartridge: the cartridges it
    inserts, in order, with the argv each one gets.

  There is one kind of cartridge: every one is installed on demand
  (`wb.sh add <name>`), and a collection is just a cartridge whose
  installer inserts other cartridges. Features are registered in
  `WorkbenchIgniter.Features`, whose catalog names every cartridge.
  `use WorkbenchIgniter.Feature` also derives `name/0`, `version/0` and
  `summary/0` from the cartridge itself — its directory, its
  CHANGELOG.md and its task's `@shortdoc` — for the catalog.

  ## Cartridge modules

  A fully migrated feature is a directory under
  `lib/workbench_igniter/features/<name>/` holding only code: the feature
  module (manifest + install logic), a thin
  `Mix.Tasks.Workbench.Install.<Name>` shell, and its README. Everything
  that is not code — EEx templates, verbatim assets, binaries — lives
  under `priv/features/<name>/`. `use WorkbenchIgniter.Feature` provides
  the manifest defaults plus the `embed_templates/0` and `embed_assets/0`
  macros that compile those files into local `template/2` and `asset/1`
  functions.
  """

  @doc "Name of the mix task that installs the feature."
  @callback task() :: String.t()

  @doc "Documented in the generated project, but its installer is not done yet."
  @callback pending?() :: boolean()

  @doc """
  The cartridges a *collection* cartridge inserts, in order — by name,
  as the catalog names them, each with the argv its installer gets. The
  argv is the collection's recipe: how its choices (`opts`, parsed with
  the collection's own schema) shape each member's install. Membership
  may depend on the choices too (chiefs_setup inserts `rest` or
  `graphql` as `--interface` says). Empty by default: a plain cartridge
  inserts nothing but itself.
  """
  @callback members(opts :: keyword()) :: [{String.t(), [String.t()]}]

  @doc """
  Whether the feature is already installed in the target project.

  Read off the *same mark the installer's guard reads* — the module,
  file or dependency whose presence makes a re-run a no-op — so the
  guard and the status query can never disagree. Same shape as
  `Igniter.Project.Module.module_exists/2`: the returned igniter must
  not be discarded.
  """
  @callback installed?(igniter :: Igniter.t()) :: {boolean(), Igniter.t()}

  @doc """
  The values some of the installer's options take, for the catalog.

  `OptionParser` types say `:string` or `:csv`; this says which strings.
  A plain list is closed — the installer rejects anything else, the
  same list its validation reads. `{:open, list}` is a suggestion: the
  option takes other values too (`--with` takes any package). A list of
  `{group, values}` pairs keeps the values in sections. A value is a
  string, a `{value, doc}` pair when one line can say what it does, or
  `{value, doc, requires}` when choosing it builds on other cartridges
  (ash's `--auth password` on live and mailer): the installer refuses
  with an issue while they are not in (`missing_option_requirements/3`)
  and the catalog carries them beside the value —
  the form shows it beside the choice.

      [data_layer: [{"postgres", "ash_postgres"}, {"none", "no data layer"}],
       with: {:open, [ai: ~w(tidewave ash_ai)]}]
  """
  @callback choices() :: [{atom(), choice()}]
  @type value ::
          String.t()
          | {String.t(), String.t() | nil}
          | {String.t(), String.t() | nil, [String.t()]}
  @type choice :: [value()] | [{atom(), [value()]}] | {:open, [value()] | [{atom(), [value()]}]}

  @doc """
  One line per option of the installer, keyed as in the `info/2` schema:
  what it does, its default, its values. The one source of the task's
  "## Options" section — `options_doc/1` renders it into the task's
  `@moduledoc` — and of the help a form shows beside each field.
  """
  @callback option_docs() :: [{atom(), String.t()}]

  @doc """
  What a second run does on a project that already carries the
  cartridge: `:noop` — the installer's guard skips everything (the
  default; the options were fixed when it was inserted, and changing
  them means ejecting and inserting again) — or `:adds`, for a cartridge
  whose options are independent pieces the installer only adds when
  missing (ash: every option is a package), so running it again with
  more options grows what is installed.
  """
  @callback rerun() :: :noop | :adds

  @doc """
  What the project carries of the cartridge's options, read off the
  project. Required of every cartridge whose `info/2` declares a
  schema: the answer has exactly the schema's keys, one value per
  option, and only a cartridge without options keeps the `%{}` default.

  Each value is what was found, read off a mark the project has for
  its own sake — the route in its router, the key in its mix.exs, the
  file the installer wrote — never off a record kept for the workbench:
  a string, a list, `true`/`false` for a boolean. `nil` says the option
  leaves no mark the project keeps: a one-shot action (`--build` runs
  the suite once, its output is gitignored) or a flag the installer
  no longer reads. Say which, beside the read; do not guess a value.

  Four readers depend on the answer, so its silence is never neutral:
  `mix workbench.status` carries it, the console's Inserted list shows
  it as the line the cartridge went in with, a door's `{option}` path
  is filled from it (and falls back to the default when it is `nil`),
  and `services/1` and `console/0`'s `{:with, value}` condition read
  it. Same shape as `installed?/1`: the returned igniter must not be
  discarded. The catalog test installs every cartridge with non-default
  values and checks the answer against the schema.
  """
  @callback state(igniter :: Igniter.t()) :: {map(), Igniter.t()}

  @doc """
  What must be in the project before this cartridge, because what it
  installs builds on it: cartridges by name, as the catalog names them
  (live on html: `phx.new` itself generates live only with html), and,
  when the name is not enough, the **state** the cartridge has to be
  in — `{"ecto", database: "postgres"}` for pgadmin, which administers
  Postgres and nothing else. The state is asked of the required
  cartridge's own `state/1`, which reads the project as it is, born
  with it or inserted, so the requirement holds on a project that
  changed its mind since and never depends on what an insert was
  asked. The installer refuses with an issue that names what is
  missing and how to get it (`missing_requirements/2`, `refuse/3`);
  the catalog carries the names as `requires` and the states as
  `conditions`. Empty by default.
  """
  @callback requires() :: [requirement()]
  @type requirement :: String.t() | {String.t(), keyword()}
  @typedoc """
  What a requirement lacks in the project: the cartridge is not in
  (`:absent`, with the state it was asked for), or it is in and one key
  of its state is not what was asked (`:short`, with what was found).
  """
  @type shortfall ::
          {:absent, String.t(), keyword()} | {:short, String.t(), keyword(), atom(), term()}

  @doc """
  What follows the insert, when something does — one sentence with the
  command, for the catalog and whoever reads it (the console shows it
  in the box, beside what the cartridge builds on): ecto's `./wb.sh
  bake`, clustering's scaled deployment. `nil` by default: most
  cartridges are done when inserted.
  """
  @callback afterwards() :: String.t() | nil

  @doc """
  What the cartridge adds to the console once it is in — the cartridge
  lights the console up. A keyword list of:

    * `doors:` — routes the project answers on the app's port once the
      cartridge is in, a health endpoint as much as a docs page:
      `{label, path}` or `{label, path, when: condition}`, shown only
      when the condition holds: `{:with, value}` (the cartridge's
      `state/1` reports the value under `:with`), `{:cartridge, name}`
      (that cartridge is in). `{option}` in a path is the option's value
      as `state/1` reports it, or its default. The console reads them
      and calls them; it asks nothing of the project for its own sake —
      a route exists for the project's reasons, and the workbench only
      takes advantage of it.
    * `tabs:` — screens the console shows only with this cartridge:
      `:cluster`.

  Empty by default. The catalog carries it as `console`.
  """
  @callback console() :: keyword()

  @doc """
  The compose services the cartridge needs the workspace to run, by
  name, given what the project carries of it (`state/1`): the workbench
  bakes them into the workspace's compose (`mix workbench.compose`,
  scripts/PLAN.md). A name is the cartridge's own — what it is in a
  compose file is said by the same cartridge, in `compose/1` — and it
  is also what the status reports and what a neighbour asks about
  (`"prometheus"`, for k6). A cartridge that needs no container says
  nothing — the default. Asked with `:any` instead of a state, it
  answers every name it may ever ask by (ecto: one per engine), which
  is how the workbench knows the images of the house without a project.
  """
  @callback services(state :: map() | :any) :: [String.t()]

  @doc """
  What the cartridge's services are, in a compose file: for each name
  of `services/1` that `context.services` asks for, what it contributes
  to the file being rendered (`WorkbenchIgniter.ComposeFile.Service`) —
  its block, the ports it publishes, what the app waits for, mounts and
  is told because of it, its volumes and configs. The definition is the
  cartridge's own, whole: its fragments live under
  `priv/features/<name>/compose/` (`embed_compose/0`), and nothing about
  the service is written anywhere else.

  `context` is what the file is rendered from
  (`WorkbenchIgniter.Compose.context/2`): the deployment (`deploy`,
  `dev`, `topology`), the project (`app_name`, `image`, `dockerfile`,
  `uid`, `gid`, `internal_port`), the topology's own (`replicas`,
  `balancer`, `clustering`), `version` — the image tag handed over for
  a name, or the default the cartridge gives —, `host_ports` and
  `services`, every name asked for, so a service can see its
  neighbours: k6 writes to Prometheus when it is there, Adminer asks
  ecto which database the project has. A set of services no file can
  be made of is refused with `{:error, reason}`. Nothing by default.
  """
  @callback compose(context :: map()) ::
              [WorkbenchIgniter.ComposeFile.Service.t()] | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour WorkbenchIgniter.Feature

      import WorkbenchIgniter.Feature,
        only: [
          embed_templates: 0,
          embed_templates: 1,
          embed_assets: 0,
          embed_assets: 1,
          embed_compose: 0,
          dep_installed?: 2,
          file_installed?: 2,
          marker_installed?: 3,
          file_content: 2,
          mix_project_value: 2
        ]

      @impl WorkbenchIgniter.Feature
      def pending?, do: false

      @impl WorkbenchIgniter.Feature
      def members(_opts), do: []

      @impl WorkbenchIgniter.Feature
      def choices, do: []

      @impl WorkbenchIgniter.Feature
      def option_docs, do: []

      @impl WorkbenchIgniter.Feature
      def rerun, do: :noop

      @impl WorkbenchIgniter.Feature
      def state(igniter), do: {%{}, igniter}

      @impl WorkbenchIgniter.Feature
      def requires, do: []

      @impl WorkbenchIgniter.Feature
      def afterwards, do: nil

      @impl WorkbenchIgniter.Feature
      def console, do: []

      @impl WorkbenchIgniter.Feature
      def services(_state), do: []

      @impl WorkbenchIgniter.Feature
      def compose(_context), do: []

      defoverridable requires: 0,
                     services: 1,
                     compose: 1,
                     afterwards: 0,
                     console: 0,
                     pending?: 0,
                     members: 1,
                     choices: 0,
                     option_docs: 0,
                     rerun: 0,
                     state: 1

      # The cartridge directory name names its `priv/features/<name>/`
      # directory, where its templates, assets and binaries live, and is
      # the name everything outside the package knows it by (`wb.sh add
      # <name>`, `assets/covers/<name>/`).
      @cartridge_dir Path.dirname(__ENV__.file)
      @feature_name Path.basename(@cartridge_dir)

      @doc "The cartridge's name: its directory under `features/`."
      def name, do: @feature_name

      @doc """
      The cartridge's current version and date, `{"0.1.0", "2026-08-28"}`,
      read off the first entry of its CHANGELOG.md — the one source, so
      nothing says a version the cartridge does not. `nil` while the
      cartridge has no changelog yet.
      """
      def version, do: WorkbenchIgniter.Feature.changelog_version(@cartridge_dir)

      @doc "One line on what the cartridge installs: its task's `@shortdoc`."
      def summary, do: WorkbenchIgniter.Feature.shortdoc(task())

      @doc """
      The developer's need the cartridge answers, in one line — the
      first paragraph of its NEED.md, the sentence the shelf shows —
      and the whole file's body beside it: `{line, body}`, or `nil`
      while the cartridge has no NEED.md. Read off the file, so the
      shelf, the console and the box art say the same thing.
      """
      def need, do: WorkbenchIgniter.Feature.need(@cartridge_dir)

      @doc false
      def priv_asset(path), do: WorkbenchIgniter.feature_asset(@feature_name, path)

      @doc false
      def plant_binary_asset(igniter, asset, target),
        do: WorkbenchIgniter.plant_binary_asset(igniter, @feature_name, asset, target)
    end
  end

  @doc """
  Embeds every `priv/features/<feature>/<dir>/**/*.eex` file of the
  calling cartridge as clauses of a local `template/2` function.

  Each file is read at compile time and registered as `@external_resource`,
  so editing a template recompiles the feature. Rendering semantics match
  `WorkbenchIgniter.template/2`: assigns are accessible as `@key` and the
  template is evaluated with `trim: true`.

      embed_templates()
      template("controller.eex", app_name: :demo)
  """
  defmacro embed_templates(dir \\ "templates") do
    quote bind_quoted: [dir: dir] do
      base = WorkbenchIgniter.Feature.priv_dir(__ENV__.file, dir)
      paths = Path.wildcard(Path.join(base, "**/*.eex"))

      if paths == [] do
        raise ArgumentError, "no .eex templates found under #{base}"
      end

      for path <- paths do
        @external_resource path
        def template(unquote(Path.relative_to(path, base)), assigns) do
          # Compiled here and evaluated apart, not `EEx.eval_string/3`: that
          # one hands its options on to `Code.eval_quoted/3`, whose success
          # typing has no `:trim`, and dialyzer then reads every installer
          # rendering a template as code that never returns.
          {rendered, _binding} =
            unquote(File.read!(path))
            |> EEx.compile_string(trim: true)
            |> Code.eval_quoted(assigns: assigns)

          rendered
        end
      end
    end
  end

  @doc """
  Embeds every `priv/features/<feature>/compose/**/*.eex` file of the
  calling cartridge as clauses of a local `compose_fragment/2`: the YAML
  its services contribute to a compose file (`compose/1`), by topology —
  `pod/<service>.yml.eex`, `scaled/<service>.yml.eex`, and
  `<service>.configs.yml.eex` for its top-level entries.

  Unlike `embed_templates/0` nothing is trimmed: a fragment is YAML as
  it goes into the file, its control tags placed so that a branch that
  is out leaves no line behind (at the end of the line before, and at
  the end of the branch's last line). The file's final newline is not
  part of the fragment. `context` is `compose/1`'s, read as `@key`.

      embed_compose()
      compose_fragment("pod/pgadmin.yml.eex", context)
  """
  defmacro embed_compose do
    # bind_quoted, as the two above: it is what lets the clauses below
    # unquote the paths found when the cartridge compiles.
    quote bind_quoted: [dir: "compose"] do
      base = WorkbenchIgniter.Feature.priv_dir(__ENV__.file, dir)
      paths = Path.wildcard(Path.join(base, "**/*.eex"))

      if paths == [] do
        raise ArgumentError, "no .eex fragments found under #{base}"
      end

      for path <- paths do
        @external_resource path
        def compose_fragment(unquote(Path.relative_to(path, base)), context) do
          {rendered, _binding} =
            unquote(File.read!(path))
            |> EEx.compile_string()
            |> Code.eval_quoted(assigns: Map.to_list(context))

          String.trim_trailing(rendered, "\n")
        end
      end
    end
  end

  @doc """
  Embeds every file under `priv/features/<feature>/<dir>/` of the calling
  cartridge as clauses of a local `asset/1` function returning the raw
  content — no EEx rendering. For files copied verbatim into the target
  project (e.g. report templates whose own `<%= %>` tags belong to the
  target). Living in `priv/`, they are never compiled, so an Elixir asset
  is stored under its final name (`cover.ex`).

  Each file is registered as `@external_resource`, so editing one
  recompiles the feature. Text assets only; binaries live beside them in
  `priv/features/<feature>/` (e.g. `images/`), read at runtime with
  `priv_asset/1` or planted with `plant_binary_asset/3`.

      embed_assets()
      asset("cover.ex")
      asset("template/exdoc-ish/coverage.html.eex")
  """
  defmacro embed_assets(dir \\ "assets") do
    quote bind_quoted: [dir: dir] do
      base = WorkbenchIgniter.Feature.priv_dir(__ENV__.file, dir)
      paths = base |> Path.join("**") |> Path.wildcard() |> Enum.filter(&File.regular?/1)

      if paths == [] do
        raise ArgumentError, "no asset files found under #{base}"
      end

      for path <- paths do
        @external_resource path

        def asset(unquote(Path.relative_to(path, base))) do
          unquote(File.read!(path))
        end
      end
    end
  end

  @doc false
  # Compile-time path of a cartridge's `priv/features/<name>/<dir>`: the
  # cartridge module lives at `lib/workbench_igniter/features/<name>/`,
  # four levels below the package root, whatever the compiling cwd is.
  def priv_dir(cartridge_file, dir) do
    feature = cartridge_file |> Path.dirname() |> Path.basename()

    [Path.dirname(cartridge_file), "../../../..", "priv/features", feature, dir]
    |> Path.join()
    |> Path.expand()
  end

  @doc """
  What `feature.requires/0` asks for and the project lacks, in that
  order: each requirement asked of the required cartridge's own
  `installed?/1`, and, when it names a state, of its `state/1`.
  Returns the igniter too, as the checks include files in it.
  """
  @spec missing_requirements(Igniter.t(), module()) :: {[shortfall()], Igniter.t()}
  def missing_requirements(igniter, feature),
    do: shortfalls(igniter, feature, feature.requires())

  @doc """
  What the chosen option values build on and the project lacks:
  `{option, value, shortfalls}` per chosen value whose `{value, doc,
  requires}` entry in `choices/0` names a requirement the project does
  not meet. `opts` are the installer's parsed options (a value or a
  list per key).
  """
  @spec missing_option_requirements(Igniter.t(), module(), keyword()) ::
          {[{atom(), String.t(), [shortfall()]}], Igniter.t()}
  def missing_option_requirements(igniter, feature, opts) do
    needs =
      for {key, choice} <- feature.choices(),
          chosen = List.wrap(Keyword.get(opts, key) || []),
          {value, requires} <- value_requirements(choice),
          value in chosen,
          do: {key, value, requires}

    Enum.reduce(needs, {[], igniter}, fn {key, value, requires}, {missing, igniter} ->
      case shortfalls(igniter, feature, requires) do
        {[], igniter} -> {missing, igniter}
        {gone, igniter} -> {missing ++ [{key, value, gone}], igniter}
      end
    end)
  end

  @doc "The names `requires/0` asks for, without their states."
  @spec requires_names(module()) :: [String.t()]
  def requires_names(feature), do: Enum.map(feature.requires(), &requirement_name/1)

  @doc ~S|The states `requires/0` asks for, by name: `%{"ecto" => %{database: "postgres"}}`.|
  @spec conditions(module()) :: %{String.t() => map()}
  def conditions(feature) do
    for {name, state} <- feature.requires(), state != [], into: %{}, do: {name, Map.new(state)}
  end

  @doc """
  The one issue that refuses an insert for what it lacks: what the
  cartridge builds on, what is not in and how to insert it, what is in
  and not as asked. Every cartridge's refusal reads the same way.

      pgadmin builds on ecto with database postgres, and this project's
      database is mysql.
      live builds on html, not in the project yet. Insert that first:
      ./wb.sh add html
  """
  @spec refuse(Igniter.t(), module(), [shortfall()]) :: Igniter.t()
  def refuse(igniter, feature, shortfalls),
    do: Igniter.add_issue(igniter, "#{feature.name()} builds on " <> lacking(shortfalls))

  @doc "A requirement or a shortfall, said: `ecto`, `ecto with database postgres`, `html with live`."
  @spec describe(requirement() | shortfall()) :: String.t()
  def describe(name) when is_binary(name), do: name
  def describe({name, []}), do: name
  def describe({name, state}), do: "#{name} with #{Enum.map_join(state, " and ", &said/1)}"
  def describe({:absent, name, state}), do: describe({name, state})
  def describe({:short, name, state, _key, _found}), do: describe({name, state})

  @doc """
  The `wb.sh add` line that brings a requirement in, its state as the
  installer's switches — the same line for what is in but short of the
  state, since a second run adds the piece (`rerun: :adds`).
  """
  @spec remedy(shortfall() | requirement()) :: String.t()
  def remedy({:absent, name, state}), do: remedy({name, state})
  def remedy({:short, name, state, _key, _found}), do: remedy({name, state})
  def remedy(name) when is_binary(name), do: "./wb.sh add #{name}"

  def remedy({name, state}),
    do: Enum.join(["./wb.sh add #{name}" | Enum.map(state, &switch/1)], " ")

  defp said({key, true}), do: to_string(key)
  defp said({key, false}), do: "no #{key}"
  defp said({key, value}), do: "#{key} #{value}"

  defp switch({key, true}), do: "--#{flag(key)}"
  defp switch({key, false}), do: "--no-#{flag(key)}"
  defp switch({key, value}), do: "--#{flag(key)} #{value}"
  defp flag(key), do: key |> to_string() |> String.replace("_", "-")

  @doc """
  What is lacking, said after "NAME builds on": "html, not in the
  project yet. Insert that first: ./wb.sh add html"; "ecto with
  database postgres, and this project's database is mysql."; and, with
  both kinds, "html with live and mailer: this project's live is off,
  and mailer is not in yet. Insert that first: ./wb.sh add html --live,
  then ./wb.sh add mailer".
  """
  @spec lacking([shortfall()]) :: String.t()
  def lacking(shortfalls) do
    absent = for {:absent, _, _} = s <- shortfalls, do: s
    short = for {:short, _, _, _, _} = s <- shortfalls, do: s
    named = Enum.map_join(shortfalls, " and ", &describe/1)

    case {absent, short} do
      {_, []} ->
        named <> ", not in the project yet. Insert that first: " <> remedies(absent)

      {[], _} ->
        named <> ", and this project's " <> found_all(short) <> "."

      _ ->
        named <>
          ": this project's " <>
          found_all(short) <>
          ", and " <>
          Enum.map_join(absent, " and ", &describe/1) <>
          " is not in yet. Insert that first: " <> remedies(short ++ absent)
    end
  end

  defp found_all(short),
    do:
      Enum.map_join(short, " and ", fn {:short, _, _, key, found} ->
        "#{key} is #{found(found)}"
      end)

  defp remedies(shortfalls),
    do: shortfalls |> Enum.map(&remedy/1) |> Enum.uniq() |> Enum.join(", then ")

  defp found(nil), do: "not set"
  defp found(false), do: "off"
  defp found(true), do: "on"
  defp found(value), do: to_string(value)

  defp requirement_name({name, _state}), do: name
  defp requirement_name(name) when is_binary(name), do: name

  defp value_requirements({:open, values}), do: value_requirements(values)

  defp value_requirements([{g, v} | _] = groups) when is_atom(g) and is_list(v),
    do: Enum.flat_map(groups, fn {_, v} -> value_requirements(v) end)

  defp value_requirements(values),
    do: for({value, _doc, requires} <- values, do: {value, requires})

  defp shortfalls(igniter, feature, requirements) do
    Enum.reduce(requirements, {[], igniter}, fn requirement, {missing, igniter} ->
      {name, state} = normalize(requirement)

      required =
        Enum.find(WorkbenchIgniter.Features.catalog(), &(&1.name() == name)) ||
          raise ArgumentError, "#{feature.name()} requires an unknown cartridge: #{name}"

      case required.installed?(igniter) do
        {false, igniter} -> {missing ++ [{:absent, name, state}], igniter}
        {true, igniter} when state == [] -> {missing, igniter}
        {true, igniter} -> short_of(igniter, required, name, state, missing)
      end
    end)
  end

  # The keys of the state asked that the cartridge's own state does not
  # meet, each a `:short` with what was found.
  defp short_of(igniter, required, name, state, missing) do
    {has, igniter} = required.state(igniter)

    short =
      for {key, expected} <- state,
          Map.get(has, key) != expected,
          do: {:short, name, state, key, Map.get(has, key)}

    {missing ++ short, igniter}
  end

  defp normalize({name, state}) when is_binary(name) and is_list(state), do: {name, state}
  defp normalize(name) when is_binary(name), do: {name, []}

  @doc """
  The content of a file of the project, for `state/1` to read a mark
  off: `{content, igniter}`, `nil` when the file is not there. The
  file joins the igniter's rewrite, as `installed?/1`'s checks do, so
  the returned igniter must not be discarded.
  """
  @spec file_content(Igniter.t(), Path.t()) :: {String.t() | nil, Igniter.t()}
  def file_content(igniter, path) do
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      {igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content), igniter}
    else
      {nil, igniter}
    end
  end

  @doc """
  The literal a key of `mix.exs`'s `project/0` keyword holds — `:version`,
  `:name`, `:source_url` — as `{value, igniter}`; `nil` when the key is
  not there or its value is not a plain literal (a call, a variable).
  """
  @spec mix_project_value(Igniter.t(), atom()) :: {term() | nil, Igniter.t()}
  def mix_project_value(igniter, key) do
    igniter = Igniter.include_existing_file(igniter, "mix.exs")

    zipper =
      igniter.rewrite
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:quoted)
      |> Sourceror.Zipper.zip()

    value =
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :project, 0),
           {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, key),
           {:__block__, _, [literal]} when is_binary(literal) or is_number(literal) <-
             zipper.node do
        literal
      else
        _ -> nil
      end

    {value, igniter}
  end

  @doc """
  `installed?/1` for a cartridge whose mark is a dependency in `mix.exs`.
  """
  @spec dep_installed?(Igniter.t(), atom()) :: {boolean(), Igniter.t()}
  def dep_installed?(igniter, dep) when is_atom(dep) do
    {Igniter.Project.Deps.has_dep?(igniter, dep), igniter}
  end

  @doc """
  `installed?/1` for a cartridge whose mark is a file it creates.
  """
  @spec file_installed?(Igniter.t(), Path.t()) :: {boolean(), Igniter.t()}
  def file_installed?(igniter, path) do
    {Igniter.exists?(igniter, path), igniter}
  end

  @doc """
  `installed?/1` for a cartridge whose mark is a line it appends to a
  file it does not own (clustering's block in `rel/env.sh.eex`).
  """
  @spec marker_installed?(Igniter.t(), Path.t(), String.t()) :: {boolean(), Igniter.t()}
  def marker_installed?(igniter, path, marker) do
    case file_content(igniter, path) do
      {nil, igniter} -> {false, igniter}
      {content, igniter} -> {String.contains?(content, marker), igniter}
    end
  end

  @doc """
  The "## Options" list of a task's `@moduledoc`, rendered from the
  cartridge's `option_docs/0` in the order of its `info/2` schema: one
  bullet per option, `--no-key` for a boolean that defaults to true.
  Empty when the installer takes no options.
  """
  @spec options_doc(module()) :: String.t()
  def options_doc(feature) do
    docs = feature.option_docs()
    %{schema: schema, defaults: defaults} = feature.info([], nil)

    for {key, type} <- schema || [], doc = docs[key] do
      flag =
        if type == :boolean and Keyword.get(defaults || [], key) == true, do: "--no-", else: "--"

      "* `#{flag}#{String.replace(to_string(key), "_", "-")}` - #{doc}"
    end
    |> Enum.map_join("\n", &wrap_bullet/1)
  end

  # A bullet wrapped at 72 columns, continuation lines indented two,
  # as the sections were written by hand.
  defp wrap_bullet(text) do
    text
    |> String.split(" ")
    |> Enum.reduce([], fn
      word, [] ->
        [word]

      word, [line | rest] ->
        if String.length(line) + 1 + String.length(word) > 72,
          do: ["  " <> word, line | rest],
          else: [line <> " " <> word | rest]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  @doc false
  # The first entry of a cartridge's CHANGELOG.md, `## v0.1.0 - (2026-08-28)`,
  # as {version, date}; the same line covers.py reads for the back.
  def changelog_version(cartridge_dir) do
    path = Path.join(cartridge_dir, "CHANGELOG.md")

    with true <- File.regular?(path),
         [_, version, date] <-
           Regex.run(~r/^## v?(\S+?)\s*-\s*\((\d{4}-\d{2}-\d{2})\)/m, File.read!(path)) do
      {version, date}
    else
      _ -> nil
    end
  end

  @doc false
  # A cartridge's NEED.md as {line, body}: the line is the first
  # paragraph after the title — the situation in one sentence, what the
  # shelf shows — and the body the file from that paragraph on. The
  # file's shape is fixed by features/README.md: a title, the sentence,
  # then **Before:**, **After:** and **Not for:** paragraphs.
  def need(cartridge_dir) do
    path = Path.join(cartridge_dir, "NEED.md")

    with true <- File.regular?(path),
         body = path |> File.read!() |> String.replace(~r/\A#[^\n]*\n+/, "") |> String.trim(),
         [line | _] <- String.split(body, ~r/\n\s*\n/, parts: 2),
         line = line |> String.split("\n") |> Enum.map_join(" ", &String.trim/1),
         false <- line == "" do
      {line, body}
    else
      _ -> nil
    end
  end

  @doc false
  # The @shortdoc of a mix task, by name; nil when the task has none or
  # is not compiled in (a pending cartridge has no task module).
  def shortdoc(task) do
    case Mix.Task.get(task) do
      nil -> nil
      module -> Mix.Task.shortdoc(module)
    end
  end
end
