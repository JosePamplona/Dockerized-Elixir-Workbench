defmodule LoremIpsumWeb.ExDocControllerTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase, async: true

  # ExDoc Documentation
  describe "[HTML] /dev/docs" do
    test "return 200 with project documentation HTML index page",
      %{conn: conn}
    do
      response =
        conn
        |> get(~p"/dev/docs")
        |> response(200)

      # Check response
      assert response =~ "<title>Lorem Ipsum v0.0.0 — Documentation"
    end

    test "return 200 with project documentation specific HTML page",
      %{conn: conn}
    do
      response =
        conn
        |> get(~p"/dev/docs/index.html")
        |> response(200)

      # Check response
      assert response =~ "<title>Lorem Ipsum v0.0.0 — Documentation"
    end
    
    test "return 200 with coverage report HTML page", %{conn: conn} do
      response =
        conn
        |> get(~p"/dev/docs/cover")
        |> response(200)

      # Check response
      assert response =~ "<title>Coverage"
    end

    test "return 404 with not-found HTML page", %{conn: conn} do
      response =
        conn
        |> get(~p"/dev/docs/non-existing")
        |> response(404)

      # Check response
      assert response =~ "<title>404 — Lorem Ipsum v0.0.0"
    end
  end
end
