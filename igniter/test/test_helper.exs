# A phx.new project held in memory, for the tests of what the cartridges
# do to one: phx.new's own output (`PhxDelta.generate/1`), with the
# sources loaded — Igniter's test-mode glob does not match the relative
# patterns its module search uses, so without this the project's modules
# (the router, the web module) would be invisible to it.
defmodule WorkbenchIgniter.TestProject do
  @flags ~w(--app test --module Test --database postgres --adapter bandit)

  # The stack a born project's Dockerfile names (phx.gen.release --docker).
  @docker %{elixir_vsn: "1.19.6", otp_vsn: "28.5.0.6", debian_version: "trixie-20260824-slim"}
  def docker, do: @docker

  @doc "`flags` are added to the defaults, or replace them when they carry --app."
  def new(flags \\ [], files \\ %{}) do
    flags = if "--app" in flags, do: flags, else: @flags ++ flags

    Igniter.new()
    |> Igniter.assign(:test_mode?, true)
    |> Igniter.assign(
      :test_files,
      Map.merge(WorkbenchIgniter.PhxDelta.generate(flags, @docker), files)
    )
    |> Igniter.include_glob("**/*.{ex,exs}")
  end
end

# A project grown cartridge by cartridge, against the one phx.new makes
# outright: the rod every base cartridge is measured with
# (grown_vs_born_test, and each cartridge's options). phx.new's own
# generator makes both; the installers run as `wb.sh add` runs them,
# each applied before the next.
defmodule WorkbenchIgniter.Grown do
  alias WorkbenchIgniter.MixFile
  alias WorkbenchIgniter.PhxDelta

  @cartridges ~w(mailer gettext ecto esbuild tailwind html live dashboard)

  # Written on the way by who is not phx.new: the environment files
  # ecto's variable goes into (a birth has them from workbench.setup),
  # and Igniter's own configuration.
  @not_phx_news ~w(.env .env.sample .igniter.exs)
  def not_phx_news, do: @not_phx_news

  @doc """
  The project phx.new makes with exactly these cartridges in, and the
  `flags` of its own on top (`--database mysql`, `--binary-id`). As a
  run of `wb.sh add` finds a project: on disk, nothing loaded — Igniter
  takes up the files an installer touches, and those alone.
  """
  def born(cartridges, flags \\ []) do
    database = if "--database" in flags, do: [], else: ~w(--database postgres)
    off = for c <- @cartridges, c not in cartridges, do: "--no-#{c}"

    Igniter.new()
    |> Igniter.assign(:test_mode?, true)
    |> Igniter.assign(
      :test_files,
      PhxDelta.generate(
        ~w(--app test --module Test --adapter bandit) ++ database ++ off ++ flags,
        WorkbenchIgniter.TestProject.docker()
      )
    )
  end

  @doc "A cartridge added with its options, and applied: `{:ok, igniter}`, or `{:error, why}` with its issues."
  def add(igniter, cartridge, argv \\ []) do
    # live is html's option: as a step of an order, "html" goes in
    # without it and "live" is html run again, which adds it.
    {task, argv} =
      case cartridge do
        "html" -> {"html", ["--no-live" | argv]}
        "live" -> {"html", argv}
        other -> {other, argv}
      end

    igniter = Igniter.compose_task(igniter, "workbench.install.#{task}", argv)

    case igniter.issues do
      [] -> {:ok, Igniter.Test.apply_igniter!(igniter)}
      issues -> {:error, "add #{cartridge}: #{Enum.join(issues, " · ")}"}
    end
  end

  def grow(igniter, order) do
    Enum.reduce_while(order, {:ok, igniter}, fn cartridge, {:ok, igniter} ->
      case add(igniter, cartridge) do
        {:ok, igniter} -> {:cont, {:ok, igniter}}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  What differs between a project born and one grown: nothing, or words
  for it. What may differ is said here and nowhere else: the secrets
  phx.new draws on every run; how a file ends; for Elixir, a blank line
  after a line that opens a block — phx.new's router has one the
  formatter takes out, and a merge writes what `mix format` would leave
  (PhxDelta); the order of `mix.exs`'s lists and of `.gitignore`'s
  patterns, where order means nothing; and `not_phx_news/0`.
  """
  def differences(born, grown) do
    {b, g} = {files(born), files(grown)}

    for(path <- Map.keys(g) -- Map.keys(b), do: "#{path}: a birth does not have it") ++
      for(path <- Map.keys(b) -- Map.keys(g), do: "#{path}: a birth has it, this lacks it") ++
      for {path, content} <- b, Map.has_key?(g, path), not same?(path, content, g[path]) do
        "#{path}: differs"
      end
  end

  defp files(igniter), do: Map.drop(igniter.assigns[:test_files], @not_phx_news)

  defp same?("mix.exs", born, grown), do: mix(born) == mix(grown)
  defp same?(".gitignore", born, grown), do: patterns(born) == patterns(grown)
  defp same?(path, born, grown), do: normal(path, born) == normal(path, grown)

  @secret ~r/((?:signing_salt|secret_key_base):\s*)"[^"]*"/

  defp normal(path, content) do
    content = Regex.replace(@secret, content, "\\1\"…\"")

    content =
      if Path.extname(path) in [".ex", ".exs"],
        do: Regex.replace(~r/^([ \t]*[a-z_@].*\sdo)\n(?:[ \t]*\n)+/m, content, "\\1\n"),
        else: content

    String.trim_trailing(content) <> "\n"
  end

  # mix.exs as what it holds, in no order.
  defp mix(content) do
    read = MixFile.read(content)

    code = fn list ->
      list |> Enum.map(fn {k, v} -> {k, Macro.to_string(v)} end) |> Enum.sort()
    end

    %{project: code.(read.project), deps: code.(read.deps), aliases: code.(read.aliases)}
  end

  defp patterns(content), do: content |> String.split("\n", trim: true) |> Enum.sort()
end

# `:exhaustive` walks every order the base cartridges can go in (grown_vs_born_test):
# minutes on every core, so by name only — `mix test --only exhaustive`.
ExUnit.start(exclude: [:exhaustive])
