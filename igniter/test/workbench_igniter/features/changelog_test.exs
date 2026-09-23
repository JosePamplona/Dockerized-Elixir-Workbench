defmodule WorkbenchIgniter.Features.ChangelogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Changelog

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

  describe "mix workbench.install.changelog" do
    test "opens the changelog at the version mix.exs has, and leaves mix.exs alone" do
      igniter = Igniter.compose_task(phx_test_project(), "workbench.install.changelog", [])

      assert_unchanged(igniter, "mix.exs")

      changelog = files(igniter)["CHANGELOG.md"]
      assert changelog =~ "## v0.1.0 - (#{today()})"
      assert changelog =~ "## Unreleased"
      assert changelog =~ "recorded here from this version on"
    end

    test "a project well under way opens at its own version, read through @version" do
      igniter =
        test_project(files: %{"mix.exs" => @attribute_mix})
        |> Igniter.compose_task("workbench.install.changelog", ["--readme-badge"])

      assert_unchanged(igniter, "mix.exs")
      assert files(igniter)["CHANGELOG.md"] =~ "## v2.3.1 - (#{today()})"
      assert files(igniter)["README.md"] =~ "version-2.3.1-lightgrey.svg"
    end

    test "--init-version writes the one asked for, into mix.exs and the changelog" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", ["--init-version", "0.0.0"])
        |> files()

      assert files["mix.exs"] =~ ~s|version: "0.0.0"|
      assert files["CHANGELOG.md"] =~ "## v0.0.0 - (#{today()})"
    end

    test "--init-version moves @version, not the key that points at it" do
      files =
        test_project(files: %{"mix.exs" => @attribute_mix})
        |> Igniter.compose_task("workbench.install.changelog", ["--init-version", "3.0.0"])
        |> files()

      assert files["mix.exs"] =~ ~s|@version "3.0.0"|
      assert files["mix.exs"] =~ "version: @version"
    end

    # The shape is declared (`formats/0`) and refused before anything is
    # written, with the sentence every cartridge refuses with.
    test "a version Mix would not compile is refused" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.changelog", ["--init-version", "1.2"])
      |> assert_has_issue(
        &(&1 =~ ~s|--init-version takes a version (1.2.3), and "1.2" is not one|)
      )
    end

    # The version read off mix.exs goes through no flag, so the
    # installer's own guard is what catches it.
    test "a version mix.exs carries that Version cannot read is refused too" do
      mix = String.replace(@attribute_mix, ~s|@version "2.3.1"|, ~s|@version "two"|)

      test_project(files: %{"mix.exs" => mix})
      |> Igniter.compose_task("workbench.install.changelog", [])
      |> assert_has_issue(&(&1 =~ "not a version Mix accepts"))
    end

    test "a version that cannot be read asks for --init-version" do
      mix =
        String.replace(@attribute_mix, ~s|@version "2.3.1"|, "@version File.read!(\"VERSION\")")

      test_project(files: %{"mix.exs" => mix})
      |> Igniter.compose_task("workbench.install.changelog", [])
      |> assert_has_issue(&(&1 =~ "say where the history opens with --init-version"))
    end

    test "a pre-release goes into the badge with its dash doubled" do
      files =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.changelog",
          ~w(--init-version 2.0.0-rc.1 --readme-badge)
        )
        |> files()

      assert files["README.md"] =~
               "![v2.0.0-rc.1](https://img.shields.io/badge/version-2.0.0--rc.1-lightgrey.svg)"
    end

    test "is a no-op on a second run, and never moves the version under a written history" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.changelog", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.changelog", ["--init-version", "9.9.9"])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "keeps its own history"))
    end
  end

  describe "--mix-task and --readme-badge" do
    test "neither is in by default" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
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
          "workbench.install.changelog",
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
        |> Igniter.compose_task("workbench.install.changelog", ~w(--init-version 1.2.3))
        |> apply_igniter!()
        |> Igniter.compose_task(
          "workbench.install.changelog",
          ~w(--init-version 9.9.9 --readme-badge)
        )

      assert_has_patch(igniter, "README.md", """
      + | ![v1.2.3](https://img.shields.io/badge/version-1.2.3-lightgrey.svg)
      """)

      assert_unchanged(igniter, "mix.exs")
      assert_unchanged(igniter, "CHANGELOG.md")
    end

    test "state reads the two back" do
      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", ~w(--mix-task --readme-badge))
        |> apply_igniter!()

      assert {%{init_version: "0.1.0", mix_task: true, readme_badge: true}, _} =
               Changelog.state(installed)

      bare =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert {%{mix_task: false, readme_badge: false}, _} = Changelog.state(bare)
    end
  end

  describe "a second run" do
    test "--mix-task adds the task to a project that already keeps a changelog" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.changelog", ~w(--mix-task))

      assert_has_notice(igniter, &(&1 =~ "CHANGELOG.md already exists"))
      assert_creates(igniter, "lib/mix/tasks/version.ex")
      assert_creates(igniter, "test/mix/tasks/version_test.exs")
      assert_unchanged(igniter, "CHANGELOG.md")

      assert {%{mix_task: true}, _} = igniter |> apply_igniter!() |> Changelog.state()
    end
  end

  defp without_readme do
    phx_test_project() |> Igniter.rm("README.md") |> apply_igniter!()
  end

  describe "without a README" do
    test "the badge reads nil: there is no README to carry it" do
      installed =
        without_readme()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert {%{readme_badge: nil}, _} = Changelog.state(installed)
    end

    test "--readme-badge says there is nowhere to put it, and writes no README" do
      igniter =
        without_readme()
        |> Igniter.compose_task("workbench.install.changelog", ~w(--readme-badge))

      assert_has_notice(igniter, &(&1 =~ "README.md not found: no badge to put the version on."))
      refute Igniter.exists?(igniter, "README.md")
      # The changelog opens all the same.
      assert_creates(igniter, "CHANGELOG.md")
    end
  end

  describe "state" do
    test "the version the history opens at is the changelog's oldest, not mix.exs's" do
      changelog =
        "# Changelog\n\n## [Unreleased]\n\n## [1.4.0] - 2026-02-01\n\n## [1.0.0-rc.1] - 2025-06-20\n"

      project = phx_test_project(files: %{"CHANGELOG.md" => changelog})

      assert {%{init_version: "1.0.0-rc.1"}, _} = Changelog.state(project)
      assert {%{init_version: nil}, _} = Changelog.state(phx_test_project())
    end
  end

  describe "the mark" do
    test "is the changelog, not the version every project already has" do
      assert {false, _} = Changelog.installed?(phx_test_project())

      installed =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert {true, _} = Changelog.installed?(installed)
      assert {%{init_version: "0.1.0", mix_task: false}, _} = Changelog.state(installed)
    end
  end

  describe "the docs site" do
    test "a docs site that is already there gets the changelog as a page, once" do
      mix_exs = fn igniter -> igniter.assigns[:test_files]["mix.exs"] end

      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      # exdoc leaves the entries commented out: the slot, not a listing.
      refute mix_exs.(igniter) =~ ~r/^\s*\{"CHANGELOG\.md"/m

      igniter =
        igniter
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert mix_exs.(igniter) =~ ~s|{"CHANGELOG.md", [title: "Changelog"]}|
      assert [_, project] = Regex.run(~r/Project: \[(.*?)\]/s, mix_exs.(igniter))
      assert project =~ ~s|"CHANGELOG.md"|

      # A second run finds it listed.
      again =
        igniter
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> apply_igniter!()

      assert length(String.split(mix_exs.(again), ~s|"CHANGELOG.md"|)) == 3
      refute mix_exs.(again) =~ "# {\"CHANGELOG.md\""
      assert {:ok, _} = Code.string_to_quoted(mix_exs.(again))
    end

    # exdoc's own `--changelog` is for a site built after a changelog —
    # it needs this box in. A site built before one lists nothing, and
    # this box puts its page in when it opens the file.
    test "a site built before the changelog gets the page when it is opened" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> apply_igniter!()

      refute files(igniter)["mix.exs"] =~ "CHANGELOG.md"

      mix_exs =
        igniter
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> files()
        |> Map.get("mix.exs")

      assert mix_exs =~ ~s|{"CHANGELOG.md", [title: "Changelog"]}|
      assert [_, project] = Regex.run(~r/Project: \[(.*?)\]/s, mix_exs)
      assert project =~ ~s|"CHANGELOG.md"|
    end

    test "without a docs site mix.exs gets no docs block" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.changelog", [])
        |> files()

      refute files["mix.exs"] =~ "docs:"
    end

    test "a docs block the project wrote itself, without groups, gets the page and no group" do
      igniter =
        phx_test_project()
        |> Igniter.update_elixir_file("mix.exs", fn zipper ->
          {:ok, zipper} = Igniter.Code.Function.move_to_def(zipper, :project, 0)

          Igniter.Code.Keyword.set_keyword_key(
            zipper,
            :docs,
            Sourceror.parse_string!(~s|[extras: ["README.md"]]|),
            fn z -> {:ok, z} end
          )
        end)
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.changelog", [])

      mix_exs = files(igniter)["mix.exs"]
      assert mix_exs =~ ~s|extras: ["README.md", {"CHANGELOG.md", [title: "Changelog"]}]|
      refute mix_exs =~ "groups_for_extras"
    end
  end
end
