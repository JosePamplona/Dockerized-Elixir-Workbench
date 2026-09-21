defmodule WorkbenchIgniter.ConsoleTest do
  @moduledoc false

  # What each cartridge adds to the console, as the catalog carries it.

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features

  test "doors and tabs, with their conditions" do
    by = fn name ->
      Features.entry(Enum.find(Features.catalog(), &(&1.name() == name))).console
    end

    # A page on disk: what the tool writes, served by the console off
    # the workspace, whether the app runs or not.
    assert by.("exdoc").doors == [
             %{label: "docs", path: "doc/", output: %{dir: "doc", index: "index.html"}, when: nil}
           ]

    assert by.("coverage").doors == [
             %{
               label: "coverage",
               path: "cover/",
               output: %{dir: "cover", index: "excoveralls.html"},
               when: nil
             }
           ]

    assert by.("ash").doors == [%{label: "admin", path: "/admin", when: %{with: "ash_admin"}}]
    assert Enum.map(by.("rest").doors, & &1.path) == ["/dev/swagger", "/dev/openapi"]

    # A health endpoint is a door like any other: the project's route,
    # which the console reads and calls — never a probe the project
    # would carry for the workbench's sake.
    assert by.("health_probe").doors == [
             %{label: "live", path: "{path}/live", when: nil},
             %{label: "ready", path: "{path}/ready", when: nil}
           ]

    assert by.("clustering").tabs == [:cluster]
    assert by.("credo") == %{doors: [], tabs: []}
  end

  test "every route starts with a slash or an {option}; an output is a relative dir" do
    for feature <- Features.catalog(), door <- Features.entry(feature).console.doors do
      case door do
        %{output: %{dir: dir}} ->
          assert {:ok, ^dir} = Path.safe_relative(dir), "#{feature.name()}: #{dir}"

        %{path: path} ->
          assert String.starts_with?(path, ["/", "{"]), "#{feature.name()}: #{path}"
      end
    end
  end

  test "health_probe reports the prefix it was inserted with" do
    igniter =
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_probe", ~w(--path /probe))
      |> apply_igniter!()

    assert {%{path: "/probe"}, _} = Features.HealthProbe.state(igniter)
    assert {%{}, _} = Features.HealthProbe.state(phx_test_project())
  end

  test "health_endpoint reports the endpoint it was inserted with, and its OpenAPI variant" do
    igniter =
      phx_test_project()
      |> Igniter.compose_task(
        "workbench.install.health_endpoint",
        ~w(--endpoint /health3 --open-api)
      )
      |> apply_igniter!()

    assert {%{endpoint: "/health3", open_api: true}, _} = Features.HealthEndpoint.state(igniter)

    igniter =
      phx_test_project()
      |> Igniter.compose_task("workbench.install.health_endpoint", [])
      |> apply_igniter!()

    assert {state, _} = Features.HealthEndpoint.state(igniter)
    assert state == %{endpoint: "/health", open_api: false}

    assert {%{}, _} = Features.HealthEndpoint.state(phx_test_project())
  end
end
