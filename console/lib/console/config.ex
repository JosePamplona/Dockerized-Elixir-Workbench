defmodule Console.Config do
  @moduledoc """
  `config.conf`, read as the form it already is: every `export KEY=value`
  a field, the comment block above it its help, the `# ---` lines its
  sections, `# --` a group inside one, the commented-out exports and the
  stack tags its alternatives. Read off the mount and never written
  here: the writer is `wb.sh config set` (see console/PLAN.md).

  A comment block belongs to whatever follows it with no blank line in
  between: an export takes it as its help; a blank line leaves it
  hanging — the section's intro when the block opened the section, its
  closing note when it came after a field.
  """

  defstruct sections: [], alts: %{}, stacks: [], text: ""

  @type field :: %{key: String.t(), value: String.t(), quoted: boolean(), help: String.t(), inline: String.t(), group: String.t()}

  @doc "The file parsed: sections of fields, the alternatives, the stack tags."
  def parse(text) do
    first = %{title: "Workspace", intro: [], outro: [], fields: []}

    acc =
      text
      |> String.split("\n")
      |> Enum.reduce(%{sections: [first], alts: %{}, stacks: [], block: [], opening: true, group: ""}, &line/2)

    %__MODULE__{
      text: text,
      # The file's header says what the file is, not what the workspace is.
      sections: acc.sections |> Enum.reverse() |> List.update_at(0, &%{&1 | intro: []}) |> Enum.map(&finish/1),
      alts: Map.new(acc.alts, fn {k, v} -> {k, Enum.reverse(v)} end),
      stacks: Enum.reverse(acc.stacks)
    }
  end

  defp finish(sec), do: %{sec | outro: Enum.reverse(sec.outro), fields: Enum.reverse(sec.fields)}

  defp line(raw, acc) do
    line = String.trim(raw)
    [sec | rest] = acc.sections

    cond do
      line == "" ->
        sec =
          cond do
            acc.block == [] -> sec
            acc.opening -> %{sec | intro: sec.intro ++ Enum.reverse(acc.block)}
            true -> %{sec | outro: [acc.block |> Enum.reverse() |> Enum.join(" ") | sec.outro]}
          end

        %{acc | sections: [sec | rest], block: []}

      m = Regex.run(~r/^# ---\s*(.*?)[\s.-]*$/, line) ->
        title = m |> Enum.at(1) |> String.replace(~r/\.$/, "")
        %{acc | sections: [%{title: title, intro: [], outro: [], fields: []} | acc.sections], block: [], opening: true, group: ""}

      m = Regex.run(~r/^# --\s*(.*?)[\s.-]*$/, line) ->
        %{acc | group: Enum.at(m, 1), block: []}

      m = Regex.run(~r/^# (\d[\w.]*-erlang-[\w.]*-debian-[\w.-]*)$/, line) ->
        %{acc | stacks: [Enum.at(m, 1) | acc.stacks]}

      m = Regex.run(~r/^# export (\w+)="?([^"]*)"?/, line) ->
        [_, key, value] = m
        %{acc | alts: Map.update(acc.alts, key, [value], &[value | &1])}

      m = Regex.run(~r/^export\s+(\w+)=("?)([^"#]*)\2\s*(?:#\s*(.*))?$/, line) ->
        [_, key, quote, value | inline] = m

        field = %{
          key: key,
          value: String.trim(value),
          quoted: quote == "\"",
          help: acc.block |> Enum.reverse() |> Enum.join(" ") |> String.trim(),
          inline: List.first(inline) || "",
          group: acc.group
        }

        %{acc | sections: [%{sec | fields: [field | sec.fields]} | rest], block: [], opening: false}

      m = Regex.run(~r/^#\s?(.*)$/, line) ->
        text = m |> Enum.at(1) |> String.trim()
        if text == "", do: acc, else: %{acc | block: [text | acc.block]}

      true ->
        acc
    end
  end

  @doc "Every field's value by key."
  def values(%__MODULE__{sections: sections}),
    do: for(sec <- sections, f <- sec.fields, into: %{}, do: {f.key, f.value})
end
