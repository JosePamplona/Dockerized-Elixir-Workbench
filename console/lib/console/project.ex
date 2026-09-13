defmodule Console.Project do
  @moduledoc """
  The project's own papers, off the workspace: Birth, `.env`,
  README.md, CHANGELOG.md, and its git as Changes and History. The
  `.env` travels masked — a secret, a token, a password, a key, and the
  credentials inside a URL are replaced before the text leaves this
  module, so no page ever carries them. Three are no file: Birth is
  composed off the status by `ConsoleWeb.Record` — what the project is,
  which is what it was born as, first on the ribbon whenever there is a
  project to draw it for — and Changes and History are the workspace's git, read by
  `ConsoleWeb.ConsoleLive.Git`, there whenever there is a repository.
  Git was a tab of its own until 2026-09-09: the repository is the
  project's, so its papers are the project's too.
  """

  alias Console.Papers

  # The ribbon's order, and so the first paper taken: what the project
  # is, then what has happened to it, then what it holds — the git two
  # moved up beside the Record on 2026-09-10, from the tail where they
  # landed when Git stopped being a tab of its own.
  @papers [
    {"record", "Birth", nil},
    {"history", "History", nil},
    {"pending", "Changes", nil},
    {"env", ".env", ".env"},
    {"readme", "README", "README.md"},
    {"changelog", "CHANGELOG", "CHANGELOG.md"}
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

  @doc """
  Which of the six the workspace has, off the status: the files it
  holds, Birth whenever there is a project, Changes and History
  whenever there is a repository. Nothing without a status.
  """
  def carried(nil), do: []

  def carried(%{"exists" => true, "workspace" => workspace} = status) when is_binary(workspace) do
    repo? = get_in(status, ["git", "repo"]) == true

    for {key, _, file} <- @papers, carried?(key, file, workspace, repo?), do: key
  end

  def carried(_status), do: []

  defp carried?("record", _file, _workspace, _repo?), do: true
  defp carried?(key, _file, _workspace, repo?) when key in ["pending", "history"], do: repo?
  defp carried?(_key, file, workspace, _repo?), do: File.regular?(Path.join(workspace, file))

  @doc """
  A paper rendered: the booklet for the two in Markdown, the masked lines
  for .env. Record is drawn by the screen off the status as it stands,
  so its page is only the word that it was taken.
  """
  def render(nil, _key), do: nil

  def render(_workspace, "record"), do: %{record: true}
  def render(_workspace, "pending"), do: %{git: "pending"}
  def render(_workspace, "history"), do: %{git: "history"}

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
