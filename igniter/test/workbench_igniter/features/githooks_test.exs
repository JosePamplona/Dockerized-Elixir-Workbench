defmodule WorkbenchIgniter.Features.GithooksTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.githooks" do
    test "adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task("workbench.install.githooks", [])
      |> assert_has_patch("mix.exs", """
      + | {:git_hooks, "~> 0.7", only: :dev, runtime: false}
      """)
    end

    test "is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task("workbench.install.githooks", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.githooks", [])
      |> assert_unchanged()
    end
  end
end
