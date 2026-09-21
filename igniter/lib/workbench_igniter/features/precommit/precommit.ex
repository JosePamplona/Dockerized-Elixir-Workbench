defmodule WorkbenchIgniter.Features.Precommit do
  @moduledoc """
  The checks that run before the commit exists, in the workspace's own
  container.

  The box is three things, and the third is the one that makes it a box
  rather than an option of somebody else:

    * the dependency, `git_hooks`, which writes `.git/hooks/pre-commit`
      when the dev dependencies compile and takes it away again when the
      configuration goes;
    * `.githooks/mix`, the host's way in — the hook runs on the machine
      that commits, and that machine has Docker and nothing else, so
      `mix` there means `docker compose exec app mix`;
    * `.githooks/pre-commit`, the ordered list of checks, where **every
      cartridge owns a block** (`WorkbenchIgniter.BlockFile`) and the
      first failure cuts the rest.

  Its own options are the checks that belong to no cartridge — the
  formatter, the compiler's warnings, the suite, the unused
  dependencies. Nobody installs `mix format`; it comes with Elixir, and
  a shelf where the hook is an option of credo would be a shelf that
  can run Credo before a commit and not the formatter.

  A cartridge that brings a check of its own does not write here by
  hand: it composes this installer and calls `check/4`, the way
  coveralls composes test_doubles for the double its tests need. credo
  and coveralls do (`--githook`), each owning its block, so ejecting
  either leaves the other's checks standing.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.BlockFile

  embed_assets()

  @dep {:git_hooks, "~> 0.7", only: :dev, runtime: false}

  @hook ".githooks/pre-commit"
  @runner ".githooks/mix"

  # The line the skeleton carries between the two stages: a block is
  # born above it (`:fast`) or below it (`:slow`, the default for a
  # cartridge that does not say). It is a comment the project's reader
  # sees, and moving a block past it is theirs to do — BlockFile
  # replaces a block where it stands.
  @slow_anchor "# --- slow:"

  # The checks that belong to no cartridge, in the order they run: the
  # cheap ones first, so a commit that is going to be refused is
  # refused in a second. `default` is what the box installs when
  # `--checks` is not given.
  @checks [
    %{
      name: "format",
      command: "mix format --check-formatted",
      stage: :fast,
      default: true,
      doc: "`mix format --check-formatted`: the formatter, which no cartridge installs"
    },
    %{
      name: "unused_deps",
      command: "mix deps.unlock --check-unused",
      stage: :fast,
      default: false,
      doc: "`mix deps.unlock --check-unused`: a lock file with nothing stale left in it"
    },
    %{
      name: "compile",
      command: "mix compile --warnings-as-errors",
      stage: :slow,
      default: false,
      doc: "`mix compile --warnings-as-errors`: no warning reaches the branch"
    },
    %{
      name: "test",
      command: "mix test",
      stage: :slow,
      default: false,
      doc: "`mix test`: the suite, which is the slowest thing a commit can wait for"
    }
  ]
  @names Enum.map(@checks, & &1.name)
  @defaults for c <- @checks, c.default, do: c.name

  @doc "The checks the box installs itself, in the order they run."
  @spec checks() :: [%{name: String.t(), command: String.t(), doc: String.t()}]
  def checks, do: @checks

  @doc "The file every cartridge's checks stand in."
  @spec hook() :: Path.t()
  def hook, do: @hook

  @doc "Dependency this feature adds, exposed for the task shell docs."
  def dep, do: @dep

  @impl true
  def task, do: "workbench.install.precommit"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  # `--checks`, plural, and not `--check`: that one is Igniter's own
  # (`check: :boolean`, among the global switches every task carries),
  # and a cartridge declaring it is shadowed on the command line
  # without a word — the composed call still works, so only a real run
  # shows it.
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --checks format,compile",
      schema: [checks: :csv]
    }
  end

  @impl true
  def option_docs do
    [
      checks:
        "Comma-separated, the checks the hook runs: #{Enum.map_join(@checks, ", ", &"`#{&1.name}`")}. " <>
          "Default: `#{Enum.join(@defaults, ",")}`. A cartridge's own check is its option, not one of these (`credo --githook`)."
    ]
  end

  @impl true
  def choices do
    [checks: for(check <- @checks, do: {check.name, check.doc})]
  end

  # Each check is a piece the installer adds when missing.
  @impl true
  def rerun, do: :adds

  @impl true
  def afterwards,
    do:
      "The hook installs itself when the dev dependencies compile (`./wb.sh mix deps.get`); " <>
        "`./wb.sh mix git_hooks.install` does it on demand, and `sh #{@hook}` runs the checks without committing."

  # The mark: the file the installer writes, which is also what the
  # project's developer edits and reads. The dependency is not it —
  # git_hooks without this file is a project that configured its hooks
  # some other way.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @hook)

  @doc """
  What the project carries: the checks standing in this cartridge's own
  block of the hook, in the box's order. Another cartridge's block is
  not read — those are its state, not this one's.
  """
  @impl true
  def state(igniter) do
    {content, igniter} = file_content(igniter, @hook)
    carried = carried(content, name())

    {%{checks: for(check <- @checks, check.command in carried, do: check.name)}, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    chosen =
      case igniter.args.options[:checks] do
        nil -> @defaults
        [] -> @defaults
        checks -> checks
      end

    case Enum.reject(chosen, &(&1 in @names)) do
      [] ->
        igniter
        |> Igniter.Project.Deps.add_dep(@dep, on_exists: :skip)
        |> configure_git_hooks()
        |> Igniter.create_new_file(@runner, asset("mix"), on_exists: :skip)
        |> check(name(), commands(chosen),
          stage: stage(chosen),
          note: "the checks that come with Elixir, not with a cartridge"
        )

      unknown ->
        Igniter.add_issue(
          igniter,
          "--checks must be one of #{Enum.join(@names, ", ")}, got: #{Enum.join(unknown, ", ")}"
        )
    end
  end

  defp commands(chosen), do: for(check <- @checks, check.name in chosen, do: check.command)

  # A block is born where its slowest check belongs: the box's own
  # stands in the fast section until the suite is one of them.
  defp stage(chosen) do
    if Enum.all?(@checks, &(&1.name not in chosen or &1.stage == :fast)), do: :fast, else: :slow
  end

  # --- config/dev.exs ---------------------------------------------------------

  # The whole configuration of the library, and the only place any
  # cartridge writes it: one hook, whose one task is the file below.
  # What goes in that file is the file's business, so a cartridge
  # bringing a check never comes back here.
  #
  # `project_path: "."` is not decoration. The library writes the value
  # of `File.cwd!()` into the hook it installs, and it installs it from
  # inside the container, where that is `/app/src` — a path the host
  # would `cd` into and not find. A dot is true on both sides of the
  # mount.
  defp configure_git_hooks(igniter) do
    igniter
    |> Igniter.Project.Config.configure("dev.exs", :git_hooks, [:auto_install], true)
    |> Igniter.Project.Config.configure("dev.exs", :git_hooks, [:verbose], true)
    |> Igniter.Project.Config.configure("dev.exs", :git_hooks, [:project_path], ".")
    |> Igniter.Project.Config.configure("dev.exs", :git_hooks, [:mix_path], "sh #{@runner}")
    |> Igniter.Project.Config.configure(
      "dev.exs",
      :git_hooks,
      [:hooks, :pre_commit, :tasks],
      {:code, Sourceror.parse_string!(~s([{:cmd, "sh #{@hook}"}]))}
    )
  end

  # --- the way in -------------------------------------------------------------

  @doc """
  Registers `commands` in `owner`'s block of the project's pre-commit
  hook — one command per line, run in order, the first failure cutting
  the rest (`set -e`).

  A cartridge with a check of its own composes this installer and calls
  this: its commands are its own, and so is the block, so an eject
  takes them away without touching anybody else's
  (`WorkbenchIgniter.BlockFile`).

  Options: `:note`, the line the project's reader gets beside the
  block's name, and `:stage` — `:fast` for a check that reads the
  source, `:slow` (the default) for one that compiles it or runs the
  suite. The stage decides where a new block is *born*; a block already
  in the file is replaced where it stands, because a project that moved
  it meant to.
  """
  @spec check(Igniter.t(), String.t(), [String.t()], keyword()) :: Igniter.t()
  def check(igniter, owner, commands, opts \\ []) do
    {content, igniter} = file_content(igniter, @hook)
    carried = carried(content, owner)
    lines = carried ++ Enum.reject(commands, &(&1 in carried))

    BlockFile.put(
      igniter,
      @hook,
      owner,
      Enum.join(lines, "\n"),
      [create: asset("pre-commit")] ++
        anchor(Keyword.get(opts, :stage, :slow)) ++ Keyword.take(opts, [:note])
    )
  end

  @doc """
  The commands standing in `owner`'s block of the project's hook, for
  its own `state/1` to read: `{[command], igniter}`, empty when the
  project has no hook or the owner no block in it.
  """
  @spec checks_of(Igniter.t(), String.t()) :: {[String.t()], Igniter.t()}
  def checks_of(igniter, owner) do
    {content, igniter} = file_content(igniter, @hook)

    {carried(content, owner), igniter}
  end

  @doc "The owner's checks out of the hook — what its eject owes."
  @spec forget(Igniter.t(), String.t()) :: Igniter.t()
  def forget(igniter, owner), do: BlockFile.drop(igniter, @hook, owner)

  defp anchor(:fast), do: [before: @slow_anchor]
  defp anchor(_slow), do: []

  defp carried(nil, _owner), do: []

  defp carried(content, owner) do
    case BlockFile.block(content, owner) do
      {:ok, body} ->
        body |> String.trim_trailing("\n") |> String.split("\n") |> Enum.reject(&(&1 == ""))

      _ ->
        []
    end
  end
end
