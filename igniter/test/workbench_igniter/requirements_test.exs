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
    test "a name, a name with a state, booleans either way" do
      assert Feature.describe("ecto") == "ecto"
      assert Feature.describe({"ecto", []}) == "ecto"
      assert Feature.describe({"ecto", database: "postgres"}) == "ecto with database postgres"
      assert Feature.describe({"html", live: true}) == "html with live"
      assert Feature.describe({"ecto", binary_id: false}) == "ecto with no binary_id"

      assert Feature.describe({:short, "ecto", [database: "postgres"], :database, "mysql"}) ==
               "ecto with database postgres"
    end

    test "the remedy is the add line with the state as switches" do
      assert Feature.remedy("ecto") == "./wb.sh add ecto"

      assert Feature.remedy({"ecto", database: "postgres"}) ==
               "./wb.sh add ecto --database postgres"

      assert Feature.remedy({"html", live: true}) == "./wb.sh add html --live"

      assert Feature.remedy({:absent, "ecto", binary_id: false}) ==
               "./wb.sh add ecto --no-binary-id"
    end
  end

  describe "the one refusal" do
    test "absent: not in yet, and the line that brings it" do
      [issue] = Feature.refuse(test_project(), Features.Live, [{:absent, "html", []}]).issues

      assert issue ==
               "live builds on html, not in the project yet. Insert that first: ./wb.sh add html"
    end

    test "short: in, and not as asked" do
      [issue] =
        Feature.refuse(test_project(), Features.Pgadmin, [
          {:short, "ecto", [database: "postgres"], :database, "mysql"}
        ]).issues

      assert issue ==
               "pgadmin builds on ecto with database postgres, and this project's database is mysql."
    end

    test "both, in one sentence" do
      [issue] =
        Feature.refuse(test_project(), Features.Pgadmin, [
          {:short, "ecto", [database: "postgres"], :database, nil},
          {:absent, "html", []}
        ]).issues

      assert issue =~ "pgadmin builds on ecto with database postgres and html"
      assert issue =~ "this project's database is not set"
      assert issue =~ "Insert that first: ./wb.sh add html"
    end
  end

  describe "the resolver" do
    test "a state requirement holds on a project born with it, and is short on one that changed its mind" do
      assert {[], _} = Feature.missing_requirements(phx_test_project(), Features.Pgadmin)

      mysql =
        phx_test_project()
        |> Igniter.Project.Deps.remove_dep(:postgrex)
        |> Igniter.Project.Deps.add_dep({:myxql, "~> 0.7"})
        |> apply_igniter!()

      assert {[{:short, "ecto", [database: "postgres"], :database, "mysql"}], _} =
               Feature.missing_requirements(mysql, Features.Pgadmin)

      assert {[{:absent, "ecto", [database: "postgres"]}], _} =
               Feature.missing_requirements(test_project(), Features.Pgadmin)
    end
  end

  describe "the catalog" do
    test "carries the names as requires and the states as conditions" do
      assert Feature.requires_names(Features.Pgadmin) == ["ecto"]
      assert Feature.conditions(Features.Pgadmin) == %{"ecto" => %{database: "postgres"}}

      assert %{requires: ["ecto"], conditions: %{"ecto" => %{database: "postgres"}}} =
               Features.entry(Features.Pgadmin)

      assert %{requires: ["html"], conditions: %{}} = Features.entry(Features.Live)
    end
  end
end
