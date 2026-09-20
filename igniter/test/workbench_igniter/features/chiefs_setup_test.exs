defmodule WorkbenchIgniter.Features.ChiefsSetupTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features
  alias WorkbenchIgniter.Features.ChiefsSetup

  describe "the recipe (members/1)" do
    test "default choices: the picks in insertion order, with their argv" do
      assert ChiefsSetup.members(interface: "rest") == [
               {"ansi", []},
               {"version_manager", []},
               {"toolchain", []},
               {"changelog", []},
               {"dashboard_extras", []},
               {"db_admin", []},
               {"credo", []},
               {"mock", []},
               {"test_doubles", []},
               {"exdebug", []},
               {"rest", ["--health"]},
               {"coveralls", ["--exdoc"]},
               {"exdoc", ["--coveralls"]},
               {"enhancements", ["--interface", "rest", "--exdoc", "--health"]},
               {"health_endpoint", []}
             ]
    end

    test "--interface graphql swaps the interface member" do
      members = ChiefsSetup.members(interface: "graphql")

      assert {"graphql", []} in members
      refute Enum.any?(members, fn {name, _} -> name == "rest" end)
      assert {"enhancements", ["--interface", "graphql", "--exdoc", "--health"]} in members
    end

    test "every member names a registered, non-pending cartridge" do
      for interface <- ~w(rest graphql),
          {name, _argv} <- ChiefsSetup.members(interface: interface) do
        feature = Features.named(name)
        assert feature, "unknown member: #{name}"
        refute feature.pending?()
      end
    end
  end

  describe "mix workbench.install.chiefs_setup" do
    test "refuses an unknown interface with an issue" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.chiefs_setup", ["--interface", "soap"])

      assert [issue] = igniter.issues
      assert issue =~ "--interface must be one of rest, graphql"
    end

    test "installs every pick, and the delegated mark flips" do
      igniter =
        phx_test_project()
        |> Igniter.compose_task("workbench.install.chiefs_setup", [])
        |> apply_igniter!()

      {installed?, igniter} = ChiefsSetup.installed?(igniter)
      assert installed?

      {state, _igniter} = ChiefsSetup.state(igniter)
      assert state == %{interface: "rest"}
    end

    test "is not installed while a pick is missing" do
      {installed?, igniter} = ChiefsSetup.installed?(phx_test_project())
      refute installed?

      {state, _igniter} = ChiefsSetup.state(igniter)
      assert state == %{}
    end
  end
end
