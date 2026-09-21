defmodule WorkbenchIgniter.Features.TestData do
  @moduledoc """
  The records a test needs, with valid defaults and the one value the
  test is about written in the test: a factory module, and Faker for
  the values nobody asserts on.

  The box reads the project's **line** (DESIGN.md §3.1):

  | The project has | It writes |
  | --- | --- |
  | `ash` | faker; `<App>.Generator`, `use Ash.Generator`, in `test/support/generator.ex` |
  | `ecto_sql`, no `ash` | ex_machina and faker; `<App>.Factory`, `use ExMachina.Ecto`, in `test/support/factory.ex`; the test that inserts every factory |
  | neither | nothing: it refuses, naming ecto |

  Ash first: an Ash project on Postgres has a repo too, and ExMachina
  writes through it under the resource's actions, validations and
  policies. A generator runs the action.

  Both libraries' test-helper lines go in this cartridge's block of
  `test/test_helper.exs`, as their READMEs ask. The factory module
  carries the rules in its own `@moduledoc`, where the next person to
  add a factory reads them.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.BlockFile

  embed_templates()

  @ex_machina {:ex_machina, "~> 2.8", only: :test}
  @faker {:faker, "~> 0.19", only: :test}

  @helper "test/test_helper.exs"
  @anchor "ExUnit.start()"

  @doc "The dependencies of each line: `:ecto` and `:ash`."
  def deps, do: %{ecto: [@ex_machina, @faker], ash: [@faker]}

  @impl true
  def task, do: "workbench.install.test_data"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: "mix " <> task()
    }
  end

  # Each piece — a dependency, a file, the helper's block — is added
  # when missing, so a project that took the old exmachina box gets the
  # rest on a second run.
  @impl true
  def rerun, do: :adds

  # The mark: Faker, on either line — or ExMachina, which a project that
  # took the old exmachina box carries alone.
  @impl true
  def installed?(igniter) do
    {faker?, igniter} = dep_installed?(igniter, :faker)
    {machina?, igniter} = dep_installed?(igniter, :ex_machina)
    {faker? or machina?, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    {ash?, igniter} = dep_installed?(igniter, :ash)
    {ecto?, igniter} = dep_installed?(igniter, :ecto_sql)

    cond do
      ash? -> ash(igniter)
      ecto? -> ecto(igniter)
      true -> WorkbenchIgniter.Feature.refuse(igniter, __MODULE__, [{:absent, "ecto", []}])
    end
  end

  # --- the Ecto line ----------------------------------------------------------

  defp ecto(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    factory = Module.concat(app_module, Factory)
    test_module = Module.concat(app_module, FactoryTest)
    data_case = Module.concat(app_module, DataCase)
    {data_case?, igniter} = Igniter.Project.Module.module_exists(igniter, data_case)

    igniter
    |> add_deps(deps().ecto)
    |> create_once(factory, "test/support/factory.ex", "factory.eex",
      app_module: inspect(app_module),
      repo: inspect(Module.concat(app_module, Repo)),
      test_module: inspect(test_module)
    )
    |> create_once(test_module, "test/#{app_name}/factory_test.exs", "factory_test.eex",
      factory: inspect(factory),
      data_case: data_case?,
      case: if(data_case?, do: inspect(data_case), else: "ExUnit.Case")
    )
    |> helper(["{:ok, _} = Application.ensure_all_started(:ex_machina)", "Faker.start()"])
    |> support_compiled()
  end

  # --- the Ash line -----------------------------------------------------------

  defp ash(igniter) do
    app_module = Igniter.Project.Module.module_name_prefix(igniter)

    igniter
    |> add_deps(deps().ash)
    |> create_once(
      Module.concat(app_module, Generator),
      "test/support/generator.ex",
      "generator.eex", app_module: inspect(app_module))
    |> helper(["Faker.start()"])
    |> support_compiled()
  end

  # --- the pieces -------------------------------------------------------------

  defp add_deps(igniter, deps),
    do: Enum.reduce(deps, igniter, &Igniter.Project.Deps.add_dep(&2, &1, on_exists: :skip))

  # A module the project already has — its own factory, say — is the
  # project's: said, not written over.
  defp create_once(igniter, module, path, template, assigns) do
    case Igniter.Project.Module.module_exists(igniter, module) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{inspect(module)} already exists: test_data leaves it as it is."
        )

      {false, igniter} ->
        Igniter.Project.Module.create_module(igniter, module, template(template, assigns),
          path: path
        )
    end
  end

  defp helper(igniter, lines) do
    BlockFile.put(igniter, @helper, name(), Enum.join(lines, "\n"),
      before: @anchor,
      create: "#{@anchor}\n",
      note: "its libraries, started as their READMEs ask"
    )
  end

  # `phx.new` compiles `test/support` in the test environment; a project
  # that does not is told the line rather than having its mix.exs edited.
  defp support_compiled(igniter) do
    {content, igniter} = file_content(igniter, "mix.exs")

    if is_binary(content) and String.contains?(content, "test/support") do
      igniter
    else
      Igniter.add_notice(igniter, """
      test/support is not compiled in the test environment. Add to mix.exs:
          elixirc_paths: elixirc_paths(Mix.env()),
          defp elixirc_paths(:test), do: ["lib", "test/support"]
          defp elixirc_paths(_), do: ["lib"]
      """)
    end
  end
end
