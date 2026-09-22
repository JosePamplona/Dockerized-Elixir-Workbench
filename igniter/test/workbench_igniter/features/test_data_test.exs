defmodule WorkbenchIgniter.Features.TestDataTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.TestData

  @task "workbench.install.test_data"

  defp on_ash(igniter) do
    igniter
    |> Igniter.Project.Deps.add_dep({:ash, "~> 3.0"})
    |> apply_igniter!()
  end

  defp without_ecto(igniter) do
    igniter
    |> Igniter.Project.Deps.remove_dep(:postgrex)
    |> Igniter.Project.Deps.remove_dep(:ecto_sql)
    |> apply_igniter!()
  end

  defp content(igniter, path) do
    igniter
    |> Igniter.include_existing_file(path)
    |> Map.fetch!(:rewrite)
    |> Rewrite.source!(path)
    |> Rewrite.Source.get(:content)
  end

  describe "on the Ecto line" do
    test "ex_machina and faker, test-only" do
      phx_test_project()
      |> Igniter.compose_task(@task, [])
      |> assert_has_patch("mix.exs", """
      + | {:ex_machina, "~> 2.8", only: :test}
      """)
      |> assert_has_patch("mix.exs", """
      + | {:faker, "~> 0.19", only: :test}
      """)
    end

    test "the factory module on the project's repo, with its rules and no factory" do
      igniter = phx_test_project() |> Igniter.compose_task(@task, []) |> apply_igniter!()
      factory = content(igniter, "test/support/factory.ex")

      assert factory =~ "defmodule Test.Factory do"
      assert factory =~ "use ExMachina.Ecto, repo: Test.Repo"
      assert factory =~ "Unique by sequence"
      assert factory =~ "# def user_factory do"
      refute factory =~ ~r/^\s*def \w+_factory/m
    end

    test "the test that inserts every factory, in the sandbox" do
      igniter = phx_test_project() |> Igniter.compose_task(@task, []) |> apply_igniter!()
      test = content(igniter, "test/test/factory_test.exs")

      assert test =~ "defmodule Test.FactoryTest do"
      assert test =~ "use Test.DataCase, async: true"
      assert test =~ "Test.Factory.__info__(:functions)"
      assert test =~ ~s|test "\#{factory} inserts"|
    end

    test "both libraries started before ExUnit, in the cartridge's block" do
      igniter = phx_test_project() |> Igniter.compose_task(@task, []) |> apply_igniter!()
      helper = content(igniter, "test/test_helper.exs")

      assert {:ok, body} = WorkbenchIgniter.BlockFile.block(helper, "test_data")
      assert body =~ "{:ok, _} = Application.ensure_all_started(:ex_machina)\nFaker.start()"

      [before, _] = String.split(helper, "ExUnit.start()", parts: 2)
      assert before =~ "Faker.start()"
    end

    test "is a no-op the second time" do
      phx_test_project()
      |> Igniter.compose_task(@task, [])
      |> apply_igniter!()
      |> Igniter.compose_task(@task, [])
      |> assert_unchanged()
    end

    test "a project that took the old exmachina box gets the rest" do
      igniter =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ex_machina, "~> 2.8", only: :test})
        |> apply_igniter!()

      assert {true, _} = TestData.installed?(igniter)

      igniter
      |> Igniter.compose_task(@task, [])
      |> assert_creates("test/support/factory.ex")
      |> assert_has_patch("mix.exs", """
      + | {:faker, "~> 0.19", only: :test}
      """)
    end

    test "a factory module the project already has is left alone" do
      igniter =
        phx_test_project()
        |> Igniter.Project.Module.create_module(Test.Factory, "def mine, do: :ok")
        |> apply_igniter!()
        |> Igniter.compose_task(@task, [])

      assert Enum.any?(igniter.notices, &(&1 =~ "Test.Factory already exists"))
      refute diff(igniter) =~ "use ExMachina.Ecto"
    end
  end

  describe "on the Ash line" do
    test "faker and the generator, no ExMachina" do
      igniter = phx_test_project() |> on_ash() |> Igniter.compose_task(@task, [])

      assert_has_patch(igniter, "mix.exs", """
      + | {:faker, "~> 0.19", only: :test}
      """)

      refute diff(igniter) =~ "ex_machina"
      refute Igniter.exists?(igniter, "test/support/factory.ex")

      generator = igniter |> apply_igniter!() |> content("test/support/generator.ex")
      assert generator =~ "defmodule Test.Generator do"
      assert generator =~ "use Ash.Generator"
      assert generator =~ "changeset_generator"
    end

    test "Faker's line alone in the helper" do
      helper =
        phx_test_project()
        |> on_ash()
        |> Igniter.compose_task(@task, [])
        |> apply_igniter!()
        |> content("test/test_helper.exs")

      assert {:ok, body} = WorkbenchIgniter.BlockFile.block(helper, "test_data")
      assert String.trim(body) == "Faker.start()"
    end
  end

  test "a project without Ecto is refused, naming ecto — Ash or not" do
    igniter = phx_test_project() |> without_ecto() |> Igniter.compose_task(@task, [])

    assert [issue] = igniter.issues
    assert issue =~ "test_data builds on ecto"
    assert issue =~ "./wb.sh add ecto"

    igniter = phx_test_project() |> without_ecto() |> on_ash() |> Igniter.compose_task(@task, [])
    assert [issue] = igniter.issues
    assert issue =~ "test_data builds on ecto"
  end

  test "the manifest builds on ecto" do
    assert WorkbenchIgniter.Features.TestData.requires() == ["ecto"]
  end
end
