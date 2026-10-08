defmodule WorkbenchIgniter.Features.Coverage do
  @moduledoc """
  ExCoveralls test coverage with the workbench HTML report and `mix cover`.

  Full feature cartridge: manifest and install logic live in this
  directory, and the `Mix.Tasks.Workbench.Install.Coverage` shell in
  `task.ex` delegates here. The `coveralls.json` template and the verbatim
  assets it plants (report themes, `mix cover` task) live under
  `priv/features/coverage/`.
  """
  use WorkbenchIgniter.Feature

  alias WorkbenchIgniter.Features.Precommit
  alias WorkbenchIgniter.Features.TestDoubles

  embed_templates()
  embed_assets()

  @example "mix workbench.install.coverage --md-report"

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

  # The line --githook puts in the project's pre-commit hook: the suite
  # with coverage, refused under the minimum coveralls.json carries.
  @check "mix coveralls"

  # The report's templates: dev-tool source, so under test/ — which the
  # release's Dockerfile context leaves out and nothing compiles (only
  # test/support is, and mix test loads *_test.exs) — never under
  # assets/, the release build's input. Until v0.4.0 they were there.
  @template_path "test/coverage/template"

  # Report themes: one directory per theme under the cartridge's
  # `priv/features/coverage/assets/template/`, each holding the three
  # files excoveralls renders. Adding a theme is adding a directory; the
  # option validates against this list. `default` has no directory: it
  # is ExCoveralls' own report, so nothing is planted and coveralls.json
  # carries no `template_path`.
  @themes_dir WorkbenchIgniter.Feature.priv_dir(__ENV__.file, "assets/template")
  @default_theme "default"
  @themes [@default_theme | @themes_dir |> File.ls!() |> Enum.sort()]
  @report_template_files ~w(coverage.html.eex _script.html.eex _style.html.eex)

  # The groups `--ignore-files` takes, each a set of paths the report
  # is better without, and what each one is made of. A path is a regex
  # excoveralls matches against the file's own, so a group whose files
  # the project does not have costs nothing — but only the ones that
  # are there are written, so the file reads as the project it is.
  #
  # The choice of groups is the reading of what projects skip (DESIGN):
  # the wiring phx.new writes and no test asserts, the generated
  # components, the developer's own Mix tasks and an API spec's modules
  # — and first the two no project wants counted, the dependencies and
  # the tests themselves, which are not the code under test.
  @groups [
    deps: [{"deps", nil}],
    test: [{"test", nil}],
    boilerplate: [
      "lib/{app}/application.ex",
      "lib/{app}/release.ex",
      "lib/{app}/repo.ex",
      "lib/{app}/mailer.ex",
      "lib/{app}_web.ex",
      "lib/{app}_web/endpoint.ex",
      "lib/{app}_web/telemetry.ex",
      "lib/{app}_web/gettext.ex",
      "lib/{app}_web/router.ex",
      "lib/{app}_web/channels/user_socket.ex"
    ],
    # A directory is written as one line, so it needs a file of its own
    # to say whether the project has it: layouts.ex is what `phx.new`
    # writes with html. The two below have no witness to read — an API
    # spec's modules and the project's Mix tasks are named by whoever
    # wrote them — so they are written as asked, like `deps` and `test`.
    components: [{"lib/{app}_web/components", "lib/{app}_web/components/layouts.ex"}],
    mix_tasks: [{"lib/mix/tasks", nil}],
    open_api: [{"lib/{app}_web/open_api", nil}]
  ]
  @group_names Enum.map(@groups, fn {name, _} -> to_string(name) end)
  @default_groups ~w(deps test boilerplate components)

  @doc "The line `--githook` puts in the pre-commit hook."
  @spec check_command() :: String.t()
  def check_command, do: @check

  @doc "Available HTML report themes (`priv/features/coverage/assets/template/<theme>/`)."
  @spec themes() :: [String.t()]
  def themes, do: @themes

  # The report tool. The doubles the `mix cover` task's tests use are
  # test_doubles' box, which `--md-report` builds on.
  @impl true
  def deps(_state), do: [{:excoveralls, "~> 0.18", only: :test}]

  @impl true
  def task, do: "workbench.install.coverage"

  @impl true
  # `mix cover` is the project's command where this box was inserted
  # with `--md-report`, which is what plants that task — never off
  # whether the exdoc cartridge is in, which says nothing about it.
  # Without it, ExCoveralls' own task writes the same page and nothing
  # else. Both run in the test env: `cli/0` says so (`@preferred_envs`).
  def console,
    do: [
      doors: [
        # The door follows the report: `{output_dir}` is what `state/1`
        # reads off coveralls.json, so a moved report is still found.
        {
          "coverage",
          {:output, "{output_dir}", "excoveralls.html"},
          # The report is of the tests run over the code: either moves it.
          build: [{"cover", when: {:option, :md_report}}, "coveralls.html"], from: ~w(lib test)
        }
      ]
    ]

  # The minimum goes into coveralls.json as a bare number: anything
  # else leaves a file excoveralls cannot read.
  @impl true
  def formats,
    do: [
      minimum_coverage: {:integer, 0..100},
      file_column_width: {:integer, 40..999},
      output_dir: :dir
    ]

  # The themes are the directories under assets/template — the same
  # list the installer checks --html-theme against.
  @impl true
  def choices do
    [
      # The default first, as every list of values here reads.
      html_theme: [
        {"default", "ExCoveralls' own report, as the tool writes it: nothing is planted"},
        {"custom", "the workbench's own report, which reads on its own wherever it is opened"},
        {"exdoc-ish",
         "mimics the ExDoc pages (sidebar, light/dark theme, fonts), so the report blends into a documentation site"}
      ],
      # The task's own tests stand on a double of `File`, which is
      # Mimic's side of test_doubles: the option builds on that box
      # instead of inserting it, so whoever owns the doubles is the box
      # that does, and one insert stays one cartridge.
      md_report: [
        {true, "the mix cover task, and the Markdown report it writes",
         [{"test_doubles", double: "mimic"}]}
      ],
      # A closed list: what the box knows how to leave out, and nothing
      # else. A project that wants another path out of the report edits
      # its own `coveralls.json`, which is a file it owns — the box
      # would only be writing what it cannot read back as a decision.
      ignore_files: [
        {"deps", "the dependencies, `deps/`"},
        {"test", "the tests themselves and their support modules, `test/`"},
        {"boilerplate",
         "the wiring `phx.new` writes and no test asserts: the application, the endpoint, the router, telemetry, gettext, the repo, the mailer, the release and the socket"},
        {"components", "the generated components and layouts of `lib/<app>_web/components/`"},
        {"mix_tasks",
         "the project's own Mix tasks, `lib/mix/tasks/` — a developer's commands, not the app"},
        {"open_api", "an API specification's modules, `lib/<app>_web/open_api/`"}
      ],
      # The hook is precommit's: its block goes in a file that box owns.
      githook: [{true, "the suite before the commit", ["precommit"]}]
    ]
  end

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      minimum_coverage:
        "Minimum coverage percentage, a whole number from 0 to 100. Default: `80`.",
      output_dir:
        "Where the HTML report is written — ExCoveralls' `output_dir`, a directory inside the project. Default: `cover`, which phx.new gitignores.",
      file_column_width:
        "How wide the file column of the terminal table is, in characters — ExCoveralls' `file_column_width`. A path longer than the column is cut, and `mix cover` reads that table to build the report's own, so a cut path is a file the report loses. Default: `80`; ExCoveralls' own is 40, and a project with deep module paths wants more.",
      ignore_files:
        "What the report leaves out, comma-separated: the groups above, and no other value. Default: `#{Enum.join(@default_groups, ",")}`. A path of the project's own goes in its `coveralls.json`, which is the project's file to edit.",
      html_theme:
        "The HTML report's theme, one of #{Enum.map_join(themes(), ", ", &"`#{&1}`")}: `default` is ExCoveralls' own report and plants nothing, `custom` is the workbench's own report, `exdoc-ish` mimics the ExDoc pages (sidebar, light/dark theme, fonts) so the report blends into a documentation site. Default: `default`.",
      md_report:
        "Plants `mix cover`, the task that runs the suite and writes the report as Markdown — `TESTING.md` at the project's root, a page any reader of the repository opens, and the one a documentation site lists (exdoc's `--coverage`). Its own tests stand on a double of `File`, so it builds on the test_doubles cartridge with Mimic among its doubles: insert it first (`./wb.sh add test_doubles`).",
      githook:
        "Run `#{@check}` before every commit, in this cartridge's own block of `#{Precommit.hook()}`. Builds on the precommit cartridge, which owns the hook: insert it first. Off by default: it is the suite plus its instrumentation, the slowest check a commit can wait for, and coverage's natural home is CI."
    ]
  end

  # What an option says that none of its values can, under them in a form.
  @impl true
  def option_notes do
    [
      ignore_files:
        "A path of the project's own goes in its `coveralls.json`, which is the project's file to edit."
    ]
  end

  @impl true
  def afterwards,
    do:
      "./wb.sh mix cover runs the suite and writes the report — or the coverage door's build, in the console."

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        minimum_coverage: :string,
        file_column_width: :string,
        output_dir: :string,
        ignore_files: :csv,
        html_theme: :string,
        md_report: :boolean,
        githook: :boolean
      ],
      defaults: [
        output_dir: @output_dir,
        minimum_coverage: "80",
        file_column_width: "80",
        ignore_files: @default_groups,
        html_theme: @default_theme,
        md_report: false,
        githook: false
      ]
    }
  end

  # The json, the theme and the report's shape were fixed at the
  # insert; the mix cover task and the hook block are pieces a second
  # run puts in when they are missing.
  @impl true
  def adds, do: [:md_report, :githook]

  # The mark: the coveralls.json the installer writes.
  @impl true
  def installed?(igniter), do: file_installed?(igniter, "coveralls.json")

  # What the project carries, read off what the install wrote: the
  # minimum and what the report leaves out off coveralls.json, the
  # `mix cover` task --md-report plants, and the theme by matching the
  # planted report template against the cartridge's own — `default`
  # where coveralls.json points at no template, `nil` once the project
  # has edited it.
  @impl true
  def state(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    {json, igniter} = file_content(igniter, "coveralls.json")
    # Where the project's coveralls.json says the templates are: this
    # edition's test/, an older one's assets/, or wherever it moved them.
    {report, igniter} = file_content(igniter, "#{template_path(json)}/coverage.html.eex")
    {cover_task?, igniter} = file_installed?(igniter, "lib/mix/tasks/cover.ex")
    {checks, igniter} = Precommit.checks_of(igniter, name())

    minimum = number(json, "minimum_coverage")

    theme =
      cond do
        is_binary(json) and not (json =~ ~r/"template_path"/) ->
          @default_theme

        report ->
          Enum.find(
            @themes -- [@default_theme],
            &(asset("template/#{&1}/coverage.html.eex") == report)
          )

        true ->
          nil
      end

    {%{
       minimum_coverage: minimum,
       file_column_width: number(json, "file_column_width"),
       output_dir: string(json, "output_dir") || @output_dir,
       ignore_files: ignored(json, app_name),
       md_report: cover_task?,
       html_theme: theme,
       githook: @check in checks
     }, igniter}
  end

  # A number the json carries, as it is written there.
  # A string the json carries under `key`, or nil.
  defp string(json, key) do
    case json && Regex.run(~r/"#{key}":\s*"([^"]*)"/, json) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp number(json, key) do
    case json && Regex.run(~r/"#{key}":\s*([\d.]+)/, json) do
      [_, value] -> value
      _ -> nil
    end
  end

  # What the report leaves out, as it was asked for: a group whose
  # paths are all there is that group's name, and what is left over is
  # itself — a path the project added by hand reads back as the path it
  # is. `nil` with no file to read.
  defp ignored(nil, _app_name), do: nil

  defp ignored(json, app_name) do
    skipped =
      case Regex.run(~r/"skip_files":\s*\[(.*?)\]/s, json) do
        [_, list] -> Regex.scan(~r/"([^"]*)"/, list) |> Enum.map(&List.last/1)
        nil -> []
      end

    {names, rest} =
      Enum.reduce(@groups, {[], skipped}, fn {name, paths}, {names, rest} ->
        paths =
          for path <- paths,
              {written, _witness} = written_and_witness(path, app_name),
              written in rest,
              do: written

        if paths == [],
          do: {names, rest},
          else: {names ++ [to_string(name)], rest -- paths}
      end)

    names ++ rest
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    # The report's directory as ExCoveralls takes it: no trailing slash.
    opts =
      Keyword.update(
        igniter.args.options,
        :output_dir,
        @output_dir,
        &String.trim_trailing(String.trim(&1), "/")
      )

    {installed?, igniter} = installed?(igniter)

    {missing, igniter} =
      WorkbenchIgniter.Feature.missing_option_requirements(igniter, __MODULE__,
        md_report: opts[:md_report],
        githook: opts[:githook]
      )

    cond do
      # Refused before anything is written, a second run included:
      # the block goes in precommit's hook, which has to be there.
      missing != [] ->
        WorkbenchIgniter.Feature.refuse_values(igniter, missing)

      # Already inserted: the json, the theme and the report are fixed at
      # the insert, but the hook block is a piece the installer adds when
      # it is missing, so `--githook` on a project that took coverage
      # without it is honoured instead of being silently skipped.
      installed? ->
        igniter
        |> Igniter.add_notice(
          "coveralls.json already exists: coverage is already installed, skipping" <>
            pieces_said(opts) <> "."
        )
        |> plant_cover_task(opts)
        |> githook(opts[:githook])

      # `[]` is truthy: the clause is the comparison, not the binding.
      (unknown = Enum.reject(asked(opts[:ignore_files]), &(&1 in @group_names))) != [] ->
        Igniter.add_issue(
          igniter,
          "--ignore-files takes the groups this box knows, and #{Enum.map_join(unknown, ", ", &inspect/1)} " <>
            "is not one of them: #{Enum.join(@group_names, ", ")}. " <>
            "A path of your own goes in the project's coveralls.json."
        )

      opts[:html_theme] not in @themes ->
        Igniter.add_issue(
          igniter,
          "Unknown coverage report theme #{inspect(opts[:html_theme])}. " <>
            "Available themes: #{Enum.join(@themes, ", ")}."
        )

      true ->
        install(igniter, opts)
    end
  end

  defp install(igniter, opts) do
    app_name = Igniter.Project.Application.app_name(igniter)
    {skip, igniter} = skip_files(igniter, app_name, asked(opts[:ignore_files]))
    opts = Keyword.put(opts, :skip_files, skip)

    igniter
    |> Igniter.Project.Deps.add_dep({:excoveralls, "~> 0.18", only: :test}, on_exists: :skip)
    |> configure_mix_project()
    |> create_coveralls_json(app_name, opts)
    |> plant_report_template(opts[:html_theme])
    |> plant_cover_task(opts)
    |> githook(opts[:githook])
  end

  # `--githook`: the suite with coverage before every commit. The hook,
  # the way it reaches mix inside the container and the checks that come
  # with Elixir are the precommit cartridge's; this is a block of that
  # file belonging to this cartridge alone, so ejecting either box
  # leaves the other's checks standing.
  # The default stage, `:slow`, said out loud: `mix coveralls` compiles
  # the project and runs the whole suite instrumented, so its block
  # belongs below the hook's divider, after every check that can refuse
  # the commit in a second.
  # What a second run still puts in, said in the notice so the skipping
  # is never read as "nothing happened".
  defp pieces_said(opts) do
    case Enum.filter([{:md_report, "the mix cover task"}, {:githook, "the pre-commit hook"}], fn
           {key, _} -> opts[key]
         end) do
      [] -> ""
      pieces -> " everything but " <> Enum.map_join(pieces, " and ", &elem(&1, 1))
    end
  end

  defp githook(igniter, true) do
    igniter
    |> Precommit.check(name(), [@check],
      note: "the suite, and what it did not reach",
      stage: :slow
    )
  end

  defp githook(igniter, _off), do: igniter

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

  # What the report leaves out, in the order it is written: each
  # asked-for group — only the paths the project actually has, so the
  # file reads as the project it is. A group the project has no file for
  # writes nothing.
  # What was asked for: Igniter hands a `:csv` nobody answered as `[]`,
  # which is also what an empty answer is, so both are the default set.
  defp asked(values) do
    case (values || []) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq() do
      [] -> @default_groups
      values -> values
    end
  end

  defp skip_files(igniter, app_name, asked) do
    Enum.reduce(asked, {[], igniter}, &asked_for(&1, &2, app_name))
  end

  # One value of the option: a group, whose paths are read one by one,
  # or a path of the reader's own, which goes in as it is.
  defp asked_for(value, {skip, igniter}, app_name) do
    case Keyword.get(@groups, safe_group(value)) do
      nil -> {skip ++ [value], igniter}
      paths -> Enum.reduce(paths, {skip, igniter}, &path_of(&1, &2, app_name))
    end
  end

  # A path of a group: written when the project has the file that
  # witnesses it, and always when there is none to read.
  defp path_of(path, {skip, igniter}, app_name) do
    case written_and_witness(path, app_name) do
      {path, nil} -> {skip ++ [path], igniter}
      {path, witness} -> keep(igniter, skip, path, witness)
    end
  end

  defp keep(igniter, skip, path, witness) do
    case file_installed?(igniter, witness) do
      {true, igniter} -> {skip ++ [path], igniter}
      {false, igniter} -> {skip, igniter}
    end
  end

  # A group by name, and nothing else: a path of the reader's own is
  # never an atom this did not already have.
  defp safe_group(value) when value in @group_names, do: String.to_existing_atom(value)
  defp safe_group(_value), do: nil

  # What is written, and the file whose presence says the project has
  # it: a path of its own for a file, the one named beside it for a
  # directory, none for a directory nobody can witness.
  defp written_and_witness({path, witness}, app_name),
    do: {fill(path, app_name), witness && fill(witness, app_name)}

  defp written_and_witness(path, app_name), do: {fill(path, app_name), fill(path, app_name)}

  defp fill(path, app_name), do: String.replace(path, "{app}", to_string(app_name))

  defp create_coveralls_json(igniter, app_name, opts) do
    content =
      template("coveralls_json.eex",
        app_name: to_string(app_name),
        output_dir: opts[:output_dir],
        # ExCoveralls' own report is the one it finds with no path.
        template_path: opts[:html_theme] != @default_theme && @template_path,
        # Written as parsed, so `080` lands as JSON's `80`.
        minimum_coverage: whole(opts[:minimum_coverage]),
        file_column_width: whole(opts[:file_column_width]),
        skip_files: opts[:skip_files]
      )

    Igniter.create_new_file(igniter, "coveralls.json", content, on_exists: :overwrite)
  end

  # The value the shape already holds (`formats/0`), as a number: `080`
  # is JSON's `80`.
  defp whole(value) do
    {number, ""} = Integer.parse(to_string(value))
    number
  end

  defp template_path(json) when is_binary(json) do
    case Regex.run(~r/"template_path":\s*"([^"]+)"/, json) do
      [_, path] -> path |> String.trim_leading("./") |> String.trim_trailing("/")
      nil -> @template_path
    end
  end

  defp template_path(_), do: @template_path

  # --- excoveralls HTML report theme -----------------------------------------

  # The chosen theme's files land flat under `test/coverage/template/`,
  # the `template_path` coveralls.json points excoveralls at. The
  # default theme is the tool's own, and plants nothing.
  defp plant_report_template(igniter, @default_theme), do: igniter

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

  # --- mix cover: the Markdown report -----------------------------------------

  defp plant_cover_task(igniter, opts) do
    if opts[:md_report] do
      igniter
      # The cover task's unit tests stand on a double of `File`: the
      # report is written with `File.write!/2`, and the tests read what
      # it would have written instead of writing it. That is Mimic's
      # side of test_doubles — `File` is nobody's module to declare a
      # behaviour for — which the option builds on, and the copy is
      # registered in this cartridge's own block of the test helper.
      |> TestDoubles.copy(name(), ["File"],
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
      # The report is the task's to write, and this is the page until it
      # runs: a reader who opens it is told which command fills it, and
      # a documentation site that lists it (exdoc's `--coverage`) has a
      # file to list. `mix cover` overwrites it, and an existing report
      # is never clobbered.
      |> Igniter.create_new_file("TESTING.md", asset("TESTING.md"), on_exists: :skip)
    else
      igniter
    end
  end
end
