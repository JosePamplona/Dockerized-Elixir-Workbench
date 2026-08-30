defmodule WorkbenchIgniter.Feature do
  @moduledoc """
  Behaviour and conveniences for workbench feature cartridges.

  A *feature* is everything `workbench.setup` needs to know to orchestrate
  one workbench capability, declared in a single module instead of being
  spread across the setup task:

  * `task/0` - the `mix workbench.install.*` task that installs it.
  * `flag/0` / `enabled?/1` - when the setup options turn it on.
  * `implies/0` - flags this feature forces on (e.g. `openai` implies
    `auth0`).
  * `argv/1` - the arguments setup forwards when composing the task.
  * `pending?/0` - declared in setup's docs/templates but not ported yet.
  * `installed?/1` - whether the target project already carries it, read
    off the same mark the installer's guard reads.

  Features are registered, in composition order, in
  `WorkbenchIgniter.Features`; the standalone ones (never composed by
  setup) beside them, so the registry's catalog names every cartridge.
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

  @doc "Setup flag that toggles the feature, or `nil` when not flag-driven."
  @callback flag() :: atom() | nil

  @doc "Whether the normalized setup options enable the feature."
  @callback enabled?(opts :: keyword()) :: boolean()

  @doc "Flags this feature forces on when it is enabled."
  @callback implies() :: [atom()]

  @doc "Arguments setup forwards to `task/0` when composing it."
  @callback argv(opts :: keyword()) :: [String.t()]

  @doc "Feature is documented in the generated project but not ported yet."
  @callback pending?() :: boolean()

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
  @type value :: String.t() | {String.t(), String.t() | nil} | {String.t(), String.t() | nil, [String.t()]}
  @type choice :: [value()] | [{atom(), [value()]}] | {:open, [value()] | [{atom(), [value()]}]}

  @doc """
  One line per option of the installer, keyed as in the `info/2` schema:
  what it does, its default, its values. The one source of the task's
  "## Options" section — `options_doc/1` renders it into the task's
  `@moduledoc` — and of the help a form shows beside each field.
  """
  @callback option_docs() :: [{atom(), String.t()}]

  @doc """
  What turns the feature on when `workbench.setup` composes it: a setup
  flag (`:exdoc`), a flag it shares with others (`:enhance`, for the
  trivial group), a valued option (`{:interface, "rest"}`), or `nil` for
  a standalone cartridge. Defaults to `flag/0`; the cartridges whose
  `enabled?/1` reads something else say so.
  """
  @callback enabled_by() :: atom() | {atom(), String.t()} | nil

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
  project — for an `:adds` cartridge, so a form can show what is in
  and offer the rest. Keys are option names; values are what was found
  (a value, a list, or `true` for a piece whose detail is not readable
  from the project). Empty by default. Same shape as `installed?/1`:
  the returned igniter must not be discarded.
  """
  @callback state(igniter :: Igniter.t()) :: {map(), Igniter.t()}

  @doc """
  The cartridges that must be in the project before this one — by
  name, as the catalog names them — because what it installs builds on
  what they install (live on html: `phx.new` itself generates live only
  with html). The installer refuses with an issue naming the missing
  ones (`missing_requirements/2`); the catalog carries the list as
  `requires`. Empty by default.
  """
  @callback requires() :: [String.t()]

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

    * `doors:` — links on the app's port: `{label, path}` or
      `{label, path, when: condition}`, shown only when the condition
      holds: `{:with, value}` (the cartridge's `state/1` reports the
      value under `:with`), `{:cartridge, name}` (that cartridge is in).
    * `probes:` — paths the console polls and shows on the board:
      `{label, path}`; `{option}` in a path is the option's value as
      `state/1` reports it, or its default.
    * `tabs:` — screens the console shows only with this cartridge:
      `:cluster`.

  Empty by default. The catalog carries it as `console`.
  """
  @callback console() :: keyword()

  defmacro __using__(_opts) do
    quote do
      @behaviour WorkbenchIgniter.Feature

      import WorkbenchIgniter.Feature,
        only: [
          embed_templates: 0,
          embed_templates: 1,
          embed_assets: 0,
          embed_assets: 1,
          flags: 2,
          no_flags: 2,
          dep_installed?: 2,
          file_installed?: 2,
          marker_installed?: 3
        ]

      @impl WorkbenchIgniter.Feature
      def flag, do: nil

      @impl WorkbenchIgniter.Feature
      def enabled?(opts), do: WorkbenchIgniter.Feature.default_enabled?(__MODULE__, opts)

      @impl WorkbenchIgniter.Feature
      def implies, do: []

      @impl WorkbenchIgniter.Feature
      def argv(_opts), do: []

      @impl WorkbenchIgniter.Feature
      def pending?, do: false

      @impl WorkbenchIgniter.Feature
      def choices, do: []

      @impl WorkbenchIgniter.Feature
      def option_docs, do: []

      @impl WorkbenchIgniter.Feature
      def enabled_by, do: flag()

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

      defoverridable requires: 0,
                     afterwards: 0,
                     console: 0,
                     flag: 0,
                     enabled?: 1,
                     implies: 0,
                     argv: 1,
                     pending?: 0,
                     choices: 0,
                     option_docs: 0,
                     enabled_by: 0,
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
          EEx.eval_string(unquote(File.read!(path)), [assigns: assigns], trim: true)
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
  Which of the cartridges `feature.requires/0` names are not in the
  project, in that order — asked of each one's own `installed?/1`.
  Returns the igniter too, as the checks include files in it.
  """
  @spec missing_requirements(Igniter.t(), module()) :: {[String.t()], Igniter.t()}
  def missing_requirements(igniter, feature), do: missing_names(igniter, feature, feature.requires())

  @doc """
  What the chosen option values build on and is not in the project:
  `{option, value, missing}` per chosen value whose `{value, doc,
  requires}` entry in `choices/0` names a cartridge the project lacks.
  `opts` are the installer's parsed options (a value or a list per key).
  """
  @spec missing_option_requirements(Igniter.t(), module(), keyword()) ::
          {[{atom(), String.t(), [String.t()]}], Igniter.t()}
  def missing_option_requirements(igniter, feature, opts) do
    needs =
      for {key, choice} <- feature.choices(),
          chosen = List.wrap(Keyword.get(opts, key) || []),
          {value, requires} <- value_requirements(choice),
          value in chosen,
          do: {key, value, requires}

    Enum.reduce(needs, {[], igniter}, fn {key, value, requires}, {missing, igniter} ->
      case missing_names(igniter, feature, requires) do
        {[], igniter} -> {missing, igniter}
        {gone, igniter} -> {missing ++ [{key, value, gone}], igniter}
      end
    end)
  end

  defp value_requirements({:open, values}), do: value_requirements(values)

  defp value_requirements([{g, v} | _] = groups) when is_atom(g) and is_list(v),
    do: Enum.flat_map(groups, fn {_, v} -> value_requirements(v) end)

  defp value_requirements(values), do: for({value, _doc, requires} <- values, do: {value, requires})

  defp missing_names(igniter, feature, names) do
    Enum.reduce(names, {[], igniter}, fn name, {missing, igniter} ->
      required =
        Enum.find(WorkbenchIgniter.Features.catalog(), &(&1.name() == name)) ||
          raise ArgumentError, "#{feature.name()} requires an unknown cartridge: #{name}"

      case required.installed?(igniter) do
        {true, igniter} -> {missing, igniter}
        {false, igniter} -> {missing ++ [name], igniter}
      end
    end)
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
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
      {String.contains?(content, marker), igniter}
    else
      {false, igniter}
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
      flag = if type == :boolean and Keyword.get(defaults || [], key) == true, do: "--no-", else: "--"
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

  @doc false
  # Default enabled?/1: on when the feature's flag is set in the options.
  def default_enabled?(module, opts) do
    case module.flag() do
      nil -> false
      flag -> opts[flag] == true
    end
  end

  @doc """
  Maps the option keys that are set to `--key` switches, for forwarding
  feature toggles: `flags(opts, [:auth0, :health])` -> `["--auth0"]`.
  """
  @spec flags(keyword(), [atom()]) :: [String.t()]
  def flags(opts, keys) do
    for key <- keys, opts[key], do: "--#{key}"
  end

  @doc """
  Maps the option keys that are unset to `--no-key` switches, for options
  that default to true: `no_flags(opts, [:html])` -> `["--no-html"]`.
  """
  @spec no_flags(keyword(), [atom()]) :: [String.t()]
  def no_flags(opts, keys) do
    for key <- keys, !opts[key], do: "--no-#{key}"
  end
end
