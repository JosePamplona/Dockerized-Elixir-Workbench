defmodule Mix.Tasks.Cover.Formatter do
  @moduledoc """
  ExUnit formatter that dumps the suite results as structured JSON for
  `mix cover`, which renders them into the testing report.

  Runs alongside the default console formatter (`--formatter
  ExUnit.CLIFormatter`, so the console output stays), and captures per
  test what the console cannot express unambiguously:
  module, file, line, describe block, bare name, time, state and the
  formatted failure detail.
  """

  use GenServer

  # Consumed (and removed) by `mix cover` right after the suite run.
  @output "cover/tests.json"

  @impl GenServer
  def init(opts) do
    meta = %{seed: opts[:seed], max_cases: opts[:max_cases]}

    {:ok, %{meta: meta, tests: []}}
  end

  @impl GenServer
  def handle_cast({:test_finished, test}, state) do
    {test_state, detail} = state_fields(test)

    entry = %{
      module: inspect(test.module),
      file: Path.relative_to_cwd(test.tags.file),
      line: test.tags.line,
      describe: test.tags[:describe],
      name: bare_name(test),
      time_us: test.time,
      state: test_state,
      detail: detail
    }

    {:noreply, %{state | tests: [entry | state.tests]}}
  end

  def handle_cast({:suite_finished, times}, state) do
    meta = Map.merge(state.meta, %{run_us: times[:run], async_us: times[:async]})
    report = %{meta: meta, tests: Enum.reverse(state.tests)}

    File.mkdir_p!(Path.dirname(@output))
    File.write!(@output, Jason.encode!(report))

    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  # ExUnit reports a test name as "test [describe ]name": strip the
  # prefixes back off to recover the bare name.
  defp bare_name(test) do
    base =
      test.name
      |> Atom.to_string()
      |> String.replace_prefix("test ", "")

    case test.tags[:describe] do
      nil -> base
      describe -> String.replace_prefix(base, describe <> " ", "")
    end
  end

  defp state_fields(%{state: nil}), do: {"passed", nil}
  defp state_fields(%{state: {:excluded, _}}), do: {"skipped", nil}
  defp state_fields(%{state: {:skipped, _}}), do: {"skipped", nil}
  defp state_fields(%{state: {:invalid, _}}), do: {"failed", nil}

  defp state_fields(%{state: {:failed, failures}} = test) do
    detail =
      test
      |> ExUnit.Formatter.format_test_failure(failures, 1, :infinity, fn _, msg -> msg end)
      |> String.trim_trailing()

    {"failed", detail}
  end
end
