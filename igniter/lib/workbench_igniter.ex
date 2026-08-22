defmodule WorkbenchIgniter do
  @moduledoc """
  Igniter-based installers for the Dockerized Elixir Workbench.

  Each workbench feature is exposed as a `mix workbench.install.*` task that
  patches the target project semantically (AST-based) instead of with `sed`.
  """

  @doc """
  Renders an EEx template from `priv/templates`.

  Templates receive `assigns`, accessible as `@key` inside the template.
  Rendered with `trim: true` so block tags (`<%= if ... do %>`) that sit
  alone on a line don't leave blank lines behind.
  """
  @spec template(String.t(), Keyword.t()) :: String.t()
  def template(path, assigns) do
    :workbench_igniter
    |> :code.priv_dir()
    |> Path.join("templates")
    |> Path.join(path)
    |> EEx.eval_file([assigns: assigns], trim: true)
  end

  @doc """
  Reads a file from `priv/assets` verbatim — no EEx rendering.

  For content that must be copied as-is, like the excoveralls report
  templates (whose own `<%= %>` tags belong to the target project).
  """
  @spec asset(String.t()) :: String.t()
  def asset(path) do
    :workbench_igniter
    |> :code.priv_dir()
    |> Path.join("assets")
    |> Path.join(path)
    |> File.read!()
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
