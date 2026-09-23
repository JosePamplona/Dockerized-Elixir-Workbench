defmodule Mix.Tasks.Workbench.Install.Exdoc do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Exdoc

  @shortdoc "Adds the ExDoc documentation site to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdoc` feature:

  * adds `{:ex_doc, "~> 0.38", only: :dev, runtime: false}` to the deps
  * configures `name`, `source_url` and the full `docs` section in
    `mix.exs` (assets, extras, groups and regex-based module groups),
    plus the `before_closing_*_tag` helper functions
  * plants the site's sources under `guides/` — outside `assets/`, the
    release build's input: its config, the logo, the theme JS and the
    database placeholder, plus the root `TESTING.md` placeholder for
    `mix cover` with `--coverage`

  `mix docs` writes the site to the standard `doc/` output dir, already
  gitignored by phx.new, and the console serves it from there: the
  project carries no route or controller for it.

  ## Example

      mix workbench.install.exdoc --project-name "Lorem Ipsum" --coverage

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Exdoc)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdoc.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Exdoc, igniter)
end
