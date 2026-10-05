defmodule WorkbenchIgniter.BlockFile do
  @moduledoc """
  The project's shared *ordered* files — `test_helper.exs`, a git hook:
  plain text several cartridges write into, where order carries
  meaning. Everything that works on them lives here. Igniter has
  nothing for them.

  `WorkbenchIgniter.TextFile` is the other half of this: `.env` and
  `.gitignore` are **sets**, so an entry goes at the end and a merge
  can reorder freely (`IgnoreFile.merge/3` never conflicts, because
  order carries no meaning there). These files are not sets. Every
  `Mimic.copy/1` has to stand before `ExUnit.start()`; a hook runs its
  commands in sequence and the first failure cuts the rest. Appending
  at the end is wrong here, and rewriting the file whole means the
  second cartridge erases the first.

  So a cartridge owns a **block**, delimited and named:

      # >>> coverage
      Mimic.copy(File)
      # <<< coverage

  and this module puts it, replaces it, reads it and takes it away
  without touching anybody else's. Four properties come out of that,
  and they are the reason the delimiters are there rather than an
  implicit convention:

    * `put/5` is idempotent, and re-running an installer with other
      options **replaces** the block where it stands instead of adding
      a second one.
    * `drop/4` leaves the file as if the cartridge had never passed —
      what an eject owes — and `owners/2` answers *who wrote here*,
      which is what an eject that cannot apply has to say.
    * A three-way merge compares a block with the block of the same
      owner, never with whatever ended up beside it.
    * A reader of the project's file can see which lines came in
      together and delete them together, which is the block's excuse
      for existing in a file the project owns.

  **The delimiter is never a mark.** `installed?/1` and `state/1` read
  the project's own marks — the dep, the route, the file the installer
  wrote — "never off a record kept for the workbench"
  (`WorkbenchIgniter.Feature`). A block's sentinel is an editing
  boundary inside a file, not a register, and no cartridge may answer
  either callback by looking for one.

  ## The block

  `>>> owner` opens and `<<< owner` closes, each behind the file's
  comment marker (`:comment`, `#` by default — Elixir, shell, YAML and
  Make all take it). `owner` is the cartridge's name as the catalog
  names it. The open line takes an optional `:note`, for the project's
  reader:

      # >>> health_endpoint — the modules its controller test copies

  ## Where a new block goes

  `:before` names the line the block must stand above: the first line
  that contains that string (or matches that regex) — `ExUnit.start()`
  for `test_helper.exs`. Without it, or when no line matches, the block
  goes at the end. A block that is already there is replaced **where it
  is**: the anchor decides where a block is born, never where it lives
  afterwards, so a project that moved it keeps it moved.

  Blank lines are preserved: one is written between the block and what
  it was separated from, and none of the file's own spacing is
  squeezed. On `drop/4` only the seam is repaired — the blank line the
  block left doubled.

  ## Failure

  An open sentinel without its close is `{:error, {:unterminated,
  owner}}`; the Igniter-side functions raise, naming the file and the
  owner, because silently rewriting a file whose block somebody
  half-deleted is worse than stopping.
  """

  @default_comment "#"
  @owner_format ~r/\A[a-z0-9_]+\z/

  @type owner :: String.t()
  @type reason :: {:unterminated, owner()}

  # --- the project's files ----------------------------------------------------

  @doc """
  The owner's block in the project's `path`, put where `:before` says
  or replaced where it stands. A project without the file gets it,
  starting from `:create` (the empty string by default) — a hook's
  shebang, say.

  Options: `:comment`, `:note`, `:before`, `:create`.
  """
  @spec put(Igniter.t(), Path.t(), owner(), String.t(), keyword()) :: Igniter.t()
  def put(igniter, path, owner, body, opts \\ []) do
    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(
        path,
        &Rewrite.Source.update(&1, :content, fn content ->
          content |> put_text(owner, body, opts) |> unwrap!(path)
        end)
      )
    else
      content =
        opts
        |> Keyword.get(:create, "")
        |> put_text(owner, body, opts)
        |> unwrap!(path)

      Igniter.create_new_file(igniter, path, content)
    end
  end

  @doc """
  The owner's block out of the project's `path`. A no-op when the file
  has no such block, and when the project has no such file.
  """
  @spec drop(Igniter.t(), Path.t(), owner(), keyword()) :: Igniter.t()
  def drop(igniter, path, owner, opts \\ []) do
    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(
        path,
        &Rewrite.Source.update(&1, :content, fn content ->
          content |> drop_text(owner, opts) |> unwrap!(path)
        end)
      )
    else
      igniter
    end
  end

  # --- the text ---------------------------------------------------------------

  @doc "`content` with the owner's block put or replaced. The body of `put/5`."
  @spec put_text(String.t(), owner(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, reason()}
  def put_text(content, owner, body, opts \\ []) do
    comment = comment(opts)
    validate!(owner)

    case locate(content, owner, comment) do
      {:error, reason} ->
        {:error, reason}

      {:ok, found} ->
        lines = lines(content)
        block = block_lines(comment, owner, body, opts)

        placed =
          case found do
            {from, to} -> Enum.take(lines, from) ++ block ++ Enum.drop(lines, to + 1)
            nil -> insert(lines, block, opts)
          end

        {:ok, unlines(placed)}
    end
  end

  @doc "`content` without the owner's block. The body of `drop/4`."
  @spec drop_text(String.t(), owner(), keyword()) :: {:ok, String.t()} | {:error, reason()}
  def drop_text(content, owner, opts \\ []) do
    validate!(owner)

    case locate(content, owner, comment(opts)) do
      {:error, reason} -> {:error, reason}
      {:ok, nil} -> {:ok, content}
      {:ok, {from, to}} -> {:ok, removed(lines(content), from, to)}
    end
  end

  @doc """
  The body of the owner's block, without its sentinels; `:error` when
  the content has no block of that owner.
  """
  @spec block(String.t(), owner(), keyword()) :: {:ok, String.t()} | :error | {:error, reason()}
  def block(content, owner, opts \\ []) do
    case locate(content, owner, comment(opts)) do
      {:error, reason} ->
        {:error, reason}

      {:ok, nil} ->
        :error

      {:ok, {from, to}} ->
        {:ok, content |> lines() |> Enum.slice(from + 1, to - from - 1) |> unlines()}
    end
  end

  @doc """
  Every owner with a block in `content`, in the order their blocks
  stand — what an eject that cannot apply says about who wrote there.
  """
  @spec owners(String.t(), keyword()) :: [owner()]
  def owners(content, opts \\ []) do
    prefix = open_prefix(comment(opts), "")

    content
    |> lines()
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.map(fn line ->
      line |> String.replace_prefix(prefix, "") |> String.split(" ", parts: 2) |> hd()
    end)
  end

  # --- sentinels --------------------------------------------------------------

  defp comment(opts), do: Keyword.get(opts, :comment, @default_comment)

  defp open_prefix(comment, owner), do: "#{comment} >>> #{owner}"
  defp close_line(comment, owner), do: "#{comment} <<< #{owner}"

  defp open_line(comment, owner, nil), do: open_prefix(comment, owner)
  defp open_line(comment, owner, note), do: "#{open_prefix(comment, owner)} — #{note}"

  defp block_lines(comment, owner, body, opts) do
    [open_line(comment, owner, Keyword.get(opts, :note))] ++
      lines(body) ++ [close_line(comment, owner)]
  end

  defp validate!(owner) do
    unless is_binary(owner) and Regex.match?(@owner_format, owner) do
      raise ArgumentError,
            "a block's owner is a cartridge name ([a-z0-9_]+), got: #{inspect(owner)}"
    end
  end

  # {from, to} of the owner's block, `nil` when it has none.
  defp locate(content, owner, comment) do
    lines = lines(content)
    open = open_prefix(comment, owner)
    close = close_line(comment, owner)

    case Enum.find_index(lines, &open?(&1, open)) do
      nil ->
        {:ok, nil}

      from ->
        case lines |> Enum.drop(from) |> Enum.find_index(&(String.trim_trailing(&1) == close)) do
          nil -> {:error, {:unterminated, owner}}
          offset -> {:ok, {from, from + offset}}
        end
    end
  end

  # The open line is the prefix alone, or the prefix and a note.
  defp open?(line, prefix) do
    line = String.trim_trailing(line)
    line == prefix or String.starts_with?(line, prefix <> " ")
  end

  # --- placement --------------------------------------------------------------

  defp insert(lines, block, opts) do
    case anchor(lines, Keyword.get(opts, :before)) do
      nil ->
        cond do
          lines == [] -> block
          blank?(List.last(lines)) -> lines ++ block
          true -> lines ++ [""] ++ block
        end

      index ->
        {head, tail} = Enum.split(lines, index)
        head = if head == [] or blank?(List.last(head)), do: head, else: head ++ [""]
        head ++ block ++ [""] ++ tail
    end
  end

  defp anchor(_lines, nil), do: nil

  defp anchor(lines, %Regex{} = regex), do: Enum.find_index(lines, &Regex.match?(regex, &1))

  defp anchor(lines, string) when is_binary(string),
    do: Enum.find_index(lines, &String.contains?(&1, string))

  # The block out, and only the seam it leaves repaired.
  defp removed(lines, from, to) do
    kept = Enum.take(lines, from) ++ Enum.drop(lines, to + 1)

    cond do
      from == 0 ->
        kept |> Enum.drop_while(&blank?/1) |> unlines()

      from >= length(kept) ->
        kept |> drop_trailing_blanks() |> unlines()

      blank?(Enum.at(kept, from - 1)) and blank?(Enum.at(kept, from)) ->
        kept |> List.delete_at(from) |> unlines()

      true ->
        unlines(kept)
    end
  end

  # --- lines ------------------------------------------------------------------

  defp lines(""), do: []
  defp lines(content), do: content |> String.trim_trailing("\n") |> String.split("\n")

  defp unlines([]), do: ""
  defp unlines(lines), do: Enum.join(lines, "\n") <> "\n"

  defp blank?(line), do: String.trim(line) == ""

  defp drop_trailing_blanks(lines) do
    lines |> Enum.reverse() |> Enum.drop_while(&blank?/1) |> Enum.reverse()
  end

  defp unwrap!({:ok, content}, _path), do: content

  defp unwrap!({:error, {:unterminated, owner}}, path) do
    raise "#{path}: the block of #{owner} opens (#{open_prefix(@default_comment, owner)}) " <>
            "and never closes; fix the file by hand before this cartridge touches it"
  end
end
