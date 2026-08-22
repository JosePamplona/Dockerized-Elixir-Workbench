defmodule Mix.Tasks.Workbench.Install.DepsTest do
  @moduledoc """
  Table-driven tests for the trivial dependency-only installers.

  All of them share the exact same contract — add one dep to `mix.exs`,
  be a no-op on re-run — so a single parameterized suite covers the group.
  """

  use ExUnit.Case, async: true

  import Igniter.Test

  @dep_tasks [
    {"workbench.install.credo", ~S|{:credo, "~> 1.7", only: [:dev, :test], runtime: false}|},
    {"workbench.install.githooks", ~S|{:git_hooks, "~> 0.7", only: :dev, runtime: false}|},
    {"workbench.install.exmachina", ~S|{:ex_machina, "~> 2.8", only: :test}|},
    {"workbench.install.mock", ~S|{:mock, "~> 0.3", only: :test}|},
    {"workbench.install.exdebug", ~S|{:ex_debug, "~> 1.0"}|},
    {"workbench.install.psql_extras", ~S|{:ecto_psql_extras, "~> 0.8", only: :dev}|}
  ]

  for {task, dep_line} <- @dep_tasks do
    @task task
    @dep_line dep_line

    test "mix #{task} adds the dependency to mix.exs" do
      test_project()
      |> Igniter.compose_task(@task, [])
      |> assert_has_patch("mix.exs", """
      + | #{@dep_line}
      """)
    end

    test "mix #{task} is a no-op when the dependency is already present" do
      test_project()
      |> Igniter.compose_task(@task, [])
      |> apply_igniter!()
      |> Igniter.compose_task(@task, [])
      |> assert_unchanged()
    end
  end
end
