defmodule WorkbenchIgniter.Feature do
  @moduledoc """
  Behaviour and conveniences for workbench feature cartridges.

  A *feature* is everything the workbench needs to know about one
  capability, declared in a single module — its manifest plus its
  install logic:

  * `task/0` - the `mix workbench.install.*` task that installs it.
  * `pending?/0` - documented, but its installer is not done yet.
  * `archived/0` - retired: its papers stay on the shelf, it is not
    offered for new projects.
  * `installed?/1` - whether the target project already carries it, read
    off the same mark the installer's guard reads.
  * `state/1` - what the project carries of its options, read off the
    project; required of every cartridge with options.
  * `ejected/1` - what its eject owes beyond the revert: what the
    insert left outside the tree, taken away.
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
  Why the cartridge was retired, in one line opening with the date
  (`"2026-09-20: db_admin's box covers it"`), or `nil` — the default —
  while it is current.

  A retired cartridge is *not* a deleted one: its papers, its CHANGELOG
  and its box stay where they are, because the reasoning that made it
  is worth reading after the box stops being offered. That is the whole
  point of the state — the shelf keeps the log. What changes is only
  what the workbench offers for a *new* project: `wb.sh add` refuses
  and names the flag that forces it anyway (`--archived`), the console
  shows the box unlit with this line as the reason, and nothing here
  touches a project that already carries it — `installed?/1`, `state/1`
  and `eject` answer exactly as before, because archiving is a fact of
  the box and being inserted is a fact of the project.

  The mirror of `pending?/0`: that one is *not yet* — no installer to
  run, so nothing can force it — and this one is *no longer*, the
  installer still working. `use WorkbenchIgniter.Feature` derives
  `archived?/0` from this, so the fact and its reason can never
  disagree.
  """
  @callback archived() :: String.t() | nil

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
  option takes other values too, and a form offers a field for them. A list of `{group, values}` pairs keeps the
  values in sections. A value is a
  string, a `{value, doc}` pair when one line can say what it does, or
  `{value, doc, requires}` when choosing it builds on other cartridges
  (ash's `--auth password` on live and mailer): the installer refuses
  with an issue while they are not in (`missing_option_requirements/3`)
  and the catalog carries them beside the value —
  the form shows it beside the choice.

      [data_layer: [{"postgres", "ash_postgres"}, {"none", "no data layer"}],
       auth: [{"password", "email and password", [{"html", live: true}, "mailer"]}]]

  A boolean switch has one value worth declaring, `true`, and declares
  it only for what turning it on builds on: credo's `--githook` writes
  its block into the hook the precommit cartridge owns, so
  `githook: [{true, doc, ["precommit"]}]`. The catalog carries that as
  the option's own `requires` rather than as a list of values, and the
  console shows the box unlit, with the reason, while the project lacks
  it.
  """
  @callback choices() :: [{atom(), choice()}]
  @type value ::
          String.t()
          | {true, String.t() | nil, [requirement()]}
          | {String.t(), String.t() | nil}
          | {String.t(), String.t() | nil, [String.t()]}
  @type choice :: [value()] | [{atom(), [value()]}] | {:open, [value()] | [{atom(), [value()]}]}

  @doc """
  The shape a string option's value has to have, by schema key — the
  option's *format*, which the type cannot say: `:url` (exdoc's
  repository and website, guidelines' page), `:version` (changelog's
  first release), `:dns_name` (clustering's query), `:route`
  (health_probe's prefix), `:dir` (a directory inside the project:
  exdoc's and coverage's output) or `{:integer, range}` (coverage's minimum).

  It is a fact of the option, declared once and read twice: the
  installer refuses a value that does not hold it — one message for
  every cartridge, `check_formats/2` before `install/1` — and the
  catalog carries it, so a form asks for that shape (a URL field, a
  number) and says which it is under the flag, where an unshaped string
  says `text`. A value the reader leaves empty is not checked: empty is
  *unasked*, and what unasked means is the cartridge's own.

  Empty by default: most options are a word the cartridge itself lists
  (`choices/0`), which it checks against that list.
  """
  @callback formats() :: [{atom(), format()}]

  @typedoc "What a value has to look like — see `c:formats/0`."
  @type format :: :url | :version | :dns_name | :route | :dir | {:integer, Range.t()}

  @doc """
  The options whose default is read off the project when not given —
  changelog's first version, clustering's DNS name, exdoc's name,
  repository and module groups — by their schema key. They carry no
  default in the schema, since the value is the project's; the catalog
  marks them `detected`, and `detect/1` says how each is found. Empty
  by default.
  """
  @callback detected() :: [atom()]

  @doc """
  The value each `detected/0` option takes on this project when it is
  not given, read the way the installer reads it — the installer takes
  its defaults from here, so what a form shows as the default is what
  the insert would write. Exactly `detected/0`'s keys; `nil` where the
  project says nothing and the installer falls back to a placeholder
  or refuses. Read off the project's source only: nothing is compiled
  or written. `mix workbench.status` carries it per cartridge as
  `detected`, and the console's form shows each as the field's
  placeholder. Same shape as `state/1`: the returned igniter must not
  be discarded.
  """
  @callback detect(igniter :: Igniter.t()) :: {map(), Igniter.t()}

  @doc """
  One line per option of the installer, keyed as in the `info/2` schema:
  what it does, its default, its values. The one source of the task's
  "## Options" section — `options_doc/1` renders it into the task's
  `@moduledoc` — and of the help a form shows under a field with no
  values to choose from (a value's own doc helps the others).
  """
  @callback option_docs() :: [{atom(), String.t()}]

  @doc """
  What an option says that none of its values can, keyed as in the
  `info/2` schema: what leaving it out means, what is out of it always.
  A form shows each value's own doc under its input, and this, when an
  option has one, under them all; `option_docs/0` stays the command
  line's, which lists the values the form already shows. Most options
  have none.
  """
  @callback option_notes() :: [{atom(), String.t()}]

  @doc """
  The options that only say how another one is done, by schema key:
  the switch each is a detail of. mishka_chelekom's `--mcp-path` is
  where `--mcp` forwards the server, and says nothing without it:

      [mcp_path: :mcp]

  A detail goes with its switch everywhere. The installer refuses one
  given without it; the catalog carries it as the option's `of`; and a
  form offers the field only while the switch is on — unlit, with the
  reason, otherwise — and, on a box that is in, while the switch is a
  piece it still adds. Empty by default.
  """
  @callback details() :: [{atom(), atom()}]

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
  What a second run can still put in, option by option: `:none` —
  nothing, so inserting it again changes nothing (the default) —,
  `:all`, when whatever it is asked for is a piece it adds while
  missing (ash: every option is a package; a collection: every option
  picks members; a cartridge with no options at all, which a second run
  completes), or the keys of the options a second run still adds, the
  rest having been fixed when it was inserted.

  It is what a form is locked by: a cartridge in whose `adds/0` is
  `:none` takes no more input at all, and one that names keys takes
  input on those alone. `rerun/0` is derived from it, so the two can
  never say different things.

      # coverage: the report and its theme were fixed at the insert;
      # the mix task and the hook block are added when missing.
      @impl WorkbenchIgniter.Feature
      def adds, do: [:md_report, :githook]
  """
  @callback adds() :: :none | :all | [atom()]

  @doc """
  `rerun/0` off `adds/0`: a cartridge that adds nothing on a second run
  is a no-op, and one that adds anything runs again. Derived so the two
  can never say different things.
  """
  @spec rerun_of(:none | :all | [atom()]) :: :noop | :adds
  def rerun_of(:none), do: :noop
  def rerun_of(_adds), do: :adds

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
  and `services/1` and `console/0`'s `{:option, key, value}` condition
  read it. Same shape as `installed?/1`: the returned igniter must not be
  discarded. The catalog test installs every cartridge with non-default
  values and checks the answer against the schema.
  """
  @callback state(igniter :: Igniter.t()) :: {map(), Igniter.t()}

  @doc """
  What must be in the project before this cartridge, because what it
  installs builds on it: cartridges by name, as the catalog names them
  (live on html: `phx.new` itself generates live only with html), and,
  when the name is not enough, the **state** the cartridge has to be
  in — `{"ecto", database: "postgres"}` for what administers Postgres
  and nothing else; a list of values asks for any one of them
  (`database: ["postgres", "mysql", "mssql"]`). The state is asked of the required
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

  @doc """
  What a switch works fully only with, without refusing it: by schema
  key, the cartridges turning it on is incomplete without, and why, in
  one line. html's `--live` configures LiveView on any project, and the
  browser connects to it through the `LiveSocket` in `assets/js/app.js`,
  which only esbuild brings:

      [live: {["esbuild"], "the LiveSocket lives in assets/js/app.js, which only esbuild brings"}]

  Unlike a requirement, it refuses nothing: `phx.new --no-esbuild`
  with live is a project `phx.new` makes, and another bundler can serve
  the client. The installer adds a notice while the project lacks it
  (`advise/3`); the catalog carries it as the option's `advises`, and
  the console says it beside the switch, the switch still lit. Empty by
  default.
  """
  @callback advises() :: [{atom(), {[requirement()], String.t()}}]
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
  What the cartridge's eject owes beyond its revert: the things its
  insert left **outside the tree**, which no commit carries and so no
  revert takes away — precommit's hook in `.git/hooks`, written by
  `git_hooks.install` as a task of the insert. Given the project's
  root, it takes them away with plain file operations and answers one
  line per thing it undid (`"removed .git/hooks/pre-commit"`), or
  nothing.

  `wb.sh eject` runs it after the revert is committed
  (`mix workbench.ejected`), never before: the revert is the decision,
  and it can still conflict and be abandoned. So by the time this runs
  the cartridge's code — its dependency, its configuration — is gone
  from the project, and whatever it needs has to be here, in the
  cartridge. It must be idempotent, and must leave alone what it cannot
  tell is its own. A failure does not undo the eject; the workbench
  says what was left.

  Nothing by default, and that is the rule: a cartridge keeps to the
  tree, where the revert is the whole eject. One that does not declares
  here how to undo it, beside the insert that did it.
  """
  @callback ejected(root :: Path.t()) :: [String.t()]

  @doc """
  What the cartridge adds to the console once it is in — the cartridge
  lights the console up. A keyword list of:

    * `doors:` — routes the project answers on the app's port once the
      cartridge is in, a health endpoint as much as a docs page:
      `{label, path}` or `{label, path, when: condition}`, shown only
      when the condition holds: `{:option, key}` (its `state/1`
      reports that option on), `{:option, key, value}` (its `state/1`
      reports that value for it — among its values, for a `:csv`
      option; a list of values asks for any one of them, as in
      `requires/0`), `{:cartridge, name}` (that cartridge is in). `{option}` in a path is the option's value
      as `state/1` reports it, or its default. The console reads them
      and calls them; it asks nothing of the project for its own sake —
      a route exists for the project's reasons, and the workbench only
      takes advantage of it. A door can be a page on disk instead,
      `{label, {:output, dir, index}}`: what a tool of the project
      writes for its reader (`{"docs", {:output, "doc", "index.html"}}`),
      which the console serves off the workspace on an origin of its
      own, so the project needs no route for it (console/README.md). A
      page on disk says how it is made, `build:`: the Mix task of the
      project that writes it (`build: "docs"`), so the console can
      offer it where the page is not there yet — it runs
      `./wb.sh mix <task>`, the project's own command, and never learns
      one of its own. Several, `[{task, when: condition}, …]`, when
      which command writes it depends on what the project carries
      (coverage: `mix cover` where it was inserted with `--md-report`, which
      is what plants that task, `mix coveralls.html` otherwise); the first whose condition holds
      is the one offered. A page says what it is made from too,
      `from:` — the files and directories of the project a change in
      which leaves the page behind (`from: ~w(lib test)` for a coverage
      report) — and the console compares their dates with the page's:
      up to date, or behind by so many files. Without it a page is
      written or missing, and no more is said. A route can be a door for a client and not a
      page, `client: [{label, line}, …]`: an endpoint a program talks
      to, which a browser opens onto an error (mishka_chelekom's
      `/mcp`). The console shows its address and does not link it,
      counts any answer to its call as the door answering, and offers
      each line with `{url}` filled with the address — the words are
      the cartridge's, and the console learns no protocol
      (`client: [{"Claude Code", "claude mcp add --transport http
      NAME {url}"}]`; `client: []` for an endpoint with nothing to
      say, as mishka_chelekom's, whose task writes what a client
      reads). With `build:`, the Mix task the cartridge
      planted in the project to set a client up — mishka_chelekom's
      `mix chelekom.mcp.json` — is offered beside the door, as a page's is;
      and with `writes:`, the file that task leaves at the project's
      root (`writes: ".mcp.json"`), the console says its state as it
      says a page's: missing, up to date while it carries the door's
      address, behind once the address moved.

  Empty by default. There was a `tabs:` too until 2026-09-25 — screens
  the console showed only with this cartridge, which only clustering
  ever used: its Cluster tab is a box under the scaled row of the
  Deploy screen now, and a cartridge contributes doors and nothing
  else. The catalog carries it as `console`.
  """
  @callback console() :: keyword()

  @doc """
  The dependencies the cartridge puts in the project's `mix.exs`, as
  the tuples `Igniter.Project.Deps.add_dep/3` is given — the same shape
  the installer writes, so the declaration and the writing cannot drift
  (the suite reads the installer's source and holds them together).

  Asked with the project's state (`state/1`) it answers the ones that
  project carries of it: test_doubles' `--double mimic,mox` is two
  packages and `--double mox` is one. Asked with `:any` it answers
  every package it may ever bring, which is what the shelf shows for a
  box nobody has inserted yet — *this is what it would add*. A
  cartridge that brings none says nothing, the default.

  What a project actually pins and what its lock file resolved are not
  here: those are the project's own, read off `mix.exs` and
  `mix.lock` by `mix workbench.status`, which puts them beside this.
  """
  @callback deps(state :: map() | :any) :: [tuple()]

  @doc """
  Where the packages an insert put in `mix.exs` came from, when the
  cartridge does not write them itself: one note per origin, each the
  sentence a reader is told and the packages it covers. `opts` are the
  options the insert went in with (its argv, parsed against the
  installer's schema, defaults in); `insert` is what its commit says —
  `added`, the packages it put in `mix.exs`, and `phx_new`, the version
  the project stamped at that commit.

  The cartridge says exactly what happened, since only it knows: ash
  queues `mix igniter.install`, which adds the packages the command
  names, and each of their installers may add more. A base cartridge's
  packages arrive inside the `phx.new` delta, and that is the default
  (`base_origins/2`); any other says nothing. A package no note covers
  is said plainly by `origins/3`, so no row is left without a reason.
  """
  @callback origins(opts :: keyword(), insert :: insert()) :: [{String.t(), [String.t()]}]
  @type insert :: %{added: [String.t()], phx_new: String.t() | nil}

  @doc """
  The compose services the cartridge needs the workspace to run, by
  name, given what the project carries of it (`state/1`): the workbench
  bakes them into the workspace's compose (`mix workbench.compose`,
  `WorkbenchIgniter.Compose`). A name is the cartridge's own — what it is in a
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
  be made of is refused with `{:error, reason}`. A deployment the
  project cannot have, being what it is — replicas, each on a SQLite
  file of its own — is answered with `{:unavailable, reason}` instead:
  nothing went wrong, there is no such file for this project, and the
  reason is shown as it is wherever the deployment would be. Nothing by
  default.
  """
  @callback compose(context :: map()) ::
              [WorkbenchIgniter.ComposeFile.Service.t()]
              | {:error, String.t()}
              | {:unavailable, String.t()}

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
          mix_project_value: 2,
          display_name: 1,
          repo_url: 1
        ]

      @impl WorkbenchIgniter.Feature
      def pending?, do: false

      @impl WorkbenchIgniter.Feature
      def archived, do: nil

      @doc "Whether the cartridge is retired: `archived/0` gave a reason."
      # `is_binary` and not `!= nil`: a cartridge that overrides
      # `archived/0` with its line has a literal for a body, and the type
      # checker reads the comparison as one that is always true.
      def archived?, do: is_binary(archived())

      @impl WorkbenchIgniter.Feature
      def members(_opts), do: []

      @impl WorkbenchIgniter.Feature
      def choices, do: []

      @impl WorkbenchIgniter.Feature
      def option_docs, do: []

      @impl WorkbenchIgniter.Feature
      def option_notes, do: []

      @impl true
      def details, do: []

      @impl WorkbenchIgniter.Feature
      def formats, do: []

      @impl WorkbenchIgniter.Feature
      def detected, do: []

      @impl WorkbenchIgniter.Feature
      def detect(igniter), do: {%{}, igniter}

      @impl WorkbenchIgniter.Feature
      def adds, do: :none

      @impl WorkbenchIgniter.Feature
      def rerun, do: WorkbenchIgniter.Feature.rerun_of(adds())

      @impl WorkbenchIgniter.Feature
      def state(igniter), do: {%{}, igniter}

      @impl WorkbenchIgniter.Feature
      def requires, do: []

      @impl WorkbenchIgniter.Feature
      def advises, do: []

      @impl WorkbenchIgniter.Feature
      def afterwards, do: nil

      @impl WorkbenchIgniter.Feature
      def console, do: []

      @impl WorkbenchIgniter.Feature
      def deps(_state), do: []

      @impl WorkbenchIgniter.Feature
      def origins(_opts, insert), do: WorkbenchIgniter.Feature.base_origins(__MODULE__, insert)

      @impl WorkbenchIgniter.Feature
      def services(_state), do: []

      @impl WorkbenchIgniter.Feature
      def compose(_context), do: []

      @impl WorkbenchIgniter.Feature
      def ejected(_root), do: []

      defoverridable requires: 0,
                     advises: 0,
                     deps: 1,
                     origins: 2,
                     services: 1,
                     compose: 1,
                     ejected: 1,
                     afterwards: 0,
                     console: 0,
                     pending?: 0,
                     archived: 0,
                     members: 1,
                     choices: 0,
                     option_docs: 0,
                     option_notes: 0,
                     details: 0,
                     formats: 0,
                     detected: 0,
                     detect: 1,
                     rerun: 0,
                     adds: 0,
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
  The cartridge's installer, run the way every insert runs it: the
  values checked against the shapes the manifest declares
  (`c:formats/0`), and `install/1` only when they hold. The one place
  a cross-cutting check goes, so a cartridge's own installer is what it
  writes and nothing else; every `task.ex` calls this.

  A value that does not hold its shape ends the run with an issue — the
  same sentence whichever cartridge and whichever option — and nothing
  is written: `WorkbenchIgniter.Task` exits non-zero on an issue, so
  `wb.sh add` makes no commit.
  """
  @spec install(module(), Igniter.t()) :: Igniter.t()
  def install(feature, igniter) do
    case check_formats(feature, igniter.args.options) do
      [] -> feature.install(igniter)
      issues -> Enum.reduce(issues, igniter, &Igniter.add_issue(&2, &1))
    end
  end

  @doc """
  What the given options break of the cartridge's declared shapes, one
  sentence each: the option, the shape it takes and the value that is
  not it. An option not given, or given empty, is not checked — empty
  is unasked, and what unasked means is the cartridge's own.
  """
  @spec check_formats(module(), keyword()) :: [String.t()]
  def check_formats(feature, opts) do
    for {key, format} <- feature.formats(),
        value = opts[key],
        is_binary(value),
        String.trim(value) != "",
        not holds_format?(value, format) do
      flag = "--" <> String.replace(to_string(key), "_", "-")
      "#{flag} takes #{shape(format)}, and #{inspect(value)} is not one."
    end
  end

  defp shape(:url), do: "a URL (https://example.com/page)"
  defp shape(:version), do: "a version (1.2.3)"
  defp shape(:dns_name), do: "a DNS name (app.default.svc.cluster.local)"
  defp shape(:route), do: "a path (/health)"
  defp shape(:dir), do: "a directory inside the project (priv/static/doc)"

  defp shape({:integer, %Range{first: first, last: last}}),
    do: "a whole number from #{first} to #{last}"

  # A browsable address: the scheme the browser opens it with, and a
  # host to open. Nothing of the rest is judged — a path, a port and a
  # query are the address's own business.
  defp holds_format?(value, :url) do
    case URI.parse(String.trim(value)) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] ->
        is_binary(host) and host != "" and not String.contains?(value, [" ", "\n", "\r", "\""])

      _ ->
        false
    end
  end

  # What Mix compiles as a project's version, which is what a changelog
  # opens at and what `mix version` writes back.
  defp holds_format?(value, :version), do: match?({:ok, _}, Version.parse(String.trim(value)))

  # Labels of letters, digits and dashes, each starting and ending in
  # one of the first two, up to the 253 a name is allowed.
  defp holds_format?(value, :dns_name) do
    value = String.trim(value)

    String.length(value) <= 253 and
      Regex.match?(
        ~r|^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*$|,
        value
      )
  end

  # Segments a URL carries as they are: no space, no query, no fragment.
  # The slashes around them are the cartridge's to trim.
  defp holds_format?(value, :route),
    do: Regex.match?(~r|^/*([A-Za-z0-9._~-]+/*)*$|, String.trim(value))

  # A directory of the project's own: relative, segments of plain
  # characters, none of them `..` — the console serves it off the
  # workspace, and a path that climbed out would serve something else.
  defp holds_format?(value, :dir) do
    value = value |> String.trim() |> String.trim_trailing("/")

    value != "" and not String.starts_with?(value, "/") and
      Regex.match?(~r|^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$|, value) and
      ".." not in String.split(value, "/")
  end

  defp holds_format?(value, {:integer, range}) do
    case Integer.parse(String.trim(value)) do
      {number, ""} -> number in range
      _ -> false
    end
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

  @doc """
  Each package an insert put in `mix.exs`, with the note that says
  where it came from: `%{name => sentence}`. `argv` is the insert's, as
  its commit subject carries it; parsed against the installer's schema
  with its defaults in, it is the cartridge's `origins/2` opts. A
  package the cartridge does not account for gets the plain sentence,
  which is true of any: it is in the commit and the box declares it not.
  """
  @spec origins(module(), [String.t()], insert()) :: %{String.t() => String.t()}
  def origins(feature, argv, %{added: added} = insert) do
    said =
      for {sentence, names} <- feature.origins(insert_opts(feature, argv), insert),
          name <- names,
          name in added,
          into: %{},
          do: {name, sentence}

    for name <- added, into: %{} do
      {name,
       said[name] ||
         "The cartridge declares no package: this one arrived with its insert commit."}
    end
  end

  defp insert_opts(feature, argv) do
    case feature.pending?() do
      true ->
        []

      false ->
        info = feature.info([], nil)
        # OptionParser knows no `:csv`: kept, and split on the commas.
        csv = for {key, :csv} <- info.schema, do: key

        switches =
          for {key, type} <- info.schema, do: {key, if(type == :csv, do: :keep, else: type)}

        {parsed, _rest, _invalid} =
          OptionParser.parse(argv, strict: switches, aliases: info.aliases)

        opts = Enum.reduce(csv, parsed, &split_csv/2)

        Keyword.merge(info.defaults, opts)
    end
  end

  # A `:csv` switch kept once per time it was given, as one list.
  defp split_csv(key, parsed) do
    case Keyword.get_values(parsed, key) do
      [] ->
        parsed

      values ->
        Keyword.put(parsed, key, Enum.flat_map(values, &String.split(&1, ",", trim: true)))
    end
  end

  @doc """
  The default `origins/2`: a base cartridge's packages arrive inside
  the `phx.new` delta (`WorkbenchIgniter.PhxDelta`), generated at the
  version the project stamped then; any other cartridge says nothing.
  """
  @spec base_origins(module(), insert()) :: [{String.t(), [String.t()]}]
  def base_origins(feature, %{added: added, phx_new: phx_new}) do
    if String.to_atom(feature.name()) in WorkbenchIgniter.PhxDelta.capabilities() do
      at = if phx_new, do: "phx.new " <> phx_new, else: "phx.new"

      [
        {"The cartridge does not install this package itself: it comes with #{at} — the difference " <>
           "between the project generated with the flag and without it — and the version is " <>
           "the one that installer writes.", added}
      ]
    else
      []
    end
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

      live builds on html, not in the project yet. Insert that first:
      ./wb.sh add html
  """
  @spec refuse(Igniter.t(), module(), [shortfall()]) :: Igniter.t()
  def refuse(igniter, feature, shortfalls),
    do: Igniter.add_issue(igniter, "#{feature.name()} builds on " <> lacking(shortfalls))

  @doc """
  The same refusal for chosen values (`missing_option_requirements/3`),
  one issue each, named by the switch:

      --admin pgadmin builds on ecto with database postgres, and this
      project's database is mysql.
  """
  @spec refuse_values(Igniter.t(), [{atom(), String.t(), [shortfall()]}]) :: Igniter.t()
  def refuse_values(igniter, missing) do
    Enum.reduce(missing, igniter, fn {key, value, shortfalls}, igniter ->
      Igniter.add_issue(igniter, "#{switch_said(key, value)} builds on " <> lacking(shortfalls))
    end)
  end

  @doc """
  One notice per switch turned on whose `advises/0` the project lacks,
  what it lacks and the line that brings it:

      --live is in without esbuild: the LiveSocket lives in
      assets/js/app.js, which only esbuild brings. Add it with:
      ./wb.sh add esbuild

  `opts` are the installer's options, with the switches' defaults in.
  """
  @spec advise(Igniter.t(), module(), keyword()) :: Igniter.t()
  def advise(igniter, feature, opts) do
    Enum.reduce(feature.advises(), igniter, fn {key, {requires, why}}, igniter ->
      case Keyword.get(opts, key) == true && shortfalls(igniter, feature, requires) do
        {[_ | _] = gone, igniter} ->
          Igniter.add_notice(
            igniter,
            "#{switch_said(key, true)} is in without " <>
              Enum.map_join(gone, " and ", &describe/1) <>
              ": #{why}. Add it with: " <> remedies(gone)
          )

        {[], igniter} ->
          igniter

        false ->
          igniter
      end
    end)
  end

  @doc """
  A requirement or a shortfall, said: `ecto`, `ecto with database
  postgres`, `html with live`, `ecto with database postgres, mysql or
  mssql`.
  """
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
  defp said({key, values}) when is_list(values), do: "#{key} #{any_of(values)}"
  defp said({key, value}), do: "#{key} #{value}"

  defp any_of([value]), do: value

  defp any_of(values),
    do: "#{values |> Enum.drop(-1) |> Enum.join(", ")} or #{List.last(values)}"

  defp switch({key, true}), do: "--#{flag(key)}"
  defp switch({key, false}), do: "--no-#{flag(key)}"
  # Any one of a list, as a usage line says it.
  defp switch({key, values}) when is_list(values), do: "--#{flag(key)} #{Enum.join(values, "|")}"
  defp switch({key, value}), do: "--#{flag(key)} #{value}"
  defp flag(key), do: key |> to_string() |> String.replace("_", "-")

  # A boolean is its flag alone: `--githook`, not `--githook true`.
  defp switch_said(key, true), do: "--#{flag(key)}"
  defp switch_said(key, value), do: "--#{flag(key)} #{value}"

  @doc """
  What is lacking, said after "NAME builds on": "html, not in the
  project yet. Insert that first: ./wb.sh add html"; "ecto with
  database postgres, and this project's database is mysql." — with the
  line that tops it up where the box adds its pieces on a second run
  ("coverage with md_report, and this project's md_report is off. Add
  it with: ./wb.sh add coverage --md-report"); and, with
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
        # A box that adds its pieces on a second run can be topped up
        # without going out first, so the line that does it is worth
        # saying; one whose options are fixed at the insert has no line
        # to offer, and the reading of the project is the whole answer.
        named <>
          ", and this project's " <>
          found_all(short) <>
          "." <> if(addable?(short), do: " Add it with: " <> remedies(short), else: "")

      _ ->
        named <>
          ": this project's " <>
          found_all(short) <>
          ", and " <>
          Enum.map_join(absent, " and ", &describe/1) <>
          " is not in yet. Insert that first: " <> remedies(short ++ absent)
    end
  end

  # Whether every box short of its state adds pieces on a second run
  # (`rerun/0`): asking it of the cartridge, as everything else here.
  defp addable?(short) do
    Enum.all?(short, fn {:short, name, _state, _key, _found} ->
      case WorkbenchIgniter.Features.named(name) do
        nil -> false
        feature -> feature.rerun() == :adds
      end
    end)
  end

  defp found_all(short),
    do:
      Enum.map_join(short, " and ", fn {:short, _, _, key, found} ->
        "#{key} is #{found(found)}"
      end)

  defp remedies(shortfalls),
    do: shortfalls |> Enum.map(&remedy/1) |> Enum.uniq() |> Enum.join(", then ")

  defp found([]), do: "none"
  defp found(values) when is_list(values), do: Enum.join(values, " and ")
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
          not met?(Map.get(has, key), expected),
          do: {:short, name, state, key, Map.get(has, key)}

    {missing ++ short, igniter}
  end

  # A list asks for any one of its values, and a state answered with a
  # list — a `:csv` option: test_doubles' doubles, db_admin's admins —
  # is met when it carries what was asked.
  defp met?(found, expected) when is_list(found) and is_list(expected),
    do: Enum.any?(found, &(&1 in expected))

  defp met?(found, expected) when is_list(found), do: expected in found
  defp met?(found, expected) when is_list(expected), do: found in expected
  defp met?(found, expected), do: found == expected

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
  The project's display name, as `{name, igniter}`: the `name:` its
  `mix.exs` already has — somebody wrote it, and it is not rewritten —
  or else the app's name made words, capitalized and spaced:
  `:lorem_ipsum` is `"Lorem Ipsum"`, `:lorem_3` is `"Lorem 3"`. An
  acronym comes out as a word (`:my_api` is `"My Api"`); the flag that
  asks for the name is how to say it otherwise.
  """
  @spec display_name(Igniter.t()) :: {String.t(), Igniter.t()}
  def display_name(igniter) do
    case mix_project_value(igniter, :name) do
      {name, igniter} when is_binary(name) and name != "" ->
        {name, igniter}

      {_, igniter} ->
        name =
          igniter
          |> Igniter.Project.Application.app_name()
          |> to_string()
          |> String.split("_", trim: true)
          |> Enum.map_join(" ", &String.capitalize/1)

        {name, igniter}
    end
  end

  @doc """
  The project's repository as a browsable URL, as `{url | nil, igniter}`:
  the `source_url:` its `mix.exs` already has, or else the `origin`
  remote of the project's own git repository (`git_origin/1`). `nil`
  when neither says it — the caller writes its placeholder. Under
  `Igniter.Test` the remote is not read: the suite runs inside the
  workbench's repository, whose remote is nobody's project.
  """
  @spec repo_url(Igniter.t()) :: {String.t() | nil, Igniter.t()}
  def repo_url(igniter) do
    case mix_project_value(igniter, :source_url) do
      {url, igniter} when is_binary(url) and url != "" ->
        {url, igniter}

      {_, igniter} ->
        if igniter.assigns[:test_mode?],
          do: {nil, igniter},
          else: {git_origin(File.cwd!()), igniter}
    end
  end

  @doc """
  The `origin` remote of the git repository rooted at `dir`, as an
  `https://` URL a browser opens; `nil` when `dir` is not the root of
  its own repository — a project directory inside another repository
  (a workspace under the workbench's) must not take that one's remote —
  when there is no `origin`, or when it is not a host/owner/repo address.
  """
  @spec git_origin(Path.t()) :: String.t() | nil
  def git_origin(dir) do
    # The prefix of `dir` within its repository is empty at the root.
    with {"\n", 0} <-
           System.cmd("git", ["-C", dir, "rev-parse", "--show-prefix"], stderr_to_stdout: true),
         {remote, 0} <- System.cmd("git", ["-C", dir, "config", "--get", "remote.origin.url"]) do
      browsable(String.trim(remote))
    else
      _ -> nil
    end
  end

  @doc """
  A git remote as the `https://` page of its repository:
  `git@github.com:acme/app.git`, `ssh://git@gitlab.com:2222/acme/app.git`
  and `https://user@github.com/acme/app.git` are all
  `https://<host>/acme/app`. `nil` for what is not host/owner/repo — a
  local path, a `file://` remote.
  """
  @spec browsable(String.t()) :: String.t() | nil
  def browsable(remote) do
    patterns = [
      ~r{^[\w.-]+@([\w.-]+):(?!//)(.+?)(?:\.git)?/?$},
      ~r{^(?:ssh|git|https?)://(?:[^@/]+@)?([\w.-]+)(?::\d+)?/(.+?)(?:\.git)?/?$}
    ]

    Enum.find_value(patterns, &page(Regex.run(&1, remote)))
  end

  # host and owner/repo — a subgroup's path included — as the page.
  defp page([_, host, path]), do: if(path =~ ~r{^[^/]+/[^/]+}, do: "https://#{host}/#{path}")
  defp page(nil), do: nil

  @doc """
  The literal a key of `mix.exs`'s `project/0` keyword holds — `:version`,
  `:name`, `:source_url` — as `{value, igniter}`; `nil` when the key is
  not there or its value is not a plain literal (a call, a variable).
  A module attribute holding a literal is read through: `version:
  @version` under `@version "1.2.3"`, as many a released project
  writes it, answers `"1.2.3"`.
  """
  @spec mix_project_value(Igniter.t(), atom()) :: {term() | nil, Igniter.t()}
  def mix_project_value(igniter, key) do
    igniter = Igniter.include_existing_file(igniter, "mix.exs")

    module =
      igniter.rewrite
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:quoted)
      |> Sourceror.Zipper.zip()

    value =
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(module, :project, 0),
           {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, key) do
        literal(zipper.node) || attribute_literal(module, zipper.node)
      else
        _ -> nil
      end

    {value, igniter}
  end

  defp literal({:__block__, _, [literal]}) when is_binary(literal) or is_number(literal),
    do: literal

  defp literal(_), do: nil

  # `@name` as a value: the literal its definition, `@name "..."`, holds.
  defp attribute_literal(module, {:@, _, [{name, _, context}]}) when is_atom(context) do
    found =
      Sourceror.Zipper.find(module, fn
        {:@, _, [{^name, _, [value]}]} -> literal(value) != nil
        _ -> false
      end)

    with %Sourceror.Zipper{node: {:@, _, [{_, _, [value]}]}} <- found, do: literal(value)
  end

  defp attribute_literal(_module, _node), do: nil

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
