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

  describe "--task and --readme-badge" do
    test "neither is in by default" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", [])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      refute files["lib/mix/tasks/version.ex"]
      refute files["README.md"] =~ "img.shields.io/badge/version-"
    end

    test "--task plants the task and its test; --readme-badge the badge under the title" do
      files =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.versioning",
          ~w(--version 1.2.3 --task --readme-badge)
        )
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      assert files["lib/mix/tasks/version.ex"] =~ "defmodule Mix.Tasks.Version do"
      assert files["test/mix/tasks/version_test.exs"] =~ "defmodule Mix.Tasks.VersionTest do"

      assert files["README.md"] =~
               ~r/^# .*\n\n!\[v1\.2\.3\]\(https:\/\/img\.shields\.io\/badge\/version-1\.2\.3-white\.svg\)/m
    end

    test "a second run adds the missing piece at the project's version, and moves nothing" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ~w(--version 1.2.3))
        |> apply_igniter!()
        |> Igniter.compose_task(
          "workbench.install.versioning",
          ~w(--version 9.9.9 --readme-badge)
        )

      assert_has_patch(igniter, "README.md", """
      + | ![v1.2.3](https://img.shields.io/badge/version-1.2.3-white.svg)
      """)

      assert_unchanged(igniter, "mix.exs")
      assert_unchanged(igniter, "CHANGELOG.md")
    end

    test "state reads the two back, nil for the badge without a README" do
      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ~w(--task --readme-badge))
        |> apply_igniter!()

      assert {%{version: "0.0.0", task: true, readme_badge: true}, _} =
               Versioning.state(installed)

      bare =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", [])
        |> apply_igniter!()

      assert {%{task: false, readme_badge: false}, _} = Versioning.state(bare)
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
      assert {%{version: "0.0.0", task: false}, _} = Versioning.state(installed)
    end
  end
end
