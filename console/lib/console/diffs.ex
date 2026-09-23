defmodule Console.Diffs do
  @moduledoc """
  What a cartridge wrote, read off the workspace's git. One insert commit
  is one cartridge's whole diff: `add` refuses a dirty tree, so nothing
  else rode in with it. A collection leaves no commit of its own, so its
  diff is the range its members span, taken as one tree against another
  — never a concatenation of their patches, whose line numbers already
  count the ones before — and only when their commits are contiguous: a
  second pass, a member born with `phx.new`, one ejected in between, and
  the breakdown per member is all there is to show.

  A patch cannot be handed to a lexer — with the `+`, `-` and `@@` in
  front of every line it is not code — so both faces of each file are
  read whole and cut into lines (`Console.Highlight.lines/2`), and the
  hunks are put back together out of them: context and additions off
  the new face, removals off the old.
  """

  @doc """
  One cartridge's diff: its active insert commit, its files.
  `insert` is the status's `git.inserts` entry.
  """
  def cartridge(workspace, %{"sha" => sha} = insert) do
    files = files_of(workspace, sha)

    Map.merge(
      %{sha: sha, subject: insert["subject"], date: insert["date"], files: files},
      totals(files)
    )
  end

  @doc """
  A cartridge's diff across every insert of it still standing, newest
  first — the status's order. A cartridge goes in more than once when a
  later insert adds an option (`rerun: :adds`: changelog's `--mix-task`,
  db_admin's second admin), and each insert is its own commit, so each
  stays its own here: other cartridges' commits may sit between them,
  and a range would carry those too. `inserts` are the status's
  `git.inserts` entries of this cartridge.
  """
  def inserted(workspace, inserts) do
    picks = Enum.map(inserts, &cartridge(workspace, &1))

    %{
      picks: picks,
      files: Enum.flat_map(picks, & &1.files),
      added: Enum.sum(Enum.map(picks, & &1.added)),
      removed: Enum.sum(Enum.map(picks, & &1.removed))
    }
  end

  @doc """
  The packages an insert put in the project's `mix.exs`, read off its
  own commit: `%{name, requirement, git, from}`, newest insert first;
  `git` is where a package from git comes from (`MixFile.git_of/1`). A base
  cartridge declares none — its packages arrive inside the `phx.new`
  delta, whatever that installer writes — so what it brought is read
  where it was written, and nothing is kept by hand. A project born
  with the flag has no insert commit, and so nothing to read: that is
  what the panel says instead of guessing. Each package carries the
  `phx.new` the delta was generated at (`from`): the `PHX_NEW` the
  project's `Dockerfile.local` stamped at that same commit, which is
  the one `PhxDelta` generates at — read there and not today, since the
  stamp moves when the project upgrades and the insert does not.
  `inserts` are the status's entries of that cartridge.
  """
  def packages_of(_workspace, []), do: []

  def packages_of(workspace, inserts) do
    inserts
    |> Enum.flat_map(fn %{"sha" => sha} ->
      # mix.exs before the insert and after it, read as code: what the
      # insert brought is the dependencies only the new one has. By the
      # tree and not by the line, so a dependency written over several
      # lines — a git one, with its tag three lines down — is read
      # whole, and a line rewritten only for its comma is no new one.
      before = mix_exs_at(workspace, sha <> "^")
      now = mix_exs_at(workspace, sha)
      from = phx_new_at(workspace, sha)

      for {name, code} <- WorkbenchIgniter.MixFile.diff(before, now).deps do
        %{
          name: to_string(name),
          requirement: WorkbenchIgniter.MixFile.requirement_of(code),
          git: WorkbenchIgniter.MixFile.git_of(code),
          from: from
        }
      end
    end)
    |> Enum.uniq_by(& &1.name)
  end

  @doc """
  The names of the packages `mix.exs` lists at a commit — the first
  one, for what the project was born with. Empty where the commit has
  no `mix.exs` that reads as code.
  """
  def packages_at(workspace, rev) do
    for {name, _code} <- WorkbenchIgniter.MixFile.read(mix_exs_at(workspace, rev)).deps,
        do: to_string(name)
  end

  # mix.exs as a commit holds it; empty where it does not, or does not
  # read as code — an empty file has no dependencies to take away.
  defp mix_exs_at(workspace, rev) do
    case System.cmd("git", ["-C", workspace, "show", rev <> ":mix.exs"], stderr_to_stdout: true) do
      {text, 0} -> if match?({:ok, _}, Code.string_to_quoted(text)), do: text, else: ""
      _ -> ""
    end
  end

  # The phx.new a commit's Dockerfile.local stamps; nil without one.
  defp phx_new_at(workspace, sha) do
    case System.cmd("git", ["-C", workspace, "show", sha <> ":Dockerfile.local"],
           stderr_to_stdout: true
         ) do
      {text, 0} ->
        case Regex.run(~r/^ARG\s+PHX_NEW="([^"]+)"/m, text) do
          [_, version] -> version
          nil -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  A collection's diff: the range its members' commits span, when they
  are contiguous in the log, with who touched each file; otherwise the
  fact that they are not, and how many commits sit between.
  `inserts` are the status's, newest first, filtered to the members.
  """
  def collection(_workspace, []), do: nil

  def collection(workspace, inserts) do
    log = git(workspace, ["log", "--format=%H"]) |> String.split("\n", trim: true)
    index = log |> Enum.with_index() |> Map.new()
    idx = inserts |> Enum.map(&index[&1["sha"]]) |> Enum.reject(&is_nil/1) |> Enum.sort()
    {first, last} = {List.first(idx), List.last(idx)}
    contiguous = idx != [] and last - first + 1 == length(idx)
    newest = Enum.at(log, first)
    oldest = Enum.at(log, last)
    base = git(workspace, ["rev-parse", "--verify", "--quiet", oldest <> "^"]) |> String.trim()

    picks = for i <- inserts, do: Map.put(cartridge(workspace, i), :name, i["feature"])

    if contiguous and base != "" do
      touched = Map.new(picks, fn p -> {p.name, MapSet.new(p.files, & &1.path)} end)

      files =
        for f <- files_of(workspace, {base, newest}), do: Map.put(f, :by, by(touched, f.path))

      Map.merge(
        %{
          contiguous: true,
          between: 0,
          picks: picks,
          files: files,
          range: String.slice(base, 0, 7) <> ".." <> String.slice(newest, 0, 7),
          base: base,
          tip: newest
        },
        totals(files)
      )
    else
      %{
        contiguous: false,
        between: max(last - first + 1 - length(idx), 0),
        picks: picks,
        files: [],
        added: 0,
        removed: 0,
        range: nil,
        base: nil,
        tip: newest
      }
    end
  end

  # The picks that wrote a path.
  defp by(touched, path), do: for({name, paths} <- touched, MapSet.member?(paths, path), do: name)

  defp totals(files),
    do: %{
      added: Enum.sum(Enum.map(files, &(&1.added || 0))),
      removed: Enum.sum(Enum.map(files, &(&1.removed || 0)))
    }

  @doc """
  The working tree against HEAD, for the Git screen: what a commit would
  take. The tracked changes as a diff, and every untracked file as born,
  read whole off the disk — git has no patch for what it does not know.
  `files: []` is a clean tree.
  """
  def worktree(workspace) do
    tracked = files_of(workspace, :worktree)

    untracked =
      git(workspace, ["ls-files", "--others", "--exclude-standard"])
      |> String.split("\n", trim: true)
      |> Enum.map(&untracked(workspace, &1))

    files = Enum.sort_by(tracked ++ untracked, & &1.path)
    Map.merge(%{files: files}, totals(files))
  end

  # An untracked file as born: every line of it added, when it is text.
  defp untracked(workspace, path) do
    treatment = Console.Highlight.treatment(path)
    text = File.read(Path.join(workspace, path))

    readable =
      match?({:ok, t} when is_binary(t), text) and String.valid?(elem(text, 1)) and
        treatment not in [:image, :omit]

    rows = if readable, do: born_rows(path, elem(text, 1)), else: []

    %{
      path: path,
      added: if(readable, do: length(rows)),
      removed: if(readable, do: 0),
      born: true,
      gone: false,
      binary: not readable,
      treatment: treatment,
      tip: "HEAD",
      base: "HEAD",
      rows: rows
    }
  end

  @doc """
  How wide the sheet's line-number columns are for these rows: the
  digits of the widest number, never fewer than two. Each row is its
  own flex line, so the width has to be one per file — the last
  number's, the way GitHub and GitLab size a gutter — for the numbers
  to sit in one column.
  """
  @spec gutter([tuple()]) :: pos_integer()
  def gutter(rows) do
    rows
    |> Enum.flat_map(fn {_, o, n, _, _} -> [o, n] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 1 end)
    |> Integer.digits()
    |> length()
    |> max(2)
  end

  # The file's lines as added rows, coloured.
  defp born_rows(path, text) do
    # A file ending in a newline is cut into one line more than it
    # has, an empty one: not a line anyone added.
    case Console.Highlight.lines(path, text) do
      {_, lines} ->
        lines
        |> drop_final_blank(String.ends_with?(text, "\n"))
        |> Enum.with_index(1)
        |> Enum.map(fn {html, n} -> {:add, nil, n, "+", html} end)

      _ ->
        []
    end
  end

  defp drop_final_blank(lines, true) when lines != [] do
    if List.last(lines) == "", do: Enum.drop(lines, -1), else: lines
  end

  defp drop_final_blank(lines, _), do: lines

  # A revision's diff — a commit, a range as {base, tip}, or the working
  # tree against HEAD as :worktree — file by file: the path, its ±
  # counts (nil for a binary), whether it was born or is gone, and its
  # rows ready for the sheet.
  def files_of(workspace, rev) do
    {cmd, args, tip, base} =
      case rev do
        :worktree -> {"diff", ["HEAD"], :worktree, "HEAD"}
        {base, tip} -> {"diff", [base, tip], tip, base}
        sha -> {"show", [sha], sha, sha <> "^"}
      end

    counts =
      git(workspace, [cmd, "--format=", "--numstat" | args])
      |> String.split("\n", trim: true)
      |> Enum.map(&String.split(&1, "\t"))
      |> Enum.filter(&(length(&1) == 3))
      |> Map.new(fn [a, r, path] -> {path, {num(a), num(r)}} end)

    git(workspace, [cmd, "--format=" | args])
    |> String.split(~r/^(?=diff --git )/m)
    |> Enum.filter(&String.starts_with?(&1, "diff --git "))
    |> Enum.map(&file_of(workspace, &1, counts, tip, base))
  end

  # One file of the diff, off its chunk.
  defp file_of(workspace, chunk, counts, tip, base) do
    path = path_of(chunk)
    {added, removed} = Map.get(counts, path, {nil, nil})
    born = Regex.match?(~r/^new file mode /m, chunk)
    gone = Regex.match?(~r/^deleted file mode /m, chunk)
    treatment = Console.Highlight.treatment(path)
    # An image of the working tree has no revision the blob route could
    # serve: it is shown as what it is, binary, until it is committed.
    binary = is_nil(added) or (tip == :worktree and treatment == :image)

    new_face = if gone or binary, do: nil, else: face(workspace, tip, path)
    old_face = if born or binary, do: nil, else: face(workspace, base, path)

    %{
      path: path,
      added: added,
      removed: removed,
      born: born,
      gone: gone,
      binary: binary,
      treatment: treatment,
      tip: if(tip == :worktree, do: "HEAD", else: tip),
      base: base,
      rows: rows(patch(chunk), new_face, old_face)
    }
  end

  # The hunks of the chunk, without the header.
  defp patch(chunk) do
    case Regex.run(~r/^@@ .*/ms, chunk) do
      [hunk] -> String.trim_trailing(hunk, "\n")
      _ -> ""
    end
  end

  defp num("-"), do: nil
  defp num(s), do: String.to_integer(s)

  defp path_of(chunk) do
    Enum.find_value(
      [~r/^\+\+\+ b\/(.+)$/m, ~r/^--- a\/(.+)$/m, ~r/^diff --git a\/(.+?) b\//],
      "?",
      fn re ->
        case Regex.run(re, chunk) do
          [_, p] when p != "dev/null" -> p
          _ -> nil
        end
      end
    )
  end

  # A face of the file, cut into lines: nil when it cannot be read or is
  # not text. The working tree's face is the file on disk.
  defp face(workspace, :worktree, path) do
    case File.read(Path.join(workspace, path)) do
      {:ok, out} -> lines_of(path, out)
      _ -> nil
    end
  end

  defp face(workspace, rev, path) do
    case System.cmd("git", ["-C", workspace, "show", rev <> ":" <> path], stderr_to_stdout: true) do
      {out, 0} -> lines_of(path, out)
      _ -> nil
    end
  end

  # The text cut into coloured lines; nil for what is not text.
  defp lines_of(path, out) do
    if String.valid?(out) do
      case Console.Highlight.lines(path, out) do
        {_, lines} -> List.to_tuple(lines)
        _ -> nil
      end
    end
  end

  # The rows of the patch: each with the line numbers it has, its sign,
  # and the line itself — coloured off the face it came from when that
  # face could be read, the patch's own text otherwise.
  defp rows(patch, new_face, old_face) do
    patch
    |> String.split("\n")
    |> Enum.reduce({[], 0, 0}, fn line, {rows, o, n} ->
      cond do
        m = Regex.run(~r/^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/, line) ->
          [_, o, n] = m

          {[{:hunk, nil, nil, "", escape(line)} | rows], String.to_integer(o),
           String.to_integer(n)}

        line == "" or
            Regex.match?(
              ~r/^(diff --git |index |new file|deleted file|similarity |rename |--- |\+\+\+ |Binary files)/,
              line
            ) ->
          {rows, o, n}

        String.starts_with?(line, "+") ->
          {[{:add, nil, n, "+", at(new_face, n, line)} | rows], o, n + 1}

        String.starts_with?(line, "-") ->
          {[{:del, o, nil, "−", at(old_face, o, line)} | rows], o + 1, n}

        String.starts_with?(line, "\\") ->
          {[{:meta, nil, nil, "", escape(line)} | rows], o, n}

        true ->
          {[{:ctx, o, n, " ", at(new_face, n, line)} | rows], o + 1, n + 1}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp at(nil, _n, line), do: escape(String.slice(line, 1..-1//1))

  defp at(face, n, line),
    do:
      if(n >= 1 and n <= tuple_size(face),
        do: elem(face, n - 1),
        else: escape(String.slice(line, 1..-1//1))
      )

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp git(workspace, args) do
    case System.cmd("git", ["-C", workspace | args], stderr_to_stdout: true) do
      {out, 0} -> out
      _ -> ""
    end
  end
end
