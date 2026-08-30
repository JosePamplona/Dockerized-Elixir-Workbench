defmodule WorkbenchIgniter.Features.Tailwind do
  @moduledoc """
  Tailwind — the dependency, heroicons, its configuration, the watcher and the assets aliases — for a project generated with `--no-tailwind`.

  A base cartridge: it names the `phx.new` flag and the mark, and
  `WorkbenchIgniter.PhxDelta` brings in whatever `phx.new` generates for
  it at the installer's version, merged onto the project's files.

  Re-running is a no-op.
  """
  use WorkbenchIgniter.Feature

  @impl true
  def task, do: "workbench.install.tailwind"

  @doc "Task metadata, exposed unchanged through the mix task shell."
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{group: :workbench_igniter, example: "mix " <> task()}
  end

  # The mark: the first thing --no-tailwind leaves out.
  @impl true
  def installed?(igniter), do: dep_installed?(igniter, :tailwind)

  @doc "Installer body, run by the mix task shell as its `igniter/1`."
  def install(igniter) do
    {facts, igniter} = WorkbenchIgniter.PhxDelta.facts(igniter)
    igniter = WorkbenchIgniter.PhxDelta.insert(igniter, __MODULE__, :tailwind)

    # phx.new's app.css imports phoenix-colocated/<app>/colocated.css,
    # a directory LiveView's compiler writes — and that compiler comes
    # with html. The insert is exact either way; the build is not.
    if facts.tailwind or facts.html or igniter.issues != [] do
      igniter
    else
      Igniter.add_notice(
        igniter,
        "tailwind is in, and its app.css imports phoenix-colocated, which LiveView's compiler " <>
          "writes: mix assets.build fails until html is in (./wb.sh add html)."
      )
    end
  end
end
