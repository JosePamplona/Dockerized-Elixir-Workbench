defmodule WorkbenchIgniter.Features.AnsiTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Ansi

  describe "mix workbench.install.ansi" do
    test "turns ANSI on in config.exs" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.ansi", [])
      |> assert_has_patch("config/config.exs", """
      + |config :elixir, ansi_enabled: true
      """)
    end

    test "is a no-op when the key is already configured" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.ansi", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.ansi", [])
      |> assert_unchanged()
    end
  end

  describe "the mark" do
    test "is the configuration key itself" do
      assert {false, _} = Ansi.installed?(phx_test_project())

      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.ansi", [])
        |> apply_igniter!()

      assert {true, _} = Ansi.installed?(installed)
    end
  end
end
