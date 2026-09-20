defmodule Mix.Tasks.Workbench.Catalog do
  use Mix.Task

  @shortdoc "Lists every workbench cartridge with its manifest"

  @moduledoc """
  #{@shortdoc}

      mix workbench.catalog [--json] [--covers DIR]

  Reads the registry (`WorkbenchIgniter.Features.catalog/0`): every
  cartridge in shelf order, each with its name, task, one-line summary,
  version (off its CHANGELOG.md), the switches of its installer, and
  the facts that are true of it — it inserts other cartridges
  (`collection`, with its `members`), `phx.new` decides it at
  generation time (`base`), it is not done yet (`pending`), it is
  retired and no longer offered (`archived`, with the line saying why —
  the box stays here, because its papers are the log of the reasoning
  that made it). The
  facts are independent, and most cartridges carry none: there is one
  kind of cartridge, and these say what a box does, not what it is.
  Nothing here looks at a project: for what the current project
  carries, see `mix workbench.status`.

  A cartridge that brings compose services says so twice: `compose` is
  what a project gets from it with nothing chosen, and `offers` is the
  whole menu — every container it could raise, each with the choices it
  comes `with`, so a reader can light the ones a given set of switches
  would bring.

  ## Options

  * `--json` - One JSON array instead of the table, for tools.
  * `--covers DIR` - The covers directory (`assets/covers/` of the
    workbench). Each entry then says which of its sealed covers exist,
    as paths relative to that directory.
  """

  alias WorkbenchIgniter.Features

  @switches [json: :boolean, covers: :string]

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: @switches)

    entries = read(opts[:covers])

    if opts[:json],
      do: IO.puts(Jason.encode!(entries, pretty: true)),
      else: IO.puts(table(entries))
  end

  @doc "Every entry of the catalog, with its covers when a directory is given."
  def read(covers_dir) do
    Features.catalog()
    |> Enum.map(&Features.entry/1)
    |> Enum.map(&with_covers(&1, covers_dir))
  end

  defp with_covers(entry, nil), do: entry

  defp with_covers(entry, dir) do
    covers =
      for {face, file} <- [front: "cover.jpg", back: "back.jpg"], into: %{} do
        path = Path.join([entry.name, "sealed", file])
        {face, if(File.regular?(Path.join(dir, path)), do: path)}
      end

    Map.put(entry, :covers, covers)
  end

  @doc false
  def table(entries) do
    width = entries |> Enum.map(&String.length(&1.name)) |> Enum.max(fn -> 0 end)
    facts = entries |> Enum.map(&String.length(facts_column(&1))) |> Enum.max(fn -> 0 end)

    Enum.map_join(entries, "\n", fn entry ->
      [
        String.pad_trailing(entry.name, width),
        String.pad_trailing(version_column(entry), 8),
        String.pad_trailing(facts_column(entry), facts),
        # The shelf's line is the developer's need (NEED.md); a
        # cartridge without one still shows what it installs.
        (entry.need && entry.need.line) || entry.summary || ""
      ]
      |> Enum.join("  ")
      |> String.trim_trailing()
    end)
  end

  defp version_column(%{version: %{version: v}}), do: "v" <> v
  defp version_column(_), do: "-"

  # What is true of the box, not what kind of box it is: there is one
  # kind. The facts are independent and a cartridge can carry several,
  # so they are joined and not chosen between; one that carries none —
  # most of them — says nothing here.
  defp facts_column(entry) do
    [
      if(entry.pending, do: "pending"),
      if(entry.archived, do: "archived"),
      if(entry.collection, do: "inserts #{length(entry.members)}"),
      if(entry.base, do: "base")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end
end
