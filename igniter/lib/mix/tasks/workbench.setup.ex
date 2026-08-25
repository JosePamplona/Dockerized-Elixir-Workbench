defmodule Mix.Tasks.Workbench.Setup do
  use Igniter.Mix.Task

  @example "mix workbench.setup --project-name \"Lorem Ipsum\" --enhance --health --yes"
  @shortdoc "Configures a freshly generated Phoenix project the workbench way"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `configure_files` stage plus the feature
  orchestration that `app.sh` drives from `config.conf`. In a single atomic
  patch set it:

  * sets the initial version in `mix.exs`
  * base config: ANSI colors, `:utc_datetime_usec` generators, migration
    primary key / timestamp types, `0.0.0.0` endpoint IP for dev,
    `dev_routes` in test
  * prepends `.env` and `.elixir_ls` to `.gitignore`
  * generates the project text files from templates: `README.md`,
    `CHANGELOG.md`, `.env.sample`, `.env` and `.tool-versions` — the
    dev `Dockerfile.local` is a copy of the workbench toolchain
    dockerfile placed by the workbench script, and the production
    `Dockerfile`/`.dockerignore` come from `mix phx.gen.release --docker`
  * composes the requested feature installers (`--enhance`, `--health`, …)

  Flags map 1:1 to `config.conf`; `app.sh` translates that file into this
  task's arguments. Feature order, dependencies (`--stripe` or `--openai`
  imply `--auth0`) and per-feature argv live in the
  `WorkbenchIgniter.Features` registry and each feature's manifest.

  ## Example

      #{@example}

  ## Options

  * `--project-name` - Display name (default: capitalized app name).
  * `--version` - Initial project version. Default: `0.0.0`.
  * `--elixir-version`, `--erlang-version`, `--debian-version` - Stack
    versions for the Dockerfiles and `.tool-versions`.
  * `--id-type` - `migration_primary_key` type (e.g. `uuid`). Optional.
  * `--timestamps` - `migration_timestamps` type (e.g.
    `naive_datetime_usec`). Optional.
  * `--interface` - `rest` | `graphql` | `none`. Default: `rest`.
  * `--app-port` - Application HOST port, used in the README URLs.
    Default: `4000`.
  * `--internal-port` - Port the server binds inside the container
    (`PORT` in `.env`); must match the workspace compose mapping.
    Default: `4000`.
  * `--db-host`, `--db-port`, `--db-user`, `--db-pass` - Database
    connection data for `DATABASE_URL`.
  * `--repo-url` - Repository URL for the README badges.
  * `--no-html`, `--no-assets`, `--no-mailer`, `--no-dashboard` - Mirror
    the `phx.new` options the project was created with.
  * `--enhance`, `--exdoc`, `--coveralls`, `--health`, `--auth0`,
    `--openai`, `--stripe` - Feature toggles (`config.conf`).
  * `--coverage-theme` - HTML coverage report theme forwarded to the
    coveralls feature (`exdoc-ish` | `custom`). Optional.
  """

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :workbench_igniter,
      example: @example,
      composes: WorkbenchIgniter.Features.tasks(),
      schema: [
        project_name: :string,
        version: :string,
        elixir_version: :string,
        erlang_version: :string,
        debian_version: :string,
        id_type: :string,
        timestamps: :string,
        interface: :string,
        app_port: :string,
        internal_port: :string,
        db_host: :string,
        db_port: :string,
        db_user: :string,
        db_pass: :string,
        repo_url: :string,
        guidelines_url: :string,
        html: :boolean,
        assets: :boolean,
        mailer: :boolean,
        dashboard: :boolean,
        ecto: :boolean,
        enhance: :boolean,
        exdoc: :boolean,
        coveralls: :boolean,
        coverage_theme: :string,
        health: :boolean,
        auth0: :boolean,
        openai: :boolean,
        stripe: :boolean
      ],
      defaults: [
        version: "0.0.0",
        elixir_version: "1.19.5",
        erlang_version: "27.3",
        debian_version: "trixie-20260112-slim",
        interface: "rest",
        app_port: "4000",
        internal_port: "4000",
        db_host: "localhost",
        db_port: "5432",
        db_user: "postgres",
        db_pass: "postgres",
        repo_url: "https://github.com/user/repo",
        html: true,
        assets: true,
        mailer: true,
        dashboard: true,
        ecto: true,
        enhance: false,
        exdoc: false,
        coveralls: false,
        health: false,
        auth0: false,
        openai: false,
        stripe: false
      ]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    opts = normalize(igniter.args.options)
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Igniter.Project.Module.module_name_prefix(igniter)
    repo = Module.concat(app_module, Repo)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint = Module.concat(web_module, Endpoint)

    igniter
    |> set_initial_version(opts)
    |> base_config(app_name, repo, endpoint, opts)
    |> adjust_gitignore()
    |> create_text_files(app_name, opts)
    # The fresh phx.new lock can pin transitive deps against the feature
    # deps this setup adds (e.g. it locks idna 7.x while auth0_jwks
    # needs hackney's idna ~> 6.1): igniter's automatic post-apply fetch
    # tolerates that resolution failure, but the queued feature tasks
    # below (binary asset planting) run `mix` in the project and abort
    # on unresolved deps. Re-resolving the lock from scratch first —
    # queued here so it runs ahead of every feature task; unlock and get
    # are Mix builtins, runnable even with broken deps — makes the
    # feature deps land whole. On a minutes-old generated lock this is
    # loss-free.
    |> Igniter.add_task("deps.unlock", ["--all"])
    |> Igniter.add_task("deps.get", [])
    |> WorkbenchIgniter.Features.compose(opts)
  end

  # --- Options ----------------------------------------------------------------

  defp normalize(opts) do
    opts
    # Feature dependencies, as declared by each feature's implies/0.
    |> WorkbenchIgniter.Features.normalize()
    |> Keyword.put_new_lazy(:project_name, fn ->
      Mix.Project.config()[:app] |> to_string() |> String.capitalize()
    end)
  end

  # --- mix.exs ----------------------------------------------------------------

  defp set_initial_version(igniter, opts) do
    version = opts[:version]

    Igniter.Project.MixProject.update(igniter, :project, [:version], fn _zipper ->
      # A binary passed as {:code, ...} is parsed as source, so the string
      # literal needs its quotes.
      {:ok, {:code, inspect(version)}}
    end)
  end

  # --- config/*.exs -----------------------------------------------------------

  defp base_config(igniter, app_name, repo, endpoint, opts) do
    igniter
    # Enabling ANSI color codes for TTY emulation.
    |> Igniter.Project.Config.configure("config.exs", :elixir, [:ansi_enabled], true)
    |> Igniter.Project.Config.configure(
      "config.exs",
      app_name,
      [:generators, :timestamp_type],
      :utc_datetime_usec
    )
    |> configure_migration_types(app_name, repo, opts)
    # Allow access from all machines in the Docker network.
    |> Igniter.Project.Config.configure(
      "dev.exs",
      app_name,
      [endpoint, :http, :ip],
      {0, 0, 0, 0}
    )
    # Enable dev routes for exdocs, dashboard and mailbox endpoints in test.
    |> Igniter.Project.Config.configure("test.exs", app_name, [:dev_routes], true)
  end

  defp configure_migration_types(igniter, app_name, repo, opts) do
    set = fn igniter, key, type ->
      case type do
        nil ->
          igniter

        type ->
          Igniter.Project.Config.configure(
            igniter,
            "config.exs",
            app_name,
            [repo, key],
            type: String.to_atom(type)
          )
      end
    end

    igniter
    |> set.(:migration_primary_key, opts[:id_type])
    |> set.(:migration_timestamps, opts[:timestamps])
  end

  # --- .gitignore -------------------------------------------------------------

  @gitignore_header """
  # Secrets required to configure the application.
  .env

  # Elixir Language Server directory.
  /.elixir_ls/

  """

  defp adjust_gitignore(igniter) do
    if Igniter.exists?(igniter, ".gitignore") do
      igniter
      |> Igniter.include_existing_file(".gitignore")
      |> Igniter.update_file(".gitignore", fn source ->
        Rewrite.Source.update(source, :content, &prepend_gitignore_header/1)
      end)
    else
      Igniter.create_new_file(igniter, ".gitignore", @gitignore_header)
    end
  end

  defp prepend_gitignore_header(content) do
    if String.contains?(content, ".env"),
      do: content,
      else: @gitignore_header <> content
  end

  # --- Text files from templates ----------------------------------------------

  defp create_text_files(igniter, app_name, opts) do
    interface = opts[:interface]
    port = opts[:app_port]
    repo_url = opts[:repo_url]
    database_url = "ecto://#{opts[:db_user]}:#{opts[:db_pass]}@#{opts[:db_host]}/#{app_name}_prod"

    env_assigns = [
      app_name: to_string(app_name),
      # PORT is the port the server binds INSIDE the container; the host
      # port (--app-port) only shows up in the README URLs and in the
      # workspace compose port mapping.
      port: opts[:internal_port],
      database_url: database_url,
      secret_key_base: secret_key_base(),
      auth0: opts[:auth0],
      openai: opts[:openai],
      stripe: opts[:stripe]
    ]

    # Same template as .env, with the secret blanked out: the sample is
    # meant to be committed, so it must never carry a real secret.
    sample_assigns = Keyword.put(env_assigns, :secret_key_base, "")

    readme_assigns = [
      project_name: opts[:project_name],
      version: opts[:version],
      api_type: api_type(interface),
      repo_url: repo_url,
      repo_badge: repo_badge(repo_url),
      port: port,
      internal_port: opts[:internal_port],
      coverage_command: if(opts[:coveralls], do: "mix cover", else: "mix test --cover"),
      ecto: opts[:ecto],
      html: opts[:html],
      graphql: interface == "graphql",
      rest: interface == "rest",
      health: opts[:health],
      mailer: opts[:mailer],
      dashboard: opts[:dashboard],
      exdoc: opts[:exdoc],
      coveralls: opts[:coveralls],
      enhance: opts[:enhance],
      auth0: opts[:auth0],
      openai: opts[:openai],
      stripe: opts[:stripe]
    ]

    stack_assigns = [
      app_name: to_string(app_name),
      assets: opts[:assets],
      elixir_version: opts[:elixir_version],
      erlang_version: opts[:erlang_version],
      erlang_major: opts[:erlang_version] |> String.split(".") |> hd(),
      debian_version: opts[:debian_version]
    ]

    changelog_assigns = [
      version: opts[:version],
      creation_date: Date.utc_today() |> Date.to_iso8601()
    ]

    igniter
    |> plant("env.eex", ".env.sample", sample_assigns, on_exists: :overwrite)
    # Secrets are generated once: an existing .env is never overwritten.
    |> plant("env.eex", ".env", env_assigns, on_exists: :skip)
    |> plant("readme.eex", "README.md", readme_assigns, on_exists: :overwrite)
    |> plant("changelog.eex", "CHANGELOG.md", changelog_assigns, on_exists: :skip)
    |> plant("tool_versions.eex", ".tool-versions", stack_assigns, on_exists: :overwrite)
  end

  defp plant(igniter, template, path, assigns, opts) do
    # create_new_file only honors :skip for sources already loaded in the
    # patch set — a file that exists just on disk would still be replaced.
    if opts[:on_exists] == :skip and Igniter.exists?(igniter, path) do
      igniter
    else
      # EEx's :trim leaves stray newlines around block tags; collapse runs
      # of blank lines so conditional sections don't leave gaps behind.
      content =
        template
        |> WorkbenchIgniter.template(assigns)
        |> String.replace(~r/\n{3,}/, "\n\n")
        |> String.trim_trailing("\n")

      Igniter.create_new_file(igniter, path, content <> "\n", opts)
    end
  end

  defp api_type("graphql"), do: "GraphQL"
  defp api_type(_), do: "REST"

  defp repo_badge(repo_url) do
    repo_url
    |> String.trim_trailing("/")
    |> String.split("/")
    |> Enum.take(-2)
    |> Enum.join("/")
  end

  defp secret_key_base do
    :crypto.strong_rand_bytes(96)
    |> Base.encode64()
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> binary_part(0, 64)
  end
end
