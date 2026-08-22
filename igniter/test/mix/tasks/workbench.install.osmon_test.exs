defmodule Mix.Tasks.Workbench.Install.OsmonTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  describe "mix workbench.install.osmon" do
    test "adds :os_mon to extra_applications" do
      test_project()
      |> Igniter.compose_task("workbench.install.osmon", [])
      |> assert_has_patch("mix.exs", """
      - | extra_applications: [:logger]
      + | extra_applications: [:logger, :os_mon]
      """)
    end

    test "is a no-op when :os_mon is already enabled" do
      test_project()
      |> Igniter.compose_task("workbench.install.osmon", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.osmon", [])
      |> assert_unchanged()
    end
  end
end
