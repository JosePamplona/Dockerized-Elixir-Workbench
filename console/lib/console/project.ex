defmodule Console.Project do
  @moduledoc """
  The project's own papers, off the workspace: README.md, CHANGELOG.md
  and `.env`. The `.env` travels masked — a secret, a token, a password,
  a key, and the credentials inside a URL are replaced before the text
  leaves this module, so no page ever carries them.
  """

  alias Console.Papers

  @papers [{"readme", "README", "README.md"}, {"changelog", "CHANGELOG", "CHANGELOG.md"}, {"env", ".env", ".env"}]

  def papers, do: @papers

  @doc "Which of the three the workspace has."
  def carried(nil), do: []
  def carried(workspace), do: for({key, _, file} <- @papers, File.regular?(Path.join(workspace, file)), do: key)

  @doc "A paper rendered: the booklet for the two in Markdown, the masked lines for .env."
  def render(nil, _key), do: nil

  def render(workspace, "env") do
    case File.read(Path.join(workspace, ".env")) do
      {:ok, text} -> %{env: text |> mask() |> String.split("\n")}
      _ -> nil
    end
  end

  def render(workspace, key) do
    with {_, _, file} <- Enum.find(@papers, &(elem(&1, 0) == key)),
         {:ok, md} <- File.read(Path.join(workspace, file)) do
      html = md |> Papers.to_html() |> String.replace(~r/<img src="(?!https?:|data:)/, ~s(<img src="#" data-missing=")) |> Papers.head_ids("p-")
      {html, heads} = html
      title = Regex.run(~r/<h1[^>]*>(.*?)<\/h1>/s, html) |> then(&(&1 && Enum.at(&1, 1))) || file
      %{html: html, toc: if(length(heads) >= 3, do: heads, else: []), title: title}
    else
      _ -> nil
    end
  end

  @doc "The .env with its secrets replaced by dots: by key name, and inside URLs."
  def mask(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      case Regex.run(~r/^(\w+)=(.*)$/, line) do
        [_, key, value] ->
          cond do
            Regex.match?(~r/SECRET|TOKEN|PASSWORD|KEY/, key) -> key <> "=••••••••"
            String.contains?(value, "://") -> key <> "=" <> Regex.replace(~r/:\/\/([^:@\/]+):[^@\/]+@/, value, "://\\1:••••@")
            true -> line
          end

        _ -> line
      end
    end)
  end
end
