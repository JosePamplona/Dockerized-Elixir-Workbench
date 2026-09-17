defmodule Mix.Tasks.Workbench.Install.Auth0 do
  use WorkbenchIgniter.Task

  alias WorkbenchIgniter.Features.Auth0

  @shortdoc "Adds Auth0 JWT authentication with an Accounts context to the project"

  @moduledoc """
  #{@shortdoc}

  Igniter port of the workbench Auth0 feature. In app.sh this spanned three
  stages (`implement_auth0`, a `mix phx.gen.context` run inside the
  container, and `refine_auth0`); here the final state is generated
  directly:

  * adds `{:auth0_jwks, "~> 0.3"}` and starts `Auth0Jwks.Strategy` in the
    supervision tree
  * config: `:auth0_jwks` JSON library, and the `AUTH0_*` environment
    block in `runtime.exs` (including the ExDoc `auth_config.js` writer)
  * creates `MyApp.Accounts` (`user_from_claim/2`), the `Accounts.User`
    schema (StatusEnum + EctoURI), its migration, `MyApp.EctoURI` and the
    `MyAppWeb.Plugs.Token` plug
  * router: `:auth` pipeline (token validation + user loading); with
    `--interface rest` the `/api/v1` scope is switched to
    `[:api, :auth]` and gets the `GET /user` endpoint with its
    controller, JSON view and OpenAPI schema
  * plants the unit tests and `AccountsFixtures`

  Requires the enhancements feature (`MyApp.Schema`): the installer
  refuses, naming it, until it is in the project.

  ## Example

      mix workbench.install.auth0 --project-name "Lorem Ipsum"

  ## Options

  #{WorkbenchIgniter.Feature.options_doc(Auth0)}
  """

  @impl Igniter.Mix.Task
  def info(argv, composing_task), do: Auth0.info(argv, composing_task)

  @impl Igniter.Mix.Task
  def igniter(igniter), do: Auth0.install(igniter)
end
