defmodule Mix.Tasks.CoverTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureIO
  import Mock

  alias Mix.Tasks.Cover

  @passing_output """
  Running ExUnit with seed: 0, max_cases: 1

  MyApp.FooTest [test/my_app/foo_test.exs]
    * test run/1 does something (12.5ms) [L#10]
    * test run/1 another thing (3ms) [L#15]
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
    * test run/1 does something (12.5ms) [L#10]
    * test run/1 another thing (3ms) [L#15]

    1) test run/1 does something (MyApp.FooTest)
       Assertion with == failed
       code:  assert 1 == 2

  Finished in 4.5 seconds (0.8s async, 3.7s sync)
  2 tests, 1 failure
  """

  # Structured results, as dumped by Mix.Tasks.Cover.Formatter.
  @passing_json Jason.encode!(%{
                  meta: %{seed: 0, max_cases: 1, run_us: 4_500_000, async_us: 800_000},
                  tests: [
                    %{
                      module: "MyApp.FooTest",
                      file: "test/my_app/foo_test.exs",
                      line: 10,
                      describe: "run/1",
                      name: "does something",
                      time_us: 12_500,
                      state: "passed",
                      detail: nil
                    },
                    %{
                      module: "MyApp.FooTest",
                      file: "test/my_app/foo_test.exs",
                      line: 15,
                      describe: "run/1",
                      name: "another thing",
                      time_us: 3_000,
                      state: "passed",
                      detail: nil
                    },
                    %{
                      module: "MyApp.FooTest",
                      file: "test/my_app/foo_test.exs",
                      line: 20,
                      describe: nil,
                      name: "skipped one",
                      time_us: nil,
                      state: "skipped",
                      detail: nil
                    },
                    %{
                      module: "MyApp.BarTest",
                      file: "test/my_app/bar_test.exs",
                      line: 5,
                      describe: nil,
                      name: "sorts first",
                      time_us: 1_000,
                      state: "passed",
                      detail: nil
                    }
                  ]
                })

  @failing_json Jason.encode!(%{
                  meta: %{seed: 0, max_cases: 1, run_us: 4_500_000, async_us: 800_000},
                  tests: [
                    %{
                      module: "MyApp.FooTest",
                      file: "test/my_app/foo_test.exs",
                      line: 10,
                      describe: "run/1",
                      name: "does something",
                      time_us: 12_500,
                      state: "failed",
                      detail:
                        "  1) test run/1 does something (MyApp.FooTest)\n" <>
                          "     test/my_app/foo_test.exs:10\n" <>
                          "     Assertion with == failed\n" <>
                          "     code:  assert 1 == 2\n" <>
                          "     left:  1\n" <>
                          "     right: 2"
                    },
                    %{
                      module: "MyApp.FooTest",
                      file: "test/my_app/foo_test.exs",
                      line: 15,
                      describe: "run/1",
                      name: "another thing",
                      time_us: 3_000,
                      state: "passed",
                      detail: nil
                    }
                  ]
                })

  @empty_json Jason.encode!(%{meta: %{}, tests: []})

  defp run_capturing_report(console, json) do
    parent = self()

    with_mocks [
      {File, [:passthrough], write!: fn path, content -> send(parent, {:write, path, content}) end}
    ] do
      capture_io(fn -> Cover.run(test_report_output: console, test_report_json: json) end)
    end

    assert_received {:write, "./TESTING.md", testing}
    testing
  end

  # mix cover
  describe "cover run/1" do
    test "generate test & coverage report files to integrate with ExDoc." do
      with_mocks [
        {File, [:passthrough], write!: fn _, _ -> :ok end}
      ] do
        output =
          capture_io(fn ->
            Cover.run(test_report_output: @passing_output, test_report_json: @passing_json)
          end)

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

    test "render the coverage section with per-file links and totals." do
      content = run_capturing_report(@passing_output, @passing_json)

      assert content =~ "## Coverage"
      assert content =~ "Full test coverage report: [Test Coverage Overview](./cover)."
      assert content =~ "| Coverage | Status | File | Lines | Relevant | Missed |"
      assert content =~ "| 90.0% | ✅ | [`lib/my_app/foo.ex`](cover#lib/my_app/foo.ex) | 20 | 10 | 1 |"
      assert content =~ "| **95.0%** | ✅ | | **30** | **15** | **1** |"
    end

    test "render the execution result board." do
      content = run_capturing_report(@passing_output, @passing_json)

      assert content =~ "# Test Suite Report"
      assert content =~ "> #### Execution Result Board {: .neutral}"
      assert content =~ "> | Test Success ratio | 100% | 100% | ✅ |"
      assert content =~ "> | Test Coverage ratio | 95% | 80% | ✅ |"
      assert content =~ "> | Total Tests | 4 | |"
      assert content =~ "> | passing | 3 | ✅ |"
      assert content =~ "> | skipped | 1 | ➖ |"
      assert content =~ "> - Ran ExUnit with: seed: **0**, max_cases: **1**"
      assert content =~ "> - Time: **4.5s** (**0.8s** async, **3.7s** sync)"
      assert content =~ "> - Status: ✅ **Pass**"
    end

    test "render one section per test module with per-test rows." do
      content = run_capturing_report(@passing_output, @passing_json)

      # Passing modules carry no mark in their heading
      assert content =~ "## MyApp.FooTest"
      refute content =~ "## ❌ MyApp.FooTest"
      assert content =~ "Module tests: **3**, passing: **2**, skipped: **1**, time: **15.5ms**"
      assert content =~ "| Line | Status | Test | Time |"
      assert content =~ "| ✅ | does something | 12.5ms |"
      assert content =~ "| ✅ | another thing | 3.0ms |"
      assert content =~ "| ➖ | skipped one | |"
      assert content =~ "L#10"
    end

    test "group tests under their describe block as a nested heading." do
      content = run_capturing_report(@passing_output, @passing_json)

      # The describe nests as H3 under the module H2, in execution order;
      # the test without describe renders right under the module.
      assert content =~ "### run/1"

      assert [_before_module, module_section] = String.split(content, "## MyApp.FooTest")
      assert [no_describe, describe_section] = String.split(module_section, "### run/1")
      assert no_describe =~ "| ➖ | skipped one | |"
      assert describe_section =~ "| ✅ | does something | 12.5ms |"
    end

    test "sort the module sections alphabetically." do
      content = run_capturing_report(@passing_output, @passing_json)

      # BarTest ran last but renders first: the report is ordered by
      # module name, not by execution order. The coverage section renders
      # before any module.
      assert [meta, after_bar] = String.split(content, "## MyApp.BarTest")
      assert meta =~ "## Coverage"
      assert after_bar =~ "## MyApp.FooTest"
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
            capture_io(fn ->
              Cover.run(test_report_output: @failing_output, test_report_json: @failing_json)
            end)
          end
        )
      end

      # The report is still written, marking the failed test and its detail
      assert_received {:write, "./TESTING.md", content}
      # The failing module is flagged in its heading (visible in the
      # ExDoc sidebar)
      assert content =~ "## ❌ MyApp.FooTest"
      assert content =~ "| ❌ | does something | 12.5ms |"
      # No coverage table in the output: the board only scores the suite
      # and the coverage section is omitted
      refute content =~ "## Coverage"
      assert content =~ "> #### Execution Result Board {: .error}"
      assert content =~ "> | Test Success ratio | 50% | 100% | ❌ |"
      refute content =~ "Test Coverage ratio"
      assert content =~ "> | failures | 1 | ❌ |"
      assert content =~ "> - Status: ❌ **Not Pass**"
      # The failure detail renders as an ExDoc error admonition: numbered
      # title with the test line, the message as a list item, and the
      # assertion body fenced under it — all inside the blockquote
      assert content =~ "> #### Fail 1 (L#10) - does something {: .error}"
      assert content =~ "> Assertion with == failed"
      assert content =~ "> ```elixir"
      assert content =~ "> code:  assert 1 == 2"
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
                """,
                test_report_json: @empty_json
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
            capture_io(fn ->
              Cover.run(test_report_output: "", test_report_json: @empty_json)
            end)
          end
        )
      end
    end
  end
end
