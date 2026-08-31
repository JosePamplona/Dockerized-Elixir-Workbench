defmodule WorkbenchIgniter do
  @moduledoc """
  Igniter-based installers for the Dockerized Elixir Workbench.

  Each workbench feature is exposed as a `mix workbench.install.*` task that
  patches the target project semantically (AST-based) instead of with `sed`.
  """

  @doc """
  Renders a `mix workbench.setup` EEx template from `priv/setup/templates`.

  Templates receive `assigns`, accessible as `@key` inside the template.
  Rendered with `trim: true` so block tags (`<%= if ... do %>`) that sit
  alone on a line don't leave blank lines behind.
  """
  @spec template(String.t(), Keyword.t()) :: String.t()
  def template(path, assigns) do
    :workbench_igniter
    |> :code.priv_dir()
    |> Path.join("setup/templates")
    |> Path.join(path)
    |> EEx.eval_file([assigns: assigns], trim: true)
  end

  @doc """
  Renders a `priv/setup/templates` template with `template/2` and creates
  it at `path` in the target project.

  EEx's `trim: true` still leaves stray newlines around block tags, so
  runs of blank lines are collapsed: a conditional section that renders
  nothing leaves no gap behind.

  `opts` are `Igniter.create_new_file/4` options, with `on_exists: :skip`
  honored for files that only exist on disk too — igniter honors it just
  for sources already loaded in the patch set, so a file that must never
  be overwritten (`.env`, carrying its generated secret) would still be
  replaced.
  """
  @spec plant_template(Igniter.t(), String.t(), String.t(), Keyword.t(), Keyword.t()) ::
          Igniter.t()
  def plant_template(igniter, name, path, assigns, opts) do
    if opts[:on_exists] == :skip and Igniter.exists?(igniter, path) do
      igniter
    else
      content =
        name
        |> template(assigns)
        |> String.replace(~r/\n{3,}/, "\n\n")
        |> String.trim_trailing("\n")

      Igniter.create_new_file(igniter, path, content <> "\n", opts)
    end
  end

  @doc """
  A 64-character alphanumeric `SECRET_KEY_BASE`, the value the setup tasks
  plant in the generated `.env`.
  """
  @spec secret_key_base() :: String.t()
  def secret_key_base do
    :crypto.strong_rand_bytes(96)
    |> Base.encode64()
    |> String.replace(~r/[^A-Za-z0-9]/, "")
    |> binary_part(0, 64)
  end

  @doc """
  Reads a file from `priv/features/<feature>` verbatim — a cartridge's
  binary assets (images and the like), which stay out of the compiled
  module unlike the text assets embedded with `embed_assets/1`.
  Cartridges call it through the local `priv_asset/1`.
  """
  @spec feature_asset(String.t(), String.t()) :: binary()
  def feature_asset(feature, path) do
    :workbench_igniter
    |> :code.priv_dir()
    |> Path.join("features")
    |> Path.join(feature)
    |> Path.join(path)
    |> File.read!()
  end

  @doc """
  Plants a `priv/features/<feature>` asset into the project verbatim,
  through an after-apply task.

  Binary assets must never go through `Igniter.create_new_file/4`: the
  rewrite pipeline trims trailing bytes and appends a newline on every
  write, corrupting them. Composing `mix workbench.plant_asset` instead
  copies the file byte-for-byte once the patch set is confirmed and
  applied, keeping dry-run semantics intact. Cartridges call it through
  the local `plant_binary_asset/3`.
  """
  @spec plant_binary_asset(Igniter.t(), String.t(), String.t(), String.t()) ::
          Igniter.t()
  def plant_binary_asset(igniter, feature, asset, target) do
    Igniter.add_task(igniter, "workbench.plant_asset", [feature, asset, target])
  end

  @doc """
  Appends a gitignore entry (comment + pattern) to the project `.gitignore`,
  creating the file when the project has none. A no-op when the pattern is
  already listed.
  """
  @spec gitignore_entry(Igniter.t(), String.t(), String.t()) :: Igniter.t()
  def gitignore_entry(igniter, comment, pattern) do
    entry = "# #{comment}\n#{pattern}\n"

    if Igniter.exists?(igniter, ".gitignore") do
      igniter
      |> Igniter.include_existing_file(".gitignore")
      |> Igniter.update_file(".gitignore", fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          if String.contains?(content, pattern),
            do: content,
            else: String.trim_trailing(content, "\n") <> "\n\n" <> entry
        end)
      end)
    else
      Igniter.create_new_file(igniter, ".gitignore", entry)
    end
  end

  @doc """
  Appends an entry (comment + lines) to the project `.env` and
  `.env.sample`, creating the files when the project has none. A no-op
  when the first variable of `body` is already declared.

  The counterpart of `gitignore_entry/3` for the environment files: it
  lets a cartridge own its own variables instead of parking them,
  commented out, in the setup template. Both files receive
  the very same text unless `sample_body` is given — `.env.sample` is
  meant to be committed, so a secret goes in `body` for `.env` and its
  blanked-out line (`KEY=""`) in `sample_body`, the same key first.
  """
  @spec env_entry(Igniter.t(), String.t(), String.t(), String.t() | nil) :: Igniter.t()
  def env_entry(igniter, comment, body, sample_body \\ nil) do
    # The first `KEY=` of the body marks the entry as already present.
    marker = body |> String.split("=", parts: 2) |> hd() |> String.trim()

    [{".env", body}, {".env.sample", sample_body || body}]
    |> Enum.reduce(igniter, fn {path, body}, igniter ->
      entry = "# #{comment}\n" <> String.trim_trailing(body, "\n") <> "\n"
      append_env_entry(igniter, path, entry, marker)
    end)
  end

  defp append_env_entry(igniter, path, entry, marker) do
    if Igniter.exists?(igniter, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Igniter.update_file(path, fn source ->
        Rewrite.Source.update(source, :content, fn content ->
          if String.contains?(content, marker),
            do: content,
            else: String.trim_trailing(content, "\n") <> "\n\n" <> entry
        end)
      end)
    else
      Igniter.create_new_file(igniter, path, entry)
    end
  end

  @doc """
  Returns `count` consecutive migration timestamps guaranteed to be greater
  than any migration already present — in the patch set (installers composed
  in the same run) or on disk. Same-second collisions would otherwise break
  migration ordering and produce duplicated Ecto versions.
  """
  @spec migration_timestamps(Igniter.t(), pos_integer()) :: [String.t()]
  def migration_timestamps(igniter, count) do
    existing =
      igniter.rewrite
      |> Rewrite.paths()
      |> Kernel.++(Path.wildcard("priv/repo/migrations/*.exs"))
      |> Enum.flat_map(fn path ->
        case Regex.run(~r|priv/repo/migrations/(\d{14})_|, path) do
          [_, timestamp] -> [String.to_integer(timestamp)]
          _ -> []
        end
      end)

    now =
      DateTime.utc_now()
      |> Calendar.strftime("%Y%m%d%H%M%S")
      |> String.to_integer()

    first = Enum.max([now | existing])

    Enum.map(1..count, &Integer.to_string(first + &1))
  end
end
