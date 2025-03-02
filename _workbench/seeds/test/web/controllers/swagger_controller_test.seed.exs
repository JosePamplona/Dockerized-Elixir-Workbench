defmodule %{elixir_module}Web.SwaggerControllerTest do
  @moduledoc false

  use %{elixir_module}Web.ConnCase, async: true

  # Swagger UI documentation
  describe "[HTML] /dev/swagger" do
    test "return 200 with Swagger API-REST documentation HTML", %{conn: conn} do
      response =
        conn
        |> get(~p"/dev/swagger")
        |> response(200)

      # Check response
      assert response =~ "<title>Swagger UI</title>"
    end
  end
end
