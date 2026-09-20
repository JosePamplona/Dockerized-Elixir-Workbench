defmodule WorkbenchIgniter.Features.TestDoubles do
  @moduledoc """
  What a test puts in the place of the real thing: the API over the
  network, the file a task writes, the database that is supposed to
  fail. Two libraries, by **whose module is being replaced**
  (`--double`, one or several):

  | `--double` | What it is | For |
  | --- | --- | --- |
  | `mimic` | copies a module out of the way and answers in its place | a module that is not yours: `File`, `System`, `Finch`, a repo made to raise |
  | `mox` | builds a *new* module against a behaviour you declare | a boundary the cartridge owns, with a `@callback` and a line of `config/test.exs` |

  They are not rivals and the option is not a preference. Mox never
  replaces anything — "No ad-hoc mocks. You can only create mocks based
  on behaviours" — so it cannot reach `File` or `Finch`, and the code
  under test has to ask its configuration whom to call. Mimic reaches
  any module and asks nothing of the code, at the price of standing on
  somebody else's API. Without `--double` the box installs **mimic**,
  which is what a project inherits from the shelf's own tests
  (DESIGN.md §3.2).

  `--type-check` is one switch with two implementations: Hammox on the
  Mox side (it brings `mox` itself), `type_check: true` on every
  `Mimic.copy/2` on the other.

  The box is a dependency **and the way in**: `copy/4` and `defmock/4`
  are what a cartridge whose generated tests need a double calls, each
  owning its block of `test/test_helper.exs`
  (`WorkbenchIgniter.BlockFile`), so health_endpoint's copied modules and
  coveralls' can stand in one file and be eject-ed apart. It takes over
  from `mock`, which is a dependency and nothing else, whose library
  has not released since 2024-12-16 and whose pin (`meck ~> 0.9.2`)
  locks out the meck that compiles on OTP 29.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.BlockFile

  @helper "test/test_helper.exs"
  @anchor "ExUnit.start()"

  # The doubles, in the order the box tells them: the one that replaces
  # a module, then the one that builds one. `dep` is the mark.
  @doubles [
    %{
      name: "mimic",
      dep: {:mimic, "~> 2.0", only: :test},
      doc: "Mimic: copies the module out of the way — any module, yours or not"
    },
    %{
      name: "mox",
      dep: {:mox, "~> 1.2", only: :test},
      doc: "Mox: a new module against a behaviour you declare, injected by configuration"
    }
  ]
  @names Enum.map(@doubles, & &1.name)
  @default "mimic"

  # `--type-check` on the Mox side is a different package: Hammox wraps
  # Mox (it depends on it) and checks the callbacks' typespecs at run
  # time. On the Mimic side it is an option of each copy.
  @typed_mox {:hammox, "~> 1.0", only: :test}

  @doc "The dependency each double is installed as, untyped: `%{\"mimic\" => {:mimic, …}}`."
  def deps, do: Map.new(@doubles, &{&1.name, &1.dep})

  @impl true
  def task, do: "workbench.install.test_doubles"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task() <> " --double mimic",
      schema: [double: :csv, type_check: :boolean],
      defaults: [type_check: false]
    }
  end

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      double:
        "Comma-separated, the double libraries to install: `mimic` (replaces a module that is not yours) or `mox` (a new module against a behaviour you declare). Default: `mimic`.",
      type_check:
        "Check the doubles against the typespecs at run time: Hammox in place of Mox, `type_check: true` on every Mimic copy. Default: off."
    ]
  end

  @impl true
  def choices do
    [double: for(double <- @doubles, do: {double.name, double.doc})]
  end

  # Each double is a piece the installer adds when missing.
  @impl true
  def rerun, do: :adds

  # The mark: the dependency of either double.
  @impl true
  def installed?(igniter) do
    Enum.reduce(installed_deps(), {false, igniter}, fn dep, {found?, igniter} ->
      {in?, igniter} = dep_installed?(igniter, dep)
      {found? or in?, igniter}
    end)
  end

  @doc """
  What the project carries: the doubles whose dependency is there, and
  whether they are checked against the typespecs — Hammox in place of
  Mox, or a copy asking for it in the test helper.
  """
  @impl true
  def state(igniter) do
    {mimic?, igniter} = dep_installed?(igniter, :mimic)
    {mox?, igniter} = dep_installed?(igniter, :mox)
    {hammox?, igniter} = dep_installed?(igniter, :hammox)
    {helper, igniter} = file_content(igniter, @helper)

    doubles =
      [{"mimic", mimic?}, {"mox", mox? or hammox?}]
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))

    typed? = hammox? or (is_binary(helper) and String.contains?(helper, "type_check: true"))

    {%{double: doubles, type_check: typed?}, igniter}
  end

  @impl true
  def afterwards,
    do:
      "A cartridge registers what its tests replace through `WorkbenchIgniter.Features.TestDoubles.copy/4` and `defmock/4`; by hand, the lines go in `#{@helper}` before `#{@anchor}`."

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    # `:csv` with no `--double` is an empty list, not nil.
    doubles =
      case igniter.args.options[:double] do
        nil -> [@default]
        [] -> [@default]
        doubles -> doubles
      end

    typed? = igniter.args.options[:type_check] || false

    case Enum.reject(doubles, &(&1 in @names)) do
      [] ->
        Enum.reduce(doubles, igniter, &add_double(&2, &1, typed?))

      unknown ->
        Igniter.add_issue(
          igniter,
          "--double must be one of #{Enum.join(@names, ", ")}, got: #{Enum.join(unknown, ", ")}"
        )
    end
  end

  defp add_double(igniter, "mox", true), do: add(igniter, @typed_mox)
  defp add_double(igniter, name, _typed?), do: add(igniter, deps()[name])

  defp add(igniter, dep), do: Igniter.Project.Deps.add_dep(igniter, dep, on_exists: :skip)

  defp installed_deps, do: [:mimic, :mox, :hammox]

  # --- the way in -------------------------------------------------------------

  @doc """
  Registers, in `owner`'s block of the project's test helper, the
  modules whose functions its tests replace — Mimic's `copy/1`, which
  "will not change the behaviour of the module" until a test stubs one
  of its functions. `modules` are written as given (`"File"`,
  `inspect(module)`).

  Lines already in the block are not written twice, and the block is
  the owner's alone: another cartridge's copies stand in theirs. With
  `--type-check` in, each copy asks for it.
  """
  @spec copy(Igniter.t(), String.t(), [String.t()], keyword()) :: Igniter.t()
  def copy(igniter, owner, modules, opts \\ []) do
    {state, igniter} = state(igniter)
    typed = if state[:type_check], do: ", type_check: true", else: ""

    add_lines(igniter, owner, Enum.map(modules, &"Mimic.copy(#{&1}#{typed})"), opts)
  end

  @doc """
  Registers, in `owner`'s block of the project's test helper, the mocks
  its tests expect against: `{"MyApp.MockHTTP", "MyApp.HTTP"}` becomes
  `Mox.defmock(MyApp.MockHTTP, for: MyApp.HTTP)` — `Hammox.defmock`
  with `--type-check` in. The behaviour and the `config/test.exs` line
  that injects the mock are the cartridge's own: Mox replaces nothing,
  so the code has to ask.
  """
  @spec defmock(Igniter.t(), String.t(), [{String.t(), String.t()}], keyword()) :: Igniter.t()
  def defmock(igniter, owner, mocks, opts \\ []) do
    {state, igniter} = state(igniter)
    fun = if state[:type_check], do: "Hammox.defmock", else: "Mox.defmock"

    add_lines(igniter, owner, Enum.map(mocks, fn {m, b} -> "#{fun}(#{m}, for: #{b})" end), opts)
  end

  @doc "The owner's block out of the test helper — what its eject owes."
  @spec forget(Igniter.t(), String.t()) :: Igniter.t()
  def forget(igniter, owner), do: BlockFile.drop(igniter, @helper, owner)

  # The owner's block, grown by the lines it does not carry yet.
  defp add_lines(igniter, owner, new_lines, opts) do
    {content, igniter} = file_content(igniter, @helper)
    carried = carried(content, owner)
    lines = carried ++ Enum.reject(new_lines, &(&1 in carried))

    BlockFile.put(
      igniter,
      @helper,
      owner,
      Enum.join(lines, "\n"),
      [before: @anchor, create: "#{@anchor}\n"] ++ Keyword.take(opts, [:note])
    )
  end

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
