defmodule %{elixir_module}Web.TokenTest do
  @moduledoc false

  use %{elixir_module}Web.ConnCase, async: true

  import %{elixir_module}.Fixtures

  alias %{elixir_module}Web.Plugs.Token

  setup [:sessions]

  # Plug used to set claims_to_user/2 on conn assigns
  describe "call/2" do
    test "success", %{
      conn: conn,
      sessions: %{valid: %{user: session_user}}
    } do
      conn =
        %{conn | assigns: %{
          auth0_access_token: "token",
          auth0_claims: %{},
          current_user: session_user
        }}

      # Check return
      assert %Plug.Conn{} = result_conn = Token.call(conn, [])
      # Check if there is no errors assigned to the connection
      assert result_conn.state == :unset
      assert is_nil(result_conn.status)
    end

    test "return 401: unauthorized request", %{conn: conn} do
      # Check return
      assert %Plug.Conn{} = result_conn = Token.call(conn, [])
      # Check if there is no errors assigned to the connection
      assert result_conn.state == :sent
      assert result_conn.status == 401
    end

    test "return 403: unverified session user email", %{
      conn: conn,
      sessions: %{unverified_email: %{user: session_user}}
    } do
      conn =
        %{conn | assigns: %{
          auth0_access_token: "token",
          auth0_claims: %{},
          current_user: session_user
        }}

      # Check return
      assert %Plug.Conn{} = result_conn = Token.call(conn, [])
      # Check if there is no errors assigned to the connection
      assert result_conn.state == :sent
      assert result_conn.status == 403
    end

    test "return 500: auth service request failed", %{conn: conn} do
      conn =
        %{conn | assigns: %{
          auth0_access_token: "token",
          auth0_claims: %{},
          current_user: {:error, %{code: 500}}
        }}

      # Check return
      assert %Plug.Conn{} = result_conn = Token.call(conn, [])
      # Check if there is no errors assigned to the connection
      assert result_conn.state == :sent
      assert result_conn.status == 500
    end
  end
end
