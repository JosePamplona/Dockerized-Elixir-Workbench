defmodule Mix.Tasks.Cover do
  use Mix.Task

  # Target filename.
  @test_filename "TESTING.md"
  # Processed files output path.
  @test_output_path "."
  @coverage_config "coveralls.json"
  @coverage_filename "excoveralls.html"
  @coverage_link "[Test Coverage Overview](./#{@coverage_filename})"
  @coverage_options @coverage_config
                    |> File.read!()
                    |> Jason.decode!(keys: :atoms)
                    |> Map.fetch!(:coverage_options)
  @section_coverage "Coverage"
  @section_tests "Unit Testing"

  @version Mix.Project.config()[:version]

  # GitHub source links — derived from ExDoc config (degrades to plain text if missing)
  @docs_config Mix.Project.config()[:docs] || []
  @source_url Mix.Project.config()[:source_url]
  @source_ref @docs_config[:source_ref] || "main"
  @source_url_pattern @docs_config[:source_url_pattern] ||
                        (@source_url &&
                           "#{@source_url}/blob/#{@source_ref}/%{path}#L%{line}")

  # Regex patterns
  @tests ~r/(\e\[.*?m)*?\d* test(s)?, (\d*) failure/
  # \s+ instead of a literal space: excoveralls pads the total for alignment
  @total ~r/(\e\[.*?m)*?\[TOTAL]\s+(.*?%)/
  @cover ~r/(\e\[.*?m)*?FAILED: Expected minimum coverage of (.*?%)/

  # ExUnit output parsing (applied after ANSI is stripped)
  @ex_seed ~r/Running ExUnit with seed: (\d+), max_cases: (\d+)/
  @ex_finished ~r/Finished in (\S+) seconds \((\S+) async, (\S+) sync\)/
  @ex_count ~r/^(\d+) tests?, (\d+) failures?(?:, (\d+) skipped)?/
  @ex_mod ~r/^([A-Z]\S+) \[(.+\.exs)\]$/
  @ex_pass ~r/^\s+\* test (.+?) \(([\d.]+)ms\) \[L#(\d+)\]/
  @ex_skip ~r/^\s+# test (.+?) \((excluded|skipped)\) \[L#(\d+)\]/
  @ex_fail_start ~r/^\s+\d+\) test (.+) \(\S+\)/

  @moduledoc """
  Generates a testing report file on `#{@test_output_path}/#{@test_filename}`
  and a HTML page coverage report file on
  `#{@coverage_options.output_dir}/#{@coverage_filename}` to enable ExDoc to
  integrate the test & coverage documentation files.

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
            ["coveralls.html", "--trace", "--seed", "0", "--color"],
            stderr_to_stdout: true,
            env: [{"MIX_ENV", "test"}]
          )

        # coveralls-ignore-stop

        output ->
          {output, 0}
      end

    formatted_output = format_tests_report(output)
    File.write!("#{@test_output_path}/#{@test_filename}", formatted_output)

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

  defp format_tests_report(content) do
    [date, time] =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:microsecond)
      |> NaiveDateTime.to_string()
      |> String.split(" ")

    now = "`#{date}` at `#{time}`"

    {tests_lines, coverage_lines} =
      content
      |> String.split("\n")
      |> Enum.map(&clean_line/1)
      |> Enum.reject(&noise_line?/1)
      |> split_at_tests_summary()

    header = [
      "# Testing reports",
      "",
      "Reports generated on #{now} for version: **#{@version}**.",
      "",
      "## #{@section_coverage}",
      "",
      "Full unit tests coverage report: #{@coverage_link}.",
      ""
    ]

    footer = [
      "",
      "## #{@section_tests}",
      ""
    ]

    (header ++
       coverage_to_table(coverage_lines) ++
       footer ++ tests_to_markdown(tests_lines))
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
    |> then(fn l ->
      if Regex.match?(~r/\* test.*?\((excluded|skipped)\) \[L#\d+\]/, l),
        do: String.replace(l, "* test", "# test"),
        else: l
    end)
  end

  defp noise_line?(line) do
    line == "----------------" or
      line == "Generating report..." or
      String.starts_with?(line, "Saved to:")
  end

  defp split_at_tests_summary(lines) do
    lines
    |> Enum.split_while(&(not Regex.match?(@tests, &1)))
    |> case do
      {before, [pivot | rest]} -> {before ++ [pivot], rest}
      {all, []} -> {all, []}
    end
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
            "| " <>
            "| **#{sums.lines}** " <>
            "| **#{sums.relevant}** " <>
            "| **#{sums.missed}** |"

        table =
          [
            "| Coverage | File | Lines | Relevant | Missed |",
            "| :------: | :--- | :---- | :------- | :----- |"
          ] ++ table_rows ++ [total_row]

        case tail do
          [_ | _] -> table ++ [""] ++ format_tail(tail)
          _ -> table
        end
    end
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
    link = "[`#{file}`](#{@coverage_filename}##{file})"
    "| #{cov} | #{link} | #{lines} | #{relevant} | #{missed} |"
  end

  defp format_tail(tail) do
    Enum.map(tail, fn
      "FAILED:" <> rest -> "❌ **FAILED:**#{rest}"
      line -> line
    end)
  end

  # -- Tests markdown ----------------------------------------------------------

  defp tests_to_markdown(lines) do
    init = %{
      mods_rev: [],
      mod: nil,
      tests_rev: [],
      failed: MapSet.new(),
      fail_details: %{},
      capturing_fail: nil,
      meta: %{}
    }

    state = Enum.reduce(lines, init, &parse_test_line/2)

    all_mods =
      state
      |> flush_mod()
      |> Map.get(:mods_rev)
      |> Enum.reverse()

    mod_sections =
      Enum.flat_map(
        all_mods,
        &render_mod_section(&1, state.failed, state.fail_details)
      )

    render_test_meta(state.meta) ++ ["", "### Modules", ""] ++ mod_sections
  end

  defp parse_test_line(line, state) do
    cond do
      m = Regex.run(@ex_seed, line) ->
        [_, seed, max] = m

        %{
          state
          | capturing_fail: nil,
            meta: Map.merge(state.meta, %{seed: seed, max_cases: max})
        }

      m = Regex.run(@ex_finished, line) ->
        [_, t, a, s] = m

        %{
          state
          | capturing_fail: nil,
            meta: Map.merge(state.meta, %{time: t, async: a, sync: s})
        }

      m = Regex.run(@ex_count, line) ->
        [_, total, failures | rest] = m
        skipped = if rest == [] or hd(rest) == "", do: "0", else: hd(rest)

        state
        |> flush_mod()
        |> Map.merge(%{mod: nil, tests_rev: [], capturing_fail: nil})
        |> Map.update!(
          :meta,
          &Map.merge(&1, %{total: total, failures: failures, skipped: skipped})
        )

      m = Regex.run(@ex_mod, line) ->
        [_, name, path] = m

        state
        |> flush_mod()
        |> Map.merge(%{mod: {name, path}, tests_rev: [], capturing_fail: nil})

      m = Regex.run(@ex_pass, line) ->
        [_, desc, time, lnum] = m

        if state.mod,
          do: %{
            state
            | capturing_fail: nil,
              tests_rev: [{:pass, desc, time, lnum} | state.tests_rev]
          },
          else: %{state | capturing_fail: nil}

      m = Regex.run(@ex_skip, line) ->
        [_, desc, _kind, lnum] = m

        if state.mod,
          do: %{
            state
            | capturing_fail: nil,
              tests_rev: [{:skip, desc, lnum} | state.tests_rev]
          },
          else: %{state | capturing_fail: nil}

      m = Regex.run(@ex_fail_start, line) ->
        [_, desc] = m

        %{
          state
          | failed: MapSet.put(state.failed, desc),
            capturing_fail: desc,
            fail_details: Map.put(state.fail_details, desc, [line])
        }

      true ->
        case state.capturing_fail do
          nil ->
            state

          desc ->
            %{
              state
              | fail_details:
                  Map.update!(state.fail_details, desc, &[line | &1])
            }
        end
    end
  end

  defp flush_mod(%{mod: nil} = state), do: state

  defp flush_mod(%{mod: mod, tests_rev: tests_rev, mods_rev: mods_rev} = state) do
    %{state | mods_rev: [{mod, Enum.reverse(tests_rev)} | mods_rev]}
  end

  defp render_mod_section({{name, path}, tests}, failed_set, fail_details) do
    n_fail =
      Enum.count(tests, fn
        {:pass, desc, _, _} -> MapSet.member?(failed_set, desc)
        _ -> false
      end)

    n_pass = Enum.count(tests, &match?({:pass, _, _, _}, &1)) - n_fail
    n_skip = Enum.count(tests, &match?({:skip, _, _}, &1))
    n_total = n_pass + n_fail + n_skip

    total_ms =
      tests
      |> Enum.filter(&match?({:pass, _, _, _}, &1))
      |> Enum.reduce(0.0, fn {:pass, _, time, _}, acc ->
        acc + parse_ms(time)
      end)

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

    rows =
      Enum.map(tests, fn
        {:pass, desc, time, lnum} ->
          lnum_cell = maybe_link("`L##{lnum}`", source_link(path, lnum))

          failed_set
          |> MapSet.member?(desc)
          |> case do
            true -> "| #{lnum_cell} | ❌ | #{desc} | #{time}ms |"
            false -> "| #{lnum_cell} | ✅ | #{desc} | #{time}ms |"
          end

        {:skip, desc, lnum} ->
          lnum_cell = maybe_link("`L##{lnum}`", source_link(path, lnum))
          "| #{lnum_cell} | ➖ | #{desc} | |"
      end)

    test_table =
      case rows do
        [] ->
          []

        _ ->
          [
            "| Line | Status | Test | Time |",
            "| :--- | :----: | :--- | :--- |"
          ] ++ rows
      end

    fail_blocks =
      tests
      |> Enum.filter(fn
        {:pass, desc, _, _} -> MapSet.member?(failed_set, desc)
        _ -> false
      end)
      |> Enum.flat_map(fn {:pass, desc, _, _} ->
        case Map.get(fail_details, desc) do
          nil ->
            []

          lines_rev ->
            detail = lines_rev |> Enum.reverse() |> Enum.join("\n")
            ["", "```", detail, "```"]
        end
      end)

    [
      "#### #{name}",
      "",
      "#{summary_parts} #{path_link}",
      ""
    ] ++ test_table ++ fail_blocks ++ [""]
  end

  # -- Helpers -----------------------------------------------------------------

  defp parse_ms(time) do
    case Float.parse(time) do
      {ms, _} -> ms
      :error -> 0.0
    end
  end

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

  defp render_test_meta(meta) do
    total = meta[:total] && String.to_integer(meta[:total])
    failures = meta[:failures] && String.to_integer(meta[:failures])
    skipped = meta[:skipped] && String.to_integer(meta[:skipped])
    success = total && failures && skipped && total - failures - skipped

    seed_parts =
      [
        meta[:seed] && "seed: **#{meta[:seed]}**",
        meta[:max_cases] && "max_cases: **#{meta[:max_cases]}**"
      ]
      |> Enum.filter(& &1)
      |> Enum.join(", ")

    run_line =
      case seed_parts do
        "" -> []
        _ -> ["Ran **ExUnit** with: #{seed_parts}", ""]
      end

    count_rows =
      [
        success && success > 0 && "| passing | #{success} | ✅ |",
        skipped && skipped > 0 && "| skipped | #{skipped} | ➖ |",
        failures && failures > 0 && "| failures | #{failures} | ❌ |"
      ]
      |> Enum.filter(& &1)

    count_table =
      case total do
        nil ->
          []

        _ ->
          ["| Total Tests | #{total} | |", "| :-: | :-: | :-: |"] ++ count_rows
      end

    time_line =
      if meta[:time] do
        [
          "",
          "Time: **#{meta[:time]}s** " <>
            "(**#{meta[:async]}** async, **#{meta[:sync]}** sync)",
          ""
        ]
      else
        []
      end

    run_line ++ time_line ++ count_table
  end
end
