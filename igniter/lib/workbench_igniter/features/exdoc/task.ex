defmodule Mix.Tasks.Workbench.Install.Exdoc do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Exdoc

  @shortdoc "Adds ExDoc documentation served at /dev/docs to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_exdoc` feature:

  * adds `{:ex_doc, "~> 0.38", only: :dev, runtime: false}` to the deps
  * configures `name`, `source_url` and the full `docs` section in
    `mix.exs` (assets, extras, groups and regex-based module groups),
    plus the `before_closing_*_tag` helper functions
  * creates `MyAppWeb.ExDocController` (index / coverage / 404 fallback)
    with its unit tests
  * router: `:exdoc` pipeline (`Plug.Static` over the standard `doc/`
    output dir, already gitignored by phx.new) and dev routes under
    `/dev/docs`
  * plants the documentation assets under `assets/exdoc/`: logo, theme
    JS, and the conditional pages (token, database placeholder), plus
    the root `COVERAGE.md` and `TESTING.md` placeholders for `mix cover`
  * seeds dummy pages in `doc/` so the test suite passes before the first
    `mix docs` run

  ## Example

      mix workbench.install.exdoc --project-name "Lorem Ipsum" --coverage

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Exdoc)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdoc.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exdoc.install(igniter)
end
