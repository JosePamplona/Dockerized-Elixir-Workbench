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
  2. Two projects are generated with phx.new's own generator
     (Igniter's in-memory `phx.new`): **base**, with those flags, and
     **theirs**, with the capability's flag turned on.
  3. Files theirs has and base lacks are created. Files that differ
     between the two are merged three ways onto the project's own —
     `git merge-file` with base, ours, theirs — so the project's edits
     survive and only the capability's lines come in. A conflict is
     reported as an issue and the file left alone, with phx.new's
     version of it beside it (`<path>.phx-new`) to merge by hand —
     never resolved silently.

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

    facts =
      shape(
        app,
        Igniter.Project.Module.module_name_prefix(igniter),
        dep,
        config || "",
        Igniter.exists?(igniter, "AGENTS.md")
      )

    {facts, igniter}
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

    shape(app, module, dep, config || "", agents_md?)
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

  @doc "The `phx.new` flags that generate a project of this shape."
  def flags(facts) do
    off = for cap <- @capabilities, not Map.fetch!(facts, cap), do: "--no-#{cap}"

    ["--app", to_string(facts.app), "--module", inspect(facts.module)] ++
      ["--database", facts.database, "--adapter", facts.adapter] ++
      off ++
      if(facts.binary_id, do: ["--binary-id"], else: []) ++
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

  def generate(flags) do
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

      dir
      |> Path.join("**")
      |> Path.wildcard(match_dot: true)
      |> Enum.reject(&File.dir?/1)
      |> Map.new(&{Path.relative_to(&1, dir), File.read!(&1)})
    after
      Mix.shell(shell)
      File.rm_rf!(dir)
    end
  end

  @doc """
  What the capability adds to a project of this shape: the files it
  creates and, for the files it changes, their base and theirs contents.
  `overrides` are facts the capability's generation takes differently
  (ecto's `database`).
  """
  def delta(facts, capability, overrides \\ %{}) when capability in @capabilities do
    base = generate(flags(facts))

    theirs =
      equalize_secrets(generate(flags(Map.merge(%{facts | capability => true}, overrides))), base)

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
        Igniter.add_issue(
          igniter,
          "#{feature.name()} builds on #{Enum.join(missing, " and ")}, not in the project yet. " <>
            "Insert that first: ./wb.sh add #{hd(missing)}"
        )
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

    # A file the capability takes away goes only while it is, byte for
    # byte, what phx.new put there: a placeholder nobody touched. One
    # the project edited or replaced is the project's, and stays.
    igniter =
      Enum.reduce(removed, igniter, fn {path, placeholder}, igniter ->
        drop_placeholder(igniter, path, placeholder)
      end)

    Enum.reduce(changed, igniter, fn {path, {base, theirs}}, igniter ->
      case ours do
        %{^path => own} -> merge_into(igniter, path, own, base, theirs, capability)
        _ -> Igniter.create_new_file(igniter, path, theirs)
      end
    end)
  end

  # One changed file the project has: three ways, ours with the
  # capability's change. The project's secrets are its own generation's;
  # base and theirs take them, so a salt line never reads as an edit of ours.
  defp merge_into(igniter, path, ours, base, theirs, capability) do
    secrets = secrets(ours)

    case merge3(ours, splice(base, secrets), splice(theirs, secrets)) do
      {:ok, merged} ->
        Igniter.update_file(
          igniter,
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
