defmodule WorkbenchIgniter.Features.ExdebugTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.exdebug" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.exdebug", [])
      |> assert_has_patch("mix.exs", """
      + | {:ex_debug, "~> 1.0"}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.exdebug", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.exdebug", [])
      |> assert_unchanged()
    end
  end
end
