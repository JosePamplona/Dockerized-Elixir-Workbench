defmodule Console.Highlight.ElixirTokens do
  @moduledoc """
  Elixir's tokens, re-sorted where Makeup's lexer and the grammar VS
  Code reads Elixir with disagree.

  The palette is a VS Code theme, written in a grammar's scopes; the
  sheet is painted on Makeup's classes, and the lexer sorts coarser, or
  just otherwise. The grammar is `mjmcloug.vscode-elixir`'s, the one the
  theme's forty-six scopes are all found in. Each case below is a scope
  of it, and lands on a class the lexer left free or already means it;
  `console.css` gives the class the rule the theme gives the scope.

      punctuation.separator.object     `,`                      o
      keyword.operator.other           `=>`, `<<`, `>>`         o
      punctuation.separator.method     the dot in `Foo.Bar`     o
      punctuation.definition.constant  the colon of `:ok` and of `ok:`,
                                       the quotes of `:"a b"`   sa
      constant.other.symbol            `:erlang` before a dot,
                                       which the lexer calls a
                                       module                   sa, ss
      punctuation.definition.variable  the `&` of a capture     nd
      variable.other.anonymous         the `1` of `&1`          ni
      comment.wildcard                 `_`                      c
      constant.numeric                 `?a`                     mi
      punctuation.section.list         `~w(` and its `)a`       p
      parameter.variable.function      a name in a `def`'s head nv
      comment.documentation            `@doc`, `@moduledoc` or
                                       `@typedoc` with its string,
                                       its heredoc or `false`   sd
      constant.character.escape        `\\x1f` whole, where the
                                       lexer stops at `\\x`      se

  And one the grammar has right and the lexer wrong: a keyword after a
  dot (`Mix.raise`, `range.end`) is a name.

  How the two were compared, a character at a time over the repository
  and its dependencies, and what was left apart on purpose, is in the
  CHANGELOG (2026-10-01).
  """

  @type token :: {atom(), map(), term()}

  @doc_attributes ~w(@doc @moduledoc @typedoc)
  # What the grammar opens a head with: `defp?|defmacrop?`. A guard, a
  # delegate, a protocol's are not heads to it.
  @heads ~w(def defp defmacro defmacrop)
  @keywords [:keyword, :keyword_declaration, :keyword_namespace, :operator_word]
  # The pieces a quoted thing is lexed in, by what it is.
  @quoted [:string, :string_char, :string_symbol, :string_sigil]

  @doc "The lexer's tokens, as the editor's grammar would have sorted them."
  @spec as_its_editor_reads([token()]) :: [token()]
  def as_its_editor_reads(tokens), do: tokens |> long_escapes() |> read()

  # --- one token at a time ----------------------------------------------

  defp read([]), do: []

  defp read([{:punctuation, meta, sep} | rest]) when sep in [",", "=>", "<<", ">>"],
    do: [{:operator, meta, sep} | read(rest)]

  defp read([{:operator, meta, "&"} | rest]), do: [{:name_decorator, meta, "&"} | read(rest)]

  defp read([{:name_entity, meta, value} | rest]) do
    "&" <> place = text(value)
    [{:name_decorator, meta, "&"}, {:name_entity, meta, place} | read(rest)]
  end

  defp read([{:name_builtin_pseudo, meta, "_"} | rest]), do: [{:comment, meta, "_"} | read(rest)]

  defp read([{:operator, _, "."} = dot, {keyword, meta, value} | rest]) when keyword in @keywords,
    do: [dot, {:name, meta, value} | read(rest)]

  defp read([{:name_class, meta, value} = token | rest]) do
    case text(value) do
      ":" <> name -> [{:string_affix, meta, ":"}, {:string_symbol, meta, name} | read(rest)]
      name -> if name =~ ".", do: module(name, meta) ++ read(rest), else: [token | read(rest)]
    end
  end

  defp read([{:string_char, meta, value} = token | rest]) do
    # `?a` is a number; `'abc'`, the same token to the lexer, is not.
    if String.starts_with?(text(value), "?"),
      do: [{:number_integer, meta, value} | read(rest)],
      else: [token | read(rest)]
  end

  defp read([{:string_sigil, _, value} = token | rest] = tokens) do
    if text(value) =~ ~r/\A~[wW]/ do
      {list, rest} =
        delimited(tokens, :string_sigil, ~r/\A~[wW](?:"""|'''|.)/s, "[acs]*", :punctuation)

      list ++ read(rest)
    else
      [token | read(rest)]
    end
  end

  defp read([{:string_symbol, meta, value} = token | rest] = tokens) do
    name = text(value)

    {atom, rest} =
      cond do
        # `:"a b"`, `"a b":`, and the same in single quotes.
        String.starts_with?(name, ["\"", "'", ":\"", ":'"]) ->
          delimited(tokens, :string_symbol, ~r/\A:?["']/, "", :string_affix)

        String.starts_with?(name, ":") and name != ":" ->
          {[{:string_affix, meta, ":"}, {:string_symbol, meta, String.slice(name, 1..-1//1)}],
           rest}

        true ->
          {[token], rest}
      end

    case rest do
      [{:punctuation, meta, ":"} | rest] -> atom ++ [{:string_affix, meta, ":"} | read(rest)]
      _ -> atom ++ read(rest)
    end
  end

  defp read([{:name_attribute, meta, value} = token | rest]) do
    with true <- text(value) in @doc_attributes,
         {doc, rest} <- doc_value(rest) do
      [{:string_doc, meta, value} | doc] ++ read(rest)
    else
      _ -> [token | read(rest)]
    end
  end

  defp read([
         {:keyword_declaration, _, def} = keyword,
         {:whitespace, _, _} = space,
         {:name_function, _, _} = name,
         {:punctuation, %{group_id: group}, "("} = open | rest
       ])
       when def in @heads do
    # Makeup has paired the brackets: the head ends at this one's mate.
    case Enum.split_while(rest, &(not match?({:punctuation, %{group_id: ^group}, ")"}, &1))) do
      {head, [close | rest]} ->
        [keyword, space, name, open | Enum.map(read(head), &parameter/1)] ++ [close | read(rest)]

      {_, []} ->
        [keyword, space, name, open | read(rest)]
    end
  end

  # The name a module is defined with is one name to the grammar, dots
  # and all (`entity.name.type.module`); anywhere else they separate.
  defp read([
         {:keyword_declaration, _, "defmodule"} = keyword,
         {:whitespace, _, _} = space,
         {:name_class, _, _} = name | rest
       ]),
       do: [keyword, space, name | read(rest)]

  defp read([token | rest]), do: [token | read(rest)]

  defp parameter({:name, meta, value}), do: {:name_variable, meta, value}
  defp parameter(token), do: token

  # `Foo.Bar` is one token to the lexer; the dots are separators.
  defp module(name, meta) do
    name
    |> String.split(".")
    |> Enum.map(&{:name_class, meta, &1})
    |> Enum.intersperse({:operator, meta, "."})
    |> Enum.reject(&(elem(&1, 2) == ""))
  end

  # --- docs ----------------------------------------------------------------

  # What a doc attribute is given, when it is documentation: `false`, or
  # a string of either quote, heredoc or `~s`/`~S` (which the lexer hands
  # as a string). Anything else — `@doc since: "1.2"`, a bare `@doc` —
  # is nil, and the attribute stays one.
  defp doc_value([{:whitespace, _, _} = space | rest]), do: doc_value(rest, [space])
  defp doc_value(rest), do: doc_value(rest, [])

  defp doc_value([{:name_constant, meta, "false"} | rest], space),
    do: {space ++ [{:string_doc, meta, "false"}], rest}

  defp doc_value([{kind, _, _} | _] = tokens, space) when kind in [:string, :string_char] do
    {run, rest} = run(tokens, kind)
    {space ++ flat(run, fn {_, meta, value} -> {:string_doc, meta, value} end), rest}
  end

  defp doc_value(_, _), do: nil

  # --- a quoted thing, as the run of tokens it is --------------------------

  # A string, a sigil, a quoted atom: its text in pieces, with an escape,
  # a prompt or a `\#{}` hole between them. The run is those, in order;
  # a hole carries what it holds, which is code like any other.
  defp run([{kind, _, _} = token | rest], kind), do: with_run({:piece, token}, run(rest, kind))

  defp run([{between, _, _} = token | rest], kind)
       when between in [:string_escape, :generic_prompt],
       do: with_run({:between, token}, run(rest, kind))

  defp run([{:string_interpol, _, "\#{"} = open | rest], kind) do
    {inside, close, rest} = hole(rest, 0, [])
    with_run({:hole, open, inside, close}, run(rest, kind))
  end

  defp run(rest, _kind), do: {[], rest}

  defp with_run(part, {run, rest}), do: {[part | run], rest}

  # A hole's inside, up to the brace that closes it; the depth is the
  # holes opened inside it, by the strings it may hold.
  defp hole([{:string_interpol, _, "}"} = close | rest], 0, acc),
    do: {Enum.reverse(acc), [close], rest}

  defp hole([{:string_interpol, _, "}"} = token | rest], depth, acc),
    do: hole(rest, depth - 1, [token | acc])

  defp hole([{:string_interpol, _, "\#{"} = token | rest], depth, acc),
    do: hole(rest, depth + 1, [token | acc])

  defp hole([token | rest], depth, acc), do: hole(rest, depth, [token | acc])
  defp hole([], _depth, acc), do: {Enum.reverse(acc), [], []}

  # The run as tokens again: each piece as `piece` makes it, what stands
  # between as it was, and a hole's inside read like the rest of the file.
  defp flat(run, piece) do
    Enum.flat_map(run, fn
      {:piece, token} -> [piece.(token)]
      {:between, token} -> [token]
      {:hole, open, inside, close} -> [open | read(inside)] ++ close
    end)
  end

  # A run whose first piece opens with `open`: that opening cut off as
  # `mark`, and from the last piece the delimiter that answers it, with
  # what may trail it (`trailing`, a sigil's modifiers). The text between
  # is left as it was.
  @closers %{"(" => ")", "[" => "]", "{" => "}", "<" => ">"}

  defp delimited([{_, meta, value} | _] = tokens, kind, open, trailing, mark) do
    {run, rest} = run(tokens, kind)
    [{^kind, _, _} | more] = flat(run, & &1)

    [opening] = Regex.run(open, text(value))

    opener =
      if String.ends_with?(opening, ["\"\"\"", "'''"]),
        do: String.slice(opening, -3, 3),
        else: String.last(opening)

    close = Regex.compile!(Regex.escape(Map.get(@closers, opener, opener)) <> trailing <> "\\z")
    body = [{kind, meta, String.replace_prefix(text(value), opening, "")} | more]

    {body, closing} =
      with {{^kind, last_meta, last}, init} <- List.pop_at(body, -1),
           [closing] <- Regex.run(close, text(last)) do
        {init ++ [{kind, last_meta, String.replace_suffix(text(last), closing, "")}],
         [{mark, last_meta, closing}]}
      else
        _ -> {body, []}
      end

    {Enum.reject([{mark, meta, opening} | body] ++ closing, &(elem(&1, 2) == "")), rest}
  end

  # --- escapes -------------------------------------------------------------

  # The lexer ends an escape one character after the backslash, so of
  # `\x1f` it takes `\x` and leaves `1f` to the string. The digits go
  # back to the escape, as Elixir and the grammar read it.
  defp long_escapes([
         {:string_escape, meta, value} = escape,
         {kind, piece_meta, piece} = next | rest
       ])
       when kind in @quoted do
    with "\\x" <- text(value),
         [hex, tail] <-
           Regex.run(~r/\A([0-9a-fA-F]{1,2})(.*)\z/s, text(piece), capture: :all_but_first) do
      after_it = if tail == "", do: rest, else: [{kind, piece_meta, tail} | rest]
      [{:string_escape, meta, "\\x" <> hex} | long_escapes(after_it)]
    else
      _ -> [escape | long_escapes([next | rest])]
    end
  end

  defp long_escapes([token | rest]), do: [token | long_escapes(rest)]
  defp long_escapes([]), do: []

  # A lexer may hand a lone codepoint as the value; chardata wants a list.
  defp text(value), do: value |> List.wrap() |> IO.chardata_to_string()
end
