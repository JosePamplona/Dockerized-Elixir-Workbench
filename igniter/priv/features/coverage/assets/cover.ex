defmodule Mix.Tasks.Cover do
  use Mix.Task

  # Target filename.
  @test_filename "TESTING.md"
  # Structured test results dumped by Mix.Tasks.Cover.Formatter during
  # the suite run; consumed (and removed) right after it.
  @tests_json "cover/tests.json"
  # Processed files output path.
  @test_output_path "."
  @coverage_config "coveralls.json"
  @coverage_filename "excoveralls.html"
  # ExDoc copies the coverage output dir into the site's root (the
  # `"cover" => "/"` entry of `docs: [assets: ...]`), so the report sits
  # beside this page: relative, it resolves wherever the site is served.
  @coverage_route @coverage_filename
  @coverage_link "[Test Coverage Overview](./#{@coverage_route})"
  # coveralls.json is read at compile time when present (dev/test). The
  # production image never copies it, so compilation falls back to the
  # defaults there: harmless, since releases carry no Mix and the task
  # cannot run in them anyway.
  @external_resource @coverage_config
  @coverage_options (case File.read(@coverage_config) do
                       {:ok, content} ->
                         content
                         |> Jason.decode!(keys: :atoms)
                         |> Map.fetch!(:coverage_options)

                       {:error, _} ->
                         %{output_dir: "cover"}
                     end)
  @minimum_coverage Map.get(@coverage_options, :minimum_coverage, 0)

  @version Mix.Project.config()[:version]

  # GitHub source links — derived from ExDoc config (degrades to plain text if missing)
  @docs_config Mix.Project.config()[:docs] || []
  @source_url Mix.Project.config()[:source_url]
  # The ref is read where it is used: as an attribute of its own it is
  # unused — and warns — in a project whose docs config has no
  # `source_url`, since the `&&` below never reaches it.
  @source_url_pattern @docs_config[:source_url_pattern] ||
                        (@source_url &&
                           "#{@source_url}/blob/#{@docs_config[:source_ref] || "main"}/%{path}#L%{line}")

  # Regex patterns
  @tests ~r/(\e\[.*?m)*?\d* test(s)?, (\d*) failure/
  # \s+ instead of a literal space: excoveralls pads the total for alignment
  @total ~r/(\e\[.*?m)*?\[TOTAL]\s+(.*?%)/
  @cover ~r/(\e\[.*?m)*?FAILED: Expected minimum coverage of (.*?%)/

  @moduledoc """
  Generates the test suite report (execution result board, coverage and
  per-module sections) on `#{@test_output_path}/#{@test_filename}`, and a
  HTML page coverage report file on
  `#{@coverage_options.output_dir}/#{@coverage_filename}` to enable ExDoc
  to integrate the test & coverage documentation.

  The test results are collected structurally by the
  `Mix.Tasks.Cover.Formatter` ExUnit formatter (`#{@tests_json}`); only
  the coverage table is parsed from the console output.

  Compatible with [ExCoveralls](https://hex.pm/packages/excoveralls) v0.18.1
  """

  @shortdoc "Generates testing & coverage reports to be included in ExDocs"
  @doc false
  def run(opts) do
    Mix.shell().info("Generating testing & coverage reports...")
    File.mkdir_p!(@test_output_path)

    {output, exit_code} =
      opts
      |> Keyword.get(:test_report_output)
      |> case do
        nil ->
          # coveralls-ignore-start
          System.cmd(
            "mix",
            [
              "coveralls.html",
              "--trace",
              "--seed",
              "0",
              "--color",
              "--formatter",
              "ExUnit.CLIFormatter",
              "--formatter",
              "Mix.Tasks.Cover.Formatter"
            ],
            stderr_to_stdout: true,
            env: [{"MIX_ENV", "test"}]
          )

        # coveralls-ignore-stop

        output ->
          {output, 0}
      end

    report =
      opts
      |> Keyword.get(:test_report_json)
      |> case do
        nil ->
          # coveralls-ignore-start
          # A suite that does not compile never runs the formatter and
          # leaves no dump behind: fall back to an empty report and let
          # the console validation surface the error.
          case File.read(@tests_json) do
            {:ok, json} ->
              File.rm!(@tests_json)
              json

            {:error, _} ->
              ~s({"meta": {}, "tests": []})
          end

        # coveralls-ignore-stop

        json ->
          json
      end
      |> Jason.decode!(keys: :atoms)

    testing_report = format_report(output, report)
    File.write!("#{@test_output_path}/#{@test_filename}", testing_report)

    output
    |> validate_output(exit_code)
    |> case do
      {:ok, total} ->
        Mix.shell().info(
          "Success! testing & coverage reports were generated:\n" <>
            "  #{@test_output_path}/#{@test_filename}\n" <>
            "  #{@coverage_options.output_dir}/#{@coverage_filename}\n" <>
            "Test checks:\n" <>
            "  Success rate: \e[38;5;2m100.0%\e[0m\n" <>
            "  Coverage:     \e[38;5;2m#{total}\e[0m"
        )

      {:error, error} ->
        Mix.shell().info(output)

        {message, fallback_status} =
          case error do
            {:cover, min} -> {"Failure: Total coverage below #{min}.", 1}
            {:tests, fails} -> {"Failure: #{fails} tests have not pass.", 2}
            :raise -> {"Error: An error was raised.", 1}
          end

        # The subprocess exit code when available; the seam path (and any
        # failure detected only by parsing) still exits nonzero.
        status = if exit_code == 0, do: fallback_status, else: exit_code
        Mix.raise(message, [{:exit_status, status}])
    end
  end

  # == Private =================================================================

  defp validate_output(output, exit_code) do
    tests_matches = Regex.scan(@tests, output)
    total_matches = Regex.scan(@total, output)
    cover_matches = Regex.scan(@cover, output)

    case {tests_matches, total_matches, cover_matches, exit_code} do
      {[[_, _, _, "0"]], [[_, _, total]], [], 0} ->
        {:ok, total}

      {[[_, _, _, fails]], _, _, _} when fails != "0" ->
        {:error, {:tests, fails}}

      {_, _, [[_, _, min]], _} ->
        {:error, {:cover, min}}

      _ ->
        {:error, :raise}
    end
  end

  defp format_report(content, report) do
    [date, time] =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:microsecond)
      |> NaiveDateTime.to_string()
      |> String.split(" ")

    generated =
      "Report generated on `#{date}` at `#{time}` " <>
        "for version: **#{@version}**."

    coverage_lines =
      content
      |> String.split("\n")
      |> Enum.map(&clean_line/1)
      |> Enum.reject(&noise_line?/1)

    {_rows, coverage_total, _tail} = parse_coverage_lines(coverage_lines)

    ([
       "<!-- markdownlint-disable MD028 -->",
       "# Test Suite Report",
       "",
       generated,
       ""
     ] ++ tests_to_markdown(report, coverage_lines, coverage_total))
    |> Enum.dedup()
    |> Enum.join("\n")
  end

  defp clean_line(line) do
    line
    # Terminal overwrite pattern: text\e[Xm\r  updated_text\e[0m — keep last segment
    |> String.split("\r")
    |> List.last()
    |> String.replace(~r/\e\[[\d;]+m/, "")
    |> String.replace(~r/\\e\[[\d;]+m/, "")
  end

  defp noise_line?(line) do
    line == "----------------" or
      line == "Generating report..." or
      String.starts_with?(line, "Saved to:")
  end

  # -- Coverage table ----------------------------------------------------------

  defp coverage_to_table(lines) do
    {rows, total, tail} = parse_coverage_lines(lines)

    case rows do
      [] ->
        []

      _ ->
        sums = sum_coverage(rows)
        table_rows = Enum.map(rows, &format_coverage_row/1)

        total_row =
          "| **#{total}** " <>
          "| #{status(total, sums.relevant)} " <>
          "| " <>
          "| **#{sums.lines}** " <>
          "| **#{sums.relevant}** " <>
          "| **#{sums.missed}** |"

        table =
          [
            "| Coverage | Status | File | Lines | Relevant | Missed |",
            "| :------: | :----: | :--- | :---- | :------- | :----- |"
          ] ++ table_rows ++ [total_row]

        case tail do
          [_ | _] -> table ++ [""] ++ format_tail(tail)
          _ -> table
        end
    end
  end

  # A file with no relevant lines cannot miss the minimum; anything else
  # is checked against the configured minimum coverage.
  defp status(cov, relevant) do
    {pct, _} = Float.parse(cov)

    if relevant == 0 or pct >= @minimum_coverage, do: "✅", else: "❌"
  end

  defp parse_coverage_lines(lines) do
    row_regex = ~r/^\s*(\d+\.\d+%)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/
    total_regex = ~r/^\[TOTAL\]\s+(.+)/

    {rows_rev, total, tail_rev, _past_total?} =
      Enum.reduce(
        lines,
        {[], nil, [], false},
        fn line, {rows, total, tail, past_total?} ->
          cond do
            past_total? ->
              if line == "",
                do: {rows, total, tail, true},
                else: {rows, total, [line | tail], true}

            match = Regex.run(total_regex, line) ->
              [_, total_pct] = match
              {rows, total_pct, [], true}

            match = Regex.run(row_regex, line) ->
              [_, cov, file, lines_s, relevant, missed] = match

              entry = %{
                cov: cov,
                file: file,
                lines: String.to_integer(lines_s),
                relevant: String.to_integer(relevant),
                missed: String.to_integer(missed)
              }

              {[entry | rows], total, tail, false}

            true ->
              {rows, total, tail, false}
          end
        end
      )

    {Enum.reverse(rows_rev), total, Enum.reverse(tail_rev)}
  end

  defp sum_coverage(rows) do
    Enum.reduce(rows, %{lines: 0, relevant: 0, missed: 0}, fn row, acc ->
      %{
        lines: acc.lines + row.lines,
        relevant: acc.relevant + row.relevant,
        missed: acc.missed + row.missed
      }
    end)
  end

  defp format_coverage_row(%{
         cov: cov,
         file: file,
         lines: lines,
         relevant: relevant,
         missed: missed
       }) do
    link = "[`#{file}`](#{@coverage_route}##{file})"

    "| #{cov} " <>
      "| #{status(cov, relevant)} | #{link} | #{lines} | #{relevant} | #{missed} |"
  end

  defp format_tail(tail) do
    Enum.map(tail, fn
      "FAILED:" <> rest -> "❌ **FAILED:**#{rest}"
      line -> line
    end)
  end

  # -- Tests markdown ----------------------------------------------------------

  # Report body: execution result board, coverage section, module sections.
  defp tests_to_markdown(%{meta: meta, tests: tests}, coverage_lines, coverage_total) do
    render_board(meta, tests, coverage_total) ++
      [""] ++ coverage_section(coverage_lines) ++ module_sections(tests)
  end

  # The suite may die before excoveralls prints its table (a compile
  # error): no rows, no section.
  defp coverage_section(coverage_lines) do
    case coverage_to_table(coverage_lines) do
      [] ->
        []

      table ->
        [
          "## Coverage",
          "",
          "Full test coverage report: #{@coverage_link}.",
          ""
        ] ++ table ++ [""]
    end
  end

  defp module_sections(tests) do
    tests
    |> Enum.map(& &1.module)
    |> Enum.uniq()
    # Alphabetical, so the report is stable across runs.
    |> Enum.sort()
    |> Enum.flat_map(fn module ->
      render_mod_section(module, Enum.filter(tests, &(&1.module == module)))
    end)
  end

  defp render_mod_section(module, entries) do
    path = entries |> List.first() |> Map.fetch!(:file)

    n_fail = Enum.count(entries, &(&1.state == "failed"))
    n_skip = Enum.count(entries, &(&1.state == "skipped"))
    n_total = length(entries)
    n_pass = n_total - n_fail - n_skip

    total_ms =
      entries
      |> Enum.map(&(&1.time_us || 0))
      |> Enum.sum()
      |> Kernel./(1000)

    summary_parts =
      [
        "Module tests: **#{n_total}**",
        n_pass > 0 && "passing: **#{n_pass}**",
        n_skip > 0 && "skipped: **#{n_skip}**",
        n_fail > 0 && "failures: **#{n_fail}**",
        "time: **#{:erlang.float_to_binary(total_ms, decimals: 1)}ms**"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    path_link = maybe_link("`#{path}`", source_link(path))

    # Failures numbered across the module, in execution order.
    fail_index =
      entries
      |> Enum.filter(&(&1.state == "failed"))
      |> Enum.with_index(1)
      |> Map.new()

    # Describe blocks nest as H3 under the module H2, in execution order.
    # Tests without a describe render first, right under the module — a
    # headingless table after an H3 would read as part of that describe.
    groups =
      entries
      |> Enum.map(& &1.describe)
      |> Enum.uniq()
      |> Enum.sort_by(&is_binary/1)
      |> Enum.flat_map(fn describe ->
        group = Enum.filter(entries, &(&1.describe == describe))
        heading = if describe, do: ["### #{describe}", ""], else: []

        heading ++ test_table(group) ++ fail_blocks(group, fail_index) ++ [""]
      end)

    # A failing module is flagged in its own heading (and so in the
    # sidebar); passing ones stay unmarked to keep the list quiet.
    mark = if n_fail > 0, do: "❌ ", else: ""

    [
      "## #{mark}#{module}",
      "",
      "#{summary_parts} #{path_link}",
      ""
    ] ++ groups
  end

  defp test_table([]), do: []

  defp test_table(group) do
    [
      "| Line | Status | Test | Time |",
      "| :--- | :----: | :--- | :--- |"
    ] ++ Enum.map(group, &test_row/1)
  end

  defp test_row(entry) do
    lnum_cell = maybe_link("`L##{entry.line}`", source_link(entry.file, entry.line))

    case entry.state do
      "skipped" -> "| #{lnum_cell} | ➖ | #{entry.name} | |"
      "failed" -> "| #{lnum_cell} | ❌ | #{entry.name} | #{format_ms(entry.time_us)} |"
      _ -> "| #{lnum_cell} | ✅ | #{entry.name} | #{format_ms(entry.time_us)} |"
    end
  end

  # Failure details render as ExDoc error admonitions (`{: .error}`):
  # a numbered title with the test line, the failure message as a list
  # item, and the assertion/stacktrace body fenced under it — every
  # line carrying the blockquote prefix.
  defp fail_blocks(group, fail_index) do
    group
    |> Enum.filter(&(&1.state == "failed" and &1.detail))
    |> Enum.flat_map(fn entry ->
      {message, body} = split_detail(entry.detail)

      [
        "",
        "> #### Fail #{fail_index[entry]} (L##{entry.line}) - " <>
          "#{entry.name} {: .error}",
        ">",
        "> #{message}"
      ] ++ fenced_detail(body)
    end)
  end

  # The ExUnit failure detail opens with its own numbering and location
  # ("1) test ...", "file:line") — both already carried by the title —
  # then the failure message and the assertion/stacktrace body.
  defp split_detail(detail) do
    [_numbering, _location | rest] =
      detail |> String.split("\n") |> Enum.map(&String.trim_trailing/1)

    dedent =
      rest
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&(String.length(&1) - String.length(String.trim_leading(&1))))
      |> Enum.min(fn -> 0 end)

    [message | body] = Enum.map(rest, &String.slice(&1, dedent..-1//1))

    {message, body}
  end

  defp fenced_detail([]), do: []

  defp fenced_detail(lines) do
    [">", "> ```elixir"] ++
      Enum.map(lines, &String.trim_trailing("> " <> &1)) ++ ["> ```"]
  end

  # -- Helpers -----------------------------------------------------------------

  defp format_ms(nil), do: ""
  defp format_ms(us), do: "#{:erlang.float_to_binary(us / 1000, decimals: 1)}ms"

  defp seconds(us), do: :erlang.float_to_binary(us / 1_000_000, decimals: 1)

  defp source_link(path, line \\ nil) do
    case @source_url_pattern do
      nil ->
        nil

      pattern ->
        pattern
        |> String.replace("%{path}", path)
        |> then(fn u ->
          if line,
            do: String.replace(u, "%{line}", to_string(line)),
            else: String.replace(u, ~r/#[^%]*%\{line\}/, "")
        end)
    end
  end

  defp maybe_link(text, nil), do: text
  defp maybe_link(text, url), do: "[#{text}](#{url})"

  # The "Execution Result Board": one admonition — `.info` on pass,
  # `.error` otherwise — with each metric scored against its target
  # (success ratio vs 100%, coverage vs the configured minimum), the
  # test counts, and the run detail as bullets.
  defp render_board(_meta, [], _coverage_total), do: []

  defp render_board(meta, tests, coverage_total) do
    total = length(tests)
    failures = Enum.count(tests, &(&1.state == "failed"))
    skipped = Enum.count(tests, &(&1.state == "skipped"))
    success = total - failures - skipped

    # Skipped tests count neither for nor against the success ratio.
    executed = total - skipped
    success_pct = if executed > 0, do: success / executed * 100, else: 0.0
    success_ok? = failures == 0 and executed > 0

    {coverage_pct, coverage_ok?} =
      case coverage_total do
        nil ->
          {nil, true}

        cov ->
          {pct, _} = Float.parse(cov)
          {pct, pct >= @minimum_coverage}
      end

    {class, status} =
      if success_ok? and coverage_ok?,
        do: {".neutral", "✅ **Pass**"},
        else: {".error", "❌ **Not Pass**"}

    metric_rows =
      [
        "> | Test Success ratio | #{percent(success_pct)} | 100% " <>
          "| #{if success_ok?, do: "✅", else: "❌"} |",
        coverage_pct &&
          "> | Test Coverage ratio | #{percent(coverage_pct)} " <>
            "| #{@minimum_coverage}% " <>
            "| #{if coverage_ok?, do: "✅", else: "❌"} |"
      ]
      |> Enum.filter(& &1)

    count_rows =
      [
        success > 0 && "> | passing | #{success} | ✅ |",
        skipped > 0 && "> | skipped | #{skipped} | ➖ |",
        failures > 0 && "> | failures | #{failures} | ❌ |"
      ]
      |> Enum.filter(& &1)

    seed_parts =
      [
        meta[:seed] && "seed: **#{meta[:seed]}**",
        meta[:max_cases] && "max_cases: **#{meta[:max_cases]}**"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    time_bullet =
      case meta[:run_us] do
        nil ->
          nil

        run_us ->
          async_us = meta[:async_us] || 0

          "> - Time: **#{seconds(run_us)}s** " <>
            "(**#{seconds(async_us)}s** async, " <>
            "**#{seconds(run_us - async_us)}s** sync)"
      end

    bullets =
      [
        seed_parts != "" && "> - Ran ExUnit with: #{seed_parts}",
        time_bullet,
        "> - Status: #{status}"
      ]
      |> Enum.filter(& &1)

    [
      "> #### Execution Result Board {: #{class}}",
      ">",
      "> | Metric | Score | Target | |",
      "> | :----- | :---: | :----: | :-: |"
    ] ++
      metric_rows ++
      [
        ">",
        "> | Total Tests | #{total} | |",
        "> | :---------- | :-: | :-: |"
      ] ++ count_rows ++ [">"] ++ bullets
  end

  # One decimal, trimmed when whole: 100%, 93.2%.
  defp percent(pct) do
    pct
    |> Float.round(1)
    |> :erlang.float_to_binary(decimals: 1)
    |> String.replace_suffix(".0", "")
    |> Kernel.<>("%")
  end
end
