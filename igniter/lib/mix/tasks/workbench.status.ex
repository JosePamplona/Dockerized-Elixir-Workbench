defmodule Mix.Tasks.Workbench.Status do
  use Mix.Task

  @shortdoc "Says which workbench cartridges this project carries"

  @moduledoc """
  #{@shortdoc}

      mix workbench.status [--json]

  The catalog (`mix workbench.catalog`) with one more fact per cartridge:
  whether *this* project has it installed. Each cartridge answers for
  itself (`installed?/1`), off the same mark its installer's guard reads
  — the module, file or dependency whose presence makes a re-run a
  no-op — so what this prints and what `mix workbench.install.*` would
  skip are one and the same. It reads the project's source through
  Igniter; nothing is compiled or written.

  ## Options

  * `--json` - One JSON object, `{"app": ..., "phx": {...}, "cartridges": [...]}`
    — `phx` is the project's shape in phx.new's terms: each capability,
    the database, the adapter, and the flags that would generate it today.
  """

  alias WorkbenchIgniter.Features

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [json: :boolean])

    # A plain task, on purpose: Igniter's own would compile the project
    # first, and nothing here needs it — only the rewrite application
    # that reads the source.
    Application.ensure_all_started(:rewrite)

    app = Mix.Project.config()[:app]
    {cartridges, igniter} = Features.status(Igniter.new())
    # The project's shape in phx.new's terms — the flags that would
    # generate it today, read off it (what the base cartridges read).
    {facts, _igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    phx = %{facts | module: inspect(facts.module)} |> Map.put(:flags, WorkbenchIgniter.PhxDelta.flags(facts))

    if opts[:json] do
      IO.puts(Jason.encode!(%{app: app, phx: phx, cartridges: cartridges}, pretty: true))
    else
      {installed, missing} = Enum.split_with(cartridges, & &1.installed)

      IO.puts("Cartridges of #{app}: #{length(installed)} installed, #{length(missing)} not.")
      IO.puts("As phx.new would generate it today: mix phx.new . #{Enum.join(phx.flags, " ")}\n")

      for {title, list} <- [{"Installed", installed}, {"Not installed", missing}],
          list != [] do
        IO.puts(title <> "\n" <> indent(Mix.Tasks.Workbench.Catalog.table(list)) <> "\n")
      end
    end
  end

  defp indent(text), do: text |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))
end
