defmodule Mix.Tasks.Workbench.Install.Guidelines do
  use Igniter.Mix.Task

  alias WorkbenchIgniter.Features.Guidelines

  @shortdoc "Adds the team's coding conventions to the project's docs"

  @moduledoc """
  #{@shortdoc}

  Downloads the markdown at `--url` as `assets/exdoc/coding.md` and
  lists it in the ExDoc site, under *Support*.

  It builds on exdoc, which owns the site and the `docs:` block this
  appends to: the installer refuses, naming it, until exdoc is in.

  This is the one installer that reaches the network. When the download
  fails it plants a placeholder naming the URL and warns, so `mix docs`
  keeps building; re-running it is a no-op once the page exists.

  ## Example

      #{Guidelines.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Guidelines)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Guidelines.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Guidelines.install(igniter)
end
