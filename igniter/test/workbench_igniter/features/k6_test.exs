defmodule WorkbenchIgniter.Features.K6Test do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.K6

  defp install(project \\ phx_test_project()),
    do: Igniter.compose_task(project, "workbench.install.k6", [])

  describe "mix workbench.install.k6" do
    test "writes the smoke test, aimed by BASE_URL" do
      install()
      |> assert_creates("k6/smoke.js", fn content ->
        assert content =~ "import http from 'k6/http';"
        assert content =~ "export const options = { vus: 5, duration: '15s' };"
        assert content =~ "const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';"
        assert content =~ "http.get(`${BASE_URL}/`)"
        assert content =~ "'status is 200': (r) => r.status === 200"
      end)
    end

    test "the file is the mark" do
      assert {false, _} = K6.installed?(phx_test_project())
      assert {true, _} = install() |> apply_igniter!() |> K6.installed?()
    end

    test "is a no-op when the file is there" do
      install() |> apply_igniter!() |> install() |> assert_unchanged()
    end

    test "asks nothing of the project: a bare one takes it" do
      install(test_project()) |> assert_creates("k6/smoke.js")
    end
  end

  describe "the manifest" do
    test "asks the workspace for the k6 container" do
      assert K6.services(%{}) == ["k6"]
      assert K6.requires() == []
    end
  end
end
