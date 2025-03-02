defmodule LoremIpsumWeb.OpenApiControllerTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase, async: true

  # OpenAPI Specification
  describe "[REST] /dev/openapi" do
    test "return 200 with the OpenAPI specification in JSON format",
      %{conn: conn}
    do
      response =
        conn
        |> get(~p"/dev/openapi")
        |> json_response(200)

      # Check response
      assert %{
        "components" => %{
          "schemas" => %{
            # "User" => %{},
            # "Conversation" => %{},
            # "Message" => %{}
          }
        },
        "info" => %{},
        "openapi" => _,
        "paths" => %{
          # "/health" => _,
          # "/api/v1/conversation" => _,
          # "/api/v1/conversation/{id}" => _
        },
        "security" => _,
        "servers" => [%{"url" => _, "variables" => _}],
        "tags" => _
      } = response
    end
  end
end
