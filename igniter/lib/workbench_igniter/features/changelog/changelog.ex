defmodule WorkbenchIgniter.Features.Changelog do
  @moduledoc """
  A project with no versioning, given the means to have it: a
  `CHANGELOG.md` opened at the version the project is on, where every
  change from then on gets written down, and the number in `mix.exs`
  as the one thing that names a state of the code. On request, the tool
  that cuts the next version (`--mix-task`: a `mix version` task) and the
  badge that shows it (`--readme-badge`, in the README).

  Every Mix project has a `version:`; that is a number, not versioning.
  Without a record of what changes between one number and the next, the
  number never moves, and nobody — a user, whoever deploys it, the
  developer six months on — can say what a given build carries. This
  starts the record, at any point of the project's life: by default at
  the version `mix.exs` already has, which for a fresh `phx.new` is
  SemVer's own starting point, `0.1.0`; with `--init-version`, wherever
  the project decides its history opens.

  The changelog is Keep a Changelog in the house's dress: entries land
  in `Unreleased`, and the commented title line under it is the
  template for cutting a release. `mix version 1.2.0` does the cutting:
  writes the number into `mix.exs`, closes `Unreleased` as that version
  under the template line, and updates the README's badge when there is
  one. DESIGN.md has the sources and the decisions.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.changelog --mix-task --readme-badge"

  @task_file "lib/mix/tasks/version.ex"
  @task_test_file "test/mix/tasks/version_test.exs"
  @changelog "CHANGELOG.md"
  @readme "README.md"
  @badge_url "https://img.shields.io/badge/version-"

  @impl true
  def task, do: "workbench.install.changelog"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      init_version:
        "Version the project's history opens at: the changelog's first release, and `mix.exs` when it says another. Default: the version `mix.exs` has.",
      mix_task:
        "Installs `mix version NEW`, which writes the number into `mix.exs`, closes the changelog's `Unreleased` as that version and updates the README badge when there is one. Off by default.",
      readme_badge:
        "Puts a version badge under the README's title, for `mix version` to keep current. Off by default."
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [init_version: :string, mix_task: :boolean, readme_badge: :boolean],
      defaults: [mix_task: false, readme_badge: false]
    }
  end

  # The task and the badge are pieces: a second run with the switch
  # adds the one missing, and never moves the version.
  @impl true
  def rerun, do: :adds

  # The mark: the changelog. The version in mix.exs is no mark — every
  # project has one, `phx.new` saw to that.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, @changelog)

  @doc """
  What the project carries: the version its history opens at — the
  oldest release title of the changelog, not `mix.exs`'s number, which
  moves with every release — whether the task is there, and whether the
  README carries the badge (`nil` with no README to carry it).
  """
  @impl true
  def state(igniter) do
    {changelog, igniter} = file_content(igniter, @changelog)
    {task, igniter} = file_installed?(igniter, @task_file)
    {readme, igniter} = file_content(igniter, @readme)
    badge = if readme, do: String.contains?(readme, @badge_url)

    {%{init_version: changelog && opened_at(changelog), mix_task: task, readme_badge: badge},
     igniter}
  end

  # The latest version comes first, so the last title is where the
  # history opens. The house's `## v1.2.3 - (date)` and Keep a
  # Changelog's own `## [1.2.3] - date` both read.
  defp opened_at(changelog) do
    case Regex.scan(~r/^## \[?v?(\d+\.\d+\.\d+[^\s\]]*)/m, changelog) do
      [] -> nil
      titles -> titles |> List.last() |> List.last()
    end
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options
    {current, igniter} = mix_project_value(igniter, :version)

    # The mark guards the version and the changelog: a project that
    # already keeps a changelog keeps its own version too — the two are
    # one decision, and a second run must not move the number under a
    # written history. The pieces are added on top, each when asked and
    # missing, and the badge shows the version the project has.
    case installed?(igniter) do
      {true, igniter} ->
        igniter
        |> Igniter.add_notice(
          "#{@changelog} already exists: the project keeps its own history, skipping."
        )
        |> add_pieces(opts, current)

      {false, igniter} ->
        open(igniter, opts, opts[:init_version] || current, current)
    end
  end

  # Where the history opens: the version asked for, or the one mix.exs
  # has. Mix compiles no project whose version `Version` cannot parse,
  # so neither is written before it parses.
  defp open(igniter, _opts, nil, _current) do
    Igniter.add_issue(
      igniter,
      "mix.exs's version is not a literal this can read: say where the history opens with --init-version."
    )
  end

  defp open(igniter, opts, init, current) do
    case Version.parse(init) do
      {:ok, _} ->
        changelog =
          template("changelog.eex",
            version: init,
            creation_date: Date.to_iso8601(today())
          )

        igniter
        |> set_version(init, current)
        |> Igniter.create_new_file(@changelog, changelog)
        |> add_pieces(opts, init)

      :error ->
        Igniter.add_issue(
          igniter,
          "--init-version #{init}: not a version Mix accepts. MAJOR.MINOR.PATCH, as in 0.1.0 or 2.0.0-rc.1."
        )
    end
  end

  # The developer's date, not UTC's: a release cut in the evening west
  # of Greenwich is not tomorrow's.
  defp today, do: :calendar.local_time() |> elem(0) |> Date.from_erl!()

  defp add_pieces(igniter, opts, version) do
    igniter
    |> add_task(opts[:mix_task])
    |> add_badge(opts[:readme_badge], version)
  end

  # mix.exs is left alone when it already says the version.
  defp set_version(igniter, version, version), do: igniter

  defp set_version(igniter, version, _current) do
    Igniter.Project.MixProject.update(igniter, :project, [:version], fn _zipper ->
      # A binary passed as {:code, ...} is parsed as source, so the
      # string literal needs its quotes.
      {:ok, {:code, inspect(version)}}
    end)
  end

  # --- the task ---------------------------------------------------------------

  defp add_task(igniter, true) do
    case file_installed?(igniter, @task_file) do
      {true, igniter} ->
        Igniter.add_notice(igniter, "#{@task_file} already exists: mix version is in, skipping.")

      {false, igniter} ->
        igniter
        |> Igniter.create_new_file(@task_file, template("version_task.eex", []))
        |> Igniter.create_new_file(@task_test_file, template("version_task_test.eex", []))
    end
  end

  defp add_task(igniter, _), do: igniter

  # --- the badge --------------------------------------------------------------

  # Under the README's title line, the badge `mix version` keeps
  # current. A README without a title gets it on top.
  defp add_badge(igniter, true, nil) do
    Igniter.add_notice(igniter, "mix.exs's version is not a literal this can read: no badge put.")
  end

  # shields.io splits label, message and colour on the dash, so one
  # inside the version (`2.0.0-rc.1`) is written doubled.
  defp add_badge(igniter, true, version) do
    badge = "![v#{version}](#{@badge_url}#{String.replace(version, "-", "--")}-lightgrey.svg)"

    case file_content(igniter, @readme) do
      {nil, igniter} ->
        Igniter.add_notice(igniter, "#{@readme} not found: no badge to put the version on.")

      {content, igniter} ->
        if String.contains?(content, @badge_url), do: igniter, else: put_badge(igniter, badge)
    end
  end

  defp add_badge(igniter, _, _), do: igniter

  defp put_badge(igniter, badge) do
    igniter
    |> Igniter.include_existing_file(@readme)
    |> Igniter.update_file(@readme, fn source ->
      Rewrite.Source.update(source, :content, &insert_badge(&1, badge))
    end)
  end

  defp insert_badge(content, badge) do
    case Regex.run(~r/^# .*$/m, content, return: :index) do
      [{at, len}] ->
        {head, tail} = String.split_at(content, at + len)
        head <> "\n\n" <> badge <> tail

      _ ->
        badge <> "\n\n" <> content
    end
  end
end
