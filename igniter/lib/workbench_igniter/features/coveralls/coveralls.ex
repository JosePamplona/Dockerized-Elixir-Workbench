defmodule WorkbenchIgniter.Features.Coveralls do
  @moduledoc """
  ExCoveralls test coverage with the workbench HTML report and `mix cover`.

  Full feature cartridge: manifest and install logic live in this
  directory, and the `Mix.Tasks.Workbench.Install.Coveralls` shell in
  `task.ex` delegates here. The `coveralls.json` template and the verbatim
  assets it plants (report themes, `mix cover` task) live under
  `priv/features/coveralls/`.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.Features.TestDoubles

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

  # Report themes: one directory per theme under the cartridge's
  # `priv/features/coveralls/assets/template/`, each holding the three
  # files excoveralls renders. Adding a theme is adding a directory; the
  # option validates against this list.
  @themes_dir WorkbenchIgniter.Feature.priv_dir(__ENV__.file, "assets/template")
  @themes @themes_dir |> File.ls!() |> Enum.sort()
  @default_theme "exdoc-ish"
  @report_template_files ~w(coverage.html.eex _script.html.eex _style.html.eex)

  @doc "Available HTML report themes (`priv/features/coveralls/assets/template/<theme>/`)."
  @spec themes() :: [String.t()]
  def themes, do: @themes

  @impl true
  def task, do: "workbench.install.coveralls"

  @impl true
  def console, do: [doors: [{"coverage", "/dev/docs/cover", when: {:cartridge, "exdoc"}}]]

  # The themes are the directories under assets/template — the same
  # list the installer checks --theme against.
  @impl true
  def choices do
    [
      theme: [
        {"exdoc-ish",
         "mimics the ExDoc pages (sidebar, light/dark theme, fonts), so the report blends into the docs"},
        {"custom", "the original workbench report"}
      ],
      interface: [
        {"rest", "skips the open_api files in the report"},
        {"graphql", "the GraphQL project: nothing skipped"}
      ]
    ]
  end

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      minimum_coverage: "Minimum coverage percentage. Default: `80`.",
      interface: "`rest` skips `open_api` files in the coverage report. Default: `rest`.",
      exdoc:
        "The project uses the ExDoc feature: the `mix cover` task (which generates the `TESTING.md` report for the docs) is installed.",
      theme:
        "HTML report theme, one of #{Enum.map_join(themes(), ", ", &"`#{&1}`")}: `exdoc-ish` mimics the ExDoc pages (sidebar, light/dark theme, fonts) so the report blends into the documentation site, `custom` is the original workbench report. Default: `exdoc-ish`.",
      build:
        "Run the suite once the insert is applied, so the report has numbers. Off by default: it needs the dependencies compiled and, with Ecto, a test database — which means the compose has one (`./wb.sh bake`)."
    ]
  end

  @impl true
  def afterwards,
    do: "./wb.sh mix cover runs the suite and writes the report; --build does it on the insert."

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: ["workbench.install.test_doubles"],
      schema: [
        minimum_coverage: :string,
        interface: :string,
        exdoc: :boolean,
        theme: :string,
        build: :boolean
      ],
      defaults: [
        minimum_coverage: "80",
        interface: "rest",
        exdoc: false,
        theme: @default_theme,
        build: false
      ]
    }
  end

  # The mark: the coveralls.json the installer writes.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, "coveralls.json")

  # What the project carries, read off what the install wrote: the
  # minimum and the skipped open_api folder off coveralls.json, the
  # `mix cover` task --exdoc plants, and the theme by matching the
  # planted report template against the cartridge's own — `nil` once
  # the project has edited it. --build leaves no mark: it runs the
  # suite once, and `cover/` is gitignored.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    {json, igniter} = file_content(igniter, "coveralls.json")
    {report, igniter} = file_content(igniter, "#{@template_path}/coverage.html.eex")
    {cover_task?, igniter} = file_installed?(igniter, "lib/mix/tasks/cover.ex")

    minimum =
      case json && Regex.run(~r/"minimum_coverage":\s*([\d.]+)/, json) do
        [_, minimum] -> minimum
        _ -> nil
      end

    interface =
      cond do
        is_nil(json) -> nil
        String.contains?(json, "#{app_name}_web/open_api") -> "rest"
        true -> "graphql"
      end

    theme = report && Enum.find(@themes, &(asset("template/#{&1}/coverage.html.eex") == report))

    {%{
       minimum_coverage: minimum,
       interface: interface,
       exdoc: cover_task?,
       theme: theme,
       build: nil
     }, igniter}
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    # Whether the project has html — the components folder to leave out
    # of the report — is read off the project, not asked.
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)

    opts =
      igniter.args.options
      |> Keyword.put(:html, facts.html)
      # --build's suite needs a test database when the project has one.
      |> Keyword.put(:ecto, facts.ecto)

    {installed?, igniter} = installed?(igniter)

    cond do
      installed? ->
        Igniter.add_notice(
          igniter,
          "coveralls.json already exists: coveralls is already installed, skipping."
        )

      opts[:theme] not in @themes ->
        Igniter.add_issue(
          igniter,
          "Unknown coverage report theme #{inspect(opts[:theme])}. " <>
            "Available themes: #{Enum.join(@themes, ", ")}."
        )

      true ->
        install(igniter, opts)
    end
  end

  defp install(igniter, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)

    igniter
    |> Igniter.Project.Deps.add_dep({:excoveralls, "~> 0.18", only: :test}, on_exists: :skip)
    |> configure_mix_project()
    |> create_coveralls_json(app_name, opts)
    |> plant_report_template(opts[:theme])
    |> plant_cover_task(opts)
    |> build_report(opts)
  end

  # `--build`: run the suite once the patch set is applied, so the
  # report has numbers before anyone opens it. Queued, never inline:
  # `mix cover` needs the dependencies compiled, and — on a project with
  # Ecto — a test database, which the tasks below create. It is off by
  # default because that database has to exist first: on a project born
  # without Ecto, `./wb.sh bake` puts the service in the compose.
  defp build_report(igniter, opts) do
    cond do
      !opts[:build] ->
        igniter

      opts[:ecto] ->
        igniter
        |> Igniter.add_task("ecto.create", ["--quiet"])
        |> Igniter.add_task("ecto.migrate", ["--quiet"])
        |> Igniter.add_task("cover", [])

      true ->
        Igniter.add_task(igniter, "cover", [])
    end
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

  # --- excoveralls HTML report theme -----------------------------------------

  # The chosen theme's files land flat under `assets/cover/template/`, the
  # `template_path` coveralls.json points excoveralls at.
  defp plant_report_template(igniter, theme) do
    Enum.reduce(@report_template_files, igniter, fn file, igniter ->
      Igniter.create_new_file(
        igniter,
        "#{@template_path}/#{file}",
        asset("template/#{theme}/#{file}"),
        on_exists: :overwrite
      )
    end)
  end

  # --- mix cover task (ExDoc integration) -------------------------------------

  defp plant_cover_task(igniter, opts) do
    if opts[:exdoc] do
      igniter
      # The cover task's unit tests stand on a double of `File`: the
      # report is written with `File.write!/2`, and the tests read what
      # it would have written instead of writing it. That is Mimic's
      # side of test_doubles — `File` is nobody's module to declare a
      # behaviour for — and the copy is registered in this cartridge's
      # own block of the test helper.
      |> Igniter.compose_task("workbench.install.test_doubles", ["--double", "mimic"])
      |> TestDoubles.copy("coveralls", ["File"],
        note: "the report's writer, which its task tests read instead of writing"
      )
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
      |> WorkbenchIgniter.IgnoreFile.entry(
        "Generated test suite report (mix cover).",
        "/TESTING.md"
      )
    else
      igniter
    end
  end
end
