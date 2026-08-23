defmodule WorkbenchIgniter.Features.Coveralls do
  @moduledoc """
  ExCoveralls test coverage with the workbench HTML report and `mix cover`.

  Full feature cartridge: manifest, install logic, the `coveralls.json`
  template and the verbatim assets it plants (report template, `mix cover`
  task) live in this directory, and the
  `Mix.Tasks.Workbench.Install.Coveralls` shell in `task.ex` delegates
  here. The `cover.ex.asset`/`formatter.ex.asset` files carry the extra
  suffix so mix doesn't compile them with the package sources.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_assets()

  @example "mix workbench.install.coveralls --exdoc"

  @preferred_envs [
    :cover,
    :coveralls,
    :"coveralls.detail",
    :"coveralls.post",
    :"coveralls.html",
    :"coveralls.cobertura"
  ]

  # The HTML report lands in the standard `cover/` output dir (already in
  # phx.new's stock .gitignore); only the report template is a source file.
  @output_dir "cover"
  @template_path "assets/cover/template"

  @impl true
  def task, do: "workbench.install.coveralls"

  @impl true
  def flag, do: :coveralls

  @impl true
  def argv(opts) do
    ["--interface", opts[:interface]] ++
      flags(opts, [:exdoc]) ++ no_flags(opts, [:html])
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: ["workbench.install.mock"],
      schema: [
        minimum_coverage: :string,
        interface: :string,
        html: :boolean,
        exdoc: :boolean
      ],
      defaults: [
        minimum_coverage: "80",
        interface: "rest",
        html: true,
        exdoc: false
      ]
    }
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    if Igniter.exists?(igniter, "coveralls.json") do
      Igniter.add_notice(
        igniter,
        "coveralls.json already exists: coveralls is already installed, skipping."
      )
    else
      install(igniter, igniter.args.options)
    end
  end

  defp install(igniter, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)

    igniter
    |> Igniter.Project.Deps.add_dep({:excoveralls, "~> 0.18", only: :test}, on_exists: :skip)
    |> configure_mix_project()
    |> create_coveralls_json(app_name, opts)
    |> plant_report_template()
    |> plant_cover_task(opts)
  end

  # --- mix.exs ----------------------------------------------------------------

  defp configure_mix_project(igniter) do
    igniter
    # Coverage configuration
    |> Igniter.Project.MixProject.update(:project, [:test_coverage], fn
      nil -> {:ok, {:code, "[tool: ExCoveralls]"}}
      zipper -> {:ok, zipper}
    end)
    |> add_preferred_envs()
  end

  defp add_preferred_envs(igniter) do
    Enum.reduce(@preferred_envs, igniter, fn env, igniter ->
      Igniter.Project.MixProject.update(igniter, :cli, [:preferred_envs, env], fn
        nil -> {:ok, {:code, ":test"}}
        zipper -> {:ok, zipper}
      end)
    end)
  end

  # --- coveralls.json ---------------------------------------------------------

  defp create_coveralls_json(igniter, app_name, opts) do
    content =
      template("coveralls_json.eex",
        app_name: to_string(app_name),
        output_dir: @output_dir,
        template_path: @template_path,
        minimum_coverage: opts[:minimum_coverage],
        rest: opts[:interface] == "rest",
        html: opts[:html]
      )

    Igniter.create_new_file(igniter, "coveralls.json", content, on_exists: :overwrite)
  end

  # --- Custom excoveralls HTML template ---------------------------------------

  @report_template_files ~w(coverage.html.eex _script.html.eex _style.html.eex)

  defp plant_report_template(igniter) do
    Enum.reduce(@report_template_files, igniter, fn file, igniter ->
      Igniter.create_new_file(
        igniter,
        "#{@template_path}/#{file}",
        asset("template/#{file}"),
        on_exists: :overwrite
      )
    end)
  end

  # --- mix cover task (ExDoc integration) -------------------------------------

  defp plant_cover_task(igniter, opts) do
    if opts[:exdoc] do
      igniter
      # The cover task unit tests use the Mock library.
      |> Igniter.compose_task("workbench.install.mock", [])
      |> Igniter.create_new_file(
        "lib/mix/tasks/cover.ex",
        asset("cover.ex"),
        on_exists: :skip
      )
      |> Igniter.create_new_file(
        "lib/mix/tasks/cover/formatter.ex",
        asset("formatter.ex"),
        on_exists: :skip
      )
      |> Igniter.create_new_file(
        "test/mix/tasks/cover_test.exs",
        asset("cover_test.exs"),
        on_exists: :skip
      )
      |> WorkbenchIgniter.gitignore_entry(
        "Generated testing & coverage reports (mix cover).",
        "/COVERAGE.md\n/TESTING.md"
      )
    else
      igniter
    end
  end
end
