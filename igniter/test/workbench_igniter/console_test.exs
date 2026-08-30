defmodule WorkbenchIgniter.ConsoleTest do
  @moduledoc false

  # What each cartridge adds to the console, as the catalog carries it.

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features

  test "doors, probes and tabs, with their conditions" do
    by = fn name -> Features.entry(Enum.find(Features.catalog(), &(&1.name() == name))).console end

    assert by.("exdoc").doors == [%{label: "docs", path: "/dev/docs", when: nil}]
    assert by.("coveralls").doors == [%{label: "coverage", path: "/dev/docs/cover", when: %{cartridge: "exdoc"}}]
    assert by.("ash").doors == [%{label: "admin", path: "/admin", when: %{with: "ash_admin"}}]
    assert Enum.map(by.("rest").doors, & &1.path) == ["/dev/swagger", "/dev/openapi"]
    assert by.("healthcheck2").probes == [%{label: "live", path: "{path}/live"}, %{label: "ready", path: "{path}/ready"}]
    assert by.("clustering").tabs == [:cluster]
    assert by.("credo") == %{doors: [], probes: [], tabs: []}
  end

  test "every door and probe path starts with a slash or an {option}" do
    for feature <- Features.catalog(), %{path: path} <- Features.entry(feature).console.doors ++ Features.entry(feature).console.probes do
      assert String.starts_with?(path, ["/", "{"]), "#{feature.name()}: #{path}"
    end
  end

  test "healthcheck2 reports the prefix it was inserted with" do
    igniter = phx_test_project() |> Igniter.compose_task("workbench.install.healthcheck2", ~w(--path /probe)) |> apply_igniter!()
    assert {%{path: "/probe"}, _} = Features.Healthcheck2.state(igniter)
    assert {%{}, _} = Features.Healthcheck2.state(phx_test_project())
  end
end
