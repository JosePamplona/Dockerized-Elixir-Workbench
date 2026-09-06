defmodule Console.Docker do
  @moduledoc """
  What the daemon holds, read for the Docker screen: the containers with
  what `compose ps` leaves out — since when, restarts, exit code, the
  restart policy — one container's whole inspect as a card, the images
  grouped by what they are (six names on one image are one image), the
  volumes and networks with what uses them, the disk, and the compose
  file of each deployment with its secrets masked. Every reading is a
  short `docker` command with `--format json`; none starts a container
  and none boots a BEAM. The stats are a stream and live with the page
  that shows them: `stats_args/0` opens it, `stat/1` reads a line.

  Two scopes. *This workspace*: the containers, networks and volumes of
  its compose project, and the console's own — a container on this
  daemon like any other, and the one the reader is looking through.
  *The daemon*: everything, which is where the leftovers of the
  workspaces before this one are.
  """

  alias Console.Project

  @console "workbench_console"
  @project "com.docker.compose.project"
  @service "com.docker.compose.service"
  @house ~w(workbench workbench-console hexpm/elixir postgres dpage/pgadmin4 registry.k8s.io/pause nginx)

  # --- containers -------------------------------------------------------------

  @doc "The containers in scope, this workspace's first and the console last among them."
  def containers(status, scope) do
    mine = project(status)

    all_containers()
    |> Enum.filter(&(scope == "daemon" or mine?(&1, mine)))
    |> Enum.sort_by(
      &{if(mine?(&1, mine), do: 0, else: 1), if(&1.console?, do: 1, else: 0), order(&1.service),
       &1.project || "", &1.name}
    )
  end

  @doc """
  Every container on the daemon: `ps --all` for the ids and the status
  in words, and inspect for the rest. Not `ps --format json`: that
  format carries the container's size, which the daemon measures on
  every call — 6.7 s for 29 containers here, against 30 ms for the ids
  and one inspect of them all.
  """
  def all_containers do
    with {out, 0} <- docker(["ps", "--all", "--no-trunc", "--format", "{{.ID}}\t{{.Status}}"]),
         rows <-
           for(
             line <- String.split(out, "\n", trim: true),
             [id | status] = String.split(line, "\t", parts: 2),
             do: {id, List.first(status) || ""}
           ),
         details <- inspect_all(Enum.map(rows, &elem(&1, 0))) do
      for {id, status} <- rows, d = details[id], do: container(d, status)
    else
      _ -> []
    end
  end

  defp container(d, status) do
    cfg = d["Config"] || %{}
    labels = cfg["Labels"] || %{}
    name = String.trim_leading(d["Name"] || "", "/")

    %{
      id: String.slice(d["Id"] || "", 0, 12),
      name: name,
      image: cfg["Image"],
      project: labels[@project],
      service: labels[@service] || name,
      status: status,
      ports: ports_of(get_in(d, ["NetworkSettings", "Ports"]) || %{}),
      restarts: d["RestartCount"] || 0,
      policy: policy(get_in(d, ["HostConfig", "RestartPolicy", "Name"])),
      mounts: volume_names(d),
      console?: name == @console
    }
    |> Map.merge(state_of(d))
  end

  # What the container's State says: where it is, how it ended, and when.
  defp state_of(d) do
    state = d["State"] || %{}

    %{
      state: state["Status"],
      health: health(get_in(state, ["Health", "Status"])),
      started: moment(state["StartedAt"]),
      finished: moment(state["FinishedAt"]),
      exit: state["ExitCode"],
      oom: state["OOMKilled"] == true
    }
  end

  # The volumes it mounts, by name.
  defp volume_names(d), do: for(m <- d["Mounts"] || [], m["Type"] == "volume", do: m["Name"])

  defp inspect_all([]), do: %{}

  defp inspect_all(ids) do
    case docker(["inspect" | ids]) do
      {out, 0} -> out |> Jason.decode!() |> Map.new(&{&1["Id"], &1})
      _ -> %{}
    end
  end

  @doc "Whether a container is this workspace's: of its compose project, or the console itself."
  def mine?(c, project), do: c.console? or (not is_nil(project) and c.project == project)

  # The compose's own order, then the console, then whatever else.
  defp order("app" <> _), do: 0
  defp order("database"), do: 1
  defp order("pgadmin"), do: 2
  defp order("network"), do: 3
  defp order("balancer"), do: 4
  defp order("migrate"), do: 5
  defp order(_), do: 9

  @doc "The compose project the status names, or nil without one."
  def project(nil), do: nil
  def project(status), do: status["compose_project"]

  @doc """
  One container, whole: what it runs and as whom, how it restarts,
  where its network is, its healthcheck with the last probes, its
  mounts, its env with the secrets masked, its ports and addresses.
  """
  def card(nil), do: nil

  def card(name) do
    with {out, 0} <- docker(["inspect", name]), [d] <- Jason.decode!(out) do
      card_of(d)
    else
      _ -> nil
    end
  end

  # The card off one inspect: what it runs, its state, its healthcheck,
  # its mounts, its env, its network.
  defp card_of(d) do
    cfg = d["Config"] || %{}
    state = d["State"] || %{}
    host = d["HostConfig"] || %{}
    net = d["NetworkSettings"] || %{}

    %{
      name: String.trim_leading(d["Name"] || "", "/"),
      image: cfg["Image"],
      command: command(cfg),
      user: blank(cfg["User"]),
      workdir: blank(cfg["WorkingDir"]),
      policy: policy(get_in(host, ["RestartPolicy", "Name"])),
      network: host["NetworkMode"],
      memory: host["Memory"],
      cpus: host["NanoCpus"],
      restarts: d["RestartCount"] || 0,
      pid: state["Pid"],
      healthcheck: healthcheck(cfg["Healthcheck"]),
      probes: probes(state),
      mounts: mounts(d),
      env: env(cfg),
      ports: ports_of(net["Ports"] || %{}),
      addresses: addresses(net)
    }
    |> Map.merge(state_of(d))
  end

  # What it runs: the entrypoint, then the command.
  defp command(cfg), do: shell_words((cfg["Entrypoint"] || []) ++ (cfg["Cmd"] || []))

  # The healthcheck as configured; nil without one.
  defp healthcheck(nil), do: nil

  defp healthcheck(hc) do
    %{
      test: shell_words(hc["Test"] || []),
      interval: seconds(hc["Interval"]),
      timeout: seconds(hc["Timeout"]),
      start: seconds(hc["StartPeriod"]),
      retries: hc["Retries"]
    }
  end

  # The last probes the daemon kept.
  defp probes(state) do
    for p <- get_in(state, ["Health", "Log"]) || [] do
      %{
        at: p["Start"],
        exit: p["ExitCode"],
        ms: millis(p["Start"], p["End"]),
        out: String.trim(p["Output"] || "")
      }
    end
  end

  # Every mount: volume or bind, from where to where, and how.
  defp mounts(d) do
    for m <- d["Mounts"] || [] do
      %{
        type: m["Type"],
        from: m["Name"] || m["Source"],
        to: m["Destination"],
        mode: if(m["RW"], do: "rw", else: "ro")
      }
    end
  end

  # The env with the secrets masked, one line each.
  defp env(cfg),
    do: (cfg["Env"] || []) |> Enum.join("\n") |> Project.mask() |> String.split("\n", trim: true)

  # The address on each network it is on.
  defp addresses(net),
    do:
      for(
        {n, v} <- net["Networks"] || %{},
        v["IPAddress"] not in [nil, ""],
        do: {n, v["IPAddress"]}
      )

  # --- images -----------------------------------------------------------------

  @doc "The images in scope, grouped by ID, and the untagged ones counted."
  def images(status, scope) do
    case docker(["image", "ls", "--format", "{{json .}}"]) do
      {out, 0} -> group_images(decode_lines(out), app_repo(status), scope)
      _ -> %{images: [], dangling: 0, dangling_size: nil}
    end
  end

  @doc """
  `image ls` rows into images: one per ID with every name it wears,
  the untagged apart, this workspace's — the app's, the house's — first.
  """
  def group_images(rows, app, scope) do
    grouped =
      rows
      |> Enum.group_by(& &1["ID"])
      |> Enum.map(fn {id, rs} ->
        names = for r <- rs, r["Repository"] != "<none>", do: r["Repository"] <> ":" <> r["Tag"]
        first = hd(rs)

        %{
          id: id,
          names: Enum.sort(names),
          size: first["Size"],
          bytes: bytes(first["Size"]),
          age: first["CreatedSince"],
          created: first["CreatedAt"],
          dangling: names == [],
          mine?: Enum.any?(rs, &(&1["Repository"] in @house or &1["Repository"] == app))
        }
      end)

    dangling = Enum.filter(grouped, & &1.dangling)

    images =
      grouped
      |> Enum.reject(& &1.dangling)
      |> Enum.filter(&(scope == "daemon" or &1.mine?))
      |> Enum.sort_by(&{if(&1.mine?, do: 0, else: 1), &1.created}, fn {a, ca}, {b, cb} ->
        a < b or (a == b and ca >= cb)
      end)

    %{
      images: images,
      dangling: length(dangling),
      dangling_size: dangling |> Enum.map(& &1.bytes) |> Enum.sum() |> human()
    }
  end

  # The app's image repository, from the compose: `some-test` of `some-test:local`.
  defp app_repo(nil), do: nil

  defp app_repo(status) do
    case Console.Workbench.project(status["workspace"]) do
      %{image: image} when is_binary(image) -> image |> String.split(":") |> hd()
      _ -> nil
    end
  end

  # --- volumes, networks, disk ------------------------------------------------

  @doc """
  The volumes in scope and who mounts them — `volume ls` and the
  containers' mounts, milliseconds. Their sizes are `volume_sizes/0`,
  read apart: `system df -v` measures every volume on the daemon, and
  that took 13 s here.
  """
  def volumes(status, scope) do
    mine = project(status)
    containers = all_containers()

    users =
      for c <- containers, v <- c.mounts, reduce: %{} do
        acc -> Map.update(acc, v, [c], &[c | &1])
      end

    case docker(["volume", "ls", "--format", "{{json .}}"]) do
      {out, 0} ->
        out
        |> decode_lines()
        |> Enum.map(&volume(&1, users, mine))
        |> Enum.filter(&(scope == "daemon" or &1.mine?))
        |> Enum.sort_by(&{if(&1.mine?, do: 0, else: 1), &1.anonymous, &1.project || "", &1.name})

      _ ->
        []
    end
  end

  # One volume: whose it is, who mounts it, and whether it is this workspace's.
  defp volume(v, users, mine) do
    labels = labels(v["Labels"])
    used = users[v["Name"]] || []

    %{
      name: v["Name"],
      project: labels[@project],
      anonymous: Map.has_key?(labels, "com.docker.volume.anonymous"),
      used_by: used |> Enum.map(& &1.name) |> Enum.sort(),
      mine?:
        labels[@project] == mine or String.starts_with?(v["Name"], @console) or
          Enum.any?(used, &mine?(&1, mine))
    }
  end

  @doc "Every volume's size, by name, off `system df -v` — slow: the daemon measures each one."
  def volume_sizes do
    with {out, 0} <- docker(["system", "df", "-v", "--format", "{{json .}}"]),
         {:ok, %{"Volumes" => vs}} <- Jason.decode(out) do
      Map.new(vs, &{&1["Name"], &1["Size"]})
    else
      _ -> %{}
    end
  end

  @doc "The networks in scope with their subnet and who is on them."
  def networks(status, scope) do
    mine = project(status)

    with {out, 0} <- docker(["network", "ls", "--format", "{{json .}}"]),
         rows <- decode_lines(out),
         {ins, 0} <- docker(["network", "inspect" | Enum.map(rows, & &1["Name"])]),
         {:ok, details} <- Jason.decode(ins) do
      details = Map.new(details, &{&1["Name"], &1})

      rows
      |> Enum.map(fn r ->
        d = details[r["Name"]] || %{}
        labels = labels(r["Labels"])
        on = (d["Containers"] || %{}) |> Map.values() |> Enum.map(& &1["Name"]) |> Enum.sort()

        %{
          name: r["Name"],
          driver: r["Driver"],
          project: labels[@project],
          subnet:
            get_in(d, ["IPAM", "Config"]) |> List.wrap() |> Enum.map_join(", ", & &1["Subnet"]),
          on: on,
          mine?: labels[@project] == mine or @console in on
        }
      end)
      |> Enum.filter(&(scope == "daemon" or &1.mine?))
      |> Enum.sort_by(&{if(&1.mine?, do: 0, else: 1), &1.name})
    else
      _ -> []
    end
  end

  @doc "`system df`: four rows — images, containers, volumes, build cache. Slow: seconds."
  def df do
    case docker(["system", "df", "--format", "{{json .}}"]) do
      {out, 0} ->
        for r <- decode_lines(out),
            do: %{
              type: r["Type"],
              total: r["TotalCount"],
              active: r["Active"],
              size: r["Size"],
              reclaimable: r["Reclaimable"]
            }

      _ ->
        []
    end
  end

  @doc "The daemon in one line: version, platform, CPUs, memory, storage driver, host."
  def daemon do
    with {v, 0} <-
           docker([
             "version",
             "--format",
             "{{.Server.Version}} · {{.Server.Os}}/{{.Server.Arch}}"
           ]),
         {i, 0} <-
           docker([
             "info",
             "--format",
             "{{.NCPU}} CPU · {{.MemTotal}} · {{.Driver}} in {{.DockerRootDir}} · {{.OperatingSystem}}, kernel {{.KernelVersion}}"
           ]) do
      mem =
        Regex.replace(~r/ · (\d+) · /, i, fn _, b ->
          " · " <> human(String.to_integer(b)) <> " · "
        end)

      "Docker " <> String.trim(v) <> " · " <> String.trim(mem)
    else
      _ -> nil
    end
  end

  # --- the composes -----------------------------------------------------------

  @deploys [
    {"dev", "docker-compose.yml"},
    {"prod", "docker-compose.prod.yml"},
    {"scaled", "docker-compose.scaled.yml"}
  ]

  @doc "The three deployments' compose files off the workspace, masked; `lines: nil` for one not baked."
  def composes(nil), do: for({key, file} <- @deploys, do: %{key: key, file: file, lines: nil})

  def composes(status) do
    ws = status["workspace"]

    for {key, file} <- @deploys do
      lines =
        case ws && File.read(Path.join(ws, file)) do
          {:ok, text} -> text |> Project.mask() |> String.split("\n")
          _ -> nil
        end

      %{key: key, file: file, lines: lines}
    end
  end

  # --- the stats stream -------------------------------------------------------

  @doc "The argv of the stats stream: a JSON line per container, every couple of seconds."
  def stats_args, do: ["stats", "--format", "{{json .}}"]

  @doc """
  A line of the stream into a reading, or nil. The stream homes the
  cursor before each refresh, and the escape rides the first line.

  The cpu and the memory come normalised — one decimal, the memory
  always in MiB, the limit in GiB — so that a value's length does not
  change between two readings: Docker's three significant figures
  (`1.9MB`, `1.84MB`, `282.4MiB`) redrew the table's columns on every
  refresh (`assets/design/README.md`, *a measure in a column*).
  """
  def stat(line) do
    case line |> String.replace(~r/\e\[[0-9;]*[A-Za-z]/, "") |> Jason.decode() do
      {:ok, %{"Name" => name} = s} ->
        [used | limit] = String.split(s["MemUsage"] || "", " / ")

        %{
          name: name,
          cpu: percent(s["CPUPerc"]),
          mem: mib(used),
          limit: gib(List.first(limit)),
          memp: s["MemPerc"],
          net: s["NetIO"],
          block: s["BlockIO"],
          pids: s["PIDs"]
        }

      _ ->
        nil
    end
  end

  @doc "`1.12%` into `1.1 %`; what is not a number stays as it came."
  def percent(text) do
    case Float.parse(String.trim(text || "")) do
      # Float.round works on the decimal the number prints as — 101.35 is
      # 101.349… in binary, and float_to_binary alone would say 101.3.
      {f, _} -> f |> Float.round(1) |> :erlang.float_to_binary(decimals: 1) |> Kernel.<>(" %")
      _ -> text
    end
  end

  @doc "A memory the stream wrote — `952KiB`, `183.2MiB`, `1.5GiB` — in MiB, one decimal."
  def mib(text), do: fixed(binary_bytes(text), 1_048_576, "MiB", text)

  @doc "The same in GiB, for a limit."
  def gib(text), do: fixed(binary_bytes(text), 1_073_741_824, "GiB", text)

  # What was not a number stays as it came.
  defp fixed(nil, _, _, fallback), do: fallback

  defp fixed(bytes, per, unit, _),
    do:
      (bytes / per)
      |> Float.round(1)
      |> :erlang.float_to_binary(decimals: 1)
      |> Kernel.<>(" " <> unit)

  # Docker's stats units are the binary ones (KiB, MiB, GiB), its sizes
  # the decimal ones (kB, MB, GB): both read here, each at its worth.
  defp binary_bytes(text) do
    case Regex.run(~r/^([\d.]+)\s*([kKMGT]?)(i?)B$/, String.trim(text || "")) do
      [_, n, unit, i] ->
        {f, _} = Float.parse(n)
        base = if i == "i", do: 1024, else: 1000

        f *
          :math.pow(
            base,
            Enum.find_index(["", "k", "m", "g", "t"], &(&1 == String.downcase(unit)))
          )

      _ ->
        nil
    end
  end

  # --- reading docker's words -------------------------------------------------

  @doc "`0.0.0.0:4001->4000/tcp, [::]:4001->4000/tcp` into `4001→4000`, once."
  def ports(nil), do: []

  def ports(text) do
    text
    |> String.split(", ", trim: true)
    |> Enum.flat_map(fn p ->
      case Regex.run(~r/:(\d+)->(\d+)\//, p) do
        [_, host, inside] -> [host <> "→" <> inside]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  # The same, off inspect's map: `%{"4000/tcp" => [%{"HostPort" => "4001"}]}`
  # — once per port, though the daemon binds it on 0.0.0.0 and on ::.
  defp ports_of(map) do
    for(
      {inside, binds} <- map,
      is_list(binds),
      b <- binds,
      do: b["HostPort"] <> "→" <> hd(String.split(inside, "/"))
    )
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "A `k=v,k=v` label string into a map."
  def labels(nil), do: %{}

  def labels(text) do
    text
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn kv ->
      case String.split(kv, "=", parts: 2) do
        [k, v] -> [{k, v}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  @doc "`145MB`, `4.384GB`, `736kB` into bytes."
  def bytes(nil), do: 0

  def bytes(text) do
    case Regex.run(~r/^([\d.]+)\s*([kMGT]?)i?B$/, String.trim(text)) do
      [_, n, unit] ->
        {f, _} = Float.parse(n)
        round(f * :math.pow(1000, Enum.find_index(["", "k", "M", "G", "T"], &(&1 == unit))))

      _ ->
        0
    end
  end

  @doc "Bytes into docker's own words: `145 MB`."
  def human(n) when n < 1000, do: "#{n} B"

  def human(n) do
    {v, unit} =
      Enum.reduce_while(["kB", "MB", "GB", "TB"], {n / 1000, "kB"}, fn u, {v, _} ->
        if v < 1000, do: {:halt, {v, u}}, else: {:cont, {v / 1000, u}}
      end)

    "#{Float.round(v, if(v < 10, do: 2, else: 1))} #{unit}"
  end

  defp health(h) when h in [nil, "", "none"], do: nil
  defp health(h), do: h

  defp policy(p) when p in [nil, ""], do: "no"
  defp policy(p), do: p

  defp blank(""), do: nil
  defp blank(v), do: v

  # Docker's zero time is no time.
  defp moment(nil), do: nil
  defp moment("0001-01-01T00:00:00Z"), do: nil
  defp moment(t), do: t

  defp seconds(nil), do: nil
  defp seconds(ns), do: "#{div(ns, 1_000_000_000)} s"

  defp millis(a, b) do
    with {:ok, ta, _} <- DateTime.from_iso8601(a || ""),
         {:ok, tb, _} <- DateTime.from_iso8601(b || "") do
      DateTime.diff(tb, ta, :millisecond)
    else
      _ -> nil
    end
  end

  # `["CMD", "bash", "-c", "</dev/tcp/localhost/4000"]` as it would be typed.
  defp shell_words(words) do
    words
    |> Enum.reject(&(&1 in ["CMD", "CMD-SHELL"]))
    |> Enum.map_join(" ", fn w ->
      if String.contains?(w, [" ", "<", ">", "&", "|"]), do: ~s("#{w}"), else: w
    end)
  end

  defp decode_lines(out) do
    for line <- String.split(out, "\n", trim: true),
        match?({:ok, %{}}, Jason.decode(line)),
        do: Jason.decode!(line)
  end

  defp docker(args) do
    case System.find_executable("docker") do
      nil -> {"", 127}
      docker -> System.cmd(docker, args, stderr_to_stdout: true)
    end
  rescue
    _ -> {"", 1}
  end
end
