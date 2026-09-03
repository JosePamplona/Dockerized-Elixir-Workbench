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

  @doc "The workbench's version, off the third line of wb.sh."
  def version do
    case dir() |> Path.join("wb.sh") |> File.read() do
      {:ok, text} ->
        text |> String.split("\n") |> Enum.at(2, "") |> then(&Regex.run(~r/v(\S+)/, &1)) |> then(&(&1 && Enum.at(&1, 1)))

      _ ->
        nil
    end
  end

  @doc "The workspace's directory, as config.conf names it: relative paths are the workbench's."
  def workspace do
    case Console.Config.values(config())["WORKSPACE_PATH"] do
      nil -> nil
      "" -> nil
      path -> Path.expand(path, dir())
    end
  end

  @doc "The usable stacks — the hexpm/elixir tags — asked of Docker Hub through wb.sh; seconds."
  def stacks, do: json(["stacks", "--json"])

  @doc "The workspace's dev image, as wb.sh names it: the project's name with dashes, `:local`."
  def local_image do
    name = Console.Config.values(config())["PROJECT_NAME"] || "app"
    (name |> String.downcase() |> String.replace(" ", "-")) <> ":local"
  end

  @doc "config.conf, as `Console.Config` reads it."
  def config do
    case dir() |> Path.join("config.conf") |> File.read() do
      {:ok, text} -> Console.Config.parse(text)
      _ -> Console.Config.parse("")
    end
  end

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

  @doc """
  The workspace: whether it holds a project, ports, which deployment is
  up, containers with their addresses, git — and, `:full`, what the
  project carries of the cartridges, which boots Mix in a container
  and costs seconds. `:fast` leaves that out (`"project"` is then
  null) for the readings that follow an up or a down, where nothing
  about the cartridges could have changed.
  """
  def status(mode \\ :full)
  def status(:full), do: json(["status", "--json"])
  def status(:fast), do: json(["status", "--json", "--fast"])

  @doc """
  What inserting a cartridge with these options would run — `[%{"name",
  "argv"}]`, one per insert, minus what the project already carries.
  It starts a container on the project: seconds. Asked when a box is
  opened and when it is about to be inserted, never on each keystroke.
  """
  def expand(name, argv \\ []), do: json(["expand", "--json", name | argv])

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
