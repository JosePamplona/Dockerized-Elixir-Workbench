defmodule Mix.Tasks.Workbench.Dependents do
  use Mix.Task

  @shortdoc "Says which installed cartridges build on the named one"

  @moduledoc """
  #{@shortdoc}

      mix workbench.dependents NAME [--json]

  What would be left standing on nothing if NAME came out: every
  cartridge this project carries that declares NAME in its `requires`
  or brings it in itself (`composes`: health_endpoint's installer inserts
  mock, whose library its tests use), and everything that builds on
  *those* in turn. One name per line, in
  the order they have to be ejected in — each one before anything it
  stands on — and nothing at all when the cartridge can go on its own.

  It is the mirror of a rule the insert side already keeps: a cartridge
  whose `requires` are missing refuses, naming what to insert first.
  Taking one out is the same question asked backwards, and nobody was
  asking it — `eject` reverts the commit and leaves whoever was standing
  on it standing on nothing.

  Both halves of the answer come from the project, not from a list kept
  here: `requires` and `composes` off each cartridge's own manifest, and installed off
  its `installed?/1` — the same mark its installer's guard reads. A
  cartridge inserted by hand, or one `phx.new` generated at birth,
  counts exactly like one the workbench committed: what matters is that
  the project carries it, not how it arrived.

  Exits 0 whether or not there are any: an empty answer is an answer.

  ## Options

  * `--json` - the same names as one JSON array, for tools. `wb.sh eject`
    reads this one: a plain list has to be told apart from whatever the
    build printed before it, and the array is what the workbench already
    knows how to find in that stream.
  """

  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(argv) do
    # A plain task, like `workbench.status`: Igniter's own would compile
    # the project first, and nothing here needs more than the source.
    Application.ensure_all_started(:rewrite)

    {opts, rest, _} = OptionParser.parse(argv, strict: [json: :boolean])

    name =
      case rest do
        [name | _] -> name
        [] -> Mix.raise("Missing cartridge name. Try: mix workbench.dependents exdoc")
      end

    {cartridges, _igniter} = Features.status(Igniter.new())

    unless Enum.any?(cartridges, &(&1.name == name)) do
      Mix.raise("No cartridge named #{name}. The catalog: mix workbench.catalog")
    end

    names = dependents(cartridges, name)

    if opts[:json],
      do: IO.puts(Jason.encode!(names)),
      else: Enum.each(names, &IO.puts/1)
  end

  @doc """
  The names the task prints, off `WorkbenchIgniter.Features.status/1`'s
  cartridges: the installed ones standing on NAME, in eject order.
  """
  @spec dependents([map()], String.t()) :: [String.t()]
  def dependents(cartridges, name) do
    installed = Enum.filter(cartridges, & &1.installed)
    reached = reach(installed, [name], MapSet.new([name])) |> MapSet.delete(name)

    installed
    |> Enum.filter(&MapSet.member?(reached, &1.name))
    |> eject_order()
  end

  # Everything that builds on the frontier, then everything that builds
  # on that. `seen` both keeps a cartridge reached by two paths out of
  # the walk twice and makes a cycle in the manifests terminate.
  defp reach(installed, frontier, seen) do
    next =
      installed
      |> Enum.filter(fn c ->
        not MapSet.member?(seen, c.name) and Enum.any?(frontier, &(&1 in stands_on(c)))
      end)
      |> Enum.map(& &1.name)

    if next == [],
      do: seen,
      else: reach(installed, next, MapSet.union(seen, MapSet.new(next)))
  end

  # What a cartridge stands on: what must be in before it, and what its
  # installer brought in with it.
  defp stands_on(c), do: (c.requires || []) ++ (c.composes || [])

  # Outermost first: a cartridge can only come out once nothing left in
  # the set stands on it. Levels are not enough — two cartridges can be
  # the same distance from the one being ejected and still stand on each
  # other — so this is the plain topological order of "is required by",
  # taken a layer at a time.
  defp eject_order(rest, acc \\ [])
  defp eject_order([], acc), do: acc

  defp eject_order(rest, acc) do
    {out, keep} =
      Enum.split_with(rest, fn c -> not Enum.any?(rest, &(c.name in stands_on(&1))) end)

    # Manifests that require each other in a ring leave nothing free to
    # take first. Emitting what is left beats spinning: the order is no
    # longer a promise, and the reader has the names.
    if out == [],
      do: acc ++ Enum.map(rest, & &1.name),
      else: eject_order(keep, acc ++ Enum.map(out, & &1.name))
  end
end
