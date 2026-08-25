defmodule WorkbenchIgniter.Features.CredoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.credo" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> assert_has_patch("mix.exs", """
      + | {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.credo", [])
      |> assert_unchanged()
    end
  end
end
