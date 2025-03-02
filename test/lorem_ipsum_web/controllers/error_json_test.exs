defmodule LoremIpsumWeb.ErrorJSONTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase, async: true

  alias LoremIpsumWeb.ErrorJSON

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
