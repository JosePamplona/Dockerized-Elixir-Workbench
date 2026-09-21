defmodule Mix.Tasks.Workbench.Install.Coverage do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Coverage
  alias WorkbenchIgniter.Features.Precommit

  @shortdoc "Adds test coverage reports to the project, measured by ExCoveralls"

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
    `test/coverage/template/`
  * with `--exdoc`, plants the `mix cover` task (testing & coverage reports
    integrated into ExDoc) along with its ExUnit formatter and unit tests,
    and gitignores the generated `TESTING.md` report
  * with `--githook`, puts `#{Coverage.check_command()}` before every
    commit — in this cartridge's own block of `#{Precommit.hook()}`,
    below the divider that separates the checks that refuse a commit in
    a second from the ones that compile the project. The hook itself,
    the way it reaches `mix` inside the container and the checks that
    come with Elixir are the **precommit** cartridge's, which has to be
    in first — the option refuses otherwise; ejecting coverage leaves
    the rest of the hook standing

  ## Example

      mix workbench.install.coverage --exdoc

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Coverage)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Coverage.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Coverage.install(igniter)
end
