defmodule %{elixir_module}Web.UserController do
  @moduledoc """
    User Operations controller.
    """

  use %{elixir_module}Web, :controller
  use OpenApiSpex.ControllerSpecs

  alias %{elixir_module}Web.UserJSON

  tags ["User Operations"]

  operation :get,
    summary: "Get user from current session.",
    description: """
      Retrieves the user associated to the 'sub' claim of the session token in the authorization header of the request.
      """,
    security: Requests.security(),
    produces: "application/json",
    responses: [
      Responses.build(
        200,
        "Success retrieval of current session user data.",
        Responses.view(:standard, Schemas.User)
      ),
      Responses.build(401),
      Responses.build(403)
    ]

  @doc """
    Gets user from current session.

    Retrieves user relataed to authorization token `sub` claim.
    """

  @spec get(
      conn :: Plug.Conn.t,
      params :: %{optional(binary) => any}
    ) :: Plug.Conn.t

  def get(%{assigns: %{current_user: user}} = conn, _params) do
    conn
    |> put_status(200)
    |> put_view(json: UserJSON)
    |> render(:show, user: user)
  end
end
