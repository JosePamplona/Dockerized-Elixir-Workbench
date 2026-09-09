defmodule WorkbenchIgniter.Birth do
  @moduledoc """
  How the project was made, read off its first commit and never
  inferred from what is there today.

  `wb.sh new` commits the generated project as its first commit, so the
  files that carry phx.new's marks — `mix.exs`, `config/config.exs`,
  `AGENTS.md` — and the workspace's `Dockerfile.local`, with the stack
  and installer stamped in it, are in git exactly as generation left
  them. `git show SHA:path` hands them over, and `PhxDelta.facts_of/3`
  reads the same marks `facts/1` reads today. The difference between the
  two readings is what moved since: a driver, a capability a base
  cartridge brought in later, a stack `bake` rewrote.

  Nothing here is a contract with the project: it is git's, and the
  workbench only reads it. `nil` without a repository or a commit, or
  when the first commit carries no `mix.exs` — a project imported into
  a workspace rather than born in one.
  """

  alias WorkbenchIgniter.PhxDelta

  @args ~w(ELIXIR OTP DEBIAN PHX_NEW)

  @typedoc "The birth: the commit, phx.new's shape then, and Dockerfile.local's stamps then."
  @type t :: %{
          sha: String.t(),
          date: String.t(),
          subject: String.t(),
          phx: map(),
          dockerfile: %{String.t() => String.t()}
        }

  @doc "The birth of the project at `dir` (the current directory by default), or nil."
  @spec read(Path.t()) :: t() | nil
  def read(dir \\ File.cwd!()) do
    with {:ok, sha} <- first_commit(dir),
         {:ok, [date, subject]} <- header(dir, sha),
         mix when is_binary(mix) <- show(dir, sha, "mix.exs") do
      facts =
        PhxDelta.facts_of(
          mix,
          show(dir, sha, "config/config.exs"),
          exists?(dir, sha, "AGENTS.md")
        )

      %{
        sha: sha,
        date: date,
        subject: subject,
        phx: facts |> Map.put(:flags, PhxDelta.flags(facts)),
        dockerfile: args(show(dir, sha, "Dockerfile.local") || "")
      }
    else
      _ -> nil
    end
  end

  # The root of the history: the first of the commits with no parent.
  defp first_commit(dir) do
    case git(dir, ["rev-list", "--max-parents=0", "--reverse", "HEAD"]) do
      {:ok, out} ->
        case out |> String.split("\n", trim: true) |> List.first() do
          nil -> :error
          sha -> {:ok, sha}
        end

      :error ->
        :error
    end
  end

  defp header(dir, sha) do
    case git(dir, ["show", "-s", "--format=%ci%n%s", sha]) do
      {:ok, out} ->
        case String.split(out, "\n", parts: 3) do
          [date, subject | _] -> {:ok, [date, subject]}
          _ -> :error
        end

      :error ->
        :error
    end
  end

  defp show(dir, sha, path) do
    case git(dir, ["show", sha <> ":" <> path]) do
      {:ok, text} -> text
      :error -> nil
    end
  end

  defp exists?(dir, sha, path),
    do: match?({:ok, _}, git(dir, ["cat-file", "-e", sha <> ":" <> path]))

  # The four stamps, as `wb.sh` writes them (`ARG    OTP="…"` aligns its spaces).
  defp args(dockerfile) do
    ~r/^ARG\s+(#{Enum.join(@args, "|")})="([^"]*)"/m
    |> Regex.scan(dockerfile)
    |> Map.new(fn [_, key, value] -> {key, value} end)
  end

  defp git(dir, args) do
    case System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) do
      {out, 0} -> {:ok, out}
      _ -> :error
    end
  rescue
    ErlangError -> :error
  end
end
