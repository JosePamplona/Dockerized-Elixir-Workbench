defmodule LoremIpsumWeb.TelemetryTest do
  @moduledoc false

  use LoremIpsumWeb.ConnCase, async: true

  alias LoremIpsumWeb.Telemetry
  
  # Telemetry
  describe "metrics/0" do
    test "return Telemetry metrics" do
      result = Telemetry.metrics()

      # Check return
      assert is_list(result)
    end
  end
end
