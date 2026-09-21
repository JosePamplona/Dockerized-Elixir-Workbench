defmodule Mix.Tasks.Workbench.Install.TestData do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.TestData

  @shortdoc "Adds test factories and Faker, shaped by the project's line"

  @moduledoc """
  #{@shortdoc}

  On a project with Ecto and no Ash: `ex_machina` and `faker`, the
  factory module in `test/support/factory.ex` with its rules in its
  documentation, and the test that inserts every factory. On an Ash
  project: `faker` and an `Ash.Generator` module in
  `test/support/generator.ex`, whose generators run the actions. Both
  libraries' test-helper lines go in this cartridge's block of
  `test/test_helper.exs`.

  A project with neither is refused, naming ecto. A second run adds
  whatever piece is missing and leaves the rest as it finds it.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: TestData.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: TestData.install(igniter)
end
