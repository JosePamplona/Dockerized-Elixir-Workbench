defmodule Mix.Tasks.Cover do
  use Mix.Task

  import ExUnit.CaptureIO

  @test_filename     "%{target_filename}" # Target filename.
  @test_output_path  "%{exdoc_assets}" # Processed files output path.
  @coverage_config   "%{coverage_config}"
  @coverage_filename "excoveralls.html"
  @coverage_link     "[Coverage report](./#{@coverage_filename})"
  @coverage_options (
    @coverage_config
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
    |> Map.fetch!(:coverage_options)
  )

  @version   Mix.Project.config[:version]
  # Regex patterns
  @tests ~r/(\e\[.*?m)*?\d* test(s)?, (\d*) failure/
  @total ~r/(\e\[.*?m)*?\[TOTAL] (.*?%)/
  @cover ~r/(\e\[.*?m)*?FAILED: Expected minimum coverage of (.*?%)/

  @moduledoc """
    Generates a testing report file into `#{@test_output_path}` and a
    coverage report file into `#{@coverage_options.output_dir}` to enable ExDoc 
    to integrate the test & coverage documentation files.

    Compatible with [ExCoveralls](https://hex.pm/packages/excoveralls) v0.18.1
    """

  @shortdoc "Generates testing & coverage reports to be included in ExDocs"
  @doc false
  def run(opts) do
    Mix.shell().info("Generating testing & coverage reports...")
    test_report_output = Keyword.get(opts, :test_report_output)

    File.mkdir_p!(@test_output_path)

    {_, output} = with_io(fn ->
      if test_report_output do
        IO.puts(test_report_output)
      else
        # coveralls-ignore-start
        try do
          Mix.Task.run(
            "coveralls.html", ["--trace", "--seed", "0"]
          )
        rescue e in Mix.Error -> e
        catch kind, reason -> {kind, reason}
        end
        # coveralls-ignore-stop
      end
    end)

    formatted_output = format_tests_report(output)
    File.write!("#{@test_output_path}/#{@test_filename}", formatted_output)

    # Coverage report ----------------------------------------------------------

    output
    |> validate_output()
    |> case do
      {:ok, total} ->
        Mix.shell().info(
          "Success! testing & coverage reports were generated:\n" <>
          "  #{@test_output_path}#{@test_filename}\n" <>
          "  #{@coverage_options.output_dir}/#{@coverage_filename}\n" <>
          "Test checks:\n" <>
          "  Success rate: \e[38;5;2m100.0%\e[0m\n" <>
          "  Coverage:     \e[38;5;2m#{total}\e[0m"
        )

      {:error, exit_status, error} ->
        Mix.shell().info(output)

        message =
          case error do
            {:cover, min}   -> "Failure: Total coverage below #{min}."
            {:tests, fails} -> "Failure: #{fails} tests have not pass."
            :raise          -> "Error: An error was raised."
          end

        Mix.raise(message, [{:exit_status, exit_status}])
    end
  end

  # == Private =================================================================

  defp format_tests_report(content) do
    %{
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      microsecond: {microsecond, 6}
    } = NaiveDateTime.utc_now()

    now =
      "`#{year}"
      |> Kernel.<>("-")
      |> Kernel.<>(String.pad_leading("#{month}", 2, "0"))
      |> Kernel.<>("-")
      |> Kernel.<>(String.pad_leading("#{day}", 2, "0"))
      |> Kernel.<>("` at `")
      |> Kernel.<>(String.pad_leading("#{hour}", 2, "0"))
      |> Kernel.<>(":")
      |> Kernel.<>(String.pad_leading("#{minute}", 2, "0"))
      |> Kernel.<>(":")
      |> Kernel.<>(String.pad_leading("#{second}", 2, "0"))
      |> Kernel.<>(".")
      |> Kernel.<>(String.pad_leading("#{microsecond}", 3, "0"))
      |> Kernel.<>("`")

    [
      "# Tests reports",
      "",
      "Reports generated on #{now} for version: **#{@version}**.",
      "",
      "## Automated tests",
      "",
      "```elixir"
    ] ++ (
      content
      |> String.split("\n")
      |> Enum.with_index(&format_test_line/2)
      |> List.flatten()
    ) ++ [
      "```",
      ""
    ]
    |> Enum.reduce({[], nil}, fn line, {acc, last} ->
      if line == last, do: {acc, last}, else: {acc ++ [line], line}
    end)
    |> elem(0)
    |> Enum.join("\n")
  end

  defp format_test_line(line, _i) do
    # Delete everything before a \r return cartridge escape character (win)
    line = line |> String.split("\r") |> Enum.at(-1)

    # Check if the line is an excluded test to comment out the line
    ~r/\* test.*?\(excluded\) \[L#\d+\]/
    |> Regex.scan(line)
    |> case do
      [] -> line
      _matches -> String.replace(line, ~r/(\* test)/, "# test")
    end
    |> String.replace(~r/\e\[.*?m/, "")
    |> String.replace(~r/\\e\[.*?m/, "")
    # Matches are checked against lines that require additional formatting.
    |> case do
      "----------------" -> []
      "Generating report..." -> []
      "Saved to:" <> _static_path -> []
      line ->
        @tests
        |> Regex.scan(line)
        |> case do
          [[_, _, _, _]] ->
            [
              line,
              "```",
              "",
              "## Coverage",
              "",
              "Full test coverage report: #{@coverage_link}.",
              "",
              "```elixir"
            ]

          _ -> line
        end
    end
  end

  defp validate_output(output) do
    case {
      Regex.scan(@tests, output),
      Regex.scan(@total, output),
      Regex.scan(@cover, output)
    } do
      {[[_, _, _, "0"]], [[_, _, total]], []}      -> {:ok, total}
      {[[_, _, _, fails]], _, _} when fails != "0" -> {:error, 2, {:tests, fails}}
      {_, _, [[_, _, min]]}                        -> {:error, 1, {:cover, min}}
      _                                            -> {:error, 1, :raise}
    end
  end
end
