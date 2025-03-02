
defmodule LoremIpsumWeb.Plugs.Token do
  @moduledoc """
  The plug is used in conjunction with the `Auth0Jwks.Plug.ValidateToken` and 
  `Auth0Jwks.Plug.GetUser` plugs for API calls. It validates the 
  connection's assigns resulting through the previous plugs:

  - If validation doesn't succeed, the connection is halted, and specific 
  errors are sent.
  - If validation succeeds, the connection assigns data is kept. The connection is validated.

  ## Authentication errors
  
  | Code | Message | Description |
  | :-: | :-- | :-- |
  | 401 | "unauthorized" | The given token is missing, invalid or expired. |
  | 403 | "forbidden" | The given token is valid and user claim `email_verified == false`. |
  | 500 | "auth service request failed" | Request to Auth0 tenant failed (`Auth0Jwks.UserInfo.from_token/1`). |
  """

  @behaviour Plug
  import Plug.Conn
  import Phoenix.Controller

  @doc "Initial passthorugh"
  @spec init(opts :: Keyword.t) :: opts :: Keyword.t
  def init(opts), do: opts

  @doc "Performs verification on each request call to the API."
  @spec call(conn :: Plug.Conn.t, opts :: Keyword.t) :: conn :: Plug.Conn.t
  def call(%{assigns: _context} = conn, _) do
    {unauthorized, unverified} = extract_context_data(conn)

    cond do
      # The Accounts.user_from_claim/2 function have returned an error.
      token_validation_failed?(conn) -> halt_token_error(conn)

      # One or both previous Auth0 plugs in the pipeline have failed.
      unauthorized -> halt(conn, 401)

      # If the user hasn't verified the email
      unverified -> halt(conn, 403)

      true -> conn
    end
  end

# === Private ==================================================================

  defp extract_context_data(%{assigns: context} = _conn) do
    # If these keys are not present in context, means one or both of the 
    # previous Auth0 plugs in the pipeline have failed.
    unauthorized =
      !context[:auth0_access_token] ||
      !context[:auth0_claims] ||
      !context[:current_user]

    # true if the user has verified the email, false otherwise
    unverified = 
      case context[:current_user] do
        %{email_verified: email_verified} -> not email_verified
        _ -> false
      end

    {unauthorized, unverified}
  end


  defp token_validation_failed?(%{assigns: context} = _conn) do
    match?({:error, _error}, context[:current_user])
  end

  defp halt_token_error(%{assigns: context} = conn) do
    {:error, error} = context.current_user
    halt(conn, error.code)
  end

  defp halt(conn, code) do
    conn
    |> put_status(code)
    |> put_view(json: LoremIpsumWeb.ErrorJSON)
    |> render("#{code}.json")
    |> halt()
  end
end
