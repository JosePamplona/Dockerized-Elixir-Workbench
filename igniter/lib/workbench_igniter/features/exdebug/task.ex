defmodule Mix.Tasks.Workbench.Install.Exdebug do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Exdebug

  @shortdoc "Installs ExDebug: a framed look at what passes through a pipeline, printed in :dev and :test only"

  @moduledoc """
  #{@shortdoc}

  `ExDebug.console/2` goes anywhere in a pipeline, prints the value
  passing at that point — your label and the time in the header, the
  term pretty-printed in colour, the application and its version in the
  footer — and returns that value untouched.

  Unlike `IO.inspect/2` and `dbg/1`, which print wherever they run, it
  prints in `:dev` and `:test` only: in any other environment the call
  passes the value straight through, so a probe can be left in the code
  instead of written, read and deleted. The dependency is therefore
  installed for every environment — the guard is inside the function,
  not at the call site.

  The cartridge adds `#{inspect(Exdebug.dep())}` and nothing else: the
  library's formatting options all have defaults of their own and are
  accepted per call. Idempotent — re-running it is a no-op.

  ## Example

      #{Exdebug.info([], nil).example}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Exdebug.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Exdebug.install(igniter)
end
