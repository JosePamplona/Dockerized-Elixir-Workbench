defmodule WorkbenchIgniter.Features.ExmachinaTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.exmachina" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.exmachina", [])
      |> assert_has_patch("mix.exs", """
      + | {:ex_machina, "~> 2.8", only: :test}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.exmachina", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.exmachina", [])
      |> assert_unchanged()
    end
  end
end
