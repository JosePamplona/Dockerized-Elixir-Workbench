defmodule %{elixir_module}Web.TelemetryTest do
  @moduledoc false

  use %{elixir_module}Web.ConnCase, async: true

  alias %{elixir_module}Web.Telemetry
  
  # Telemetry
  describe "metrics/0" do
    test "return Telemetry metrics" do
      result = Telemetry.metrics()

      # Check return
      assert is_list(result)
    end
  end
end
