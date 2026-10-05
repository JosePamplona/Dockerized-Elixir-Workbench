defmodule WorkbenchIgniter.RouterFile do
  @moduledoc """
  A Phoenix router read as what it is — pipelines, scopes, the routes
  in them — and a capability's change to it applied as operations on
  those, never as a text merge.

  Three base cartridges write into the router, and each writes where a
  project writes too: html turns the `scope "/api"` a project without
  it keeps its API in into a comment and puts a `scope "/"` beside it;
  dashboard and mailer open a dev block at the router's end, where a
  project appends its own scopes, and add their route at the end of the
  `/dev` scope, where a project adds its own. As text, each of those
  was a conflict on any project that had used its router (2026-09-19),
  though no route of the project's was ever in the capability's way.

  So `merge/3` reads base, theirs and the project's router as a tree of
  **items**, each known by what it is and not by where it sits:

    * a pipeline by its name, and in it a plug by what it plugs;
    * a scope by its path and alias, an `if` by its condition — the
      `if Application.compile_env(…, :dev_routes)` the dev block is;
    * in a scope, `pipe_through` by itself, a route by its verb and
      path (`get "/"`, `live_dashboard "/dashboard"`, `forward
      "/mailbox"`);
    * `use` and `import` by what they name; anything else by its code.

  An item carries the comments above it; the comments a block ends
  with, below its last item, are an item of their own. What theirs
  adds over base is added — after the item it follows in theirs, or at
  the end of the block when it ends theirs; what theirs takes away or
  changes is taken away or changed where the project still has it as
  base had it. A block the project left exactly as base had it becomes
  theirs whole, with phx.new's own layout. What the project changed is
  the project's: it stays, and a notice says what phx.new would have
  done with it — a notice, never an issue, since an issue withholds the
  whole patch set and the project's own edit is not a fault.

  The grammar is the router's, not any version's delta: the delta is
  read off the two generations each time. What makes it safe is a
  check, not a list — before anything is applied, the operations read
  off base and theirs are applied to base itself, item by item, and
  must give theirs back. A version of phx.new whose change the grammar
  cannot say (an item it cannot place, two items it knows by the same
  name) fails that check, and `merge/3` says `:fallback`: the router is
  then merged as text, as every other file is, conflict and all.
  """

  @blocks [:pipeline, :scope, :if]
  @routes ~w(get post put patch delete options head match live live_session live_dashboard forward resources)a

  @typedoc "What the project's router becomes, and the notices about what stayed the project's."
  @type result :: {:ok, String.t(), [String.t()]} | :fallback

  @doc """
  The project's router (`ours`) with the change from `base` to
  `theirs` applied as operations, or `:fallback` when the router cannot
  be read as items or the operations do not turn base into theirs.
  """
  @spec merge(String.t(), String.t(), String.t()) :: result
  def merge(ours, base, theirs) do
    with {:ok, b} <- read(base),
         {:ok, t} <- read(theirs),
         {:ok, o} <- read(ours),
         true <- round_trip?(b, t) do
      {text, notices} = apply_block(o, b, t, true)
      {:ok, text, notices}
    else
      _ -> :fallback
    end
  end

  # The operations read off base and theirs, applied to base item by
  # item — no block taken whole — give theirs back, save for layout.
  defp round_trip?(b, t) do
    {text, _} = apply_block(b, b, t, false)
    normal(text) == normal(t.text)
  end

  defp normal(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  # READING ====================================================================

  # A router as the root block: the body of its `defmodule`, over the
  # whole text, its items with their ranges as byte offsets.
  defp read(text) do
    with {:ok, ast} <- Sourceror.parse_string(text),
         {:defmodule, _, [_, _]} = mod <- ast,
         {:ok, root} <- block(mod, offsets(text), text) do
      {:ok, Map.put(root, :text, text)}
    else
      _ -> :error
    end
  end

  # A block — the module, a pipeline, a scope, an `if` — as its head
  # (from its first comment to the end of its `do` line), its items, and
  # its tail (from its last item to the line of its `end`).
  defp block({_, meta, args} = node, offs, text) do
    with [{{:__block__, _, [:do]}, body}] <- List.last(args) |> List.wrap() |> do_block(),
         do_line when is_integer(do_line) <- get_in(meta, [:do, :line]),
         end_line when is_integer(end_line) <- get_in(meta, [:end, :line]) do
      range = Sourceror.get_range(node, include_comments: true)
      start = offset(offs, range.start)
      stop = offset(offs, range.end)
      head_end = line_end(offs, text, do_line)
      end_start = line_start(offs, end_line)

      children = statements(body)

      with {:ok, items} <- items(children, offs, text) do
        last = items |> List.last(%{stop: head_end}) |> Map.fetch!(:stop)

        {:ok,
         %{
           start: start,
           stop: stop,
           head_end: head_end,
           items: items ++ tail_item(text, last, end_start)
         }}
      end
    else
      _ -> :error
    end
  end

  # What sits between the last item and the `end` line, when anything does.
  defp tail_item(text, last, end_start) do
    tail = binary_part(text, last, max(end_start - last, 0))

    if String.trim(tail) == "",
      do: [],
      else: [%{key: :tail, start: last + leading_space(tail), stop: end_start - 1, block: nil}]
  end

  defp do_block([{{:__block__, _, [:do]}, _} = kw]), do: [kw]
  defp do_block(_), do: :none

  defp statements({:__block__, _, stmts}) when is_list(stmts), do: stmts
  defp statements(nil), do: []
  defp statements(stmt), do: [stmt]

  defp items(nodes, offs, text) do
    items = Enum.map(nodes, &item(&1, offs, text))

    keys = for %{key: k} <- items, do: k

    cond do
      :error in items -> :error
      length(Enum.uniq(keys)) != length(keys) -> :error
      true -> {:ok, items}
    end
  end

  defp item(node, offs, text) do
    range = Sourceror.get_range(node, include_comments: true)

    item = %{
      key: key(node),
      start: offset(offs, range.start),
      stop: offset(offs, range.end),
      block: nil
    }

    with true <- block?(node),
         {:ok, b} <- block(node, offs, text) do
      %{item | block: b}
    else
      false -> item
      :error -> :error
    end
  end

  defp block?({name, _, args}) when name in @blocks and is_list(args),
    do: match?([{{:__block__, _, [:do]}, _}], List.last(args))

  defp block?(_), do: false

  # What an item is known by.
  defp key({:pipeline, _, [name | _]}), do: {:pipeline, code(name)}
  defp key({:scope, _, [path | rest]}), do: {:scope, code(path), alias_of(rest)}
  defp key({:if, _, [condition | _]}), do: {:if, code(condition)}
  defp key({:plug, _, [plug | _]}), do: {:plug, code(plug)}
  defp key({:pipe_through, _, _}), do: :pipe_through

  defp key({verb, _, [path | _]}) when verb in [:use, :import, :alias, :require],
    do: {verb, code(path)}

  defp key({verb, _, [path | _]} = node) when verb in @routes do
    case path do
      {:__block__, _, [p]} when is_binary(p) -> {verb, p}
      _ -> {:code, code(node)}
    end
  end

  defp key(node), do: {:code, code(node)}

  defp alias_of([{:__aliases__, _, _} = a | _]), do: code(a)
  defp alias_of(_), do: nil

  defp code(ast), do: ast |> Sourceror.to_string() |> String.replace(~r/\s+/, " ")

  # Line starts as byte offsets; a Sourceror position (1-based line,
  # column in characters) as the byte offset into the text.
  defp offsets(text) do
    lines = String.split(text, "\n")

    {starts, _} =
      Enum.map_reduce(lines, 0, fn line, at -> {{at, line}, at + byte_size(line) + 1} end)

    List.to_tuple(starts)
  end

  defp offset(offs, pos) do
    {at, line} = elem(offs, pos[:line] - 1)
    at + byte_size(String.slice(line, 0, pos[:column] - 1))
  end

  defp line_start(offs, line), do: elem(offs, line - 1) |> elem(0)

  defp line_end(offs, _text, line) do
    {at, content} = elem(offs, line - 1)
    at + byte_size(content)
  end

  defp leading_space(s), do: byte_size(s) - byte_size(String.trim_leading(s))

  # APPLYING ===================================================================

  # The change from base's block to theirs', applied to ours as splices
  # on ours' text; `whole?` lets a block the project left as base had it
  # become theirs whole — off for the round trip, which has to walk every
  # item.
  defp apply_block(o, b, t, whole?) do
    {splices, notices} = block_splices(o, b, t, whole?)
    {splice(o.text, splices), notices}
  end

  defp block_splices(o, b, t, whole?) do
    texts = %{o: o.text, b: b.text, t: t.text}
    walk(o, b, t, texts, whole?, [])
  end

  defp walk(o, b, t, texts, whole?, path) do
    om = Map.new(o.items, &{&1.key, &1})
    bm = Map.new(b.items, &{&1.key, &1})
    tm = Map.new(t.items, &{&1.key, &1})

    # The head: the comments above the block and its `do` line.
    head =
      head_ops(o, b, t, texts, path)

    t_keys = Enum.map(t.items, & &1.key)

    # The comment paragraphs ours keeps in this block: an item theirs
    # adds does not bring them a second time. A comment phx.new ends a
    # block with travels as the leading comment of whatever comes after
    # it — the project's scope appended below it, in ours; the dev
    # block, in theirs.
    kept =
      o.items
      |> Enum.reject(fn oi ->
        bi = bm[oi.key]
        bi && is_nil(tm[oi.key]) && same?(texts.o, oi, texts.b, bi)
      end)
      |> Enum.flat_map(&paragraphs(slice(texts.o, &1.start, &1.stop)))
      |> MapSet.new()

    adds =
      t.items
      |> Enum.with_index()
      |> Enum.reject(fn {item, _} -> Map.has_key?(bm, item.key) or Map.has_key?(om, item.key) end)
      |> Enum.map(fn {item, i} -> add_op(item, i, t, texts, o, om, t_keys, kept) end)

    ctx = %{o: o, texts: texts, whole?: whole?, path: path}
    others = Enum.map(b.items, &item_ops(&1, om[&1.key], tm[&1.key], ctx))

    {hs, hn} = head
    splices = hs ++ Enum.map(adds, & &1) ++ Enum.flat_map(others, &elem(&1, 0))
    notices = hn ++ Enum.flat_map(others, &elem(&1, 1))
    {splices, notices}
  end

  # What becomes of an item base has: kept, taken away, replaced by
  # theirs, walked into, or left with a notice.
  defp item_ops(bi, oi, ti, %{texts: texts} = ctx) do
    cond do
      ti && same?(texts.b, bi, texts.t, ti) -> {[], []}
      is_nil(oi) -> missing_ops(bi, ti, ctx.path)
      is_nil(ti) and same?(texts.o, oi, texts.b, bi) -> {[remove(ctx.o, oi)], []}
      is_nil(ti) -> {[], [notice(ctx.path, bi.key, :kept)]}
      true -> changed_ops(bi, oi, ti, ctx)
    end
  end

  # An item ours no longer has: nothing to do when theirs dropped it too,
  # or it is the tail.
  defp missing_ops(_bi, nil, _path), do: {[], []}
  defp missing_ops(%{key: :tail}, _ti, _path), do: {[], []}
  defp missing_ops(bi, _ti, path), do: {[], [notice(path, bi.key, :gone)]}

  # An item all three have, and theirs changed.
  defp changed_ops(bi, oi, ti, %{texts: texts} = ctx) do
    untouched = same?(texts.o, oi, texts.b, bi)

    cond do
      ctx.whole? and untouched ->
        {[replace(oi, texts.t, ti)], []}

      oi.block && bi.block && ti.block ->
        walk(
          put_text(oi.block, texts.o),
          put_text(bi.block, texts.b),
          put_text(ti.block, texts.t),
          texts,
          ctx.whole?,
          ctx.path ++ [bi.key]
        )

      untouched ->
        {[replace(oi, texts.t, ti)], []}

      true ->
        {[], [notice(ctx.path, bi.key, :changed)]}
    end
  end

  defp put_text(block, text), do: Map.put(block, :text, text)

  # The head changes where the project left it as base had it.
  defp head_ops(o, b, t, texts, path) do
    oh = slice(texts.o, o.start, o.head_end)
    bh = slice(texts.b, b.start, b.head_end)
    th = slice(texts.t, t.start, t.head_end)

    cond do
      path == [] -> {[], []}
      normal(bh) == normal(th) -> {[], []}
      normal(oh) == normal(bh) -> {[{o.start, o.head_end, th}], []}
      true -> {[], [notice(Enum.drop(path, -1), List.last(path), :changed)]}
    end
  end

  # An item theirs adds: at the end of ours' block when it ends theirs'
  # (before the block's closing comments) — where phx.new puts the dev
  # block, and where a project appends; else after the item it follows
  # in theirs, or the nearest item before it that ours has, or right
  # under the block's head. What separates it
  # from what it follows is what separates them in theirs.
  defp add_op(item, i, t, texts, o, om, t_keys, kept) do
    before = Enum.take(t_keys, i) |> Enum.reverse()
    t_prev_stop = if i == 0, do: t.head_end, else: Enum.at(t.items, i - 1).stop
    gap = slice(texts.t, t_prev_stop, item.start)
    body = slice(texts.t, item.start, item.stop) |> without_paragraphs(kept)
    last? = i == length(t.items) - 1 or (i == length(t.items) - 2 and List.last(t_keys) == :tail)

    at = add_at(item.key == :tail or last?, before, o, om)
    {at, at, gap <> body}
  end

  # Where an added item goes in ours: after its last item when it ends
  # theirs, else after the nearest item before it that ours has — the
  # one right before it first —, else under the head.
  defp add_at(at_end?, before, o, om) do
    o_body = Enum.reject(o.items, &(&1.key == :tail))

    if at_end? and o_body != [] do
      List.last(o_body).stop
    else
      case Enum.find(before, &Map.has_key?(om, &1)) do
        nil -> o.head_end
        k -> om[k].stop
      end
    end
  end

  # The comment paragraphs of a text: runs of comment lines, trimmed.
  defp paragraphs(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.chunk_by(&String.starts_with?(&1, "#"))
    |> Enum.filter(fn [first | _] -> String.starts_with?(first, "#") end)
    |> Enum.map(&Enum.join(&1, "\n"))
  end

  # An item's text without the leading comment paragraphs in `kept`,
  # and the blank line that followed each.
  defp without_paragraphs(text, kept) do
    lines = String.split(text, "\n")

    {lead, rest} =
      Enum.split_while(
        lines,
        &(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#"))
      )

    lead =
      lead
      |> Enum.chunk_by(&(String.trim(&1) == ""))
      |> Enum.chunk_every(2)
      |> Enum.reject(fn [para | _] ->
        MapSet.member?(kept, Enum.map_join(para, "\n", &String.trim/1))
      end)
      |> List.flatten()

    # The item's first line is placed by the gap before it.
    Enum.join(lead ++ rest, "\n") |> String.trim_leading()
  end

  # An item taken away, with what separates it from the item before it.
  defp remove(o, oi) do
    prev =
      o.items
      |> Enum.take_while(&(&1.key != oi.key))
      |> List.last()

    from = if prev, do: prev.stop, else: o.head_end
    {from, oi.stop, ""}
  end

  defp replace(oi, t_text, ti), do: {oi.start, oi.stop, slice(t_text, ti.start, ti.stop)}

  defp same?(a_text, a, b_text, b),
    do: normal(slice(a_text, a.start, a.stop)) == normal(slice(b_text, b.start, b.stop))

  defp slice(text, from, to), do: binary_part(text, from, max(to - from, 0))

  # Splices applied from the end of the text back, so the offsets of the
  # ones still to apply hold. Two at one offset — items theirs adds
  # side by side — go in the order they were made, the later applied
  # first so that it lands after.
  defp splice(text, splices) do
    splices
    |> Enum.with_index()
    |> Enum.sort_by(fn {{from, to, _}, i} -> {from, to, i} end, :desc)
    |> Enum.reduce(text, fn {{from, to, with}, _}, text ->
      binary_part(text, 0, from) <> with <> binary_part(text, to, byte_size(text) - to)
    end)
  end

  defp notice(path, key, what) do
    where = Enum.map_join(path ++ [key], " › ", &describe/1)

    case what do
      :kept ->
        "#{where} is the project's own now: phx.new with the capability would not have it, and it stays."

      :changed ->
        "#{where} was changed by the project: phx.new with the capability changes it too, and it stays as the project has it."

      :gone ->
        "#{where} was taken out by the project: phx.new with the capability changes it, and it stays out."
    end
  end

  defp describe({:pipeline, name}), do: "pipeline #{name}"
  defp describe({:scope, path, nil}), do: "scope #{path}"
  defp describe({:scope, path, a}), do: "scope #{path}, #{a}"
  defp describe({:if, c}), do: "if #{c}"
  defp describe({:plug, p}), do: "plug #{p}"
  defp describe(:pipe_through), do: "pipe_through"
  defp describe(:tail), do: "the comments at its end"
  defp describe({:code, c}), do: c
  defp describe({verb, p}), do: "#{verb} #{inspect(p)}"
end
