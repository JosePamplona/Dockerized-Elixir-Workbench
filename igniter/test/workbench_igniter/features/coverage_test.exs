defmodule WorkbenchIgniter.Features.CoverageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Coverage
  alias WorkbenchIgniter.Features.Precommit

  # `--exdoc` plants a task whose tests stand on Mimic: the doubles are
  # test_doubles' box, which the option builds on.
  defp with_doubles(igniter \\ phx_test_project()) do
    igniter
    |> Igniter.compose_task("workbench.install.test_doubles", [])
    |> apply_igniter!()
  end

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
      # ExCoveralls' own report: no template to point at.
      refute json =~ "template_path"

      # What it leaves out unasked: the dependencies, the tests, the
      # wiring phx.new writes, and the generated components — each
      # written only where the project has the file.
      assert json =~ ~s|"deps"|
      assert json =~ ~s|"test"|
      assert json =~ ~s|"lib/test/application.ex"|
      assert json =~ ~s|"lib/test_web/endpoint.ex"|
      assert json =~ ~s|"lib/test_web/router.ex"|
      assert json =~ ~s|"lib/test_web/components"|
      # Not this project's: it has no such file to leave out.
      refute json =~ "channels/user_socket.ex"
      refute json =~ "open_api"
      refute json =~ "lib/mix/tasks"
      assert Jason.decode!(json)["skip_files"]
    end

    test "the report's templates live under test/, never assets/" do
      before = phx_test_project()

      igniter =
        before
        |> Igniter.compose_task("workbench.install.coverage", ["--html-theme", "custom"])
        |> apply_igniter!()

      assert igniter.assigns[:test_files]["coveralls.json"] =~
               ~s|"template_path": "test/coverage/template"|

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

      assert {%{html_theme: "custom"}, _} = Coverage.state(igniter)
    end

    test "--md-report plants the cover task, its tests and the page until it runs" do
      igniter =
        with_doubles()
        |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["lib/mix/tasks/cover.ex"] =~ "defmodule Mix.Tasks.Cover do"
      assert files["test/mix/tasks/cover_test.exs"] =~ "defmodule Mix.Tasks.CoverTest do"
      # The double the task's tests stand on is test_doubles', which the
      # option builds on: this box only registers its own copy.
      assert files["mix.exs"] =~ "{:mimic,"

      # Its block of the shared test helper, and nobody else's.
      assert files["test/test_helper.exs"] =~ "# >>> coverage"
      assert files["test/test_helper.exs"] =~ "Mimic.copy(File)"
      # The report is this box's file now: the page until `mix cover`
      # writes it, and gitignored, since the report is generated.
      assert files["TESTING.md"] =~ "mix cover"
      assert files[".gitignore"] =~ "/TESTING.md"
      refute files[".gitignore"] =~ "COVERAGE.md"
    end

    # The task's tests call `Mimic.copy(File)`: the doubles are
    # test_doubles' box, and this option builds on it instead of
    # inserting it — one insert, one cartridge.
    test "--md-report needs test_doubles with Mimic, and says so" do
      refused =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])

      assert_has_issue(refused, &(&1 =~ "--md-report builds on test_doubles with double mimic"))
      assert_has_issue(refused, &(&1 =~ "./wb.sh add test_doubles"))
      refute Igniter.exists?(refused, "coveralls.json")

      # Mox alone is not the double it needs: the box is in, and short.
      mox_only =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.test_doubles", ["--double", "mox"])
        |> apply_igniter!()
        |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])

      assert_has_issue(mox_only, &(&1 =~ "this project's double is mox"))
    end

    # The cover task parses the terminal coverage rows: a column
    # narrower than a path truncates it, and a truncated path is a row
    # the parser cannot match to a file. 80 is the default, wider than
    # ExCoveralls' own 40; a project with deeper paths asks for more.
    test "writes the report where --output-dir says, and says it back; cover unasked" do
      asked =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [
          "--output-dir",
          "priv/static/cover/"
        ])
        |> apply_igniter!()

      assert asked.assigns[:test_files]["coveralls.json"] =~ ~s|"output_dir": "priv/static/cover"|
      assert {%{output_dir: "priv/static/cover"}, _} = Coverage.state(asked)

      unasked =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      assert unasked.assigns[:test_files]["coveralls.json"] =~ ~s|"output_dir": "cover"|
      assert {%{output_dir: "cover"}, _} = Coverage.state(unasked)
    end

    test "the minimum the suite is held to: the flag, else 80" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--minimum-coverage", "92"])
        |> apply_igniter!()

      assert igniter.assigns[:test_files]["coveralls.json"] =~ ~s|"minimum_coverage": 92|
      assert {%{minimum_coverage: "92"}, _} = Coverage.state(igniter)

      unasked =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      assert {%{minimum_coverage: "80"}, _} = Coverage.state(unasked)
    end

    # It goes into the json as a bare number: `abc` leaves a file
    # excoveralls cannot parse, and 101 a gate no suite passes.
    test "a minimum that is not a whole percentage is refused, and nothing is written" do
      for bad <- ~w(abc 101 -1 85.5) do
        igniter =
          phx_test_project()
          |> Igniter.compose_task("workbench.install.coverage", ["--minimum-coverage", bad])

        assert_has_issue(
          igniter,
          &(&1 =~ "--minimum-coverage takes a whole number from 0 to 100")
        )

        refute Igniter.exists?(igniter, "coveralls.json")
      end
    end

    test "the file column is as wide as it was asked for, and 80 unasked" do
      json = fn argv ->
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", argv)
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, "coveralls.json"])
      end

      assert json.([]) =~ ~s|"file_column_width": 80|
      assert json.(["--file-column-width", "128"]) =~ ~s|"file_column_width": 128|

      {state, _igniter} =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--file-column-width", "160"])
        |> apply_igniter!()
        |> Coverage.state()

      assert state.file_column_width == "160"
    end

    test "a file column that is not a whole number of characters is refused" do
      for bad <- ~w(wide 39 1000 80.5) do
        igniter =
          phx_test_project()
          |> Igniter.compose_task("workbench.install.coverage", ["--file-column-width", bad])

        assert_has_issue(
          igniter,
          &(&1 =~ "--file-column-width takes a whole number from 40 to 999")
        )

        refute Igniter.exists?(igniter, "coveralls.json")
      end
    end

    test "a group writes only the paths the project has" do
      json =
        WorkbenchIgniter.TestProject.new(~w(--no-html))
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, "coveralls.json"])

      # No html, so no components to leave out — and the wiring it does
      # have is still there.
      refute json =~ "components"
      assert json =~ ~s|"lib/test_web/endpoint.ex"|
    end

    test "--ignore-files names the groups, and only the groups" do
      json =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.coverage",
          ["--ignore-files", "open_api,mix_tasks"]
        )
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> get_in([:test_files, "coveralls.json"])

      skipped = Jason.decode!(json)["skip_files"]

      # A directory nobody can witness is written as asked; what was not
      # asked for is not there.
      assert skipped == ~w(lib/test_web/open_api lib/mix/tasks)
    end

    # The list is closed: the box writes what it knows how to read back,
    # and a path of the project's own goes in the project's own file.
    test "a value that is not a group is refused, and nothing is written" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.coverage",
          ["--ignore-files", "boilerplate,lib/test/legacy"]
        )

      assert_has_issue(igniter, &(&1 =~ ~s|--ignore-files takes the groups this box knows|))
      assert_has_issue(igniter, &(&1 =~ ~s|"lib/test/legacy" is not one of them|))
      assert_has_issue(igniter, &(&1 =~ "coveralls.json"))
      refute Igniter.exists?(igniter, "coveralls.json")
    end

    test "deps and test are groups like the rest, and read back by name" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--ignore-files", "test,deps"])
        |> apply_igniter!()

      skipped =
        igniter.assigns[:test_files]["coveralls.json"] |> Jason.decode!() |> Map.get("skip_files")

      assert skipped == ~w(test deps)
      assert {%{ignore_files: ~w(deps test)}, _} = Coverage.state(igniter)

      unasked =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      assert {%{ignore_files: ~w(deps test boilerplate components)}, _} = Coverage.state(unasked)
    end

    test "says back the groups it was inserted with, and a path the project added by hand" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task(
          "workbench.install.coverage",
          ["--ignore-files", "boilerplate,open_api"]
        )
        |> apply_igniter!()

      assert {%{ignore_files: ~w(boilerplate open_api)}, _} = Coverage.state(igniter)

      # The state reads the file, not the insert: a path the project
      # wrote into its own coveralls.json reads back as the path it is.
      edited =
        igniter
        |> Igniter.update_file("coveralls.json", fn source ->
          Rewrite.Source.update(source, :content, fn content ->
            String.replace(
              content,
              ~s|    "lib/test_web/open_api"|,
              ~s|    "lib/test_web/open_api",\n    "lib/test/legacy"|
            )
          end)
        end)
        |> apply_igniter!()

      assert {%{ignore_files: ~w(boilerplate open_api lib/test/legacy)}, _} =
               Coverage.state(edited)
    end

    test "plants no report theme by default: the report is ExCoveralls' own" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      refute Enum.any?(Map.keys(igniter.assigns[:test_files]), &(&1 =~ "coverage/template"))
      assert {%{html_theme: "default"}, _} = Coverage.state(igniter)
    end

    test "--html-theme custom plants the workbench's own report" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--html-theme", "custom"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      # Same target path whatever the theme: coveralls.json points there.
      assert files["test/coverage/template/coverage.html.eex"] =~ "Test Coverage Overview"
      assert {%{html_theme: "custom"}, _} = Coverage.state(igniter)
    end

    test "--html-theme exdoc-ish plants the theme that mimics the docs" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--html-theme", "exdoc-ish"])
        |> apply_igniter!()

      files = igniter.assigns[:test_files]

      assert files["test/coverage/template/coverage.html.eex"] =~ ~s|class="sidebar-projectName"|
      assert files["test/coverage/template/_style.html.eex"] =~ "--sidebarBackground"
      assert Map.has_key?(files, "test/coverage/template/_script.html.eex")
      assert Map.has_key?(files, "test/coverage/template/_style.html.eex")
    end

    test "rejects an unknown theme" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", ["--html-theme", "nope"])

      assert Enum.any?(igniter.issues, &(&1 =~ "Unknown coverage report theme \"nope\""))
      assert Enum.any?(igniter.issues, &(&1 =~ "default, custom, exdoc-ish"))
    end

    test "lists ExCoveralls' own report, then the themes from the asset directories" do
      assert WorkbenchIgniter.Features.Coverage.themes() == ["default", "custom", "exdoc-ish"]
    end

    # `rerun: :adds`: the json and the theme are fixed at the insert,
    # but the task and the hook are pieces, added when missing.
    test "without --md-report, no task, no page and nothing ignored for it" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      refute Map.has_key?(files, "lib/mix/tasks/cover.ex")
      refute Map.has_key?(files, "lib/mix/tasks/cover/formatter.ex")
      refute Map.has_key?(files, "test/mix/tasks/cover_test.exs")
      refute Map.has_key?(files, "TESTING.md")
      refute files[".gitignore"] =~ "TESTING.md"
      # The doubles are another box's: unasked, this one asks for none
      # and writes no block in the helper phx.new left.
      refute files["mix.exs"] =~ "{:mimic,"
      refute files["test/test_helper.exs"] =~ "coverage"
    end

    test "a second run with --md-report plants the cover task the first left out" do
      igniter =
        with_doubles()
        |> Igniter.compose_task("workbench.install.coverage", [])
        |> apply_igniter!()

      refute Igniter.exists?(igniter, "lib/mix/tasks/cover.ex")

      added =
        igniter
        |> Igniter.compose_task("workbench.install.coverage", ["--md-report"])
        |> apply_igniter!()

      assert Igniter.exists?(added, "lib/mix/tasks/cover.ex")
      assert Igniter.exists?(added, "lib/mix/tasks/cover/formatter.ex")
      assert {%{md_report: true}, _} = Coverage.state(added)
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

  # The insert writes files and never runs the suite: the report is
  # made from its door in the console, or with `./wb.sh mix cover`.
  test "the insert queues no run of its own" do
    igniter =
      WorkbenchIgniter.TestProject.new()
      |> Igniter.compose_task("workbench.install.coverage", [])

    refute Enum.any?(igniter.tasks, &match?({"cover", _}, &1))
    refute Enum.any?(igniter.tasks, &match?({"coveralls" <> _, _}, &1))
    refute Enum.any?(igniter.tasks, &match?({"ecto." <> _, _}, &1))
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
