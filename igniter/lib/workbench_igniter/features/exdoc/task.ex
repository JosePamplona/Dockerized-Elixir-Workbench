defmodule Mix.Tasks.Workbench.Install.Exdoc do
  use Igniter.Mix.Task

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
    JS, and the conditional pages (token, coding guidelines, database
    placeholder), plus the root `COVERAGE.md` and `TESTING.md`
    placeholders for `mix cover`
  * seeds dummy pages in `doc/` so the test suite passes before the first
    `mix docs` run

  ## Example

      mix workbench.install.exdoc --project-name "Lorem Ipsum" --coveralls

  ## Options

  * `--project-name` - Display name (default: capitalized app name).
  * `--repo-url` - Repository URL for `source_url`/`authors`.
  * `--guidelines-url` - URL of a coding guidelines markdown to download
    as the "Coding guidelines" page. Optional.
  * `--coveralls` - The project uses the coveralls feature (adds the
    coverage assets, page and controller action).
  * `--auth0`, `--openai`, `--stripe` - Feature flags (auth0 adds the
    token page and scripts).
  * `--no-ecto` - Project created without Ecto (skips the database page
    and diagram).
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdoc.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exdoc.install(igniter)
end
