defmodule WorkbenchIgniter.Features.VersioningTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Versioning

  describe "mix workbench.install.versioning" do
    test "sets the version in mix.exs" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.versioning", [])
      |> assert_has_patch("mix.exs", """
      - | version: "0.1.0",
      + | version: "0.0.0",
      """)
    end

    test "--version writes the one asked for, into mix.exs and the changelog" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ["--version", "1.2.3"])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      assert files["mix.exs"] =~ ~s|version: "1.2.3"|
      assert files["CHANGELOG.md"] =~ "## v1.2.3 - (#{Date.utc_today()})"
      assert files["CHANGELOG.md"] =~ "## Unreleased"
      assert files["CHANGELOG.md"] =~ "Brand new project created."
    end

    test "is a no-op on a second run, and never moves the version under a written history" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.versioning", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.versioning", ["--version", "9.9.9"])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "keeps its own history"))
    end
  end

  describe "the mark" do
    test "is the changelog, not the version every project already has" do
      assert {false, _} = Versioning.installed?(phx_test_project())

      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", [])
        |> apply_igniter!()

      assert {true, _} = Versioning.installed?(installed)
      assert {%{version: "0.0.0"}, _} = Versioning.state(installed)
    end
  end
end
