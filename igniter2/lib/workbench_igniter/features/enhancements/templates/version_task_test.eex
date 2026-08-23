defmodule Mix.Tasks.VersionTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mock

  alias Mix.Tasks.Version

  # mix version
  describe "version run/1" do
    test "update project version" do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        output = capture_io(fn -> Version.run(["0.0.0"]) end)

        # Check the expected console output
        assert String.split(output, "\n") == [
          "Setting new version...",
          "Success! project new version: 0.0.0",
          "  mix.exs",
          "  README.md",
          ""
        ]
      end
    end

    test "incompatible README.md file" do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end},
        {File, [:passthrough], read!: fn
          ("mix.exs") -> "  @version      \"0.0.0\""
          ("README.md") -> ""
        end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error, 
          "Failure: Incompatible README.md file.",
          fn ->
            capture_io(fn -> Version.run(["0.0.0"]) end)
          end
        )
      end
    end

    test "incompatible mix.exs file" do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end},
        {File, [:passthrough], read!: fn
          ("mix.exs") -> ""
          ("README.md") ->
            "![v0.0.0](https://img.shields.io/badge/version-0.0.0-white.svg)"
        end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Failure: Incompatible mix.exs file.",
          fn ->
            capture_io(fn -> Version.run(["0.0.0"]) end)
          end
        )
      end
    end
  end
end
