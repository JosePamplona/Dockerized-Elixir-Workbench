defmodule Mix.Tasks.Workbench.Install.MishkaChelekom do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.MishkaChelekom

  @shortdoc "Generates Mishka Chelekom's components into the project, all of them or the ones chosen"

  @moduledoc """
  #{@shortdoc}

  Adds `#{inspect(MishkaChelekom.dep())}` to the project deps and queues
  the library's own task, to run once this patch set is applied and the
  dependency fetched:

      mix mishka.ui.gen.components --import --helpers --global --yes

  The library writes the components into `lib/<app>_web/components/`,
  where they are the project's to edit, with the `MishkaComponents`
  macro that imports them in place of `CoreComponents`, its stylesheet
  and `@theme` in `assets/`, and its hooks in `app.js`. What it writes
  shows up in that command's output, not in this task's diff.

  ## Example

      #{MishkaChelekom.info([], nil).example}

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(MishkaChelekom)}

  ## Requirements

  The library's generator needs the network (Hex). The components are
  LiveView function components on Tailwind 4, and their hooks go into
  `assets/js/app.js`: html with live, tailwind and esbuild have to be
  in.
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: MishkaChelekom.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(MishkaChelekom, igniter)
end
