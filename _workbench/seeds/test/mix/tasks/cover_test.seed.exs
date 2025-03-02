defmodule Mix.Tasks.CoverTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mock

  alias Mix.Tasks.Cover

  # mix cover
  describe "cover run/1" do
    test "generate test & coverage report files to integrate with ExDoc." do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        output = capture_io(fn ->
          Cover.run(
            test_report_output: """
              * test some testing (excluded) [L#1]\n
              64 tests, 0 failures\n
              some \rcartridge return\n
              Randomized with seed 0\n
              [TOTAL] 100.0%\n
              ----------------\n
              Generating report...\n
              Saved to: ./some/path\n
              """
          )
        end)

        # Check the expected console output
        assert String.split(output, "\n") == [
          "Generating testing & coverage reports...",
            "Success! testing & coverage reports were generated:",
            "  assets/exdoc/testing.md",
            "  assets/exdoc/cover/html/excoveralls.html",
            "Test checks:",
            "  Success rate: \e[38;5;2m100.0%\e[0m",
            "  Coverage:     \e[38;5;2m100.0%\e[0m", 
            ""
        ]
      end
    end

    test "generate files with insufficient overall coverage." do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Failure: Total coverage below 100%.",
          fn ->
            capture_io(fn ->
              Cover.run(test_report_output: """
                * test some testing (excluded) [L#1]\n
                FAILED: Expected minimum coverage of 100%
                """
              )
            end)
          end
        )
      end
    end

    test "generate files with failing tests." do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Failure: 1 tests have not pass.",
          fn ->
            capture_io(fn ->
              Cover.run(test_report_output: """
                * test some testing (excluded) [L#1]\n
                1 tests, 1 failure
                """
              )
            end)
          end
        )
      end
    end

    test "generate files with error on tests." do
      with_mocks [
        {File, [:passthrough], write!: fn(_, _) -> :ok end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Error: An error was raised.",
          fn ->
            capture_io(fn -> Cover.run(test_report_output: "") end)
          end
        )
      end
    end
  end
end
