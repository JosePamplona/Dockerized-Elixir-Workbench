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
        text
        |> String.split("\n")
        |> Enum.at(2, "")
        |> then(&Regex.run(~r/v(\S+)/, &1))
        |> then(&(&1 && Enum.at(&1, 1)))

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

  @doc """
  The project the workspace holds, as `wb.sh` names it: `name` — the
  compose project, and the prefix of its `_build` and `deps` volumes —
  and `image`, its dev image. Read off the workspace's own compose when
  it has one, the record of its creation, and derived from config.conf's
  PROJECT_NAME otherwise, the way `new` will name it — which is also the
  name the console started its own toolchain for.
  """
  def project(ws \\ workspace()) do
    compose = if ws, do: File.read(Path.join(ws, "docker-compose.yml")), else: :none

    text =
      case compose do
        {:ok, text} -> text
        _ -> ""
      end

    lower = (Console.Config.values(config())["PROJECT_NAME"] || "app") |> String.downcase()
    # The app service's image, not the first image in the file (the pod's).
    app = text |> String.split("\n  app:\n", parts: 2) |> Enum.at(1, "")

    %{
      name: capture(text, ~r/^name: (\S+)/m) || String.replace(lower, " ", "_"),
      image: capture(app, ~r/^    image: (\S+)/m) || String.replace(lower, " ", "-") <> ":local"
    }
  end

  defp capture(text, regex),
    do: regex |> Regex.run(text, capture: :all_but_first) |> then(&(&1 && hd(&1)))

  @repository "dew"

  @doc """
  The workbench's image for a workspace, named the way `wb.sh` names it:
  `dew-exELIXIR-erlOTP-phxVERSION:WORKBENCH` — the stack and the
  installer in the repository, the workbench's version as the tag. The
  stack is config.conf's; the installer is the one stamped in the
  workspace's `Dockerfile.local`, else the one config.conf names, else
  the newest this daemon already has for the stack at this version.
  Where the workbench's own runs go — a terminal with nothing running,
  the resident away from its mount — and never the app's dev image,
  which carries no generator.
  """
  def image(ws \\ workspace()) do
    conf = Console.Config.values(config())
    version = version()
    image_tag(conf, Console.Project.born(ws), version, fn -> local_repositories(version) end)
  end

  @doc """
  `image/1` without the files and the daemon: config.conf's values, the
  workspace's stamp (`Console.Project.born/1`), the workbench's version,
  and a function that lists the workbench repositories the daemon has at
  that version, asked only when neither names an installer.
  """
  def image_tag(conf, born, version, repositories) do
    stack = "ex#{conf["ELIXIR_VERSION"]}-erl#{conf["ERLANG_VERSION"]}"

    phx =
      present((born || %{})["PHX_NEW"]) || present(conf["PHX_NEW_VERSION"]) ||
        newest(stack, repositories.())

    "#{@repository}-#{stack}" <>
      if(phx, do: "-phx#{phx}", else: "") <> if(version, do: ":#{version}", else: "")
  end

  defp present(v) when v in [nil, ""], do: nil
  defp present(v), do: v

  # The newest installer among the daemon's workbench repositories for this stack.
  defp newest(stack, repositories) do
    prefix = "#{@repository}-#{stack}-phx"

    repositories
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.map(&String.replace_prefix(&1, prefix, ""))
    |> Enum.max_by(&version_key/1, fn -> nil end)
  end

  defp version_key(v),
    do:
      v
      |> String.split(~r/[.-]/)
      |> Enum.map(
        &(Integer.parse(&1)
          |> then(fn
            {n, _} -> n
            :error -> 0
          end))
      )

  # The workbench repositories the daemon has at this version, every stack.
  defp local_repositories(version) do
    with docker when is_binary(docker) <- System.find_executable("docker"),
         {out, 0} <-
           System.cmd(docker, [
             "images",
             "--format",
             "{{.Repository}}",
             "#{@repository}-*" <> if(version, do: ":#{version}", else: "")
           ]) do
      String.split(out, "\n", trim: true)
    else
      _ -> []
    end
  end

  @doc """
  What `./wb.sh console` mounted this container for, against what
  config.conf names now: `nil` when they agree — or when the console
  runs by hand, with no mount — and the mount's
  `%{workspace:, project:, moved:}` when they do not. `moved` is which
  of the two it is, and they are not the same thing: another workspace
  means this one is not in the container at all, and the same workspace
  under another name means the build volumes it holds are another
  project's. The band says one or the other (`ConsoleWeb.Band.rebind/1`),
  so the comparison is made here, once, where the two values already
  are. The same three checks `wb.sh` makes
  (`toolchain_here`) and the resident (`mounted_here?`): while they
  fail every mix and git of a job runs in a container of its own, and
  the console has to be started again to run them here.
  """
  def rebind do
    mount = %{
      workspace: System.get_env("WORKSPACE_MOUNT_PATH"),
      project: System.get_env("WORKSPACE_MOUNT_PROJECT")
    }

    ws = workspace()

    cond do
      is_nil(System.get_env("WORKSPACE_MOUNT")) -> nil
      mount.workspace == ws and mount.project == project(ws).name -> nil
      true -> Map.put(mount, :moved, mount.workspace != ws)
    end
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
