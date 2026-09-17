defmodule Mix.Tasks.Workbench.Install.Coveralls do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Coveralls

  @shortdoc "Adds ExCoveralls test coverage reports to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench `implement_coveralls` feature:

  * adds `{:excoveralls, "~> 0.18", only: :test}` to the project deps
  * configures `test_coverage: [tool: ExCoveralls]` and the coveralls
    `preferred_envs` in `mix.exs`
  * creates `coveralls.json`: reports go to the standard `cover/` output
    dir (already gitignored by phx.new), with the custom template, minimum
    coverage and skip list
  * plants the chosen excoveralls HTML report theme (`--theme`) under
    `assets/cover/template/`
  * with `--exdoc`, plants the `mix cover` task (testing & coverage reports
    integrated into ExDoc) along with its ExUnit formatter and unit tests,
    and gitignores the generated `TESTING.md` report

  ## Example

      mix workbench.install.coveralls --exdoc

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Coveralls)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Coveralls.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Coveralls.install(igniter)
end
