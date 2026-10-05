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
    # A page on disk also says how it is made: the project's own Mix
    # task, which the console offers where the page is not there yet.
    assert by.("exdoc").doors == [
             %{
               label: "docs",
               path: "{output}/",
               output: %{
                 dir: "{output}",
                 index: "index.html",
                 build: [%{task: "docs", when: nil}]
               },
               when: nil
             }
           ]

    # Two commands, the first whose condition holds: `mix cover` is
    # there when the box went in with `--md-report`, which plants it, and
    # without it ExCoveralls' own task writes the same page.
    assert by.("coverage").doors == [
             %{
               label: "coverage",
               path: "{output_dir}/",
               output: %{
                 dir: "{output_dir}",
                 index: "excoveralls.html",
                 build: [
                   %{task: "cover", when: %{option: "md_report"}},
                   %{task: "coveralls.html", when: nil}
                 ]
               },
               when: nil
             }
           ]

    # Each behind the option that brings the package whose installer
    # writes the route; `/sign-in` with any strategy but api_key alone.
    assert [
             %{label: "admin", path: "/admin", when: %{option: "dev_tools", value: "ash_admin"}},
             %{label: "oban", path: "/oban", when: %{option: "automation", value: "ash_oban"}},
             %{label: "sign in", path: "/sign-in", when: %{option: "auth", value: pages}},
             %{label: "swagger", when: %{option: "api", value: "json_api"}},
             %{label: "openapi", path: "/api/json/open_api"},
             %{label: "graphiql", path: "/gql/playground", when: %{value: "graphql"}},
             %{label: "typescript", path: "/ash-typescript", when: %{value: "typescript"}}
           ] = by.("ash").doors

    assert "password" in pages and "api_key" not in pages

    assert Enum.map(by.("rest").doors, & &1.path) == ["/dev/swagger", "/dev/openapi"]

    # A health endpoint is a door like any other: the project's route,
    # which the console reads and calls — never a probe the project
    # would carry for the workbench's sake.
    assert by.("health_probe").doors == [
             %{label: "live", path: "{path}/live", when: nil},
             %{label: "ready", path: "{path}/ready", when: nil}
           ]

    assert by.("credo") == %{doors: []}
  end

  test "every route starts with a slash or an {option}; an output is a relative dir" do
    for feature <- Features.catalog(), door <- Features.entry(feature).console.doors do
      case door do
        %{output: %{dir: dir, build: build}} ->
          assert {:ok, ^dir} = Path.safe_relative(dir), "#{feature.name()}: #{dir}"

          # The command is a Mix task of the project, one word: the
          # console runs `./wb.sh mix <task>` and nothing else.
          for %{task: task} <- build do
            assert task =~ ~r/^[a-z][\w.]*$/, "#{feature.name()}: #{task}"
          end

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
