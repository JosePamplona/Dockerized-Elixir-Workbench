defmodule Mix.Tasks.Workbench.MishkaComponents do
  use Mix.Task

  alias WorkbenchIgniter.Features.MishkaChelekom

  # No @shortdoc on purpose: internal plumbing, hidden from `mix help`.
  @moduledoc """
  `mix mishka.ui.gen.components --import --helpers --global --yes`, for
  the components named and what they need.

      mix workbench.mishka_components [--solve-warnings] [--format] [COMPONENT...]

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

  With `--solve-warnings` the documentation of the components is
  mended first (`fenced/1`): the library writes three of its code
  blocks with one fence of the two — `combobox` without the one that
  opens, `layout`'s `flex` and `grid` without the one that closes —
  and ExDoc warns of each on every `mix docs`. A WORKAROUND, for
  mishka_chelekom 0.0.9: to remove when the library's templates carry
  both fences.

  The library's task runs watched
  (`Mix.Tasks.Workbench.IgniterInstall.watched/2`): it fails where the
  task reports issues, and its spinner has a screen to draw on.
  """

  @flags ~w(--import --helpers --global --yes)

  @doc false
  def run(argv) do
    {format, argv} = Enum.split_with(argv, &(&1 == "--format"))
    {solve, argv} = Enum.split_with(argv, &(&1 == "--solve-warnings"))
    names = argv |> Enum.flat_map(&String.split(&1, ",", trim: true)) |> Enum.uniq()

    args =
      case names do
        [] -> @flags
        names -> [names |> complete(catalog()) |> Enum.join(",") | @flags]
      end

    Mix.Tasks.Workbench.IgniterInstall.watched("mishka.ui.gen.components", args)

    if solve != [], do: Enum.each(Path.wildcard(components()), &mend/1)
    if format != [], do: Mix.Task.rerun("format", [components()])

    :ok
  end

  # Where the library writes them: phx.new's web directory.
  defp components, do: "lib/#{Mix.Project.config()[:app]}_web/components/**/*.{ex,heex}"

  defp mend(file) do
    source = File.read!(file)

    case fenced(source) do
      ^source ->
        :ok

      mended ->
        File.write!(file, mended)
        Mix.shell().info("#{file}: a code block's missing fence written")
    end
  end

  @doc """
  The source with each `@doc` and `@moduledoc` heredoc's code fences
  in pairs. A heredoc with an odd number of them gets the one it
  lacks: when its one fence is the bare line that ends it, the block
  was never opened, and ` ```elixir ` goes under the last heading
  above; otherwise the last block was never closed, and ` ``` ` goes
  at the end. A heredoc whose fences are paired, and one with nothing
  to hang the opening fence from, are left as they are.
  """
  @spec fenced(String.t()) :: String.t()
  def fenced(source) do
    source |> String.split("\n") |> docs([]) |> Enum.join("\n")
  end

  @opens ~r/^\s*@(module)?doc\s+(~[sS])?"""$/

  defp docs([], done), do: Enum.reverse(done)

  defp docs([line | rest], done) do
    if line =~ @opens do
      {body, rest} = Enum.split_while(rest, &(String.trim(&1) != ~s(""")))
      docs(rest, Enum.reverse(paired(body, rest)) ++ [line | done])
    else
      docs(rest, [line | done])
    end
  end

  # `rest` opens with the line that closes the heredoc: its indentation
  # is the heredoc's.
  defp paired(body, [closing | _]) do
    indent = String.duplicate(" ", String.length(closing) - String.length(String.trim(closing)))
    fences = Enum.filter(body, &fence?/1)

    cond do
      rem(length(fences), 2) == 0 ->
        body

      match?(["```"], Enum.map(fences, &String.trim/1)) and ends_fenced?(body) ->
        opened(body, indent)

      true ->
        body ++ [indent <> "```"]
    end
  end

  defp paired(body, []), do: body

  defp fence?(line), do: String.starts_with?(String.trim(line), "```")

  defp ends_fenced?(body) do
    body |> Enum.reverse() |> Enum.find(&(String.trim(&1) != "")) |> fence?()
  end

  defp opened(body, indent) do
    case body |> Enum.with_index() |> Enum.filter(fn {l, _} -> String.trim(l) =~ ~r/^#+ / end) do
      [] ->
        body

      headings ->
        {_, at} = List.last(headings)
        {above, below} = Enum.split(body, at + 1)
        above ++ ["", indent <> "```elixir"] ++ below
    end
  end

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
