defmodule Console.Git do
  @moduledoc """
  The workspace's git, read for the Git screen: what a commit would take
  (`Console.Diffs.worktree/1`), the log with the cartridge inserts marked
  — the commits `eject` knows how to revert — and the message of a
  commit the reader writes, on its way to `wb.sh commit --message-file`.
  Reads only: `wb.sh` alone writes the workspace, and the commit is its
  job.
  """

  @doc "What is pending: the files a commit would take, with their diffs."
  def pending(workspace), do: Console.Diffs.worktree(workspace)

  @doc """
  The log, newest first: sha, subject, body, author, date — and the
  cartridge an insert commit brought, off the status's `git.inserts`.
  """
  def log(workspace, inserts \\ []) do
    features = Map.new(inserts, &{&1["sha"], &1["feature"]})

    case System.cmd("git", ["-C", workspace, "log", "--format=%H%x1f%s%x1f%b%x1f%an%x1f%aI%x1e"],
           stderr_to_stdout: true
         ) do
      {out, 0} ->
        out
        |> String.split("\x1e", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&entry(&1, features))
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  # One commit of the log, its five fields apart; nil for a line that is not one.
  defp entry(entry, features) do
    case String.split(entry, "\x1f") do
      [sha, subject, body, author, date] ->
        %{
          sha: sha,
          short: String.slice(sha, 0, 7),
          subject: subject,
          body: String.trim(body),
          author: author,
          date: date,
          insert: features[sha]
        }

      _ ->
        nil
    end
  end

  @doc """
  The commit's message, title and body, written where `wb.sh` will read
  it: the console's jobs travel as argv split on spaces, and a body has
  lines. The path is the job's second argument.
  """
  def message_file(title, body) do
    path = Path.join(System.tmp_dir!(), "wb-commit-#{System.unique_integer([:positive])}.txt")
    body = String.trim(body || "")

    File.write!(
      path,
      String.trim(title) <> if(body == "", do: "\n", else: "\n\n" <> body <> "\n")
    )

    path
  end
end
