defmodule %{elixir_module}.ApplicationTest do
  @moduledoc false

  use %{elixir_module}Web.ConnCase, async: true

  alias %{elixir_module}.Application
  
  describe "config_change/2" do
    test "calls with the correct arguments" do
      result = Application.config_change(
        %{some_key: "some_value"},
        %{},
        [:some_removed_key]
      )

      # Check return
      assert result == :ok
    end
  end
end
