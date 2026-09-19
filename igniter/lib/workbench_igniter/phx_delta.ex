defmodule WorkbenchIgniter.PhxDelta do
  @moduledoc """
  A Phoenix capability added after the fact, as `phx.new` would have
  generated it — without the cartridge knowing how.

  `phx.new` decides its capabilities at generation time (`--no-mailer`,
  `--no-ecto`, `--no-html`…) and has no way to add one later. But it
  can be asked what one *is*: the difference between generating the
  project with the capability and without it, with the same installer.
  That difference is exact and never stale — it comes from the
  installer's own templates, at the version in use.

  So, to add a capability:

  1. `facts/1` reads the project's shape off the project itself — which
     capabilities it has, its database driver, its HTTP adapter — as
     the `phx.new` flags that would generate it today.
  2. Two projects are generated with phx.new's own generator: **base**,
     with those flags, and **theirs**, with the capability's flag turned
     on. Each is then given what `phx.gen.release --docker` writes at
     birth (`scripts/entrypoint.sh`), from Phoenix's own templates:
     that generator decides once, off what is there — `release.ex` and
     `bin/migrate` when Ecto is in, the assets steps of the `Dockerfile`
     when `assets/` exists — and a capability that brings one of those
     brings its share of them too (`release/3`).
  3. Files theirs has and base lacks are created. A file that differs
     between the two and that the project has not moved from base —
     judged by content, its secrets aside — becomes theirs, as phx.new
     writes it: a project grown untouched is the project born with the
     capability, byte for byte. That is the guarantee; what follows is
     for a file the project has moved. Such files are merged three
     ways onto the project's own —
     `git merge-file` with base, ours, theirs — so the project's edits
     survive and only the capability's lines come in. A conflict is
     reported as an issue and the file left alone, with phx.new's
     version of it beside it (`<path>.phx-new`) to merge by hand —
     never resolved silently. Two files are not merged as text:
     `.gitignore`, a set of patterns whose order means nothing, is
     merged as a set (`WorkbenchIgniter.IgnoreFile.merge/3`), the capability's lines appended
     once; `mix.exs` is applied as operations on its keywords,
     dependencies and aliases (`WorkbenchIgniter.MixFile`); and the
     router as operations on its pipelines, scopes and routes
     (`WorkbenchIgniter.RouterFile`), falling back to the text merge
     when those cannot say the change.

  Nothing about Swoosh, Ecto or LiveView is written here or in the
  cartridges that use this: each one names its flag and its mark.
  """

  @capabilities ~w(ecto mailer gettext esbuild tailwind html live dashboard)a

  @doc "The capabilities `phx.new` decides, each the name of a flag (`--no-<name>`)."
  def capabilities, do: @capabilities

  @doc """
  The project's shape, read off the project: `app`, `module`, each
  capability as a boolean, `database` and `adapter` as `phx.new` names
  them, `binary_id`. The returned igniter has the files it read.
  """
  def facts(igniter) do
    dep = &Igniter.Project.Deps.has_dep?(igniter, &1)
    app = Igniter.Project.Application.app_name(igniter)
    {config, igniter} = read(igniter, "config/config.exs")
    {dockerfile, igniter} = read(igniter, "Dockerfile")

    facts =
      shape(
        app,
        Igniter.Project.Module.module_name_prefix(igniter),
        dep,
        config || "",
        Igniter.exists?(igniter, "AGENTS.md")
      )

    {Map.put(facts, :docker, WorkbenchIgniter.Dockerfile.stack(dockerfile)), igniter}
  end

  @doc """
  The same shape, read off the files as text — `mix.exs`,
  `config/config.exs` and whether `AGENTS.md` exists — for a project
  that is not on disk as it stands: the first commit, as `git show`
  hands it over (`WorkbenchIgniter.Birth`). The marks are the ones
  `facts/1` reads; only the reader differs (a dependency here is the
  `{:name` that opens its tuple in `deps/0`).
  """
  @spec facts_of(String.t(), String.t() | nil, boolean()) :: map()
  def facts_of(mix, config, agents_md?) do
    deps = ~r/\{:([a-z0-9_]+)\b/ |> Regex.scan(mix) |> MapSet.new(&Enum.at(&1, 1))
    dep = &MapSet.member?(deps, Atom.to_string(&1))

    app =
      case Regex.run(~r/\bapp:\s*:([a-z0-9_]+)/, mix) do
        [_, name] -> String.to_atom(name)
        _ -> nil
      end

    module =
      case Regex.run(~r/defmodule\s+([A-Z][\w.]*)\.MixProject\b/, mix) do
        [_, name] -> Module.concat([name])
        _ -> nil
      end

    shape(app, module, dep, config || "", agents_md?) |> Map.put(:docker, nil)
  end

  # The marks themselves, given a way to ask for a dependency.
  defp shape(app, module, dep, config, agents_md?) do
    %{
      app: app,
      module: module,
      ecto: dep.(:ecto_sql),
      database:
        cond do
          dep.(:myxql) -> "mysql"
          dep.(:tds) -> "mssql"
          dep.(:ecto_sqlite3) -> "sqlite3"
          true -> "postgres"
        end,
      adapter: if(dep.(:plug_cowboy), do: "cowboy", else: "bandit"),
      mailer: dep.(:swoosh),
      gettext: dep.(:gettext),
      esbuild: dep.(:esbuild),
      tailwind: dep.(:tailwind),
      html: dep.(:phoenix_html),
      # --no-live keeps the phoenix_live_view dependency, and the
      # endpoint's /live socket is on with the dashboard too; what only
      # live brings is its own configuration.
      live: dep.(:phoenix_live_view) and Regex.match?(~r/^config :phoenix_live_view\b/m, config),
      dashboard: dep.(:phoenix_live_dashboard),
      binary_id: Regex.match?(~r/binary_id:\s*true/, config),
      # --no-agents-md leaves no mark but the file's absence; without
      # this both generations would carry AGENTS.md and the first
      # capability that changes it would create it in a project that
      # opted out.
      agents_md: agents_md?
    }
  end

  defp read(igniter, path) do
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      {igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content), igniter}
    else
      {nil, igniter}
    end
  end

  @doc """
  The `phx.new` flags that generate a project of this shape. A flag
  another flag makes moot is left out, as phx.new's own generator binds
  them (`Phx.New.Generator.put_binding/1`): no `--database` and no
  `--binary-id` without Ecto, no `--no-live` without HTML views, where
  `live = html && live` already.
  """
  def flags(facts) do
    off =
      for cap <- @capabilities,
          not Map.fetch!(facts, cap),
          not (cap == :live and not facts.html),
          do: "--no-#{cap}"

    ["--app", to_string(facts.app), "--module", inspect(facts.module)] ++
      if(facts.ecto, do: ["--database", facts.database], else: []) ++
      ["--adapter", facts.adapter] ++
      off ++
      if(facts.ecto and facts.binary_id, do: ["--binary-id"], else: []) ++
      if(Map.get(facts, :agents_md, true), do: [], else: ["--no-agents-md"])
  end

  @doc """
  A project generated by phx.new with these flags: `%{path => content}`.
  Nothing touches the disk — the generator runs in a test-mode igniter,
  which reads and writes only its own map of files.
  """
  @switches [
    app: :string,
    module: :string,
    database: :string,
    adapter: :string,
    binary_id: :boolean,
    ecto: :boolean,
    html: :boolean,
    live: :boolean,
    dashboard: :boolean,
    mailer: :boolean,
    gettext: :boolean,
    esbuild: :boolean,
    tailwind: :boolean,
    agents_md: :boolean
  ]

  def generate(flags, docker \\ nil) do
    # phx.new's own generator, on a scratch directory, exactly as
    # `mix phx.new` runs it (minus git, deps and the prompts): the files
    # come out as phx.new writes them, which is what the project got.
    # Igniter's in-memory port of it (`igniter.phx.install`) is not the
    # same thing — 0.8.3 injects the Ecto config into config/dev.exs
    # only, never into test.exs and runtime.exs.
    {opts, []} = OptionParser.parse!(flags, strict: @switches)
    dir = Path.join(System.tmp_dir!(), "phx_delta_#{System.unique_integer([:positive])}")
    shell = Mix.shell()
    File.mkdir_p!(dir)
    Mix.shell(Mix.Shell.Quiet)

    try do
      dir
      |> Phx.New.Project.new(opts)
      |> Phx.New.Single.prepare_project()
      |> Phx.New.Generator.put_binding()
      |> Phx.New.Single.generate()

      files =
        dir
        |> Path.join("**")
        |> Path.wildcard(match_dot: true)
        |> Enum.reject(&File.dir?/1)
        |> Map.new(&{Path.relative_to(&1, dir), File.read!(&1)})

      Map.merge(files, release(opts, files, docker))
    after
      Mix.shell(shell)
      File.rm_rf!(dir)
    end
  end

  @release_templates "priv/templates/phx.gen.release"

  # The files `bin/migrate` and `bin/server` of the release; theirs run
  # the release, so they are executable, as phx.gen.release leaves them.
  @executables ~w(rel/overlays/bin/server rel/overlays/bin/server.bat rel/overlays/bin/migrate rel/overlays/bin/migrate.bat)

  @doc """
  What `mix phx.gen.release --docker` adds to a project phx.new
  generated with `opts` — the workbench runs it at birth, right after
  phx.new — rendered from Phoenix's own templates with the generator's
  own binding: the release scripts; with Ecto (phx.new's default, off
  with `--no-ecto`) the `Release` module and `bin/migrate`; with
  `docker`, the stack `WorkbenchIgniter.Dockerfile.stack/1` read, the `Dockerfile` and
  `.dockerignore`, whose assets steps are there when the generation has
  an `assets/` directory. Without `docker` no Dockerfile: the project's
  is not the generator's, and stays its own.
  """
  @spec release(keyword(), %{String.t() => String.t()}, map() | nil) ::
          %{String.t() => String.t()}
  def release(opts, files, docker) do
    app = String.to_atom(opts[:app])
    ecto? = opts[:ecto] != false

    binding = [
      app_namespace: opts[:module],
      otp_app: app,
      assets_dir_exists?:
        Enum.any?(files, fn {path, _} -> String.starts_with?(path, "assets/") end)
    ]

    dir = Application.app_dir(:phoenix, @release_templates)

    templates =
      [
        {"rel/server.sh.eex", "rel/overlays/bin/server"},
        {"rel/server.bat.eex", "rel/overlays/bin/server.bat"}
      ] ++
        if(ecto?,
          do: [
            {"rel/migrate.sh.eex", "rel/overlays/bin/migrate"},
            {"rel/migrate.bat.eex", "rel/overlays/bin/migrate.bat"},
            {"release.ex.eex", "lib/#{app}/release.ex"}
          ],
          else: []
        ) ++
        if(docker,
          do: [{"Dockerfile.eex", "Dockerfile"}, {"dockerignore.eex", ".dockerignore"}],
          else: []
        )

    binding =
      binding ++ WorkbenchIgniter.Dockerfile.binding(docker, Path.join(dir, "Dockerfile.eex"))

    Map.new(templates, fn {template, path} ->
      {path, EEx.eval_file(Path.join(dir, template), binding)}
    end)
  end

  @doc """
  What the capability adds to a project of this shape: the files it
  creates and, for the files it changes, their base and theirs contents.
  `overrides` are facts the capability's generation takes differently
  (ecto's `database`).
  """
  def delta(facts, capability, overrides \\ %{}) when capability in @capabilities do
    docker = Map.get(facts, :docker)
    base = generate(flags(facts), docker)

    theirs =
      equalize_secrets(
        generate(flags(Map.merge(%{facts | capability => true}, overrides)), docker),
        base
      )

    created =
      for {path, content} <- theirs, not Map.has_key?(base, path), into: %{}, do: {path, content}

    changed =
      for {path, content} <- theirs, Map.has_key?(base, path), base[path] != content, into: %{} do
        {path, {base[path], content}}
      end

    # What the capability takes away: the files base has and theirs
    # has not — phx.new's static placeholders for a project without a
    # bundler (priv/static/assets/*). Kept with base's content, so that
    # apply/3 removes a file only while it is still that placeholder.
    removed =
      for {path, content} <- base, not Map.has_key?(theirs, path), into: %{}, do: {path, content}

    %{created: created, changed: changed, removed: removed}
  end

  # phx.new draws a signing salt and a secret key base on every run, so
  # two generations differ there whatever their flags. Theirs takes
  # base's values, file by file, in order: the delta is then the
  # capability's lines and nothing else, and the project's own secrets
  # are never in a hunk.
  @secret ~r/((?:signing_salt|secret_key_base):\s*)"[^"]*"/

  defp equalize_secrets(theirs, base),
    do: Map.new(theirs, fn {path, content} -> {path, with_secrets_of(content, base[path])} end)

  # Theirs takes base's secrets, when base has the file at all.
  defp with_secrets_of(content, nil), do: content
  defp with_secrets_of(content, base_content), do: splice(content, secrets(base_content))

  defp secrets(content), do: Regex.scan(@secret, content) |> Enum.map(fn [whole, _] -> whole end)

  # The n-th secret of content becomes the n-th of values, when counts match.
  defp splice(content, values) do
    own = secrets(content)

    if length(own) == length(values) do
      Enum.zip(own, values)
      |> Enum.reduce(content, fn {from, to}, c -> String.replace(c, from, to, global: false) end)
    else
      content
    end
  end

  @doc """
  A base cartridge's whole installer: refuses with an issue when a
  cartridge `feature.requires/0` names is not in, skips with a notice
  when the cartridge's own mark (`feature.installed?/1`) is, and
  otherwise `apply/3`.
  """
  @spec insert(Igniter.t(), module(), atom(), map()) :: Igniter.t()
  def insert(igniter, feature, capability, overrides \\ %{}) do
    case WorkbenchIgniter.Feature.missing_requirements(igniter, feature) do
      {[], igniter} ->
        case feature.installed?(igniter) do
          {true, igniter} ->
            Igniter.add_notice(igniter, "#{feature.name()} is in already: skipping.")

          {false, igniter} ->
            __MODULE__.apply(igniter, capability, overrides)
        end

      {missing, igniter} ->
        WorkbenchIgniter.Feature.refuse(igniter, feature, missing)
    end
  end

  @doc """
  Whether the generator can take the delta for this project: `Phx.New`
  loadable — the archive in the toolchain, a dependency elsewhere — and
  at the version that generated the project.

  The delta is exact only when the `phx_new` taking it is the one that
  generated the project: a version apart, `{:phoenix, "~> x.y.z"}` in
  `mix.exs` differs between the project and the base generation, and in
  a project with few dependencies every capability's lines go right
  after it — a conflict on `mix.exs` for each.

  Which generator made the project is written, not inferred: the
  workbench stamps it into the workspace's own `Dockerfile.local`
  (`ARG PHX_NEW="x.y.z"`) at creation. That record is the project's, it
  survives every edit to `mix.exs`, and it does not move when the
  project bumps Phoenix — the version it depends on now and the version
  that generated it are two different facts.

  Without that file (a project generated outside the workbench) the
  fallback is `{:phoenix, "~> x.y.z"}`, which `phx.new` writes as its
  own version: weaker, since bumping Phoenix rewrites it and any other
  form of the requirement says nothing at all, but better than no check.
  """
  @spec generator_check(Igniter.t()) :: {:ok, Igniter.t()} | {:error, Igniter.t(), String.t()}
  def generator_check(igniter) do
    if Code.ensure_loaded?(Phx.New.Generator) do
      {gen, igniter} = generator(igniter)

      if gen.project && gen.installer && gen.project != gen.installer do
        {:error, igniter,
         "The project was generated by phx.new #{gen.project} (#{where(gen)}) and the " <>
           "installer's is #{gen.installer}: the delta would not be the project's. " <>
           "Rebuild the workspace's toolchain from its own Dockerfile.local " <>
           "(./wb.sh build), or install that version outside the workbench " <>
           "(mix archive.install hex phx_new #{gen.project})."}
      else
        {:ok, igniter}
      end
    else
      {:error, igniter,
       "Phoenix's installer is not available: the base cartridges run phx.new's own generator. " <>
         "Install it (mix archive.install hex phx_new) and run this again."}
    end
  end

  @doc """
  Which `phx.new` generated the project, where that is recorded, and
  which one is at hand — the pair `generator_check/1` compares, and what
  `mix workbench.status` publishes so a console can say it before an
  insert refuses.

  `project` is the stamp (`ARG PHX_NEW` in the workspace's own
  `Dockerfile.local`) when there is one, and `mix.exs`'s phoenix
  requirement otherwise; `source` names which of the two answered, and
  is `nil` when neither did. `installer` is the `phx_new` archive loaded
  here, `nil` where there is none.
  """
  @spec generator(Igniter.t()) ::
          {%{project: String.t() | nil, source: String.t() | nil, installer: String.t() | nil},
           Igniter.t()}
  def generator(igniter) do
    {stamped, igniter} = stamped_generator(igniter)
    {requirement, igniter} = if stamped, do: {nil, igniter}, else: phoenix_requirement(igniter)

    {%{
       project: stamped || requirement,
       source: (stamped && "Dockerfile.local") || (requirement && "mix.exs"),
       installer: generator_version()
     }, igniter}
  end

  defp where(%{source: "Dockerfile.local"}), do: "ARG PHX_NEW in Dockerfile.local"
  defp where(%{project: v}), do: ~s({:phoenix, "~> #{v}"} in mix.exs)

  defp generator_version do
    Application.load(:phx_new)

    case Application.spec(:phx_new, :vsn) do
      nil -> nil
      vsn -> to_string(vsn)
    end
  end

  # The generator the workbench stamped into the workspace at creation.
  # `wb.sh` bakes Dockerfile.local from its seed with the version it
  # resolved, and copies it into the project: the file is the
  # workspace's, and the toolchain it builds is tagged with the same
  # number.
  defp stamped_generator(igniter) do
    {dockerfile, igniter} = read(igniter, "Dockerfile.local")

    case dockerfile && Regex.run(~r/^ARG PHX_NEW="(\d+\.\d+\.\d+)"/m, dockerfile) do
      [_, version] -> {version, igniter}
      _ -> {nil, igniter}
    end
  end

  # The x.y.z of `{:phoenix, "~> x.y.z"}` as phx.new writes it; nil in
  # any other form. The fallback, for a project with no stamp.
  defp phoenix_requirement(igniter) do
    {mix, igniter} = read(igniter, "mix.exs")

    case mix && Regex.run(~r/\{:phoenix,\s*"~> (\d+\.\d+\.\d+)"/, mix) do
      [_, version] -> {version, igniter}
      _ -> {nil, igniter}
    end
  end

  @doc """
  Adds the capability to the project the igniter holds (`overrides` as
  in `delta/3`), as a patch set:
  created files created (skipped when the project already has one),
  changed files merged three ways with the project's own, conflicts
  reported as issues. Refuses with an issue, generating nothing, when
  `generator_check/1` fails.
  """
  def apply(igniter, capability, overrides \\ %{}) do
    case generator_check(igniter) do
      {:ok, igniter} -> do_apply(igniter, capability, overrides)
      {:error, igniter, message} -> Igniter.add_issue(igniter, message)
    end
  end

  defp do_apply(igniter, capability, overrides) do
    {facts, igniter} = facts(igniter)
    %{created: created, changed: changed, removed: removed} = delta(facts, capability, overrides)

    # phx.new names lib/ and test/ after the app; Igniter would move a
    # new module to the path derived from its name, which differs when
    # the name carries digits (LoremIpsum9 → lorem_ipsum9/). The files
    # stay where phx.new puts them: the project's .igniter.exs says so.
    # The project's files as they are, read before anything is created:
    # from the first file Igniter creates on, it formats every file it
    # holds, and the merge must see the project's text, not the
    # formatter's.
    {ours, igniter} =
      Enum.reduce(changed, {%{}, igniter}, fn {path, _}, {ours, igniter} ->
        if Igniter.exists?(igniter, path) do
          igniter = Igniter.include_existing_file(igniter, path)

          {Map.put(
             ours,
             path,
             igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
           ), igniter}
        else
          {ours, igniter}
        end
      end)

    igniter =
      Igniter.Project.IgniterConfig.dont_move_file_pattern(
        igniter,
        ~r"^(lib|test)/#{Regex.escape(to_string(facts.app))}(_web)?/"
      )

    igniter =
      Enum.reduce(created, igniter, fn {path, content}, igniter ->
        Igniter.create_new_file(igniter, path, content, on_exists: :skip)
      end)

    # Igniter writes every file alike; the release's scripts run the
    # release and must be executable, as phx.gen.release leaves them —
    # set once the files are written (a queued task runs then).
    igniter =
      case Enum.filter(@executables, &Map.has_key?(created, &1)) do
        [] -> igniter
        paths -> Igniter.add_task(igniter, "workbench.executable", paths)
      end

    # A file the capability takes away goes only while it is, byte for
    # byte, what phx.new put there: a placeholder nobody touched. One
    # the project edited or replaced is the project's, and stays.
    igniter =
      Enum.reduce(removed, igniter, fn {path, placeholder}, igniter ->
        drop_placeholder(igniter, path, placeholder)
      end)

    Enum.reduce(changed, igniter, fn {path, {base, theirs}}, igniter ->
      case ours do
        # A file the project has not moved from what phx.new wrote is
        # what phx.new writes with the capability, as phx.new writes it:
        # the guarantee, and the case that matters. Operations and
        # merges below are for a file the project has moved.
        %{^path => own} ->
          if untouched?(path, own, base),
            do: as_phx_new(igniter, path, own, theirs),
            else: moved(igniter, path, own, base, theirs, capability)

        _ ->
          Igniter.create_new_file(igniter, path, theirs)
      end
    end)
  end

  defp moved(igniter, path, own, base, theirs, capability) do
    case path do
      # mix.exs is applied as operations on what it holds, not merged
      # as text (WorkbenchIgniter.MixFile): anything beside where
      # phx.new writes — the workbench's dependency of birth on the
      # `deps:` line, a dependency of the project's own — was a
      # conflict to the merge, on every project (2026-09-16).
      "mix.exs" ->
        WorkbenchIgniter.MixFile.apply(igniter, base, theirs, capability)

      _ ->
        merge_into(igniter, path, own, base, theirs, capability)
    end
  end

  # Not moved: what the project has is what phx.new wrote, its own
  # secrets aside — each generation draws its own. Judged by content,
  # not layout: an Elixir file as the formatter leaves it (a project
  # that ran `mix format`, or one Igniter formatted on an earlier
  # insert, has not moved), any other file up to how it ends.
  defp untouched?(path, own, base) do
    base = splice(base, secrets(own))

    if Path.extname(path) in [".ex", ".exs"],
      do: formatted(own) != :error and formatted(own) == formatted(base),
      else: String.trim_trailing(own, "\n") == String.trim_trailing(base, "\n")
  end

  defp formatted(text) do
    text |> Code.format_string!() |> IO.iodata_to_binary()
  rescue
    _ -> :error
  end

  # phx.new's file with the capability, with the project's secrets.
  defp as_phx_new(igniter, path, own, theirs) do
    content = splice(theirs, secrets(own))
    Igniter.update_file(igniter, path, &Rewrite.Source.update(&1, :content, fn _ -> content end))
  end

  # One changed file the project has: three ways, ours with the
  # capability's change. The project's secrets are its own generation's;
  # base and theirs take them, so a salt line never reads as an edit of ours.
  defp merge_into(igniter, path, ours, base, theirs, capability) do
    secrets = secrets(ours)
    {ours, base, theirs} = {laid_out(path, ours), laid_out(path, base), laid_out(path, theirs)}

    {merged, notices} =
      cond do
        WorkbenchIgniter.IgnoreFile.ignore_file?(path) ->
          {WorkbenchIgniter.IgnoreFile.merge(ours, base, theirs), []}

        router?(path) ->
          case WorkbenchIgniter.RouterFile.merge(ours, base, theirs) do
            {:ok, merged, notices} -> {{:ok, merged}, notices}
            :fallback -> {merge3(ours, base, theirs), []}
          end

        true ->
          {merge3(ours, splice(base, secrets), splice(theirs, secrets)), []}
      end

    case merged do
      {:ok, merged} ->
        notices
        |> Enum.reduce(igniter, &Igniter.add_notice(&2, "#{path}: #{&1}"))
        |> Igniter.update_file(
          path,
          &Rewrite.Source.update(&1, :content, fn _ -> merged end)
        )

      {:conflict, _merged} ->
        # Not resolved, and not written with markers either — Igniter
        # parses an .ex file it writes. The file stays as it is; what
        # phx.new would have it be lands beside it, to merge by hand.
        # Written to disk here, not in the patch set: an issue withholds
        # the whole patch set, and this file is the one thing the user
        # needs *because* of the issue. In test mode it stays a patch.
        igniter
        |> aside(path <> ".phx-new", theirs)
        |> Igniter.add_issue(
          "#{path}: the #{capability} lines conflict with the project's own edits. " <>
            "The file is untouched; #{path}.phx-new is the file as phx.new generates " <>
            "it with the #{capability} — merge the difference by hand and delete it."
        )
    end
  end

  # The router is applied as operations on its pipelines, scopes and
  # routes (WorkbenchIgniter.RouterFile), and merged as text only when
  # those cannot say the capability's change.
  defp router?(path), do: String.match?(path, ~r{^lib/[^/]+_web/router\.ex$})

  # phx.new's templates are not what the formatter would leave: the
  # router opens its dev routes with a blank line after `do`, which the
  # formatter takes out. A project that has been formatted — by Igniter,
  # which formats what it writes, or by the `precommit` alias phx.new
  # itself gives it — then differs from base right where dashboard
  # writes, and the merge conflicted (2026-09-17, found by growing a
  # bare project against one born whole). The project's formatter is
  # not to be asked: after html it wants LiveView's plugin, which may
  # not be loaded where this runs. So the three sides of an Elixir file
  # are merged in the one layout every formatter configuration agrees
  # on — no blank line after a line that opens a block — and differ by
  # what was written, not by how it was laid out. What the merge writes
  # is what `mix format` would have left.
  defp laid_out(path, text) do
    if Path.extname(path) in [".ex", ".exs"],
      do: Regex.replace(~r/^([ \t]*[a-z_@].*\sdo)\n(?:[ \t]*\n)+/m, text, "\\1\n"),
      else: text
  end

  defp drop_placeholder(igniter, path, placeholder) do
    if Igniter.exists?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)
      content = igniter.rewrite |> Rewrite.source!(path) |> Rewrite.Source.get(:content)
      if content == placeholder, do: Igniter.rm(igniter, path), else: igniter
    else
      igniter
    end
  end

  defp aside(igniter, path, content) do
    if igniter.assigns[:test_mode?] do
      Igniter.create_new_file(igniter, path, content, on_exists: :overwrite)
    else
      File.write!(path, content)
      igniter
    end
  end

  @doc """
  Three-way merge, as git does it: ours with the change from base to
  theirs. `{:ok, merged}` or `{:conflict, merged_with_markers}`.

  The three end with exactly one newline before merging. Igniter writes
  a file that way; phx.new's templates end however they end (`AGENTS.md`
  with none, `errors.pot` with two) — and a file an earlier insert
  wrote would otherwise differ from base on its last line, which
  conflicts with any capability that appends there (ecto on the
  `.pot`, html and live on `AGENTS.md`, live on `app.js`).
  """
  def merge3(ours, base, theirs) do
    dir = Path.join(System.tmp_dir!(), "wb-merge-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      files =
        for {name, content} <- [ours: ours, base: base, theirs: theirs] do
          path = Path.join(dir, to_string(name))
          File.write!(path, String.trim_trailing(content, "\n") <> "\n")
          path
        end

      {out, status} =
        System.cmd(
          "git",
          ["merge-file", "-p", "-L", "project", "-L", "phx.new", "-L", "with the capability"] ++
            files,
          stderr_to_stdout: false
        )

      if status == 0, do: {:ok, out}, else: {:conflict, out}
    after
      File.rm_rf!(dir)
    end
  end
end
