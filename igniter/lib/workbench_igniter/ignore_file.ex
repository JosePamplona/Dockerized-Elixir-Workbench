defmodule WorkbenchIgniter.IgnoreFile do
  @moduledoc """
  The project's ignore files — `.gitignore`, `.dockerignore`: sets of
  patterns, where order carries no meaning. Everything that works on
  them lives here. Igniter has nothing for them.

  That they are sets is the whole of it. Whoever touches one appends at
  its end — phx.new a capability's patterns, the workbench its `.env`
  at birth, a cartridge its own — so a three-way merge meets two
  appends after the same line and gives up, on every project (esbuild,
  2026-09-16). Here an entry goes in once (`entry/3`), and a
  capability's change is merged as a set (`merge/3`): never a conflict.
  """

  @files [".gitignore", ".dockerignore"]

  @doc "Whether `path` is one of them, wherever it is."
  @spec ignore_file?(Path.t()) :: boolean()
  def ignore_file?(path), do: Path.basename(path) in @files

  @doc """
  Appends an entry (comment + pattern) to the project `.gitignore`,
  creating the file when the project has none. A no-op when the pattern
  is already listed.
  """
  @spec entry(Igniter.t(), String.t(), String.t()) :: Igniter.t()
  def entry(igniter, comment, pattern) do
    WorkbenchIgniter.TextFile.append_once(
      igniter,
      ".gitignore",
      "# #{comment}\n#{pattern}\n",
      pattern
    )
  end

  @doc """
  The merge for a file that is a set of lines (`.gitignore`): the lines
  the capability adds — in theirs and not in base — appended to ours
  when ours lacks them, as one block in theirs' order; the lines it
  takes away — in base and not in theirs — dropped from ours. Comment
  and blank lines ride with the block they belong to. Never a conflict:
  order carries no meaning in such a file.
  """
  def merge(ours, base, theirs) do
    lines = &String.split(String.trim_trailing(&1, "\n"), "\n")
    base_set = MapSet.new(lines.(base))
    theirs_lines = lines.(theirs)
    ours_lines = lines.(ours)
    ours_set = MapSet.new(ours_lines)
    gone = MapSet.difference(base_set, MapSet.new(theirs_lines))

    kept = Enum.reject(ours_lines, &(String.trim(&1) != "" and &1 in gone))

    # A blank line is spacing, not a pattern: it rides with the block
    # whatever base or ours have, and the block's ends are trimmed.
    added =
      theirs_lines
      |> Enum.reject(&(String.trim(&1) != "" and (&1 in base_set or &1 in ours_set)))
      |> Enum.chunk_by(&(String.trim(&1) == ""))
      |> Enum.reject(fn [l | _] = chunk -> String.trim(l) == "" and length(chunk) > 1 end)
      |> List.flatten()
      |> trim_blank()

    merged =
      case added do
        [] -> kept
        _ -> kept ++ [""] ++ added
      end

    {:ok, Enum.join(merged, "\n") <> "\n"}
  end

  # A block without the blank lines at either end; the join puts one before it.
  defp trim_blank(lines) do
    blank? = &(String.trim(&1) == "")

    lines
    |> Enum.drop_while(blank?)
    |> Enum.reverse()
    |> Enum.drop_while(blank?)
    |> Enum.reverse()
  end
end
