defmodule WorkbenchIgniter.Features.DbschemaTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.Dbschema

  defp installed(argv) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.dbschema", argv)
    |> apply_igniter!()
    |> Map.get(:assigns)
    |> Map.get(:test_files)
  end

  describe "mix workbench.install.dbschema" do
    test "plants the task, its test and the dep it needs" do
      files = installed([])

      assert files["lib/mix/tasks/db.ex"] =~ "defmodule Mix.Tasks.Db do"
      assert files["test/mix/tasks/db_test.exs"] =~ "defmodule Mix.Tasks.DbTest do"
      assert files["mix.exs"] =~ "{:html_entities,"
    end

    test "the sources land under assets/db_schema, per --combo" do
      files = installed(["--combo", "auth0"])

      assert files["assets/db_schema/database.dbs"] =~ ~s|<table name="users"|
      assert files["assets/db_schema/light/MainLayout.svg"]
      assert files["assets/db_schema/dark/MainLayout.svg"]
      assert files["assets/db_schema/light/database.md"]
      assert files["assets/db_schema/dark/database.md"]
      # The placeholder the export carries is the project's own name.
      assert files["assets/db_schema/database.dbs"] =~ "Test"
      refute files["assets/db_schema/database.dbs"] =~ "%{project_name}"

      # The bare database has no users table, and no conversations.
      bare = installed([])
      refute bare["assets/db_schema/database.dbs"] =~ ~s|<table name="users"|
      refute bare["assets/db_schema/database.dbs"] =~ ~s|<table name="conversations"|

      assert installed(["--combo", "auth0_openai"])["assets/db_schema/database.dbs"] =~
               ~s|<table name="conversations"|
    end

    test "the page and both images are written, each with its theme fragment" do
      files = installed([])

      assert files["guides/images/model-light.svg"]
      assert files["guides/images/model-dark.svg"]

      assert files["guides/database.md"] =~
               "![img](./assets/model-light.svg#gh-light-mode-only)"

      assert files["guides/database.md"] =~ "![img](./assets/model-dark.svg#gh-dark-mode-only)"
      refute files["guides/database.md"] =~ "![img](./MainLayout.svg)"

      # And the task writes the same two lines, whenever it is run again.
      assert files["lib/mix/tasks/db.ex"] =~
               ~s|"![img](./assets/\#{@light_target}#gh-light-mode-only)"|

      assert files["lib/mix/tasks/db.ex"] =~
               ~s|"![img](./assets/\#{@dark_target}#gh-dark-mode-only)"|
    end

    test "an unknown --combo is refused" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.dbschema", ["--combo", "nope"])
      |> assert_has_issue(&(&1 =~ "Unknown --combo"))
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.dbschema", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.dbschema", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "mix db is in"))
    end

    test "state/1 says the combo back" do
      {state, _igniter} =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.dbschema", ["--combo", "auth0_openai"])
        |> apply_igniter!()
        |> Dbschema.state()

      assert state == %{combo: "auth0_openai"}

      # Nothing exported, nothing to read.
      assert {%{combo: nil}, _} = Dbschema.state(phx_test_project())
    end

    test "it builds on ecto, and refuses a project without it" do
      assert Dbschema.requires() == ["ecto"]

      WorkbenchIgniter.TestProject.new(~w(--no-ecto))
      |> Igniter.compose_task("workbench.install.dbschema", [])
      |> assert_has_issue(&(&1 =~ "dbschema builds on ecto"))
    end
  end

  describe "the docs site" do
    test "the page is listed under Support when exdoc is in" do
      files =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.exdoc", [])
        |> Igniter.compose_task("workbench.install.dbschema", [])
        |> apply_igniter!()
        |> Map.get(:assigns)
        |> Map.get(:test_files)

      assert files["mix.exs"] =~ ~s|{"guides/database.md", [title: "Database"]}|

      assert files["mix.exs"] =~
               ~r/Support: \[\s*"guides\/database\.md"/

      # And nothing is listed on a project with no docs site.
      alone = installed([])
      refute alone["mix.exs"] =~ "guides/database.md"
      assert alone["guides/database.md"]
    end
  end
end
