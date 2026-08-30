defmodule WorkbenchIgniter.Features.EctoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp no_ecto_project, do: WorkbenchIgniter.TestProject.new(~w(--no-ecto), %{".env" => "PORT=\"4000\"\n"})

  test "a --no-ecto project has no Ecto, a default one has" do
    assert {false, _} = WorkbenchIgniter.Features.Ecto.installed?(no_ecto_project())
    assert {true, _} = WorkbenchIgniter.Features.Ecto.installed?(phx_test_project())
  end

  test "puts in what phx.new generates for Ecto with Postgres, and the database URL" do
    igniter = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", [])

    igniter
    |> assert_creates("lib/test/repo.ex", fn content -> assert content =~ "adapter: Ecto.Adapters.Postgres" end)
    |> assert_creates("test/support/data_case.ex")
    |> assert_creates("priv/repo/seeds.exs")
    |> assert_has_patch("mix.exs", """
    + | {:ecto_sql, "~> 
    """)
    |> assert_has_patch("mix.exs", """
    + | {:postgrex, ">= 0.0.0"},
    """)
    |> assert_has_patch("lib/test/application.ex", """
    + | Test.Repo,
    """)
    |> assert_has_patch("config/config.exs", """
    + | ecto_repos: [Test.Repo],
    """)

    assert igniter.issues == []
    files = apply_igniter!(igniter).assigns[:test_files]
    assert files["config/runtime.exs"] =~ ~s|System.get_env("DATABASE_URL")|
    assert files[".env"] =~ ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|
    assert files[".env.sample"] =~ "DATABASE_URL="
  end

  test "--database sqlite3 brings the SQLite adapter and a path instead of a URL" do
    files = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", ~w(--database sqlite3)) |> apply_igniter!() |> Map.fetch!(:assigns) |> Map.fetch!(:test_files)

    assert files["lib/test/repo.ex"] =~ "Ecto.Adapters.SQLite3"
    assert files["mix.exs"] =~ ":ecto_sqlite3"
    refute files["mix.exs"] =~ ":postgrex"
    assert files["config/runtime.exs"] =~ ~s|System.get_env("DATABASE_PATH")|
    assert files[".env"] =~ ~s|DATABASE_PATH="test_prod.db"|
  end

  test "--binary-id: the generators entry, as phx.new --binary-id writes it" do
    files = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", ~w(--binary-id)) |> apply_igniter!() |> Map.fetch!(:assigns) |> Map.fetch!(:test_files)
    assert files["config/config.exs"] =~ "binary_id: true"
    plain = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", []) |> apply_igniter!() |> Map.fetch!(:assigns) |> Map.fetch!(:test_files)
    refute plain["config/config.exs"] =~ "binary_id: true"
  end

  test "rejects a database phx.new does not know" do
    igniter = no_ecto_project() |> Igniter.compose_task("workbench.install.ecto", ~w(--database oracle))
    assert Enum.any?(igniter.issues, &(&1 =~ "Unknown --database"))
  end

  test "is a no-op with a notice when Ecto is in" do
    phx_test_project() |> Igniter.compose_task("workbench.install.ecto", []) |> assert_unchanged()
  end
end
