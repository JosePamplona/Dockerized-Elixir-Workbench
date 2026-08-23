defmodule Mix.Tasks.Workbench.Install.Coveralls do
  use Igniter.Mix.Task

  @example "mix workbench.install.coveralls --exdoc"
  @shortdoc "Adds ExCoveralls test coverage reports to the project"

  @preferred_envs [
    :cover,
    :coveralls,
    :"coveralls.detail",
    :"coveralls.post",
    :"coveralls.html",
    :"coveralls.cobertura"
  ]

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_coveralls` feature:

  * adds `{:excoveralls, "~> 0.18", only: :test}` to the project deps
  * configures `test_coverage: [tool: ExCoveralls]` and the coveralls
    `preferred_envs` in `mix.exs`
  * creates `coveralls.json`: reports go to the standard `cover/` output
    dir (already gitignored by phx.new), with the custom template, minimum
    coverage and skip list
  * plants the custom excoveralls HTML report template under
    `assets/cover/template/`
  * with `--exdoc`, plants the `mix cover` task (testing & coverage reports
    integrated into ExDoc) along with its ExUnit formatter and unit tests,
    and gitignores the generated `COVERAGE.md` and `TESTING.md` reports

  ## Example

      #{@example}

  ## Options

  * `--minimum-coverage` - Minimum coverage percentage. Default: `80`.
  * `--interface` - `rest` skips `open_api` files in the coverage report.
    Default: `rest`.
  * `--no-html` - The project was created with `--no-html` (skips the
    components folder exclusion).
  * `--exdoc` - The project uses the ExDoc feature: the `mix cover` task
    (which generates `COVERAGE.md` and `TESTING.md` for the docs) is
    installed.
  """

  @impl Igniter.Mix.Task
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

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.exists?(igniter, "coveralls.json") do
      Igniter.add_notice(
        igniter,
        "coveralls.json already exists: coveralls is already installed, skipping."
      )
    else
      install(igniter, igniter.args.options)
    end
  end

  # The HTML report lands in the standard `cover/` output dir (already in
  # phx.new's stock .gitignore); only the report template is a source file.
  @output_dir "cover"
  @template_path "assets/cover/template"

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
      WorkbenchIgniter.template("coveralls/coveralls_json.eex",
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
        WorkbenchIgniter.asset("coveralls/template/#{file}"),
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
        WorkbenchIgniter.asset("coveralls/cover.ex"),
        on_exists: :skip
      )
      |> Igniter.create_new_file(
        "lib/mix/tasks/cover/formatter.ex",
        WorkbenchIgniter.asset("coveralls/formatter.ex"),
        on_exists: :skip
      )
      |> Igniter.create_new_file(
        "test/mix/tasks/cover_test.exs",
        WorkbenchIgniter.asset("coveralls/cover_test.exs"),
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
