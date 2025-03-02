defmodule LoremIpsumWeb.DashboardControllerTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase, async: true

  # Phoenix LiveDashboard
  describe "[HTML] /dev/dashboard" do
    test "return 302 redirecting to Phoenix LiveDashboard home page", %{
      conn: conn
    } do
      response =
        conn
        |> get(~p"/dev/dashboard")
        |> response(302)

      # Check response
      assert response =~ "/dev/dashboard/home"
    end
  end
end
