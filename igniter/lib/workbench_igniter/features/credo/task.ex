defmodule Mix.Tasks.Workbench.Install.Credo do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Credo
  alias WorkbenchIgniter.Features.Precommit

  @shortdoc "Adds Credo static code analysis to the project"

  @moduledoc """
  #{@shortdoc}

  Adds `#{inspect(Credo.dep())}` to the project deps: a reviewer that
  never gets tired of the same remarks, run with `mix credo`.

  `--githook` also puts `#{Credo.check_command()}` before every commit.
  The hook, the way it reaches `mix` inside the container and the
  checks that come with Elixir are the **precommit** cartridge's, which
  this one inserts when asked; what Credo adds to them is a block of
  `#{Precommit.hook()}` belonging to this cartridge alone, so ejecting
  either box leaves the other's checks standing.

  The line is `#{Credo.check_command()}` and not `mix credo --strict`:
  a hook that refuses the first commit after it is inserted is a hook
  nobody keeps. `--strict` is one word away, in a file the project owns.

  ## Example

      #{Credo.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Credo)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Credo.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Credo.install(igniter)
end
