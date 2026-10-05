defmodule WorkbenchIgniter.Features.VersionManagerTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Igniter.Test

  alias WorkbenchIgniter.Features.VersionManager

  @otp :erlang.system_info(:otp_release)

  defp installed(argv \\ []) do
    phx_test_project()
    |> Igniter.compose_task("workbench.install.version_manager", argv)
    |> apply_igniter!()
  end

  defp file(igniter, path), do: igniter.assigns[:test_files][path]

  describe "mix workbench.install.version_manager" do
    test "writes asdf's file with the versions running the installer" do
      igniter = installed()
      file = file(igniter, ".tool-versions")

      # Elixir with the OTP it runs on: a bare version is the build
      # against the oldest OTP that Elixir supports.
      assert file =~
               ~r/\Aerlang #{@otp}\S*\nelixir #{Regex.escape(System.version())}-otp-#{@otp}\n\z/

      refute file(igniter, "mise.toml")
    end

    test "--manager mise writes mise.toml instead" do
      igniter = installed(["--manager", "mise"])

      assert file(igniter, "mise.toml") =~
               ~r/\A\[tools\]\nerlang = "#{@otp}[^"]*"\nelixir = "#{Regex.escape(System.version())}-otp-#{@otp}"\n\z/

      refute file(igniter, ".tool-versions")
    end

    test "refuses a manager it does not know" do
      phx_test_project()
      |> Igniter.compose_task("workbench.install.version_manager", ["--manager", "rtx"])
      |> assert_has_issue(&(&1 =~ "--manager must be one of asdf, mise, got: rtx"))
    end

    test "is a no-op on a second run, and never overwrites an existing pin" do
      installed()
      |> Igniter.compose_task("workbench.install.version_manager", ["--manager", "mise"])
      |> assert_unchanged()
      |> assert_has_notice(&(&1 =~ "the pin is in"))
    end

    test "a version file of the other manager is a pin too" do
      for path <- ["mise.toml", ".mise.toml"] do
        phx_test_project(files: %{path => "[tools]\nerlang = \"27.3\"\n"})
        |> Igniter.compose_task("workbench.install.version_manager", [])
        |> assert_unchanged()
        |> assert_has_notice(&(&1 =~ "the pin is in"))
      end
    end
  end

  describe "state/1" do
    test "says the manager back off the file that is there" do
      assert {%{manager: "asdf"}, _} = VersionManager.state(installed())
      assert {%{manager: "mise"}, _} = VersionManager.state(installed(["--manager", "mise"]))
      assert {%{}, _} = VersionManager.state(phx_test_project())
    end

    test "reads a file the project wrote by hand, mise's dotfile too" do
      for {path, manager} <- [{".tool-versions", "asdf"}, {".mise.toml", "mise"}] do
        project = phx_test_project(files: %{path => "# by hand\n"})
        assert {%{manager: ^manager}, _} = VersionManager.state(project)
      end
    end
  end
end
