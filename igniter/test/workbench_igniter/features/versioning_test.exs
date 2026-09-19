defmodule WorkbenchIgniter.Features.VersioningTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Versioning

  @attribute_mix """
  defmodule Test.MixProject do
    use Mix.Project

    @version "2.3.1"

    def project do
      [app: :test, version: @version, deps: []]
    end
  end
  """

  defp today, do: :calendar.local_time() |> elem(0) |> Date.from_erl!()

  defp files(igniter),
    do: igniter |> apply_igniter!() |> Map.get(:assigns) |> Map.get(:test_files)

  describe "mix workbench.install.versioning" do
    test "opens the changelog at the version mix.exs has, and leaves mix.exs alone" do
      igniter = Igniter.compose_task(phx_test_project(), "workbench.install.versioning", [])

      assert_unchanged(igniter, "mix.exs")

      changelog = files(igniter)["CHANGELOG.md"]
      assert changelog =~ "## v0.1.0 - (#{today()})"
      assert changelog =~ "## Unreleased"
      assert changelog =~ "recorded here from this version on"
    end

    test "a project well under way opens at its own version, read through @version" do
      igniter =
        test_project(files: %{"mix.exs" => @attribute_mix})
        |> Igniter.compose_task("workbench.install.versioning", ["--readme-badge"])

      assert_unchanged(igniter, "mix.exs")
      assert files(igniter)["CHANGELOG.md"] =~ "## v2.3.1 - (#{today()})"
      assert files(igniter)["README.md"] =~ "version-2.3.1-lightgrey.svg"
    end

    test "--init-version writes the one asked for, into mix.exs and the changelog" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ["--init-version", "0.0.0"])
        |> files()

      assert files["mix.exs"] =~ ~s|version: "0.0.0"|
      assert files["CHANGELOG.md"] =~ "## v0.0.0 - (#{today()})"
    end

    test "--init-version moves @version, not the key that points at it" do
      files =
        test_project(files: %{"mix.exs" => @attribute_mix})
        |> Igniter.compose_task("workbench.install.versioning", ["--init-version", "3.0.0"])
        |> files()

      assert files["mix.exs"] =~ ~s|@version "3.0.0"|
      assert files["mix.exs"] =~ "version: @version"
    end

    test "a version Mix would not compile is refused" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.versioning", ["--init-version", "1.2"])
      |> assert_has_issue(&(&1 =~ "--init-version 1.2: not a version Mix accepts"))
    end

    test "a version that cannot be read asks for --init-version" do
      mix =
        String.replace(@attribute_mix, ~s|@version "2.3.1"|, "@version File.read!(\"VERSION\")")

      test_project(files: %{"mix.exs" => mix})
      |> Igniter.compose_task("workbench.install.versioning", [])
      |> assert_has_issue(&(&1 =~ "say where the history opens with --init-version"))
    end

    test "a pre-release goes into the badge with its dash doubled" do
      files =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.versioning",
          ~w(--init-version 2.0.0-rc.1 --readme-badge)
        )
        |> files()

      assert files["README.md"] =~
               "![v2.0.0-rc.1](https://img.shields.io/badge/version-2.0.0--rc.1-lightgrey.svg)"
    end

    test "is a no-op on a second run, and never moves the version under a written history" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.versioning", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.versioning", ["--init-version", "9.9.9"])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "keeps its own history"))
    end
  end

  describe "--mix-task and --readme-badge" do
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

    test "--mix-task plants the task and its test; --readme-badge the badge under the title" do
      files =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.versioning",
          ~w(--init-version 1.2.3 --mix-task --readme-badge)
        )
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      assert files["lib/mix/tasks/version.ex"] =~ "defmodule Mix.Tasks.Version do"
      assert files["test/mix/tasks/version_test.exs"] =~ "defmodule Mix.Tasks.VersionTest do"

      assert files["README.md"] =~
               ~r/^# .*\n\n!\[v1\.2\.3\]\(https:\/\/img\.shields\.io\/badge\/version-1\.2\.3-lightgrey\.svg\)/m
    end

    test "a second run adds the missing piece at the project's version, and moves nothing" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ~w(--init-version 1.2.3))
        |> apply_igniter!()
        |> Igniter.compose_task(
          "workbench.install.versioning",
          ~w(--init-version 9.9.9 --readme-badge)
        )

      assert_has_patch(igniter, "README.md", """
      + | ![v1.2.3](https://img.shields.io/badge/version-1.2.3-lightgrey.svg)
      """)

      assert_unchanged(igniter, "mix.exs")
      assert_unchanged(igniter, "CHANGELOG.md")
    end

    test "state reads the two back, nil for the badge without a README" do
      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", ~w(--mix-task --readme-badge))
        |> apply_igniter!()

      assert {%{init_version: "0.1.0", mix_task: true, readme_badge: true}, _} =
               Versioning.state(installed)

      bare =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.versioning", [])
        |> apply_igniter!()

      assert {%{mix_task: false, readme_badge: false}, _} = Versioning.state(bare)
    end
  end

  describe "state" do
    test "the version the history opens at is the changelog's oldest, not mix.exs's" do
      changelog =
        "# Changelog\n\n## [Unreleased]\n\n## [1.4.0] - 2026-02-01\n\n## [1.0.0-rc.1] - 2025-06-20\n"

      project = phx_test_project(files: %{"CHANGELOG.md" => changelog})

      assert {%{init_version: "1.0.0-rc.1"}, _} = Versioning.state(project)
      assert {%{init_version: nil}, _} = Versioning.state(phx_test_project())
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
      assert {%{init_version: "0.1.0", mix_task: false}, _} = Versioning.state(installed)
    end
  end
end
