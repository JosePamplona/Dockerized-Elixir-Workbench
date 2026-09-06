defmodule Console.ANSI do
  @moduledoc """
  A line of terminal output as safe HTML: the text escaped, the SGR
  sequences (`\\e[1m`, `\\e[38;5;1m`, `\\e[0m`) turned into spans with
  classes the stylesheet colours. The workbench colours its own output
  on purpose — bold for a name, dark red for an error, blue for a link
  — and stripping it would throw away the only classification there
  is. Every other escape (cursor moves, clears) is dropped.

  Classes: `ansi-b` bold, `ansi-d` dim, `ansi-u` underline, `ansi-fg-N`
  for the sixteen colours (N 0..15) and `ansi-fg-N` again for the 256
  palette, since a page has no use for more than a name per colour.
  """

  @escape ~r/\e\[([0-9;]*)m|\e\[[0-9;?]*[A-Za-z]|\e\][^\a]*\a/

  @doc "The line with every escape taken out: what it says, for whatever reads it as text."
  @spec strip(String.t()) :: String.t()
  def strip(line), do: Regex.replace(@escape, line, "")

  @doc "The line as an HTML-safe iodata string, with spans for its styles."
  @spec to_html(String.t()) :: String.t()
  def to_html(line) do
    @escape
    |> Regex.split(line, include_captures: true)
    |> Enum.reduce({[], %{}}, &piece/2)
    |> elem(0)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  # One piece of the line: a style code moves the style, text takes it.
  defp piece(piece, {out, style}) do
    case Regex.run(~r/^\e\[([0-9;]*)m$/, piece) do
      [_, codes] ->
        {out, apply_codes(style, codes)}

      nil when piece == "" ->
        {out, style}

      nil ->
        if String.starts_with?(piece, "\e"),
          do: {out, style},
          else: {[span(style, piece) | out], style}
    end
  end

  defp span(style, text) when map_size(style) == 0, do: escape(text)

  defp span(style, text) do
    classes =
      Enum.flat_map(style, fn
        {:bold, true} -> ["ansi-b"]
        {:dim, true} -> ["ansi-d"]
        {:underline, true} -> ["ansi-u"]
        {:fg, n} -> ["ansi-fg-#{n}"]
        _ -> []
      end)

    if classes == [],
      do: escape(text),
      else: [~s(<span class="), Enum.join(classes, " "), ~s(">), escape(text), "</span>"]
  end

  defp escape(text), do: Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

  defp apply_codes(style, ""), do: apply_codes(style, "0")

  defp apply_codes(style, codes) do
    codes
    |> String.split(";")
    |> Enum.map(&String.to_integer((&1 == "" && "0") || &1))
    |> walk(style)
  end

  defp walk([], style), do: style
  defp walk([0 | rest], _style), do: walk(rest, %{})
  defp walk([1 | rest], style), do: walk(rest, Map.put(style, :bold, true))
  defp walk([2 | rest], style), do: walk(rest, Map.put(style, :dim, true))
  defp walk([4 | rest], style), do: walk(rest, Map.put(style, :underline, true))
  defp walk([22 | rest], style), do: walk(rest, style |> Map.delete(:bold) |> Map.delete(:dim))
  defp walk([24 | rest], style), do: walk(rest, Map.delete(style, :underline))
  defp walk([39 | rest], style), do: walk(rest, Map.delete(style, :fg))
  defp walk([38, 5, n | rest], style), do: walk(rest, Map.put(style, :fg, n))
  defp walk([38, 2, _r, _g, _b | rest], style), do: walk(rest, style)
  defp walk([n | rest], style) when n in 30..37, do: walk(rest, Map.put(style, :fg, n - 30))
  defp walk([n | rest], style) when n in 90..97, do: walk(rest, Map.put(style, :fg, n - 90 + 8))
  defp walk([_ | rest], style), do: walk(rest, style)
end
