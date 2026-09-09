defmodule ConsoleWeb.CartridgesTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.Cartridges

  # A status with two cartridges in: ash with --with ash_oban, and rest.
  @status %{
    "project" => %{
      "cartridges" => [
        %{"name" => "ash", "installed" => true, "state" => %{"with" => ["ash_oban"]}},
        %{"name" => "rest", "installed" => true},
        %{"name" => "graphql", "installed" => false}
      ]
    }
  }
  @ash %{"name" => "ash", "state" => %{"with" => ["ash_oban"]}}

  describe "holds?/3" do
    test "an item without a when holds" do
      assert Cartridges.holds?(@status, @ash, %{"path" => "/oban"})
    end

    test "a with condition reads the cartridge's own options" do
      assert Cartridges.holds?(@status, @ash, %{"when" => %{"with" => "ash_oban"}})
      refute Cartridges.holds?(@status, @ash, %{"when" => %{"with" => "ash_cloak"}})
    end

    test "a cartridge condition asks whether that one is in" do
      assert Cartridges.holds?(@status, @ash, %{"when" => %{"cartridge" => "rest"}})
      refute Cartridges.holds?(@status, @ash, %{"when" => %{"cartridge" => "graphql"}})
    end
  end

  test "container_reading/1: exited with 0 is an absence, exited otherwise says its code" do
    assert Cartridges.container_reading(%{"State" => "running", "Health" => "healthy"}) ==
             {"healthy", "good"}

    assert Cartridges.container_reading(%{"State" => "running", "Health" => ""}) ==
             {"running", "good"}

    assert Cartridges.container_reading(%{"State" => "running", "Health" => "starting"}) ==
             {"starting", "warn busy"}

    assert Cartridges.container_reading(%{"State" => "exited", "Health" => "", "ExitCode" => 0}) ==
             {"exited", "off"}

    assert Cartridges.container_reading(%{"State" => "exited", "Health" => "", "ExitCode" => 137}) ==
             {"exited 137", "bad"}

    assert Cartridges.container_reading(%{"State" => "dead"}) == {"dead", "bad"}
  end
end
