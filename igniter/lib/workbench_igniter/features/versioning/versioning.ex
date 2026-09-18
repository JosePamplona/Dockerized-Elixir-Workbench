defmodule WorkbenchIgniter.Features.Versioning do
  @moduledoc """
  A version the project chose, and a place to record what changes it:
  the `version:` of `mix.exs` set to the one asked for, and a
  `CHANGELOG.md` opened at it. On request, the tool that writes the
  next one (`--task`: a `mix version` task) and the badge that shows it
  (`--readme-badge`, in the README).

  `phx.new` writes `0.1.0` because a generator has to write something.
  This makes the number a decision — `0.0.0` for a project that has
  released nothing — and gives it the file where the next number gets
  its reasons.

  The changelog is Keep a Changelog with the workbench's own note on
  how to close a milestone; its `Unreleased` section is where entries
  land, and the commented title line above is the template for cutting
  a release. Same format the cartridges use for their own changelogs,
  which is where `version/0` reads them from. `mix version 1.2.0` does
  what the note says: writes the number into `mix.exs`, closes
  `Unreleased` as that version under the template line, and updates
  the README's badge when there is one.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.versioning --version 0.0.0 --task --readme-badge"

  @task_file "lib/mix/tasks/version.ex"
  @task_test_file "test/mix/tasks/version_test.exs"
  @readme "README.md"
  @badge_url "https://img.shields.io/badge/version-"

  @impl true
  def task, do: "workbench.install.versioning"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      version: "Version the project starts at, in `mix.exs` and the changelog. Default: `0.0.0`.",
      task:
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
      schema: [version: :string, task: :boolean, readme_badge: :boolean],
      defaults: [version: "0.0.0", task: false, readme_badge: false]
    }
  end

  # The task and the badge are pieces: a second run with the switch
  # adds the one missing, and never moves the version.
  @impl true
  def rerun, do: :adds

  # The mark: the changelog. The version in mix.exs is no mark — every
  # project has one, `phx.new` saw to that.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, "CHANGELOG.md")

  @doc """
  What the project carries: the version `mix.exs` declares, whether the
  task is there, and whether the README carries the badge (`nil` with
  no README to carry it).
  """
  @impl true
  def state(igniter) do
    {version, igniter} = mix_project_value(igniter, :version)
    {task, igniter} = file_installed?(igniter, @task_file)
    {readme, igniter} = file_content(igniter, @readme)
    badge = if readme, do: String.contains?(readme, @badge_url)
    {%{version: version, task: task, readme_badge: badge}, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    opts = igniter.args.options
    version = opts[:version] || "0.0.0"

    # The mark guards the version and the changelog: a project that
    # already keeps a changelog keeps its own version too — the two are
    # one decision, and a second run must not move the number under a
    # written history. The pieces are added on top, each when asked and
    # missing, and the badge shows the version the project has.
    {current, igniter} =
      case installed?(igniter) do
        {true, igniter} ->
          igniter =
            Igniter.add_notice(
              igniter,
              "CHANGELOG.md already exists: the project keeps its own history, skipping."
            )

          mix_project_value(igniter, :version)

        {false, igniter} ->
          changelog =
            template("changelog.eex",
              version: version,
              creation_date: Date.utc_today() |> Date.to_iso8601()
            )

          igniter =
            igniter
            |> set_version(version)
            |> Igniter.create_new_file("CHANGELOG.md", changelog)

          {version, igniter}
      end

    igniter
    |> add_task(opts[:task])
    |> add_badge(opts[:readme_badge], current || version)
  end

  defp set_version(igniter, version) do
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
  defp add_badge(igniter, true, version) do
    badge = "![v#{version}](#{@badge_url}#{version}-white.svg)"

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
