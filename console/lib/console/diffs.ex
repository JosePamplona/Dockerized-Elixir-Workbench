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
    Map.merge(%{sha: sha, subject: insert["subject"], date: insert["date"], files: files}, totals(files))
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
        for f <- files_of(workspace, {base, newest}),
            do: Map.put(f, :by, for({name, paths} <- touched, MapSet.member?(paths, f.path), do: name))

      Map.merge(
        %{contiguous: true, between: 0, picks: picks, files: files, range: String.slice(base, 0, 7) <> ".." <> String.slice(newest, 0, 7), base: base, tip: newest},
        totals(files)
      )
    else
      %{contiguous: false, between: max(last - first + 1 - length(idx), 0), picks: picks, files: [], added: 0, removed: 0, range: nil, base: nil, tip: newest}
    end
  end

  defp totals(files), do: %{added: Enum.sum(Enum.map(files, &(&1.added || 0))), removed: Enum.sum(Enum.map(files, &(&1.removed || 0)))}

  # A revision's diff — a commit, or a range as {base, tip} — file by
  # file: the path, its ± counts (nil for a binary), whether it was born
  # or is gone, and its rows ready for the sheet.
  def files_of(workspace, rev) do
    {cmd, args, tip, base} =
      case rev do
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
    |> Enum.map(fn chunk ->
      path = path_of(chunk)
      {added, removed} = Map.get(counts, path, {nil, nil})
      born = Regex.match?(~r/^new file mode /m, chunk)
      gone = Regex.match?(~r/^deleted file mode /m, chunk)
      patch = case Regex.run(~r/^@@ .*/ms, chunk) do [hunk] -> String.trim_trailing(hunk, "\n"); _ -> "" end
      binary = is_nil(added)

      new_face = if gone or binary, do: nil, else: face(workspace, tip, path)
      old_face = if born or binary, do: nil, else: face(workspace, base, path)

      %{
        path: path, added: added, removed: removed, born: born, gone: gone, binary: binary,
        treatment: Console.Highlight.treatment(path),
        tip: tip, base: base,
        rows: rows(patch, new_face, old_face)
      }
    end)
  end

  defp num("-"), do: nil
  defp num(s), do: String.to_integer(s)

  defp path_of(chunk) do
    Enum.find_value([~r/^\+\+\+ b\/(.+)$/m, ~r/^--- a\/(.+)$/m, ~r/^diff --git a\/(.+?) b\//], "?", fn re ->
      case Regex.run(re, chunk) do
        [_, p] when p != "dev/null" -> p
        _ -> nil
      end
    end)
  end

  # A face of the file, cut into lines: nil when it cannot be read or is
  # not text.
  defp face(workspace, rev, path) do
    case System.cmd("git", ["-C", workspace, "show", rev <> ":" <> path], stderr_to_stdout: true) do
      {out, 0} ->
        if String.valid?(out) do
          case Console.Highlight.lines(path, out) do
            {_, lines} -> List.to_tuple(lines)
            _ -> nil
          end
        end

      _ -> nil
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
          {[{:hunk, nil, nil, "", escape(line)} | rows], String.to_integer(o), String.to_integer(n)}

        line == "" or Regex.match?(~r/^(diff --git |index |new file|deleted file|similarity |rename |--- |\+\+\+ |Binary files)/, line) ->
          {rows, o, n}

        String.starts_with?(line, "+") -> {[{:add, nil, n, "+", at(new_face, n, line)} | rows], o, n + 1}
        String.starts_with?(line, "-") -> {[{:del, o, nil, "−", at(old_face, o, line)} | rows], o + 1, n}
        String.starts_with?(line, "\\") -> {[{:meta, nil, nil, "", escape(line)} | rows], o, n}
        true -> {[{:ctx, o, n, " ", at(new_face, n, line)} | rows], o + 1, n + 1}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp at(nil, _n, line), do: escape(String.slice(line, 1..-1//1))
  defp at(face, n, line), do: if(n >= 1 and n <= tuple_size(face), do: elem(face, n - 1), else: escape(String.slice(line, 1..-1//1)))

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

  defp git(workspace, args) do
    case System.cmd("git", ["-C", workspace | args], stderr_to_stdout: true) do
      {out, 0} -> out
      _ -> ""
    end
  end
end
