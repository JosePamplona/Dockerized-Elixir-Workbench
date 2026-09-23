defmodule Console.Project do
  @moduledoc """
  The project's own papers, off the workspace: Birth, Mix, `.env`,
  README.md, CHANGELOG.md, and its git as Changes and History. Mix is
  `mix.exs` read as what it is (`WorkbenchIgniter.MixFile`, the module
  that owns the file): what `def project` says, and every package the
  project carries, off the status. The
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
    {"mix", "Mix", "mix.exs"},
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
  Which of the seven the workspace has, off the status: the files it
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

  # What `def project` says, as the project wrote it: each keyword and
  # its code, coloured as Elixir — `Mix.env() == :prod` stays an
  # expression. `deps:` is the table under it, not a line. And each dependency's options, the
  # table's own column, as plain text: what follows its name and
  # requirement, less where a git one comes from, which its name and
  # version already say.
  def render(workspace, "mix") do
    with {:ok, text} <- File.read(Path.join(workspace, "mix.exs")),
         {:ok, _} <- Code.string_to_quoted(text) do
      mix = WorkbenchIgniter.MixFile.read(text)

      spec =
        for {key, code} <- mix.project,
            key != :deps,
            do: {to_string(key), elixir(formatted(code))}

      options =
        for {name, code} <- mix.deps,
            options = options(code),
            options != [],
            into: %{},
            do: {to_string(name), one_a_line(options)}

      %{mix: %{spec: spec, options: options}}
    else
      _ -> nil
    end
  end

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

  @git_source [:git, :github, :tag, :branch, :ref]

  defp options(code) do
    options = WorkbenchIgniter.MixFile.options_of(code)

    if WorkbenchIgniter.MixFile.git_of(code),
      do: Keyword.drop(options, @git_source),
      else: options
  end

  # Each option on a line of its own, as a keyword list is written
  # once it no longer fits one: `only: :test,` then `runtime: false`.
  defp one_a_line(options) do
    Enum.map_join(options, ",\n", fn option -> [option] |> Macro.to_string() |> unbracket() end)
  end

  # The keyword list's own brackets, and only those: `[only: [:dev, :test]]`
  # keeps the inner list's.
  defp unbracket("[" <> rest), do: String.slice(rest, 0..-2//1)
  defp unbracket(text), do: text

  # The code the way `mix format` would write it, so a long value —
  # `docs:` is a page of options — breaks where the project's own file
  # would, and not wherever the column runs out.
  defp formatted(code) do
    code |> Macro.to_string() |> Code.format_string!() |> IO.iodata_to_binary()
  end

  # Coloured by the lexer the Files sheet uses, one HTML string: the
  # page wraps it in a `.src` that says it is Elixir.
  defp elixir(code) do
    case Console.Highlight.lines("mix.exs", code) do
      {_, lines} when is_list(lines) -> Enum.join(lines, "\n")
      _ -> code |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    end
  end

  @doc """
  Which cartridge put each package in `mix.exs`, and what it asks for:
  `%{name => reading}`, keyed as a package's row is (`ConsoleWeb.Packages.row/4`).
  `"by"` is `{:boxes, names}` — what an installed box declares, or for
  a base box what its insert commit added — `:born` for what the first
  commit already listed (phx.new, and the workbench's own dependency),
  and `:hand` for the rest. With a box come `"declared"`, the version it
  asks for, and for a base box `"read"` and `"from"`: read off its insert,
  at the phx.new stamped then. Read off git, so it runs apart from the
  page (`start_async`).
  """
  def brought_by(nil), do: %{}

  def brought_by(%{"workspace" => workspace} = status) when is_binary(workspace) do
    boxes = by_box(workspace, status)
    born = born_with(workspace, status)

    for dep <- get_in(status, ["project", "deps"]) || [], into: %{} do
      {dep["name"],
       boxes[dep["name"]] || %{"by" => if(dep["name"] in born, do: :born, else: :hand)}}
    end
  end

  def brought_by(_status), do: %{}

  # Each package the installed boxes put in mix.exs: the boxes, and what
  # the first of them asks for.
  defp by_box(workspace, status) do
    for c <- get_in(status, ["project", "cartridges"]) || [],
        c["installed"],
        dep <- box_packages(workspace, status, c),
        reduce: %{} do
      acc ->
        Map.update(acc, dep["name"], Map.put(dep, "by", {:boxes, [c["name"]]}), fn seen ->
          %{seen | "by" => {:boxes, elem(seen["by"], 1) ++ [c["name"]]}}
        end)
    end
  end

  # What mix.exs listed at the first commit.
  defp born_with(workspace, status) do
    case get_in(status, ["project", "birth", "sha"]) do
      sha when is_binary(sha) -> Console.Diffs.packages_at(workspace, sha)
      _ -> []
    end
  end

  # What a box put in mix.exs and asks for: what it declares, or — a
  # base box, which declares none — what its insert commit added.
  defp box_packages(workspace, status, c) do
    case c["deps"] do
      [_ | _] = deps ->
        for d <- deps, do: %{"name" => d["name"], "declared" => d["declared"]}

      _ ->
        inserts = ConsoleWeb.Cartridges.inserts(status, c["name"])

        for dep <- Console.Diffs.packages_of(workspace, inserts) do
          %{"name" => dep.name, "declared" => dep.requirement, "read" => true, "from" => dep.from}
        end
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
