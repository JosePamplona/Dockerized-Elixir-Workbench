defmodule Mix.Tasks.Workbench.Install.Dbschema do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Dbschema

  @shortdoc "Puts the database's own page in the project's documentation, off a DbSchema export: mix db, the model page and the diagram in both themes"

  @moduledoc """
  #{@shortdoc}

  [DbSchema](https://dbschema.com) is a desktop tool: you open it on the
  project's database and export the model to `assets/db_schema/`. This
  installs what turns that export into something a reader sees — the
  `mix db` task and its test — and runs it once for you, off a sample
  export (`--combo`), so `guides/database.md` and the two model diagrams
  are there from the first build.

  The page names a light and a dark image, each with the URL fragment
  ExDoc reads (`#gh-light-mode-only`, `#gh-dark-mode-only`), so the
  diagram follows the reader's theme with no script in the site. When
  the project has a documentation site, the page is listed in it under
  Support; when it has none, the page is written all the same and
  whoever adds the site later lists it.

  ## Example

      #{Dbschema.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Dbschema)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Dbschema.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Dbschema, igniter)
end
