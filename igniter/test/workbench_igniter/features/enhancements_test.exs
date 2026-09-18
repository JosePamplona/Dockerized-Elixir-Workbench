defmodule WorkbenchIgniter.Features.EnhancementsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp installed(argv) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.enhancements", argv)
    |> apply_igniter!()
    |> Map.get(:assigns)
    |> Map.get(:test_files)
  end

  describe "mix workbench.install.enhancements" do
    test "ecto group: helper, schema, deps, db task and diagram sources" do
      files = installed(["--project-name", "Lorem Ipsum"])

      assert files["lib/test/helper.ex"] =~ "defmodule Test.Helper do"
      assert files["test/test/helper_test.exs"] =~ "defmodule Test.HelperTest do"
      assert files["lib/test/schema.ex"] =~ "defmodule Test.Schema do"
      assert files["lib/mix/tasks/db.ex"] =~ "defmodule Mix.Tasks.Db do"
      assert files["test/mix/tasks/db_test.exs"]
      assert files["mix.exs"] =~ "{:ecto_enum,"
      assert files["mix.exs"] =~ "{:html_entities,"
      assert files["assets/db_schema/database.dbs"] =~ "Lorem Ipsum"
      assert files["assets/db_schema/light/MainLayout.svg"]
      assert files["assets/db_schema/dark/database.md"]
    end

    test "schema uses the configured id and timestamp types" do
      files = installed(["--id-type", "uuid", "--timestamps", "utc_datetime_usec"])
      schema = files["lib/test/schema.ex"]

      assert schema =~ "@primary_key {:id, Ecto.UUID, autogenerate: true}"
      assert schema =~ "@timestamps_opts [type: :utc_datetime_usec]"
      # Without --exdoc or --auth0 their blocks are dropped.
      refute schema =~ "@before_compile"
      refute schema =~ "EctoURI"
    end

    test "rest group: enhanced error view and postman collection" do
      files = installed(["--health", "--project-name", "Lorem Ipsum"])

      assert files["lib/test_web/controllers/error_json.ex"] =~ "Ecto.Changeset"
      assert files["test/test_web/controllers/error_json_test.exs"]
      assert files["test.postman_collection.json"] =~ "Lorem Ipsum"
    end

    test "base testing files and ConnCase MockHelper import" do
      files = installed([])

      assert files["test/test/application_test.exs"] =~ "defmodule Test.ApplicationTest do"
      assert files["test/test_web/telemetry_test.exs"]
      assert files["test/test_web/controllers/page_controller_test.exs"]
      assert files["test/support/fixtures.ex"] =~ "defmodule Test.Fixtures do"
      assert files["test/support/mock_helper.ex"] =~ "defmodule Test.MockHelper do"
      assert files["test/support/conn_case.ex"] =~ "import Test.MockHelper"
      assert files["mix.exs"] =~ "{:mock,"
    end

    test "is a no-op with a notice when already installed" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.enhancements", [])
      |> apply_igniter!()
      |> Igniter.compose_task("workbench.install.enhancements", [])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "already installed"))
    end
  end

  describe "composition through chiefs_setup" do
    test "the collection composes the module enhancements with its recipe argv" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.chiefs_setup", [])
      |> assert_creates("lib/test/schema.ex", fn content ->
        assert content =~ "Ecto.UUID"
      end)
      |> assert_creates("lib/test/helper.ex")
    end
  end
end
