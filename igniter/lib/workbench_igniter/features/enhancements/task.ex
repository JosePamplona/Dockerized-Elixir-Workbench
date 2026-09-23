defmodule Mix.Tasks.Workbench.Install.Enhancements do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Enhancements

  @shortdoc "Adds the workbench base enhancements (helper, schema, tasks, tests)"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the module-creating part of the workbench
  `implement_enhancements` feature (the dependency-only part lives in
  the dep-only cartridges):

  * Ecto group (unless `--no-ecto`): `MyApp.Helper` and `MyApp.Schema`
    (with the `ecto_enum` dep), and the dbschema cartridge composed for
    the database's page and its `mix db` task
  * REST group (`--interface rest`): enhanced `error_json.ex` view with
    changeset rendering, and a Postman collection for the enabled features
  * base unit testing: application/telemetry/page/dashboard/mailbox and
    error view tests, `MyApp.Fixtures`, `MyApp.MockHelper` (imported into
    `ConnCase`)

  ## Example

      mix workbench.install.enhancements --id-type uuid --timestamps naive_datetime_usec

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Enhancements)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Enhancements.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: WorkbenchIgniter.Feature.install(Enhancements, igniter)
end
