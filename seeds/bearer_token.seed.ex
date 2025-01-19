
defmodule %{elixir_module}Web.Plugs.BearerToken do
  @moduledoc """
  The plug is used in conjunction with the `Auth0Jwks.Plug.ValidateToken` and 
  `Auth0Jwks.Plug.GetUser` plugs for API calls. It validates the 
  connection's assigns resulting through the previous plugs:

  - If validation doesn't succeed, the connection is halted, and specific 
  errors are sent.
  <!-- workbench-graphql open -->
  - If validation succeeds, the connection assigns data is passed to the 
  Absinthe plug as context.
  <!-- workbench-graphql close -->
  <!-- workbench-rest open -->
  - If validation succeeds, the connection assigns data is kept. The connection is validated.
  <!-- workbench-rest close -->

  ## Authentication errors
  
  | Code | Message | Description |
  | :-: | :-- | :-- |
  | 401 | "unauthorized" | The given token is missing, invalid or expired. |
  | 403 | "forbidden" | The given token is valid and user claim `email_verified == false`. |
  | 500 | "auth service request failed" | Request to Auth0 tenant failed (`Auth0Jwks.UserInfo.from_token/1`). |
  """

  @behaviour Plug
  import Plug.Conn

  @doc "Initial passthorugh"
  @spec init(opts :: Keyword.t) :: opts :: Keyword.t
  def init(opts), do: opts

  @doc "Performs verification on each request call to the API."
  @spec call(conn :: Plug.Conn.t, opts :: Keyword.t) :: conn :: Plug.Conn.t
  #<!-- workbench-rest open -->
  def call(%{assigns: _context} = conn, _) do
  #<!-- workbench-rest close -->
  #<!-- workbench-graphql open -->
  def call(%{assigns: context} = conn, _) do
  #<!-- workbench-graphql close -->
    ExDebug.console(conn)
    #<!-- workbench-rest open -->
    {unauthorized, unverified} = extract_context_data(conn)
    #<!-- workbench-rest close -->
    #<!-- workbench-graphql open -->
    {accept, unauthorized, unverified} = extract_context_data(conn)
    #<!-- workbench-graphql close -->
    dev_routes = Application.get_env(:%{elixir_project_name}, :dev_routes)

    cond do
      #<!-- workbench-graphql open -->
      # If the enviroment is dev or test, no authentication is required in order
      # to serve the Graphiql IDE or the introspection query.
      dev_routes && ("text/html" in accept || introspection?(conn)) -> conn

      #<!-- workbench-graphql close -->
      # The Accounts.user_from_claim/2 function have returned an error.
      token_authentication_failed?(conn) -> halt_auth_error(conn, dev_routes)

      # One or both previous Auth0 plugs in the pipeline have failed.
      unauthorized -> halt(conn, 401, "unauthorized")

      # If the user hasn't verified the email
      unverified -> halt(conn, 403, "forbidden")

      #<!-- workbench-rest open -->
      true -> conn
      #<!-- workbench-rest close -->
      #<!-- workbench-graphql open -->
      true -> Absinthe.Plug.put_options(conn, context: context) 
      #<!-- workbench-graphql close -->
    end
  end

# === Private ==================================================================

  #<!-- workbench-rest open -->
  defp extract_context_data(%{assigns: context} = _conn) do
  #<!-- workbench-rest close -->
  #<!-- workbench-graphql open -->
  defp extract_context_data(%{assigns: context} = conn) do
    # Get the accept headers of the request
    accept = retrieve_accept_header(conn)
  #<!-- workbench-graphql close -->
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

    #<!-- workbench-rest open -->
    {unauthorized, unverified}
    #<!-- workbench-rest close -->
    #<!-- workbench-graphql open -->
    {accept, unauthorized, unverified}
    #<!-- workbench-graphql close -->
  end

  #<!-- workbench-graphql open -->
  defp retrieve_accept_header(conn) do
    conn
    |> get_req_header("accept")
    |> case do
      []     -> []
      accept -> accept |> Enum.at(0) |> String.split(",")
    end
  end

  defp introspection?(conn) do
    match?(%{params: %{"query" => "\n  query IntrospectionQuery" <> _}}, conn)
  end
  #<!-- workbench-graphql close -->

  defp token_authentication_failed?(%{assigns: context} = _conn) do
    match?({:error, _error}, context[:current_user])
  end

  defp halt_auth_error(%{assigns: context} = conn, dev_routes) do
    {:error, error} = context.current_user
    
    # If the enviroment is a development route, gives extra error details. 
    case dev_routes do
      false ->
        halt(conn, error.code, error.message)

      true ->
        halt(conn, error.code, %{message: error.message, detail: error.detail})
    end
  end

  defp halt(conn, code, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(code, error(message))
    |> halt()
  end

  defp error(message), do: Jason.encode!(%{message: message})
end
