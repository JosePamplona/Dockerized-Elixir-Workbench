defmodule WorkbenchIgniter.Features.ProjectShapeTest do
  @moduledoc false

  # The cartridges that adapt to what the project has of phx.new's
  # capabilities read it off the project, they do not ask.

  use ExUnit.Case, async: true

  import Igniter.Test

  defp project(extra), do: WorkbenchIgniter.TestProject.new(extra)

  defp files(igniter), do: apply_igniter!(igniter).assigns[:test_files]

  test "enhancements: no Ecto group and no mailbox test on a project without them, and no flag for it" do
    files =
      project(~w(--no-ecto --no-mailer))
      |> Igniter.compose_task("workbench.install.enhancements", ["--project-name", "Test"])
      |> files()

    refute files["lib/test/helper.ex"]
    refute files["mix.exs"] =~ "ecto_enum"
    refute files["test/test_web/controllers/mailbox_controller_test.exs"]
    assert files["test/test_web/controllers/dashboard_controller_test.exs"]
    assert files["test/support/fixtures.ex"]

    with_ =
      project([])
      |> Igniter.compose_task("workbench.install.enhancements", ["--project-name", "Test"])
      |> files()

    assert with_["lib/test/helper.ex"]
    assert with_["test/test_web/controllers/mailbox_controller_test.exs"]
  end

  test "exdoc: no database page on a project without Ecto" do
    igniter =
      project(~w(--no-ecto))
      |> Igniter.compose_task("workbench.install.exdoc", [
        "--project-name",
        "Test",
        "--repo-url",
        "https://example.com/r"
      ])

    refute files(igniter)["guides/database.md"]

    assert files(
             project([])
             |> Igniter.compose_task("workbench.install.exdoc", [
               "--project-name",
               "Test",
               "--repo-url",
               "https://example.com/r"
             ])
           )["guides/database.md"]
  end

  test "the schemas no longer take the phx.new shape" do
    for feature <- [
          WorkbenchIgniter.Features.Enhancements,
          WorkbenchIgniter.Features.Exdoc,
          WorkbenchIgniter.Features.Coverage
        ] do
      keys = Keyword.keys(feature.info([], nil).schema)

      assert Enum.filter(keys, &(&1 in [:ecto, :html, :mailer, :dashboard])) == [],
             "#{feature.name()} still asks #{inspect(keys)}"

      assert Enum.all?(keys, &Keyword.has_key?(feature.option_docs(), &1)),
             "#{feature.name()} has undocumented options: #{inspect(keys -- Keyword.keys(feature.option_docs()))}"
    end
  end
end
