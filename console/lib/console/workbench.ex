defmodule Console.Workbench do
  @moduledoc """
  The workbench as the console sees it: its directory, `wb.sh`, and the
  two JSON contracts — `catalog --json`, `status --json`. The console
  does not reimplement the workbench: every action is `wb.sh` run as a
  job (`Console.Jobs`), every fact is read from its JSON.

  `WORKBENCH_DIR` is set by `./wb.sh console`; without it (running the
  console by hand) the workbench is the directory above `console/`.
  """

  @doc "The workbench's directory."
  def dir, do: System.get_env("WORKBENCH_DIR") || Path.expand("..", File.cwd!())

  @doc "Where the box covers are."
  def covers_dir, do: Path.join(dir(), "assets/covers")

  @doc "`wb.sh` with `--yes`, run to completion; `{output, exit_status}`."
  def run(args) when is_list(args) do
    System.cmd(Path.join(dir(), "wb.sh"), ["--yes" | args],
      cd: dir(),
      stderr_to_stdout: true,
      env: [{"TERM", "dumb"}]
    )
  end

  @doc "The catalog: every cartridge, as `wb.sh catalog --json` says."
  def catalog, do: json(["catalog", "--json", "--covers"])

  @doc "The workspace: ports, containers, git, the project's cartridges."
  def status, do: json(["status", "--json"])

  defp json(args) do
    case run(args) do
      {out, 0} ->
        # mix may print what it compiles before the answer; keep from the first JSON line on.
        out
        |> String.split("\n")
        |> Enum.drop_while(&(not String.starts_with?(&1, ["{", "["])))
        |> Enum.join("\n")
        |> Jason.decode()
        |> case do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, "not JSON: " <> String.slice(out, 0, 400)}
        end

      {out, status} ->
        {:error, "wb.sh #{Enum.join(args, " ")} exited #{status}: " <> strip(out)}
    end
  end

  @doc "Terminal colour codes out of a line."
  def strip(text), do: Regex.replace(~r/\e\[[0-9;]*m/, text, "")
end
