defmodule Mix.Tasks.Workbench.MishkaComponents do
  use Mix.Task

  alias WorkbenchIgniter.Features.MishkaChelekom

  # No @shortdoc on purpose: internal plumbing, hidden from `mix help`.
  @moduledoc """
  `mix mishka.ui.gen.components --import --helpers --global --yes`, for
  the components named and what they need.

      mix workbench.mishka_components [--format] [COMPONENT...]

  Internal plumbing: the mishka_chelekom cartridge queues this once the
  dependency it added is fetched. With no component it runs the
  library's task as its installer composes it, for all of them.

  With components, the library's batch task generates exactly the names
  it is given: it hands each one `--no-deps`, since a run for all of
  them needs no dependency resolved. A list of some does, so this task
  completes it before handing it over — with what each component
  declares `necessary` in the library's catalog
  (`priv/components/<name>.exs`, read off the fetched package), and
  with the components that stand in for `CoreComponents`
  (`MishkaChelekom.core/0`), which `--global` stops importing. A name
  the catalog does not carry ends the task before anything is written.

  With `--format` the components are then run through the project's
  own formatter (`mix format` over `lib/<app>_web/components/`): the
  library leaves `button.ex` a line short of it, and a hook that checks
  the format would refuse the next commit.

  The library's task runs watched
  (`Mix.Tasks.Workbench.IgniterInstall.watched/2`): it fails where the
  task reports issues, and its spinner has a screen to draw on.
  """

  @flags ~w(--import --helpers --global --yes)

  @doc false
  def run(argv) do
    {format, argv} = Enum.split_with(argv, &(&1 == "--format"))
    names = argv |> Enum.flat_map(&String.split(&1, ",", trim: true)) |> Enum.uniq()

    args =
      case names do
        [] -> @flags
        names -> [names |> complete(catalog()) |> Enum.join(",") | @flags]
      end

    Mix.Tasks.Workbench.IgniterInstall.watched("mishka.ui.gen.components", args)

    if format != [], do: Mix.Task.rerun("format", [components()])

    :ok
  end

  # Where the library writes them: phx.new's web directory.
  defp components, do: "lib/#{Mix.Project.config()[:app]}_web/components/**/*.{ex,heex}"

  @doc """
  The names with the core set and everything they need, in the
  catalog's order; raises on a name the catalog does not carry.
  `catalog` maps each component to the ones it declares `necessary`.
  """
  @spec complete([String.t()], %{String.t() => [String.t()]}) :: [String.t()]
  def complete(names, catalog) do
    case Enum.reject(names, &Map.has_key?(catalog, &1)) do
      [] ->
        wanted = closure(names ++ MishkaChelekom.core(), catalog, MapSet.new())
        catalog |> Map.keys() |> Enum.sort() |> Enum.filter(&(&1 in wanted))

      unknown ->
        Mix.raise("""
        Mishka Chelekom has no component named #{Enum.join(unknown, ", ")}. \
        Its catalog: #{catalog |> Map.keys() |> Enum.sort() |> Enum.join(", ")}.\
        """)
    end
  end

  defp closure([], _catalog, seen), do: seen

  defp closure([name | rest], catalog, seen) do
    if name in seen,
      do: closure(rest, catalog, seen),
      else: closure(Map.get(catalog, name, []) ++ rest, catalog, MapSet.put(seen, name))
  end

  # The library's catalog, off the package as fetched: one `.exs` per
  # component, a keyword under the component's own name.
  defp catalog do
    dir = Path.join(Mix.Project.deps_paths()[:mishka_chelekom] || "", "priv/components")

    case Path.wildcard(Path.join(dir, "*.exs")) do
      [] ->
        Mix.raise(
          "mishka_chelekom's catalog was not found under #{dir}: is the dependency fetched?"
        )

      files ->
        Map.new(files, fn file ->
          name = Path.basename(file, ".exs")
          config = file |> Config.Reader.read!() |> Keyword.get(String.to_atom(name), [])
          {name, config[:necessary] || []}
        end)
    end
  end
end
