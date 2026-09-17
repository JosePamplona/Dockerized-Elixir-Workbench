defmodule WorkbenchIgniter.TextFile do
  @moduledoc """
  What the line files of a project have in common — `.env`,
  `.gitignore`: an entry goes at the end, once. The files' own modules
  (`WorkbenchIgniter.EnvFile`, `WorkbenchIgniter.IgnoreFile`) say what
  an entry is; this appends it.
  """

  @doc """
  `entry` at the end of the project's `path`, a blank line before it —
  unless the file already carries `marker`, which is then the entry
  being there already; a project without the file gets it with the
  entry alone.
  """
  @spec append_once(Igniter.t(), Path.t(), String.t(), String.t()) :: Igniter.t()
  def append_once(igniter, path, entry, marker) do
    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(
        path,
        &Rewrite.Source.update(&1, :content, fn content -> appended(content, marker, entry) end)
      )
    else
      Igniter.create_new_file(igniter, path, entry)
    end
  end

  defp appended(content, marker, entry) do
    if String.contains?(content, marker),
      do: content,
      else: String.trim_trailing(content, "\n") <> "\n\n" <> entry
  end
end
