defmodule Mix.Tasks.Workbench.Catalog do
  use Mix.Task

  @shortdoc "Lists every workbench cartridge with its manifest"

  @moduledoc """
  #{@shortdoc}

      mix workbench.catalog [--json] [--covers DIR]

  Reads the registry (`WorkbenchIgniter.Features.catalog/0`): every
  cartridge, the composed ones in composition order and then the
  standalone, each with its name, task, one-line summary, version (off
  its CHANGELOG.md), setup flag, the flags it implies, whether it is
  pending, and the switches of its installer. Nothing here looks at a
  project: for what the current project carries, see
  `mix workbench.status`.

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

    entries =
      Features.catalog()
      |> Enum.map(&Features.entry/1)
      |> Enum.map(&with_covers(&1, opts[:covers]))

    if opts[:json],
      do: IO.puts(Jason.encode!(entries, pretty: true)),
      else: IO.puts(table(entries))
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

    Enum.map_join(entries, "\n", fn entry ->
      [
        String.pad_trailing(entry.name, width),
        String.pad_trailing(version_column(entry), 8),
        String.pad_trailing(kind_column(entry), 12),
        entry.summary || ""
      ]
      |> Enum.join("  ")
      |> String.trim_trailing()
    end)
  end

  defp version_column(%{version: %{version: v}}), do: "v" <> v
  defp version_column(_), do: "-"

  defp kind_column(%{pending: true}), do: "pending"
  defp kind_column(%{standalone: true}), do: "standalone"
  defp kind_column(%{flag: nil}), do: "composed"
  defp kind_column(%{flag: flag}), do: "--#{flag}"
end
