defmodule Mix.Tasks.Workbench.Install.TestDoubles do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.TestDoubles

  @shortdoc "Installs the test double libraries: Mimic, Mox, or both"

  @moduledoc """
  #{@shortdoc}

  A test double is whatever stands in for the real thing while a test
  runs — the term is Gerard Meszaros', and it covers the stub that
  gives a canned answer, the spy that also records the call, and the
  mock that fails when the call it expected never came. Elixir has two
  maintained libraries for them, and which one you want depends on
  **whose module is being replaced**:

  * `--double mimic` (the default) copies a module out of the way and
    answers in its place. Any module: `File`, `System`, an HTTP client,
    a repo made to raise. It asks nothing of the code under test.
  * `--double mox` never replaces anything. It builds a new module
    against a behaviour you declare, and the code has to ask its
    configuration whom to call — which is the point: the boundary
    becomes explicit.

  Both, comma-separated, is a normal answer: Mox for the service the
  project owns a contract with, Mimic for everything it did not write.
  A second run adds the other.

  `--type-check` validates the doubles against the typespecs at run
  time. It is Hammox in place of Mox (Hammox wraps it), and
  `type_check: true` on every Mimic copy.

  ## Example

      #{TestDoubles.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(TestDoubles)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: TestDoubles.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(TestDoubles, igniter)
end
