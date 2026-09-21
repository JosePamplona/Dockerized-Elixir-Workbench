defmodule WorkbenchIgniter.Features.CoverallsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Coveralls
  alias WorkbenchIgniter.Features.Precommit

  describe "mix workbench.install.coveralls" do
    test "adds the dependency and the mix.exs coverage configuration" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.coveralls", [])
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
        |> Igniter.compose_task("workbench.install.coveralls", [])
        |> apply_igniter!()

      json = igniter.assigns[:test_files]["coveralls.json"]

      assert json =~ ~s|"minimum_coverage": 80|
      # The standard `cover/` output dir, already in phx.new's .gitignore.
      assert json =~ ~s|"output_dir": "cover"|
      assert json =~ ~s|"template_path": "assets/cover/template"|
      assert json =~ ~s|"test_web/open_api"|
      assert json =~ ~s|"test_web/components"|
    end

    test "--exdoc plants the cover task and its tests" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ["--exdoc"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["lib/mix/tasks/cover.ex"] =~ "defmodule Mix.Tasks.Cover do"
      assert files["test/mix/tasks/cover_test.exs"] =~ "defmodule Mix.Tasks.CoverTest do"
      # The cover task tests use Mock.
      assert files["mix.exs"] =~ "{:mimic,"

      # Its block of the shared test helper, and nobody else's.
      assert files["test/test_helper.exs"] =~ "# >>> coveralls"
      assert files["test/test_helper.exs"] =~ "Mimic.copy(File)"
      # The generated reports are not source files.
      assert files[".gitignore"] =~ "/TESTING.md"
      refute files[".gitignore"] =~ "COVERAGE.md"
    end

    test "keeps file paths untruncated for the mix cover parser" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", [])
        |> apply_igniter!()

      # The cover task parses the terminal coverage rows: a narrow column
      # would truncate long paths and break the report links.
      assert igniter.assigns[:test_files]["coveralls.json"] =~
               ~s|"file_column_width": 128|
    end

    test "--interface graphql, and a project without html, drop their skip_files entries" do
      igniter =
        WorkbenchIgniter.TestProject.new(~w(--no-html))
        |> Igniter.compose_task("workbench.install.coveralls", ["--interface", "graphql"])
        |> apply_igniter!()

      json = igniter.assigns[:test_files]["coveralls.json"]

      refute json =~ "open_api"
      refute json =~ "components"
    end

    test "plants the exdoc-ish report theme by default" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", [])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # Same target path whatever the theme: coveralls.json points there.
      assert files["assets/cover/template/coverage.html.eex"] =~ ~s|class="sidebar-projectName"|
      assert files["assets/cover/template/_style.html.eex"] =~ "--sidebarBackground"
      assert files["assets/cover/template/_script.html.eex"] =~ "ex_doc:settings"
    end

    test "--theme custom plants the original report theme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ["--theme", "custom"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["assets/cover/template/coverage.html.eex"] =~ "Test Coverage Overview"
      assert Map.has_key?(files, "assets/cover/template/_script.html.eex")
      assert Map.has_key?(files, "assets/cover/template/_style.html.eex")
    end

    test "rejects an unknown theme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ["--theme", "nope"])

      assert Enum.any?(igniter.issues, &(&1 =~ "Unknown coverage report theme \"nope\""))
      assert Enum.any?(igniter.issues, &(&1 =~ "custom, exdoc-ish"))
    end

    test "lists the themes from the asset directories" do
      assert WorkbenchIgniter.Features.Coveralls.themes() == ["custom", "exdoc-ish"]
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.coveralls", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.coveralls", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "--githook" do
    test "writes no hook by default" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", [])
        |> apply_igniter!()

      refute Igniter.exists?(igniter, Precommit.hook())
      assert {%{githook: false}, _} = Coveralls.state(igniter)
    end

    test "inserts the precommit cartridge and takes a block of its hook" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ~w(--githook))
        |> apply_igniter!()

      files = igniter.assigns[:test_files]
      hook = files[Precommit.hook()]

      # The hook box came with it: its own check, and the way into the
      # container the host has no Elixir for.
      assert hook =~ "mix format --check-formatted"
      assert files[".githooks/mix"] =~ "docker compose exec"

      assert hook =~
               "# >>> coveralls — the suite, and what it did not reach\n#{Coveralls.check_command()}\n# <<< coveralls"
    end

    test "the block is born below the divider: the suite is the slowest check" do
      hook =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ~w(--githook))
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      [fast, slow] = String.split(hook, "# --- slow:")

      assert slow =~ Coveralls.check_command()
      refute fast =~ Coveralls.check_command()
    end

    test "says back that the project carries it" do
      {state, _igniter} =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ~w(--githook))
        |> apply_igniter!()
        |> Coveralls.state()

      assert state.githook
    end

    test "a second run adds the block to a project installed without it" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", [])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.coveralls", ~w(--githook))
        |> apply_igniter!()

      assert igniter.assigns[:test_files][Precommit.hook()] =~ Coveralls.check_command()
    end

    test "ejecting coveralls leaves credo's block and the box's own checks standing" do
      hook =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coveralls", ~w(--githook))
        |> Igniter.compose_task("workbench.install.credo", ~w(--githook))
        |> apply_igniter!()
        |> Precommit.forget("coveralls")
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, Precommit.hook()])

      refute hook =~ "coveralls"
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
