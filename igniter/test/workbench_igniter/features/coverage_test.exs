defmodule WorkbenchIgniter.Features.CoverageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Coverage
  alias WorkbenchIgniter.Features.Precommit

  describe "mix workbench.install.coverage" do
    test "adds the dependency and the mix.exs coverage configuration" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.coverage", [])
      |> assert_has_patch("mix.exs", """
      + | {:excoveralls, "~> 0.18", only: :test},
      """)
      |> assert_has_patch("mix.exs", """
      + | test_coverage: [tool: ExCoveralls]
      """)
      |> assert_has_patch("mix.exs", """
      + | "coveralls.html": :test,
      """)
    end

    test "creates coveralls.json with defaults" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      json = igniter.assigns[:test_files]["coveralls.json"]

      assert json =~ ~s|"minimum_coverage": 80|
      # The standard `cover/` output dir, already in phx.new's .gitignore.
      assert json =~ ~s|"output_dir": "cover"|
      assert json =~ ~s|"template_path": "test/coverage/template"|
      assert json =~ ~s|"test_web/open_api"|
      assert json =~ ~s|"test_web/components"|
    end

    test "the report's templates live under test/, never assets/" do
      before = phx_test_project()

      igniter =
        before
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      planted =
        Map.keys(igniter.assigns[:test_files]) --
          Map.keys(apply_igniter!(before).assigns[:test_files])

      # assets/ is the release build's input; test/ is outside the
      # Dockerfile's context and nothing compiles a loose .eex there.
      assert "test/coverage/template/coverage.html.eex" in planted
      refute Enum.any?(planted, &String.starts_with?(&1, "assets/"))
    end

    test "the theme is read where coveralls.json says the templates are" do
      # A project from before v0.4.0: templates under assets/.
      igniter =
        phx_test_project()
        |> Igniter.create_new_file(
          "coveralls.json",
          ~s|{"coverage_options": {"template_path": "./assets/cover/template"}}|
        )
        |> Igniter.create_new_file(
          "assets/cover/template/coverage.html.eex",
          Coverage.asset("template/custom/coverage.html.eex")
        )
        |> apply_igniter!()

      assert {%{theme: "custom"}, _} = Coverage.state(igniter)
    end

    test "--exdoc plants the cover task and its tests" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--exdoc"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["lib/mix/tasks/cover.ex"] =~ "defmodule Mix.Tasks.Cover do"
      assert files["test/mix/tasks/cover_test.exs"] =~ "defmodule Mix.Tasks.CoverTest do"
      # The cover task tests use Mock.
      assert files["mix.exs"] =~ "{:mimic,"

      # Its block of the shared test helper, and nobody else's.
      assert files["test/test_helper.exs"] =~ "# >>> coverage"
      assert files["test/test_helper.exs"] =~ "Mimic.copy(File)"
      # The generated reports are not source files.
      assert files[".gitignore"] =~ "/TESTING.md"
      refute files[".gitignore"] =~ "COVERAGE.md"
    end

    test "keeps file paths untruncated for the mix cover parser" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      # The cover task parses the terminal coverage rows: a narrow column
      # would truncate long paths and break the report links.
      assert igniter.assigns[:test_files]["coveralls.json"] =~
               ~s|"file_column_width": 128|
    end

    test "--interface graphql, and a project without html, drop their skip_files entries" do
      igniter =
        WorkbenchIgniter.TestProject.new(~w(--no-html))
        |> Igniter.compose_task("workbench.install.coverage", ["--interface", "graphql"])
        |> apply_igniter!()

      json = igniter.assigns[:test_files]["coveralls.json"]

      refute json =~ "open_api"
      refute json =~ "components"
    end

    test "plants the exdoc-ish report theme by default" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # Same target path whatever the theme: coveralls.json points there.
      assert files["test/coverage/template/coverage.html.eex"] =~ ~s|class="sidebar-projectName"|
      assert files["test/coverage/template/_style.html.eex"] =~ "--sidebarBackground"
      assert files["test/coverage/template/_script.html.eex"] =~ "ex_doc:settings"
    end

    test "--theme custom plants the original report theme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--theme", "custom"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["test/coverage/template/coverage.html.eex"] =~ "Test Coverage Overview"
      assert Map.has_key?(files, "test/coverage/template/_script.html.eex")
      assert Map.has_key?(files, "test/coverage/template/_style.html.eex")
    end

    test "rejects an unknown theme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--theme", "nope"])

      assert Enum.any?(igniter.issues, &(&1 =~ "Unknown coverage report theme \"nope\""))
      assert Enum.any?(igniter.issues, &(&1 =~ "custom, exdoc-ish"))
    end

    test "lists the themes from the asset directories" do
      assert WorkbenchIgniter.Features.Coverage.themes() == ["custom", "exdoc-ish"]
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.coverage", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.coverage", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  defp with_precommit do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.precommit", [])
    |> apply_igniter!()
  end

  describe "--githook" do
    test "writes no hook by default" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      refute Igniter.exists?(igniter, Precommit.hook())
      assert {%{githook: false}, _} = Coverage.state(igniter)
    end

    # The hook is precommit's, so the option builds on it being in.
    test "refuses while precommit is not in, and writes nothing" do
      igniter =
        phx_test_project() |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))

      assert_has_issue(igniter, &(&1 =~ "--githook builds on precommit"))
      refute Igniter.exists?(igniter, "coveralls.json")
      refute Igniter.exists?(igniter, Precommit.hook())
    end

    test "a second run refuses it too, on a project with coverage and no precommit" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))

      assert_has_issue(igniter, &(&1 =~ "--githook builds on precommit"))
    end

    test "takes a block of precommit's hook" do
      igniter =
        with_precommit()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))
        |> apply_igniter!()

      files = igniter.assigns[:test_files]
      hook = files[Precommit.hook()]

      # precommit's own block stands beside it.
      assert hook =~ "mix format --check-formatted"

      assert hook =~
               "# >>> coverage — the suite, and what it did not reach\n#{Coverage.check_command()}\n# <<< coverage"
    end

    test "the block is born below the divider: the suite is the slowest check" do
      hook =
        with_precommit()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      [fast, slow] = String.split(hook, "# --- slow:")

      assert slow =~ Coverage.check_command()
      refute fast =~ Coverage.check_command()
    end

    test "says back that the project carries it" do
      {state, _igniter} =
        with_precommit()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))
        |> apply_igniter!()
        |> Coverage.state()

      assert state.githook
    end

    test "a second run adds the block to a project installed without it" do
      igniter =
        with_precommit()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))
        |> apply_igniter!()

      assert igniter.assigns[:test_files][Precommit.hook()] =~ Coverage.check_command()
    end

    test "ejecting coverage leaves credo's block and the box's own checks standing" do
      hook =
        with_precommit()
        |> Igniter.compose_task("workbench.install.coverage", ~w(--githook))
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()
        |> Precommit.forget("coverage")
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      refute hook =~ "coverage"
      assert hook =~ "mix credo"
      assert hook =~ "mix format --check-formatted"
    end
  end

  describe "composition through chiefs_setup" do
    test "the collection composes the installer with its recipe argv" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.chiefs_setup", [])
        |> apply_igniter!()

      assert igniter.assigns[:test_files]["coveralls.json"] =~
               ~s|"output_dir": "cover"|
    end
  end
end
