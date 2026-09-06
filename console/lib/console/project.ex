defmodule Console.Project do
  @moduledoc """
  The project's own papers, off the workspace: README.md, CHANGELOG.md
  and `.env`. The `.env` travels masked — a secret, a token, a password,
  a key, and the credentials inside a URL are replaced before the text
  leaves this module, so no page ever carries them.
  """

  alias Console.Papers

  @papers [
    {"readme", "README", "README.md"},
    {"changelog", "CHANGELOG", "CHANGELOG.md"},
    {"env", ".env", ".env"}
  ]

  def papers, do: @papers

  @doc """
  What the project was made with, off the `Dockerfile.local` the
  workspace keeps: the stack and the Phoenix installer, as `wb.sh`
  stamped them the day it was created. `bake` rewrites that file when the
  seed moves but keeps the installer it was born with — that is the
  project's generator, not config.conf's next choice — so this is the
  project's own record and not a second opinion about what is configured.
  """
  def born(nil), do: nil

  def born(workspace) do
    case File.read(Path.join(workspace, "Dockerfile.local")) do
      {:ok, text} ->
        ~r/^ARG\s+(ELIXIR|OTP|DEBIAN|PHX_NEW)="([^"]*)"/m
        |> Regex.scan(text)
        |> Map.new(fn [_, key, value] -> {key, value} end)

      _ ->
        nil
    end
  end

  @doc "Which of the three the workspace has."
  def carried(nil), do: []

  def carried(workspace),
    do: for({key, _, file} <- @papers, File.regular?(Path.join(workspace, file)), do: key)

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
      md
      |> Papers.to_html()
      |> String.replace(~r/<img src="(?!https?:|data:)/, ~s(<img src="#" data-missing="))
      |> Papers.booklet("p-", file)
    else
      _ -> nil
    end
  end

  @doc """
  The .env with its secrets replaced by dots: by key name, and inside
  URLs. A compose file's `KEY: value` lines the same way — the Docker
  screen shows the three composes, and `POSTGRES_PASSWORD: postgres` is
  a secret whatever the punctuation after the key.
  """
  def mask(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &mask_line/1)
  end

  # One line: the value of a secret key goes, a password inside a URL goes.
  defp mask_line(line) do
    case Regex.run(~r/^(\s*)([A-Za-z][A-Za-z0-9_]*)(=|: )(.*)$/, line) do
      [_, indent, key, sep, value] ->
        cond do
          Regex.match?(~r/SECRET|TOKEN|PASSWORD|KEY/i, key) ->
            indent <> key <> sep <> "••••••••"

          String.contains?(value, "://") ->
            indent <>
              key <> sep <> Regex.replace(~r/:\/\/([^:@\/]+):[^@\/]+@/, value, "://\\1:••••@")

          true ->
            line
        end

      _ ->
        line
    end
  end
end
