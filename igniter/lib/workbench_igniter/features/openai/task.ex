defmodule Mix.Tasks.Workbench.Install.Openai do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Openai

  @shortdoc "Adds an OpenAI assistant with conversations to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench OpenAI feature. Like auth0, in app.sh this
  spanned three stages (`implement_openai`, `mix phx.gen.context` for the
  Assistant context inside the container, and `refine_openai`); here the
  final state is generated directly:

  * creates the `MyApp.Assistant` context, the `Conversation` and
    `Message` schemas with their migrations
  * conversations call the OpenAI chat completions API through the
    application's Finch pool — the dep and the `{Finch, name: MyApp.Finch}`
    child are ensured (projects created with `--no-mailer` lack them)
  * config: the `AI_ASSISTANT_*` environment block in `runtime.exs`
  * with `--interface rest`: the conversation controller, JSON view and
    OpenAPI schemas, plus the five `/conversation` routes in `/api/v1`
  * plants the unit tests and `AssistantFixtures`

  Requires the auth0 feature (conversations belong to users): the
  installer refuses, naming it, until it is in the project.

  ## Example

      mix workbench.install.openai --project-name "Lorem Ipsum"

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Openai)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Openai.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Openai.install(igniter)
end
