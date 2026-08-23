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

  Features are registered, in composition order, in
  `WorkbenchIgniter.Features`.

  ## Cartridge modules

  A fully migrated feature is a directory under
  `lib/workbench_igniter/features/<name>/` holding the feature module
  (manifest + install logic), a thin `Mix.Tasks.Workbench.Install.<Name>`
  shell, and its EEx templates. `use WorkbenchIgniter.Feature` provides the
  manifest defaults and the `embed_templates/0` macro that compiles the
  cartridge's `templates/*.eex` files into a local `template/2` function.
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
          no_flags: 2
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

      defoverridable flag: 0, enabled?: 1, implies: 0, argv: 1, pending?: 0
    end
  end

  @doc """
  Embeds every `<dir>/**/*.eex` file next to the calling module as clauses
  of a local `template/2` function.

  Each file is read at compile time and registered as `@external_resource`,
  so editing a template recompiles the feature. Rendering semantics match
  `WorkbenchIgniter.template/2`: assigns are accessible as `@key` and the
  template is evaluated with `trim: true`.

      embed_templates()
      template("controller.eex", app_name: :demo)
  """
  defmacro embed_templates(dir \\ "templates") do
    quote bind_quoted: [dir: dir] do
      base = Path.join(Path.dirname(__ENV__.file), dir)
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
  Embeds every file under `<dir>/` next to the calling module as clauses
  of a local `asset/1` function returning the raw content — no EEx
  rendering, mirroring `WorkbenchIgniter.asset/1`. For files copied
  verbatim into the target project (e.g. report templates whose own
  `<%= %>` tags belong to the target).

  Each file is registered as `@external_resource`, so editing one
  recompiles the feature. Text-sized assets only; heavy binaries stay in
  `priv/features/<feature>/`.

  An asset named `*.ex` would be compiled by mix along with the package
  sources — store it with an extra `.asset` suffix (`cover.ex.asset`); the
  suffix is stripped from the asset key.

      embed_assets()
      asset("cover.ex")
      asset("template/coverage.html.eex")
  """
  defmacro embed_assets(dir \\ "assets") do
    quote bind_quoted: [dir: dir] do
      base = Path.join(Path.dirname(__ENV__.file), dir)
      paths = base |> Path.join("**") |> Path.wildcard() |> Enum.filter(&File.regular?/1)

      if paths == [] do
        raise ArgumentError, "no asset files found under #{base}"
      end

      for path <- paths do
        @external_resource path

        def asset(unquote(path |> Path.relative_to(base) |> String.replace_suffix(".asset", ""))) do
          unquote(File.read!(path))
        end
      end
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
