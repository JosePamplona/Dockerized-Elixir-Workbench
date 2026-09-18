defmodule Mix.Tasks.Workbench.Install.Enhancements do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Enhancements

  @shortdoc "Adds the workbench base enhancements (helper, schema, tasks, tests)"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the module-creating part of the workbench
  `implement_enhancements` feature (the dependency-only part lives in
  the trivial dep-only cartridges — fellow chiefs_setup picks):

  * Ecto group (unless `--no-ecto`): `MyApp.Helper` and `MyApp.Schema`
    (with `ecto_enum` and `html_entities` deps), the `mix db` task, and
    the DbSchema diagram sources under `assets/db_schema/`
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
  def igniter(igniter), do: Enhancements.install(igniter)
end
