defmodule WorkbenchIgniter.Features.Exdoc do
  @moduledoc """
  ExDoc's site for the project, with per-feature extra pages (the test
  suite report, the database diagram). `mix docs` writes it to `doc/`,
  and the console serves it off the workspace (console/PLAN.md): the
  project carries no route, no controller and no environment for it.

  Full feature cartridge: manifest, install logic, EEx templates and the
  text assets it plants (theme JS, extra pages) live in this directory;
  the `Mix.Tasks.Workbench.Install.Exdoc` shell in `task.ex` delegates
  here. The only asset kept out of the module is the binary logo, planted
  from `priv/features/exdoc/images/` via `plant_binary_asset/3`.
  """
  use WorkbenchIgniter.Feature

  embed_templates()
  embed_assets()

  # Read off the project when not given: the install computes them.
  @impl true
  def detected, do: [:project_name, :repo_url, :module_groups]

  # The presets of the sidebar's module groups; `choices/0` says each.
  @module_groups ~w(layers ash contexts none)

  @example "mix workbench.install.exdoc --project-name \"Lorem Ipsum\" --coverage"

  @impl true
  def task, do: "workbench.install.exdoc"

  @impl true
  def console, do: [doors: [{"docs", {:output, "doc", "index.html"}}]]

  @impl true
  def afterwards,
    do: "./wb.sh mix docs generates the site; --build does it on the insert."

  # The installer's options, one line each: the task's "## Options"
  # section and the help a form shows are rendered from here.
  @impl true
  def option_docs do
    [
      project_name:
        "The name the site is titled with. Default: the `name:` mix.exs already has, or the app's name in words (`lorem_ipsum` is `Lorem Ipsum`).",
      repo_url:
        "The repository, for `source_url` (the links to each function's source) and `authors`. Default: the `source_url:` mix.exs has, or the `origin` remote of the project's own git repository, or a placeholder to replace.",
      homepage_url:
        "The project's website, where the sidebar's logo and name link. Default: none — they open the docs' main page, as ExDoc does.",
      app_logo:
        "Plant a placeholder logo (`guides/images/app-logo.png`) and name it the site's `logo:`, to be replaced by the project's own. Off by default: it is a 1.9 MB image with somebody else's name on it.",
      module_groups:
        "How the sidebar groups the modules, one of #{Enum.map_join(@module_groups, ", ", &"`#{&1}`")}. Default: read off the project — `ash` when it depends on Ash, `layers` otherwise.",
      readme:
        "The project's `README.md` is the site's first page, Overview, and the one it opens on. Off, the site opens on ExDoc's API reference and leaves the README out. On by default.",
      coverage:
        "The coverage report joins the site: the Test Suite Report page `mix cover` writes, and ExCoveralls' HTML copied in beside it.",
      build:
        "Run `mix docs` once the insert is applied, so the site has pages on first boot. Off by default: it needs the dependencies fetched and compiled."
    ]
  end

  # The sidebar's module groups: what a module is, where the project
  # stands. ExDoc's own flat list is `none`.
  @impl true
  def choices do
    [
      module_groups: [
        {"layers",
         "by layer: application, contexts, schemas, live views, controllers, components, web"},
        {"ash", "by role in the Ash DSL: domains, resources, changes, validations, types"},
        {"contexts",
         "one group per context (a directory under lib/<app>/), read when the docs are built"},
        {"none", "ExDoc's own flat, alphabetical list"}
      ]
    ]
  end

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      schema: [
        project_name: :string,
        repo_url: :string,
        homepage_url: :string,
        app_logo: :boolean,
        module_groups: :string,
        readme: :boolean,
        coverage: :boolean,
        build: :boolean
      ],
      defaults: [
        app_logo: false,
        readme: true,
        coverage: false,
        build: false
      ]
    }
  end

  # The mark: the site's config, the one file of the theme every
  # edition planted — under guides/ since v0.2.0, under assets/exdoc/
  # before, where it rode into every release build. A project that
  # carries v0.1.0, controller and all, is exdoc all the same.
  @mark "guides/config/docs_config.js"
  @v0_1_mark "assets/exdoc/config/docs_config.js"
  @logo "guides/images/app-logo.png"
  @changelog "CHANGELOG.md"
  # What `source_url:` says until the project has a repository to name.
  @placeholder_repo "https://github.com/user/repo"

  @impl true
  def installed?(igniter) do
    case file_installed?(igniter, @mark) do
      {true, igniter} -> {true, igniter}
      {false, igniter} -> file_installed?(igniter, @v0_1_mark)
    end
  end

  # What the project carries, read off what the install wrote: the name
  # and source_url of mix.exs, and in its `docs:` block the website the
  # sidebar links, the module groups' preset, the placeholder logo
  # --app-logo names (the file itself lands after the patch set, a
  # binary copied verbatim) and the report page --coverage lists.
  # --build leaves no mark: it runs `mix docs` once.
  @impl true
  def state(igniter) do
    {name, igniter} = mix_project_value(igniter, :name)
    {repo_url, igniter} = mix_project_value(igniter, :source_url)
    {mix_exs, igniter} = file_content(igniter, "mix.exs")

    {%{
       project_name: name,
       repo_url: repo_url,
       homepage_url: homepage_url(mix_exs),
       app_logo: is_binary(mix_exs) and String.contains?(mix_exs, ~s|logo: "#{@logo}"|),
       module_groups: module_groups(mix_exs),
       readme: is_binary(mix_exs) and String.contains?(mix_exs, ~s|{"README.md"|),
       coverage: is_binary(mix_exs) and String.contains?(mix_exs, ~s|{"TESTING.md"|),
       build: nil
     }, igniter}
  end

  defp homepage_url(mix_exs) when is_binary(mix_exs) do
    case Regex.run(~r/homepage_url: "([^"]*)"/, mix_exs) do
      [_, url] -> url
      nil -> nil
    end
  end

  defp homepage_url(_), do: nil

  # Which preset wrote the groups, by the lines only it writes.
  defp module_groups(mix_exs) when is_binary(mix_exs) do
    cond do
      not String.contains?(mix_exs, "defp groups_for_modules") -> "none"
      String.contains?(mix_exs, "exdoc --module-groups ash") -> "ash"
      String.contains?(mix_exs, "exdoc --module-groups contexts") -> "contexts"
      String.contains?(mix_exs, "exdoc --module-groups layers") -> "layers"
      true -> nil
    end
  end

  defp module_groups(_), do: nil

  @doc """
  Whether mix.exs keeps a `docs:` block with `extras:` in `project/0`,
  as this installer writes it — where another cartridge lists a page of
  its own with `list_page/4`.
  """
  def lists_pages?(igniter), do: docs_has?(igniter, [:extras])

  @doc """
  Lists a page of another cartridge in the site: `{page, [title: title]}`
  appended to the `docs:` extras, and `page` to `groups_for_extras` under
  `group` when the block has that group — a `docs:` the project wrote
  itself is not given groups it did not ask for. Appended, never
  rewritten — the pages already listed stay where they are — and once
  only, so a second run changes nothing. Assumes `lists_pages?/1`.
  """
  def list_page(igniter, page, title, group) do
    igniter =
      update_docs(igniter, [:extras], fn zipper ->
        # Real AST, not the `{:code, source}` marker `MixProject.update/4`
        # takes for a whole value: this appends *into* a list.
        Igniter.Code.List.append_new_to_list(
          zipper,
          Sourceror.parse_string!(~s|{"#{page}", [title: "#{title}"]}|),
          names?(page)
        )
      end)

    case docs_has?(igniter, [:groups_for_extras, group]) do
      {true, igniter} ->
        update_docs(igniter, [:groups_for_extras, group], fn zipper ->
          Igniter.Code.List.append_new_to_list(
            zipper,
            Sourceror.parse_string!(~s|"#{page}"|),
            names?(page)
          )
        end)

      {false, igniter} ->
        igniter
    end
  end

  # Already listed is by name: `"CHANGELOG.md"` or `{"CHANGELOG.md", …}`,
  # however it was written — AST equality misses the entry a first run
  # wrote, and a project may list the page bare.
  defp names?(page) do
    fn a, b -> Enum.all?([a, b], &(Sourceror.to_string(&1) =~ ~s|"#{page}"|)) end
  end

  # Read, never created: `MixProject.update/4` builds a missing path.
  defp docs_has?(igniter, path) do
    igniter = Igniter.include_existing_file(igniter, "mix.exs")

    zipper =
      igniter.rewrite
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:quoted)
      |> Sourceror.Zipper.zip()

    found? =
      with {:ok, zipper} <- Igniter.Code.Function.move_to_def(zipper, :project, 0),
           {:ok, _} <- get_path(zipper, [:docs | path]) do
        true
      else
        _ -> false
      end

    {found?, igniter}
  end

  defp get_path(zipper, []), do: {:ok, zipper}

  defp get_path(zipper, [key | rest]) do
    with {:ok, zipper} <- Igniter.Code.Keyword.get_key(zipper, key), do: get_path(zipper, rest)
  end

  defp update_docs(igniter, path, fun) do
    Igniter.Project.MixProject.update(igniter, :project, [:docs | path], fn
      nil -> :error
      zipper -> fun.(zipper)
    end)
  end

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    # Whether the project has Ecto — the database page and diagram — is
    # read off the project, not asked.
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    {name, igniter} = display_name(igniter)
    {repo, igniter} = repo_url(igniter)

    opts =
      igniter.args.options
      |> Keyword.put(:ecto, facts.ecto)
      # The changelog is listed when the project keeps one; the
      # changelog cartridge lists it when it opens one later.
      |> Keyword.put(:changelog, Igniter.exists?(igniter, @changelog))
      # The sidebar follows the line the project is on, unless asked.
      |> Keyword.put_new_lazy(:module_groups, fn ->
        if Igniter.Project.Deps.has_dep?(igniter, :ash), do: "ash", else: "layers"
      end)
      |> Keyword.put_new(:project_name, name)
      # Nothing found and nothing asked: the placeholder, commented out.
      |> Keyword.put(:placeholder_repo, is_nil(repo) and is_nil(igniter.args.options[:repo_url]))
      |> Keyword.put_new(:repo_url, repo || @placeholder_repo)

    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    preset = opts[:module_groups]

    case installed?(igniter) do
      {true, igniter} ->
        Igniter.add_notice(
          igniter,
          "#{@mark} already exists: ExDoc is already installed, skipping."
        )

      {false, igniter} when preset not in @module_groups ->
        Igniter.add_issue(
          igniter,
          "Unknown --module-groups #{inspect(preset)}. " <>
            "One of: #{Enum.join(@module_groups, ", ")}."
        )

      {false, igniter} ->
        igniter
        |> Igniter.Project.Deps.add_dep({:ex_doc, "~> 0.38", only: :dev, runtime: false},
          on_exists: :skip
        )
        |> configure_mix_project(app_module, web_module, opts)
        |> plant_assets(opts)
        |> build_docs(opts)
    end
  end

  # `--build`: generate the site once the patch set is applied, so the
  # docs door has pages the first time it is opened. Queued, never run
  # inline — `mix docs` needs the dependencies fetched and compiled,
  # which only happens after the files land.
  defp build_docs(igniter, opts) do
    if opts[:build], do: Igniter.add_task(igniter, "docs", []), else: igniter
  end

  # --- mix.exs ----------------------------------------------------------------

  defp configure_mix_project(igniter, app_module, web_module, opts) do
    set = fn igniter, key, code ->
      Igniter.Project.MixProject.update(igniter, :project, [key], fn _zipper ->
        {:ok, {:code, code}}
      end)
    end

    igniter
    |> set.(:name, inspect(opts[:project_name]))
    |> set.(:source_url, inspect(opts[:repo_url]))
    |> set.(:docs, docs_source(opts))
    |> add_before_closing_tags(app_module)
    |> add_module_groups(app_module, web_module, opts)
    |> comment_placeholder_repo(opts[:placeholder_repo])
  end

  # A project with no repository to name gets the placeholder commented
  # out: live, every "source" link of the site would open a page that
  # does not exist; commented, ExDoc leaves them out, and the line waits
  # to be filled in. `source_url` sits before `docs:`, so the list stays
  # valid around the comment.
  defp comment_placeholder_repo(igniter, true) do
    Igniter.update_file(igniter, "mix.exs", fn source ->
      Rewrite.Source.update(source, :content, fn content ->
        String.replace(
          content,
          ~s|source_url: "#{@placeholder_repo}",|,
          ~s|# source_url: "#{@placeholder_repo}",|
        )
      end)
    end)
  end

  defp comment_placeholder_repo(igniter, _), do: igniter

  defp docs_source(opts) do
    # The repository's owner, as far as its URL says: none for the
    # placeholder, whose owner is nobody.
    owner =
      unless opts[:placeholder_repo],
        do: opts[:repo_url] |> String.trim_trailing("/") |> String.split("/") |> Enum.at(-2)

    assets =
      join(
        [
          ~s|"guides/config" => "/"|,
          only(opts[:coverage], ~s|"cover" => "/"|),
          ~s|"guides/images" => "/assets"|,
          ~s|"guides/js" => "/assets"|
        ],
        ",\n    "
      )

    extras =
      join(
        [
          only(opts[:readme], ~s|{"README.md", [title: "Overview"]}|),
          only(opts[:changelog], ~s|{"#{@changelog}", [title: "Changelog"]}|),
          only(opts[:ecto], ~s|{"guides/database.md", [title: "Database"]}|),
          only(opts[:coverage], ~s|{"TESTING.md", [title: "Test Suite Report"]}|)
        ],
        ",\n    "
      )

    project =
      join(
        [only(opts[:readme], ~s|"README.md"|), only(opts[:changelog], ~s|"#{@changelog}"|)],
        ",\n      "
      )

    support =
      join(
        [
          only(opts[:coverage], ~s|"TESTING.md"|),
          only(opts[:ecto], ~s|"guides/database.md"|)
        ],
        ",\n      "
      )

    groups =
      if opts[:module_groups] != "none", do: "groups_for_modules: groups_for_modules(),"

    # The sidebar's head: where its name and logo link, and the logo.
    sidebar =
      join(
        [
          only(opts[:homepage_url], ~s|homepage_url: "#{opts[:homepage_url]}",|),
          only(opts[:app_logo], ~s|logo: "#{@logo}",|)
        ],
        "\n  "
      )

    """
    [
      source_ref: "main",
      #{owner && ~s|authors: ["#{owner}"],|}
      #{sidebar}
      output: "doc",
      #{only(opts[:readme], ~s|main: "readme",|)}
      assets: %{
        #{assets}
      },
      extras: [
        #{extras}
      ],
      groups_for_extras: [
        Project: [
          #{project}
        ],
        Support: [
          #{support}
        ]
      ],
      #{groups}
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
    """
  end

  defp add_before_closing_tags(igniter, app_module) do
    scripts = ~s|  <script src="./assets/themedImage.js"></script>|
    code = template("before_closing.eex", scripts: scripts)
    mix_project = Module.concat(app_module, MixProject)

    Igniter.Project.Module.find_and_update_module!(igniter, mix_project, fn zipper ->
      {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
    end)
  end

  # The groups are functions of mix.exs, written after the project's own:
  # a preset reads a module's behaviours and directory, which a keyword
  # of literals cannot say, and `contexts` lists lib/<app>/ when the docs
  # are built. `none` writes nothing and ExDoc lists the modules flat.
  defp add_module_groups(igniter, app_module, web_module, opts) do
    case opts[:module_groups] do
      "none" ->
        igniter

      preset ->
        assigns = [
          mod: inspect(app_module),
          web: inspect(web_module),
          app: Igniter.Project.Application.app_name(igniter)
        ]

        code =
          template("groups_#{preset}.eex", assigns) <>
            "\n\n" <> template("groups_web.eex", assigns)

        Igniter.Project.Module.find_and_update_module!(
          igniter,
          Module.concat(app_module, MixProject),
          fn zipper -> {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)} end
        )
    end
  end

  # --- guides/ ---------------------------------------------------------------

  defp plant_assets(igniter, opts) do
    igniter
    |> plant_asset("js/docs_config.js", @mark)
    |> plant_logo(opts[:app_logo])
    |> plant_asset("js/themedImage.js", "guides/js/themedImage.js")
    |> plant_testing_placeholder(opts)
    |> plant_database_placeholder(opts)
  end

  defp plant_asset(igniter, asset, path) do
    Igniter.create_new_file(igniter, path, asset(asset), on_exists: :overwrite)
  end

  # The logo is a binary asset: copied verbatim after the patch set is
  # applied, never through the rewrite pipeline (which would normalize
  # its trailing bytes). See WorkbenchIgniter.plant_binary_asset/4.
  defp plant_logo(igniter, true), do: plant_binary_asset(igniter, "images/app-logo.png", @logo)
  defp plant_logo(igniter, _), do: igniter

  # TESTING.md is generated (and overwritten) by `mix cover` at the
  # project root; a placeholder keeps `mix docs` from failing on a missing
  # extra file, and an existing report is never clobbered.
  defp plant_testing_placeholder(igniter, opts) do
    if opts[:coverage] do
      Igniter.create_new_file(
        igniter,
        "TESTING.md",
        asset("TESTING.md"),
        on_exists: :skip
      )
    else
      igniter
    end
  end

  # The database.md page is generated by the enhancements feature; until
  # that runs, a placeholder keeps `mix docs` from failing on a missing
  # extra file.
  defp plant_database_placeholder(igniter, opts) do
    if opts[:ecto] and not Igniter.exists?(igniter, "guides/database.md") do
      Igniter.create_new_file(
        igniter,
        "guides/database.md",
        "# Database\n\n> Run `mix db` to generate the database documentation.\n",
        on_exists: :skip
      )
    else
      igniter
    end
  end

  # --- Helpers ----------------------------------------------------------------

  defp only(condition, string), do: if(condition, do: string)

  defp join(items, separator) do
    items
    |> Enum.filter(&is_binary/1)
    |> Enum.join(separator)
  end
end
