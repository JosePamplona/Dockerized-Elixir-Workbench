defmodule ConsoleWeb.Record do
  @moduledoc """
  The Record paper's plan: what the project is, read off the status and
  nothing else — its birth, the cartridges it carries with the
  addresses they open, and its deployments with the services each runs.

  Three tenses of one subject, from the permanent to the momentary.
  *Birth* is the first commit's reading, `project.birth`, set against
  today's: a fact that moved since carries the value it has now. The
  *cartridges* are the shelf's own rows — origin, edition — with the
  installation parameters as the flags `add` took and every address
  each opens: a route on the app's port. The *deployments* are the
  compose files beside the project, `project.deployments`: baked, in
  sync with what the cartridges ask for, up, and their services as
  ports with what `docker compose ps` says of each; the console itself
  first, the workbench's own container, mounted on this workspace.

  Every address is one face, `.door-ref`, with the reading attached: a
  route answers an HTTP code when the console calls it (`read/1`), a
  port what its healthcheck said. Nothing here is asked of the project
  for the workbench's sake: it is all read.
  """

  alias ConsoleWeb.Cartridges

  @caps ~w(ecto html live dashboard mailer gettext esbuild tailwind)
  @deploys ~w(dev prod scaled)
  @files %{
    "dev" => "docker-compose.yml",
    "prod" => "docker-compose.prod.yml",
    "scaled" => "docker-compose.scaled.yml"
  }
  @inside %{
    "app" => ":4000",
    "database" => ":5432",
    "prometheus" => ":9090",
    "grafana" => ":3000",
    "pgadmin" => ":80",
    "balancer" => ":80"
  }

  @doc "phx.new's own words for each flag, as `mix help phx.new` prints them."
  @docs %{
    "app" => "the name of the OTP application",
    "module" => "the name of the base module in the generated skeleton",
    "adapter" => "specify the http adapter. One of: cowboy, bandit. Defaults to \"bandit\"",
    "database" =>
      "specify the database adapter for Ecto. One of: postgres, mysql, mssql, sqlite3. Defaults to \"postgres\"",
    "binary-id" => "use binary_id as primary key type in Ecto schemas",
    "no-ecto" => "do not generate Ecto files",
    "no-html" => "do not generate HTML views",
    "no-live" =>
      "comment out LiveView socket setup in your Endpoint and assets/js/app.js. Automatically disabled if --no-html is given",
    "no-dashboard" => "do not include Phoenix.LiveDashboard",
    "no-mailer" => "do not generate Swoosh mailer files",
    "no-gettext" => "do not generate gettext files",
    "no-esbuild" =>
      "do not include esbuild dependencies and assets. We do not recommend setting this option, unless for API only applications",
    "no-tailwind" =>
      "do not include tailwind dependencies and assets. The generated markup will still include Tailwind CSS classes",
    "no-agents-md" => "do not generate an AGENTS.md file"
  }
  def docs, do: @docs

  @doc """
  The plan, off the status and the catalog: nil without a project.
  `reads` is what the console's last call answered, by href, or
  `:asking`; `console` is the console's own container as
  `Console.Docker.card/1` describes it, or nil when the console runs
  by hand.
  """
  def page(status, catalog, reads \\ %{}, console \\ nil)
  def page(nil, _catalog, _reads, _console), do: nil
  def page(%{"exists" => false}, _catalog, _reads, _console), do: nil

  def page(status, catalog, reads, console) do
    project = status["project"] || %{}
    port = get_in(status, ["ports", "app"])
    up = Cartridges.app_up?(status)

    %{
      name: status["compose_project"],
      port: port,
      up: up,
      birth: birth(project, status),
      cartridges: cartridges(status, catalog, port, up, reads),
      deployments: deployments(status, project),
      console: console_row(console)
    }
  end

  # --- birth --------------------------------------------------------------------

  # The first commit's reading against today's: each Dockerfile stamp and
  # each phx.new fact with what it is now when that moved.
  defp birth(%{"birth" => %{} = b} = project, status) do
    now_phx = project["phx"] || %{}
    born_phx = b["phx"] || %{}
    now_args = Console.Project.born(status["workspace"]) || %{}
    born_args = b["dockerfile"] || %{}
    generator = now_phx["generator"] || %{}

    dockerfile =
      for {key, label} <- [{"ELIXIR", "elixir"}, {"OTP", "erlang"}, {"DEBIAN", "debian"}] do
        %{
          key: label,
          born: born_args[key],
          now: moved(born_args[key], now_args[key]),
          line: ~s(ARG #{key}="#{born_args[key]}")
        }
      end

    flags =
      [
        flag("app", true, born_phx["app"], nil),
        flag("module", true, born_phx["module"], nil),
        flag(
          "adapter",
          true,
          born_phx["adapter"],
          nil,
          moved(born_phx["adapter"], now_phx["adapter"]),
          "bandit"
        ),
        flag(
          "database",
          true,
          born_phx["database"],
          "ecto",
          moved(born_phx["database"], now_phx["database"]),
          "postgres"
        ),
        flag(
          "binary-id",
          born_phx["binary_id"] == true,
          nil,
          "ecto",
          moved(born_phx["binary_id"], now_phx["binary_id"])
        )
      ] ++
        for(
          cap <- @caps,
          do:
            flag(
              "no-#{cap}",
              born_phx[cap] == false,
              nil,
              cap,
              moved(born_phx[cap], now_phx[cap])
            )
        ) ++
        [
          flag(
            "no-agents-md",
            born_phx["agents_md"] == false,
            nil,
            nil,
            moved(born_phx["agents_md"], now_phx["agents_md"])
          )
        ]

    flags =
      Enum.map(flags, fn f ->
        moot = moot(f.name, born_phx)

        f
        |> Map.put(:installed, f.cartridge && Cartridges.installed?(status, f.cartridge))
        |> Map.put(:moot, moot)
        |> then(&if(moot, do: %{&1 | used: false, arg: nil, default: nil, now: nil}, else: &1))
      end)

    %{
      sha: b["sha"],
      date: b["date"],
      subject: b["subject"],
      command: "mix phx.new . " <> Enum.join(b["phx"]["flags"] || [], " "),
      dockerfile: dockerfile,
      image:
        "hexpm/elixir:#{born_args["ELIXIR"]}-erlang-#{born_args["OTP"]}-debian-#{born_args["DEBIAN"]}",
      installer: %{
        born: born_args["PHX_NEW"],
        now: moved(born_args["PHX_NEW"], now_args["PHX_NEW"]),
        at_hand: generator["installer"],
        in_sync: is_nil(generator["installer"]) or generator["installer"] == generator["project"]
      },
      flags: flags,
      moved:
        Enum.count(dockerfile, & &1.now) + Enum.count(flags, & &1.now) +
          if(born_args["PHX_NEW"] != now_args["PHX_NEW"] and now_args["PHX_NEW"], do: 1, else: 0)
    }
  end

  defp birth(_project, _status), do: nil

  # A flag another flag makes moot, as phx.new's own generator binds them
  # (Phx.New.Generator.put_binding/1): the database and the id type only
  # exist with Ecto, and `live = html && live` — without HTML views there
  # is no LiveView to leave out. Marked, never hidden, with the reason.
  defp moot(name, %{"ecto" => false}) when name in ["database", "binary-id"],
    do: "only with Ecto: --no-ecto leaves the database out, so this flag has nothing to say"

  defp moot("no-live", %{"html" => false}),
    do:
      "only with HTML views: --no-html already leaves LiveView out (live = html && live in phx.new)"

  defp moot(_name, _born), do: nil

  defp flag(name, used, arg, cartridge, now \\ nil, default \\ nil),
    do: %{
      name: name,
      used: used,
      arg: arg && to_string(arg),
      default: arg && to_string(arg) == default,
      cartridge: cartridge,
      now: now,
      doc: @docs[name]
    }

  # What a fact is now, when it is not what it was born as; nil when unchanged or unknown.
  defp moved(born, now) when is_nil(now) or born == now, do: nil
  defp moved(_born, true), do: "in"
  defp moved(_born, false), do: "out"
  defp moved(_born, now), do: to_string(now)

  # --- cartridges -------------------------------------------------------------------

  defp cartridges(status, catalog, port, up, reads) do
    installed = Cartridges.installed(status)
    entry = fn c -> Enum.find(catalog, &(&1["name"] == c["name"])) || c end

    installed
    |> Enum.sort_by(&if(&1["base"], do: 1, else: 0))
    |> Enum.map(fn c ->
      e = entry.(c)

      %{
        c: c,
        entry: e,
        origin: Cartridges.origin(status, c),
        facts: Cartridges.facts(e),
        params: params(c, if(e["options"], do: e, else: c)),
        addresses:
          services(c, e, status) ++
            for(
              d <- get_in(e, ["console", "doors"]) || [],
              do: route(status, c, d, port, up, reads)
            )
      }
    end)
  end

  @doc """
  The installation parameters as the flags `add` takes — the vocabulary
  of the Insert commits' subjects: `[{flag, default?}]`. Every
  parameter the project reports is on the line; one that equals its
  default is marked. A boolean is its flag when on and nothing when off.
  """
  def params(c, e) do
    options = Map.new(e["options"] || [], &{&1["name"], &1})

    for {key, value} <- c["state"] || %{}, value not in [nil, [], ""], reduce: [] do
      acc ->
        o = options[key] || %{}
        flag = "--" <> String.replace(key, "_", "-")

        case {o["type"], value} do
          {"boolean", true} ->
            acc ++ [{flag, o["default"] == true}]

          {"boolean", _} ->
            acc

          {_, list} when is_list(list) ->
            acc ++ [{flag <> " " <> Enum.join(list, ","), false}]

          {_, v} ->
            acc ++ [{flag <> " " <> to_string(v), to_string(v) == to_string(o["default"])}]
        end
    end
  end

  # A route the cartridge opens on the app's port: shut by its condition,
  # or by the app being down, or open with its address and what it answered.
  defp route(status, c, d, port, up, reads) do
    path = Cartridges.fill_path(d["path"], c)

    why =
      cond do
        not Cartridges.holds?(status, c, d) ->
          if d["when"]["with"],
            do: "only with --with #{d["when"]["with"]}",
            else: "only with #{d["when"]["cartridge"]} inserted"

        not up ->
          "the app is down"

        true ->
          nil
      end

    href = if is_nil(why) and port, do: "http://localhost:#{port}#{path}"

    %{
      label: d["label"],
      path: path,
      kind: "route",
      port: port,
      href: href,
      why: why,
      read: read(reads, href)
    }
  end

  # The ports of the services a cartridge asks the workspace for, as
  # `docker compose ps` sees them now; the engine's service is `database`.
  defp services(c, e, status) do
    for name <- (e["services_of"] || []) ++ services_of(c), do: port_of(status, name)
  end

  # What `services/1` of the cartridge answers is not in the catalog per
  # cartridge; the status carries the project's asks as a whole, so the
  # one cartridge that asks for a database is read off its state.
  defp services_of(%{"name" => "ecto", "state" => %{"database" => db}})
       when db in ~w(postgres mysql mssql), do: ["database"]

  defp services_of(%{"name" => "pgadmin"}), do: ["pgadmin"]
  defp services_of(%{"name" => "k6"}), do: ["k6"]
  defp services_of(%{"name" => "monitoring"}), do: ["prometheus", "grafana"]
  defp services_of(_), do: []

  defp port_of(status, service) do
    container = Enum.find(status["containers"] || [], &(&1["Service"] == service))
    up = Cartridges.app_up?(status)

    %{
      label: service,
      path: @inside[service] || "",
      kind: "port",
      port: nil,
      href: nil,
      why: if(up, do: nil, else: "the deployment is down"),
      read: container && container_read(container)
    }
  end

  defp container_read(c) do
    state = String.downcase(blank(c["Health"]) || c["State"] || "")

    {state,
     if(state in ~w(healthy running),
       do: "good",
       else: if(state == "starting", do: "warn", else: "bad")
     )}
  end

  defp blank(""), do: nil
  defp blank(v), do: v

  defp read(_reads, nil), do: nil
  defp read(:asking, _href), do: {"asking…", "busy off"}
  defp read(reads, href), do: reads[href]

  # --- deployments ----------------------------------------------------------------

  defp deployments(status, project) do
    ws = status["workspace"]
    up_one = status["deployment"]
    reported = project["deployments"] || %{}

    for deploy <- @deploys do
      d = reported[deploy] || %{}
      baked = d["baked"] == true or get_in(status, ["baked", deploy]) == true
      up = up_one == deploy
      published = if(baked and ws, do: published(Path.join(ws, @files[deploy])), else: %{})

      %{
        deploy: deploy,
        baked: baked,
        in_sync: d["in_sync"],
        stray: d["stray"] || [],
        missing: d["missing"] || [],
        status:
          cond do
            not baked -> nil
            up -> "up"
            true -> "down"
          end,
        services:
          for name <- d["services"] || [] do
            container =
              if(up, do: Enum.find(status["containers"] || [], &(&1["Service"] == name)))

            read = container && container_read(container)
            why = if(up, do: nil, else: "the deployment is down")

            case published[name] do
              [_ | _] = ports ->
                for p <- ports,
                    do: %{
                      label: name,
                      path: "localhost:#{p}",
                      kind: "port",
                      port: nil,
                      href: up && "http://localhost:#{p}",
                      why: why,
                      read: read
                    }

              _ ->
                path =
                  if(deploy == "scaled" and @inside[name],
                    do: name <> @inside[name],
                    else: @inside[name] || ""
                  )

                [
                  %{
                    label: name,
                    path: path,
                    kind: "port",
                    port: nil,
                    href: nil,
                    why: why,
                    read: read
                  }
                ]
            end
          end
          |> List.flatten()
      }
    end
  end

  # The ports each service publishes, off the compose file: `- 4001:4000` under `ports:`.
  defp published(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> String.split("\n")
        |> Enum.reduce({nil, false, %{}}, fn line, {svc, inside, acc} ->
          service = Regex.run(~r/^  ([a-z0-9_-]+):\s*$/, line)
          bind = inside && Regex.run(~r/^\s+- (\d+):(\d+)/, line)

          cond do
            service ->
              {Enum.at(service, 1), false, acc}

            Regex.match?(~r/^\s+ports:/, line) ->
              {svc, true, acc}

            bind ->
              {svc, true, Map.update(acc, svc, [Enum.at(bind, 1)], &(&1 ++ [Enum.at(bind, 1)]))}

            inside and not Regex.match?(~r/^\s+#/, line) ->
              {svc, false, acc}

            true ->
              {svc, inside, acc}
          end
        end)
        |> elem(2)

      _ ->
        %{}
    end
  end

  # The console: the workbench's own container, a docker run outside the compose.
  defp console_row(nil), do: nil

  defp console_row(card) do
    port =
      card.ports
      |> Enum.find_value(fn p ->
        case String.split(p, "→") do
          [host, "4000"] -> host
          _ -> nil
        end
      end)

    mount =
      Enum.find_value(
        card.env,
        &(String.starts_with?(&1, "WORKSPACE_MOUNT_PATH=") &&
            String.replace_prefix(&1, "WORKSPACE_MOUNT_PATH=", ""))
      )

    state = card.state || ""

    %{
      label: "console",
      path: "localhost:#{port}",
      kind: "console",
      port: nil,
      href: port && "http://localhost:#{port}",
      why: nil,
      read: {state, if(state == "running", do: "good", else: "bad")},
      image: card.image,
      mount: mount
    }
  end

  @doc "The addresses of a plan the console can call: every open route."
  def hrefs(nil), do: []

  def hrefs(page),
    do:
      for(
        row <- page.cartridges,
        a <- row.addresses,
        is_binary(a.href),
        a.kind == "route",
        uniq: true,
        do: a.href
      )
end
