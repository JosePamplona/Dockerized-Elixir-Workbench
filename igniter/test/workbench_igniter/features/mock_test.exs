defmodule WorkbenchIgniter.Features.MockTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.mock" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.mock", [])
      |> assert_has_patch("mix.exs", """
      + | {:mock, "~> 0.3", only: :test}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.mock", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.mock", [])
      |> assert_unchanged()
    end
  end
end
