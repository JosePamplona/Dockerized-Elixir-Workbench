defmodule WorkbenchIgniter.RequirementsTest do
  @moduledoc """
  A requirement names a cartridge and, when the name is not enough, the
  state it has to be in; one resolver reads both off the project, one
  refusal says what is lacking and how to get it, and the catalog
  carries the names and the states apart.
  """
  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Feature
  alias WorkbenchIgniter.Features

  describe "said and remedied" do
    # A box short of the state can be topped up when it adds its pieces
    # on a second run; one whose options are fixed at the insert has no
    # line to offer, and saying one would send the reader nowhere.
    test "what is lacking, and the line that fixes it where there is one" do
      short_coverage = {:short, "coverage", [exdoc: true], :exdoc, false}
      short_ecto = {:short, "ecto", [database: "postgres"], :database, "mysql"}

      assert Feature.lacking([short_coverage]) ==
               "coverage with exdoc, and this project's exdoc is off. " <>
                 "Add it with: ./wb.sh add coverage --exdoc"

      assert Feature.lacking([short_ecto]) ==
               "ecto with database postgres, and this project's database is mysql."

      assert Feature.lacking([{:absent, "precommit", []}]) ==
               "precommit, not in the project yet. Insert that first: ./wb.sh add precommit"
    end

    test "a name, a name with a state, booleans either way" do
      assert Feature.describe("ecto") == "ecto"
      assert Feature.describe({"ecto", []}) == "ecto"
      assert Feature.describe({"ecto", database: "postgres"}) == "ecto with database postgres"
      assert Feature.describe({"html", live: true}) == "html with live"
      assert Feature.describe({"ecto", binary_id: false}) == "ecto with no binary_id"

      assert Feature.describe({:short, "ecto", [database: "postgres"], :database, "mysql"}) ==
               "ecto with database postgres"

      assert Feature.describe({"ecto", database: ~w(postgres mysql mssql)}) ==
               "ecto with database postgres, mysql or mssql"
    end

    test "the remedy is the add line with the state as switches" do
      assert Feature.remedy("ecto") == "./wb.sh add ecto"

      assert Feature.remedy({"ecto", database: "postgres"}) ==
               "./wb.sh add ecto --database postgres"

      assert Feature.remedy({"html", live: true}) == "./wb.sh add html --live"

      assert Feature.remedy({"ecto", database: ~w(postgres mysql)}) ==
               "./wb.sh add ecto --database postgres|mysql"

      assert Feature.remedy({:absent, "ecto", binary_id: false}) ==
               "./wb.sh add ecto --no-binary-id"
    end
  end

  describe "the one refusal" do
    test "absent: not in yet, and the line that brings it" do
      [issue] = Feature.refuse(test_project(), Features.Dashboard, [{:absent, "html", []}]).issues

      assert issue ==
               "dashboard builds on html, not in the project yet. Insert that first: ./wb.sh add html"
    end

    test "short: in, and not as asked — of a chosen value, named by its switch" do
      [issue] =
        Feature.refuse_values(test_project(), [
          {:admin, "pgadmin", [{:short, "ecto", [database: "postgres"], :database, "mysql"}]}
        ]).issues

      assert issue ==
               "--admin pgadmin builds on ecto with database postgres, and this project's database is mysql."
    end

    test "both, in one sentence" do
      [issue] =
        Feature.refuse(test_project(), Features.DbAdmin, [
          {:short, "ecto", [database: "postgres"], :database, nil},
          {:absent, "html", []}
        ]).issues

      assert issue ==
               "db_admin builds on ecto with database postgres and html: this project's " <>
                 "database is not set, and html is not in yet. Insert that first: " <>
                 "./wb.sh add ecto --database postgres, then ./wb.sh add html"
    end

    test "a short state is remedied by running the cartridge again with the switch" do
      assert Feature.remedy({:short, "html", [live: true], :live, false}) ==
               "./wb.sh add html --live"
    end
  end

  describe "the resolver" do
    defp missing(project, admin),
      do: Feature.missing_option_requirements(project, Features.DbAdmin, admin: [admin])

    defp mysql do
      phx_test_project()
      |> Igniter.Project.Deps.remove_dep(:postgrex)
      |> Igniter.Project.Deps.add_dep({:myxql, "~> 0.7"})
      |> apply_igniter!()
    end

    test "a state requirement holds on a project born with it, and is short on one that changed its mind" do
      assert {[], _} = missing(phx_test_project(), "pgadmin")

      assert {[
                {:admin, "pgadmin",
                 [{:short, "ecto", [database: "postgres"], :database, "mysql"}]}
              ], _} = missing(mysql(), "pgadmin")

      assert {[{:admin, "pgadmin", [{:absent, "ecto", [database: "postgres"]}]}], _} =
               missing(test_project(), "pgadmin")
    end

    test "a list of values is met by any one of them" do
      assert {[], _} = missing(phx_test_project(), "cloudbeaver")
      assert {[], _} = missing(mysql(), "cloudbeaver")

      sqlite =
        phx_test_project()
        |> Igniter.Project.Deps.remove_dep(:postgrex)
        |> Igniter.Project.Deps.add_dep({:ecto_sqlite3, "~> 0.1"})
        |> apply_igniter!()

      assert {[{:admin, "cloudbeaver", [{:short, "ecto", _, :database, "sqlite3"}]}], _} =
               missing(sqlite, "cloudbeaver")
    end
  end

  # A `:csv` option answers with a list, so a requirement on such a box
  # asks about one of several: db_admin's admins, test_doubles' doubles.
  # Nothing on the shelf requires db_admin today; the reading is held
  # here so the box that does gets it right.
  describe "a state a box answers with a list" do
    defmodule NeedsPgadmin do
      @moduledoc false
      def name, do: "needs_pgadmin"
      def requires, do: [{"db_admin", admin: "pgadmin"}]
    end

    defp on(argv) do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.db_admin", argv)
      |> apply_igniter!()
    end

    test "is met when it carries what was asked, whatever else it carries" do
      assert {[], _} = Feature.missing_requirements(on(~w(--admin pgadmin)), NeedsPgadmin)
      assert {[], _} = Feature.missing_requirements(on(~w(--admin pgadmin,adminer)), NeedsPgadmin)
    end

    test "is short when it carries other values, and says which they are" do
      assert {[{:short, "db_admin", [admin: "pgadmin"], :admin, ["adminer"]}], _} =
               Feature.missing_requirements(on(~w(--admin adminer)), NeedsPgadmin)

      # The refusal names them as the project has them, and offers the
      # line that adds the one asked: db_admin adds its admins.
      assert Feature.lacking([{:short, "db_admin", [admin: "pgadmin"], :admin, ["adminer"]}]) ==
               "db_admin with admin pgadmin, and this project's admin is adminer. " <>
                 "Add it with: ./wb.sh add db_admin --admin pgadmin"

      assert Feature.lacking([{:short, "db_admin", [admin: "pgadmin"], :admin, []}]) =~
               "this project's admin is none"
    end
  end

  describe "the catalog" do
    test "carries the names as requires and the states as conditions, per value too" do
      assert Feature.requires_names(Features.DbAdmin) == ["ecto"]
      assert Feature.conditions(Features.DbAdmin) == %{}

      assert %{requires: ["ecto"], conditions: %{}, options: [%{name: :admin, choices: choices}]} =
               Features.entry(Features.DbAdmin)

      assert %{requires: ["ecto"], conditions: %{"ecto" => %{database: "postgres"}}} =
               Enum.find(choices, &(&1.value == "pgadmin"))

      assert %{conditions: %{"ecto" => %{database: ~w(postgres mysql mssql)}}} =
               Enum.find(choices, &(&1.value == "cloudbeaver"))

      assert %{requires: ["ecto"], conditions: %{}} = Enum.find(choices, &(&1.value == "adminer"))
      assert %{requires: [], conditions: %{}} = Features.entry(Features.Html)
    end
  end

  describe "advice" do
    test "a switch's advice is a notice while the project lacks it, never an issue" do
      without =
        phx_test_project()
        |> Igniter.Project.Deps.remove_dep(:esbuild)
        |> apply_igniter!()
        |> Feature.advise(Features.Html, live: true)

      assert without.issues == []

      assert [
               "--live is in without esbuild: the LiveSocket lives in assets/js/app.js, " <>
                 "which only esbuild brings, and without it the browser never connects. " <>
                 "Add it with: ./wb.sh add esbuild"
             ] = without.notices

      assert Feature.advise(phx_test_project(), Features.Html, live: true).notices == []
      assert Feature.advise(without, Features.Html, live: false).notices == without.notices
    end

    test "the catalog carries it on the switch, apart from what it requires" do
      assert %{options: [%{name: :live, requires: [], advises: advises}]} =
               Features.entry(Features.Html)

      assert %{requires: ["esbuild"], conditions: %{}, doc: "the LiveSocket" <> _} = advises
      assert %{options: [%{advises: nil}]} = Features.entry(Features.DbAdmin)
    end
  end
end
