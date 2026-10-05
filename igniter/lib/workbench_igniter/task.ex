defmodule WorkbenchIgniter.Task do
  @moduledoc """
  What every installer's Mix task is: Igniter's, and one thing more —
  an issue ends the task with a failure.

  Igniter shows the issues, writes nothing, and returns `:issues` from
  `Igniter.do_or_dry_run/2`; the task then exits with zero, as any Mix
  task that returned does. `wb.sh add` reads that zero as an insert
  that landed and commits what is on disk — which, on 2026-09-16, was
  `Insert esbuild` holding nothing but `.gitignore.phx-new`, the aside
  the conflict had left for the reader. Here `run/1` is Igniter's and
  ends in `exit({:shutdown, 1})` on `:issues`, so `add` undoes the
  half-insert and refuses the commit, as it does for any failure.
  """

  defmacro __using__(opts) do
    quote do
      use Igniter.Mix.Task, unquote(opts)

      def run(argv) do
        case super(argv) do
          :issues -> exit({:shutdown, 1})
          other -> other
        end
      end
    end
  end
end
