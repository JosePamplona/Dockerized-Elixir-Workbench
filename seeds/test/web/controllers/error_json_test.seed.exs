defmodule %{elixir_module}Web.ErrorJSONTest do
  @moduledoc false

  use %{elixir_module}Web.ConnCase, async: true

  alias %{elixir_module}Web.ErrorJSON

  # ErrorJSON view
  describe "render/3" do
    test "renders 404" do
      assert ErrorJSON.render("404.json", %{}) == %{error: "Not Found"}
    end

    test "renders 500" do
      assert \
        ErrorJSON.render("500.json", %{}) == %{error: "Internal Server Error"}
    end
  end
end
