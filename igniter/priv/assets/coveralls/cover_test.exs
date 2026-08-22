defmodule Mix.Tasks.CoverTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mock

  alias Mix.Tasks.Cover

  @passing_output """
  Running ExUnit with seed: 0, max_cases: 1

  MyApp.FooTest [test/my_app/foo_test.exs]
    * test does something (12.5ms) [L#10]
    * test another thing (3ms) [L#15]
    * test skipped one (excluded) [L#20]

  Finished in 4.5 seconds (0.8s async, 3.7s sync)
  3 tests, 0 failures, 1 skipped
  ----------------
  COV    FILE                                        LINES RELEVANT   MISSED
   90.0% lib/my_app/foo.ex                              20       10        1
  100.0% lib/my_app/bar.ex                              10        5        0
  [TOTAL]  95.0%
  ----------------
  Generating report...
  Saved to: cover/
  """

  @failing_output """
  Running ExUnit with seed: 0, max_cases: 1

  MyApp.FooTest [test/my_app/foo_test.exs]
    * test does something (12.5ms) [L#10]
    * test another thing (3ms) [L#15]

    1) test does something (MyApp.FooTest)
       Assertion with == failed
       code:  assert 1 == 2

  Finished in 4.5 seconds (0.8s async, 3.7s sync)
  2 tests, 1 failure
  """

  defp run_capturing_report(fixture) do
    parent = self()

    with_mocks [
      {File, [:passthrough], write!: fn path, content -> send(parent, {:write, path, content}) end}
    ] do
      capture_io(fn -> Cover.run(test_report_output: fixture) end)
    end

    assert_received {:write, "./TESTING.md", content}
    content
  end

  # mix cover
  describe "cover run/1" do
    test "generate test & coverage report files to integrate with ExDoc." do
      with_mocks [
        {File, [:passthrough], write!: fn _, _ -> :ok end}
      ] do
        output = capture_io(fn -> Cover.run(test_report_output: @passing_output) end)

        # Check the expected console output
        assert String.split(output, "\n") == [
                 "Generating testing & coverage reports...",
                 "Success! testing & coverage reports were generated:",
                 "  ./TESTING.md",
                 "  cover/excoveralls.html",
                 "Test checks:",
                 "  Success rate: \e[38;5;2m100.0%\e[0m",
                 "  Coverage:     \e[38;5;2m95.0%\e[0m",
                 ""
               ]
      end
    end

    test "render the coverage table with per-file links and totals." do
      content = run_capturing_report(@passing_output)

      assert content =~ "# Testing reports"
      assert content =~ "Full unit tests coverage report: [Test Coverage Overview](./excoveralls.html)."
      assert content =~ "| Coverage | File | Lines | Relevant | Missed |"
      assert content =~ "| 90.0% | [`lib/my_app/foo.ex`](excoveralls.html#lib/my_app/foo.ex) | 20 | 10 | 1 |"
      assert content =~ "| **95.0%** | | **30** | **15** | **1** |"
    end

    test "render the run metadata and totals summary." do
      content = run_capturing_report(@passing_output)

      assert content =~ "Ran **ExUnit** with: seed: **0**, max_cases: **1**"
      assert content =~ "Time: **4.5s** (**0.8s** async, **3.7s** sync)"
      assert content =~ "| Total Tests | 3 | |"
      assert content =~ "| passing | 2 | ✅ |"
      assert content =~ "| skipped | 1 | ➖ |"
    end

    test "render one section per test module with per-test rows." do
      content = run_capturing_report(@passing_output)

      assert content =~ "#### MyApp.FooTest"
      assert content =~ "Module tests: **3**, passing: **2**, skipped: **1**, time: **15.5ms**"
      assert content =~ "| Line | Status | Test | Time |"
      assert content =~ "| ✅ | does something | 12.5ms |"
      assert content =~ "| ✅ | another thing | 3ms |"
      assert content =~ "| ➖ | skipped one | |"
      assert content =~ "L#10"
    end

    test "generate files with failing tests." do
      parent = self()

      with_mocks [
        {File, [:passthrough],
         write!: fn path, content -> send(parent, {:write, path, content}) end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Failure: 1 tests have not pass.",
          fn ->
            capture_io(fn -> Cover.run(test_report_output: @failing_output) end)
          end
        )
      end

      # The report is still written, marking the failed test and its detail
      assert_received {:write, "./TESTING.md", content}
      assert content =~ "| ❌ | does something | 12.5ms |"
      assert content =~ "| failures | 1 | ❌ |"
      assert content =~ "1) test does something (MyApp.FooTest)"
    end

    test "generate files with insufficient overall coverage." do
      with_mocks [
        {File, [:passthrough], write!: fn _, _ -> :ok end}
      ] do
        # Check the expected console output
        assert_raise(
          Mix.Error,
          "Failure: Total coverage below 100%.",
          fn ->
            capture_io(fn ->
              Cover.run(
                test_report_output: """
                2 tests, 0 failures
                [TOTAL]  55.2%
                FAILED: Expected minimum coverage of 100%, got 55.2%.
                """
              )
            end)
          end
        )
      end
    end

    test "generate files with error on tests." do
      with_mocks [
        {File, [:passthrough], write!: fn _, _ -> :ok end}
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
