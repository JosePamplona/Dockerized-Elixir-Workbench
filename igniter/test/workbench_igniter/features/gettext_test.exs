defmodule WorkbenchIgniter.Features.GettextTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  defp no_gettext_project, do: WorkbenchIgniter.TestProject.new(~w(--no-gettext))

  test "a --no-gettext project has none, a default one has" do
    assert {false, _} = WorkbenchIgniter.Features.Gettext.installed?(no_gettext_project())
    assert {true, _} = WorkbenchIgniter.Features.Gettext.installed?(phx_test_project())
  end

  test "puts in what phx.new generates for gettext" do
    igniter = no_gettext_project() |> Igniter.compose_task("workbench.install.gettext", [])

    igniter
    |> assert_creates("lib/test_web/gettext.ex", fn content -> assert content =~ "use Gettext.Backend, otp_app: :test" end)
    |> assert_creates("priv/gettext/errors.pot")
    |> assert_has_patch("mix.exs", """
    + | {:gettext, "~> 
    """)

    assert igniter.issues == []
    files = apply_igniter!(igniter).assigns[:test_files]
    assert files["lib/test_web/components/core_components.ex"] =~ "Gettext"
  end

  test "is a no-op with a notice when gettext is in" do
    phx_test_project() |> Igniter.compose_task("workbench.install.gettext", []) |> assert_unchanged()
  end
end
