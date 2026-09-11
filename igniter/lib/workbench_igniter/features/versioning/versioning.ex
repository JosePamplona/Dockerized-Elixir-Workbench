defmodule WorkbenchIgniter.Features.Versioning do
  @moduledoc """
  A version the project chose, and a place to record what changes it:
  the `version:` of `mix.exs` set to the one asked for, and a
  `CHANGELOG.md` opened at it.

  `phx.new` writes `0.1.0` because a generator has to write something.
  This makes the number a decision — `0.0.0` for a project that has
  released nothing — and gives it the file where the next number gets
  its reasons.

  The changelog is Keep a Changelog with the workbench's own note on
  how to close a milestone; its `Unreleased` section is where entries
  land, and the commented title line above is the template for cutting
  a release. Same format the cartridges use for their own changelogs,
  which is where `version/0` reads them from.
  """
  use WorkbenchIgniter.Feature

  embed_templates()

  @example "mix workbench.install.versioning --version 0.0.0"

  @impl true
  def task, do: "workbench.install.versioning"

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [version: "Version the project starts at, in `mix.exs` and the changelog. Default: `0.0.0`."]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [version: :string],
      defaults: [version: "0.0.0"]
    }
  end

  # The mark: the changelog. The version in mix.exs is no mark — every
  # project has one, `phx.new` saw to that.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, "CHANGELOG.md")

  @doc "What the project carries: the version `mix.exs` declares."
  @impl true
  def state(igniter) do
    {version, igniter} = mix_project_value(igniter, :version)
    {%{version: version}, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    version = igniter.args.options[:version] || "0.0.0"

    # The mark guards the whole insert: a project that already keeps a
    # changelog keeps its own version too — the two are one decision,
    # and a second run must not move the number under a written history.
    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "CHANGELOG.md already exists: the project keeps its own history, skipping."
        )

      {false, igniter} ->
        changelog =
          template("changelog.eex",
            version: version,
            creation_date: Date.utc_today() |> Date.to_iso8601()
          )

        igniter
        |> set_version(version)
        |> Igniter.create_new_file("CHANGELOG.md", changelog)
    end
  end

  defp set_version(igniter, version) do
    Igniter.Project.MixProject.update(igniter, :project, [:version], fn _zipper ->
      # A binary passed as {:code, ...} is parsed as source, so the
      # string literal needs its quotes.
      {:ok, {:code, inspect(version)}}
    end)
  end
end
