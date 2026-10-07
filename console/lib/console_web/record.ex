defmodule ConsoleWeb.Record do
  @moduledoc """
  The Birth paper's plan (the ribbon called it Record until 2026-09-12,
  and the module keeps that name): what the project is, read off the status and
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
  ports with what `docker compose ps` says of each. The console itself
  had a row here for a day and went (2026-09-09): not a deployment, and
  nothing it said was not evident from reading the page on it.

  Every address is one face, `.door-ref`, with the reading attached: a
  route answers an HTTP code when the console calls it (`read/1`), a
  port what its healthcheck said. Nothing here is asked of the project
  for the workbench's sake: it is all read.
  """

  alias ConsoleWeb.Cartridges
  alias ConsoleWeb.Reports

  @caps ~w(ecto html live dashboard mailer gettext esbuild tailwind)
  @deploys ~w(dev prod scaled)
  @files %{
    "dev" => "docker-compose.yml",
    "prod" => "docker-compose.prod.yml",
    "scaled" => "docker-compose.scaled.yml"
  }
  # What the skeleton of a compose file has of its own, and listens on;
  # a cartridge's service says its own port (`compose`, in the status).
  @skeleton %{"app" => ":4000", "balancer" => ":80"}

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
  `:asking`.
  """
  def page(status, catalog, reads \\ %{})
  def page(nil, _catalog, _reads), do: nil
  def page(%{"exists" => false}, _catalog, _reads), do: nil

  def page(status, catalog, reads) do
    project = status["project"] || %{}
    port = get_in(status, ["ports", "app"])
    up = Cartridges.app_up?(status)

    %{
      name: status["compose_project"],
      port: port,
      up: up,
      birth: birth(project, status),
      cartridges: cartridges(status, catalog, port, up, reads),
      deployments: deployments(status, project)
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
      born_phx
      |> born_flags(now_phx)
      |> Enum.map(&with_moot(&1, born_phx, now_phx, status))

    %{
      sha: b["sha"],
      date: b["date"],
      subject: b["subject"],
      command: "mix phx.new . " <> Enum.join(b["phx"]["flags"] || [], " "),
      dockerfile: dockerfile,
      image:
        "hexpm/elixir:#{born_args["ELIXIR"]}-erlang-#{born_args["OTP"]}-debian-#{born_args["DEBIAN"]}",
      docs: phx_new_docs(born_args["PHX_NEW"]),
      installer: installer(born_args["PHX_NEW"], now_args["PHX_NEW"], now_phx["generator"]),
      flags: flags,
      moved:
        Enum.count(dockerfile, & &1.now) + Enum.count(flags, & &1.now) +
          if(moved(born_args["PHX_NEW"], now_args["PHX_NEW"]), do: 1, else: 0)
    }
  end

  defp birth(_project, _status), do: nil

  # The phx_new the project was born with, the one stamped now, and the
  # one at hand to generate with.
  defp installer(born, now, generator) do
    generator = generator || %{}

    %{
      born: born,
      now: moved(born, now),
      at_hand: generator["installer"],
      in_sync: is_nil(generator["installer"]) or generator["installer"] == generator["project"]
    }
  end

  # The flags phx.new was given at birth, each against today's fact.
  defp born_flags(born_phx, now_phx) do
    cap_flag = fn cap ->
      flag(
        "no-#{cap}",
        born_phx[cap] == false,
        nil,
        cartridge_of(cap),
        moved(born_phx[cap], now_phx[cap])
      )
    end

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
      # Ecto's own flag first, then the two that only mean something with it.
      cap_flag.("ecto"),
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
      Enum.map(@caps -- ["ecto"], cap_flag) ++
      [
        flag(
          "no-agents-md",
          born_phx["agents_md"] == false,
          nil,
          nil,
          moved(born_phx["agents_md"], now_phx["agents_md"])
        )
      ]
  end

  # A flag another flag made moot says so, and why; one made moot at
  # birth whose cause came in since reads today's fact.
  defp with_moot(f, born_phx, now_phx, status) do
    f = Map.put(f, :installed, f.cartridge && Cartridges.installed?(status, f.cartridge))

    case moot(f.name, born_phx, now_phx) do
      nil ->
        Map.put(f, :moot, nil)

      # What made it moot has come in since — Ecto, the HTML views, a
      # base cartridge each: the flag was still not given, and the row
      # says what the fact is now against a birth that had none. The
      # birth's reading carries phx.new's default database under
      # --no-ecto, which is no database: today's is the news.
      :since ->
        now = if f.name == "database", do: now_phx["database"], else: f.now

        %{f | used: false, arg: nil, default: nil, now: now && to_string(now)}
        |> Map.put(:moot, nil)

      why ->
        %{f | used: false, arg: nil, default: nil, now: nil} |> Map.put(:moot, why)
    end
  end

  # A flag another flag makes moot, as phx.new's own generator binds them
  # (Phx.New.Generator.put_binding/1): the database and the id type only
  # exist with Ecto, and `live = html && live` — without HTML views there
  # is no LiveView to leave out. Marked, never hidden, with the reason —
  # while it holds: a project born minimal takes Ecto and the HTML views
  # as base cartridges afterwards, and from then on the flag has
  # something to say again (`:since`). Until 2026-09-17 the birth alone
  # decided, and those rows stayed unlit, their `now` thrown away, on a
  # project that had a database and LiveView.
  defp moot(name, %{"ecto" => false}, now) when name in ["database", "binary-id"] do
    if now["ecto"] == true,
      do: :since,
      else: "only with Ecto: --no-ecto leaves the database out, so this flag has nothing to say"
  end

  defp moot("no-live", %{"html" => false}, now) do
    if now["html"] == true,
      do: :since,
      else:
        "only with HTML views: --no-html already leaves LiveView out (live = html && live in phx.new)"
  end

  defp moot(_name, _born, _now), do: nil

  # Where the flags' words come from: `mix phx.new`'s own page, which
  # the docs column quotes. At the version that generated the project
  # when the Dockerfile's stamp says it — phx_new and phoenix share a
  # number, and hexdocs keeps a page per release, so the options read
  # there are the ones this project had and not today's — and at the
  # current page when it does not.
  defp phx_new_docs(version) when is_binary(version) and version != "" do
    if Regex.match?(~r/^\d+\.\d+\.\d+(-[\w.]+)?$/, version),
      do: "https://hexdocs.pm/phoenix/#{version}/Mix.Tasks.Phx.New.html",
      else: phx_new_docs(nil)
  end

  defp phx_new_docs(_version), do: "https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html"

  # The cartridge a capability's flag points at: its own, but for
  # LiveView, which is html's `--live` since 2026-09-18 (the `live`
  # cartridge went into html; the row named a box that is no longer on
  # the shelf), as the database and the ids are ecto's.
  defp cartridge_of("live"), do: "html"
  defp cartridge_of(cap), do: cap

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

  @doc """
  What the project carries, a row each: the catalog entry behind it,
  where it came from, its facts, the parameters it was installed with
  and the addresses it opens. The shelf's *Inserted* list draws these
  (it was the Record paper's second section until 2026-09-10, where
  only a project could read them; the shelf already knows which are
  in).
  """
  def cartridges(status, catalog, reads \\ %{}),
    do:
      cartridges(
        status,
        catalog,
        get_in(status, ["ports", "app"]),
        Cartridges.app_up?(status),
        reads
      )

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
        params: params(c, if(e["options"], do: e, else: c), Cartridges.insert(status, c["name"])),
        addresses: addresses(status, c, e, port, up, reads)
      }
    end)
  end

  @doc """
  Every address a cartridge opens, the ports of the services it asks
  for first and then its routes on the app's port — one face each,
  with the reading when there is one. What the Record's row shows, and
  the rail's Cartridges section too.
  """
  def addresses(status, c, e, reads \\ %{}),
    do:
      addresses(status, c, e, get_in(status, ["ports", "app"]), Cartridges.app_up?(status), reads)

  @doc "One door a cartridge declares, as its row reads it: the box's Opens shows the same."
  def door(status, c, d, reads \\ %{}),
    do: route(status, c, d, get_in(status, ["ports", "app"]), Cartridges.app_up?(status), reads)

  # In the rail's order — the services, the routes, the pages — each
  # group in the order the cartridge declares (2026-09-25; a page sat
  # among its cartridge's routes).
  defp addresses(status, c, e, port, up, reads) do
    doors =
      for d <- get_in(e, ["console", "doors"]) || [], do: route(status, c, d, port, up, reads)

    services(c, status, reads) ++ Enum.sort_by(doors, &(&1.kind == "output"))
  end

  @doc """
  The installation parameters as the flags `add` takes — the vocabulary
  of the Insert commits' subjects: `[{flag, default?}]`. Every
  parameter the project reports is on the line; one that equals its
  default is marked. A boolean is its flag when on and nothing when off.
  """
  def params(c, e, insert \\ nil) do
    options = Map.new(e["options"] || [], &{&1["name"], &1})

    # A cartridge that reports nothing of itself — no `state/1`, or an
    # edition from before it had one — still went in with a line, and its
    # Insert commit keeps it: `Insert health_endpoint --endpoint /health3
    # --open-api`. What the project reports wins; the commit is what is
    # left to read when it reports nothing (2026-09-10).
    case {c["state"] || %{}, insert} do
      {state, %{"argv" => [_ | _] = argv}} when state == %{} -> argv_params(argv, options)
      {state, _} -> state_params(state, options)
    end
  end

  defp state_params(state, options) do
    for {key, value} <- state, value not in [nil, [], ""], reduce: [] do
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

  # The Insert commit's words as the column's pairs: a flag with the
  # value that follows it, or a flag alone; marked when it says the
  # default, as the project's own reading is.
  defp argv_params([], _options), do: []

  defp argv_params(["--" <> _ = flag, "--" <> _ = next | rest], options),
    do: argv_params([flag], options) ++ argv_params([next | rest], options)

  defp argv_params(["--" <> name = flag, value | rest], options) do
    o = options[String.replace(name, "-", "_")] || %{}
    [{flag <> " " <> value, value == to_string(o["default"])} | argv_params(rest, options)]
  end

  defp argv_params([flag | rest], options), do: [{flag, false} | argv_params(rest, options)]

  # A page a tool of the project wrote on disk, served by the console on
  # the origin beside it (ConsoleWeb.Reports): shut by its condition, or
  # while nothing is built, never by the app — it answers with the app
  # down. Its reading is when it was built, off the disk at each render;
  # a knock renders it again, which catches a build made outside the
  # console. Never called over HTTP: the file is the truth.
  defp route(status, c, %{"output" => %{} = o} = d, _port, _up, _reads) do
    output = %{dir: Cartridges.fill_path(o["dir"], c), index: o["index"]}
    built = Reports.built(status["workspace"], output)
    port = Reports.port()
    shut = not Cartridges.holds?(status, c, d)

    why =
      cond do
        shut -> shut_why(d)
        is_nil(port) -> "the console serves no pages here"
        is_nil(built) -> "nothing built in #{output.dir}/ yet"
        true -> nil
      end

    %{
      label: d["label"],
      path: output.dir <> "/",
      filed: page_filed(status["workspace"], output, built, o["from"] || []),
      kind: "output",
      port: nil,
      href: if(is_nil(why), do: "http://localhost:#{port}/#{d["label"]}/"),
      why: why,
      read: built && {built_when(built), ""},
      # The cartridge says which of the project's Mix tasks writes it,
      # and the door offers that command whether the page is there or
      # not: nothing built, it is the one thing to press; built, it is
      # the rebuild, beside the stamp (2026-09-25). The workbench never
      # invents one — `./wb.sh mix <task>` is the project's own.
      build: if(not shut, do: build_task(status, c, o))
    }
  end

  # A route the cartridge opens on the app's port: shut by its condition,
  # or by the app being down, or open with its address and what it answered.
  defp route(status, c, d, port, up, reads) do
    path = Cartridges.fill_path(d["path"], c)

    why =
      cond do
        not Cartridges.holds?(status, c, d) ->
          shut_why(d)

        not up ->
          "the app is down"

        true ->
          nil
      end

    href = if is_nil(why) and port, do: "http://localhost:#{port}#{path}"

    Map.merge(
      %{
        label: d["label"],
        path: path,
        kind: "route",
        port: port,
        href: href,
        why: why,
        read: read(reads, href),
        build: nil,
        filed: nil,
        client: nil
      },
      for_client(status, c, d, port, path, read(reads, href))
    )
  end

  # The page is its file: missing, or written — and, where the
  # cartridge says what it is made from, up to date or behind: behind
  # when a file among its sources is newer than the page. That is what
  # the dates say and no more — a file touched and not changed counts,
  # and a dependency that moved does not — so the word is *behind*, and
  # the reason how many files.
  defp page_filed(_root, output, nil, _from),
    do: %{file: Path.join(output.dir, output.index), written: nil, state: "missing", why: nil}

  defp page_filed(root, output, built, from) do
    file = Path.join(output.dir, output.index)

    {state, why} =
      case newer(root, from, Path.join([root, output.dir, output.index])) do
        nil -> {"written", nil}
        0 -> {"up to date", nil}
        1 -> {"behind", "1 file changed since"}
        n -> {"behind", "#{n} files changed since"}
      end

    %{file: file, written: built_when(built), state: state, why: why}
  end

  # How many files under `from` — files, or directories read whole —
  # changed since `page` was written; `nil` when there is nothing to
  # compare with.
  #
  # The dates say which files to look at, and git says whether they
  # changed. A date alone is no witness: on 2026-10-07 `mix cover`
  # touched a source of the project while it ran, half a minute after
  # `mix docs` had written the site, and by the dates the site was
  # behind a file nobody had edited. So a file newer than the page
  # counts only when git has it changed in the tree, or committed since
  # the page was written. No file newer, and git is not asked at all;
  # no repository, and the dates are all there is.
  defp newer(root, from, page) when is_binary(root) and from != [] do
    case File.stat(page, time: :posix) do
      {:ok, %File.Stat{mtime: written}} ->
        later =
          from
          |> Enum.flat_map(&sources(root, &1))
          |> Enum.filter(fn path ->
            match?(
              {:ok, %File.Stat{type: :regular, mtime: m}} when m > written,
              File.stat(path, time: :posix)
            )
          end)

        changed(root, from, written, later)

      _ ->
        nil
    end
  end

  defp newer(_root, _from, _page), do: nil

  defp changed(_root, _from, _written, []), do: 0

  defp changed(root, from, written, later) do
    case moved_since(root, from, written) do
      :unknown -> length(later)
      moved -> Enum.count(later, &MapSet.member?(moved, Path.relative_to(&1, root)))
    end
  end

  # The paths under `from` that git has changed in the tree, tracked or
  # not, or committed since `written`.
  defp moved_since(root, from, written) do
    git = fn args ->
      System.cmd("git", ["-C", root, "-c", "core.quotePath=false" | args] ++ ["--" | from],
        stderr_to_stdout: true
      )
    end

    with {dirty, 0} <- git.(~w(status --porcelain --no-renames --untracked-files=all)),
         {committed, 0} <- git.(["log", "--since=@#{written}", "--name-only", "--format="]) do
      dirty = for line <- String.split(dirty, "\n", trim: true), do: String.slice(line, 3..-1//1)
      MapSet.new(dirty ++ String.split(committed, "\n", trim: true))
    else
      _ -> :unknown
    end
  end

  # A source of the project's own: a path that does not climb out of it,
  # itself when a file, everything under it when a directory.
  defp sources(root, rel) do
    with {:ok, safe} when safe != "" <- Path.safe_relative(rel),
         path = Path.join(root, safe),
         true <- File.exists?(path) do
      if File.dir?(path), do: Path.wildcard(Path.join(path, "**/*")), else: [path]
    else
      _ -> []
    end
  end

  # What a door for a client has over a page's route, while its
  # condition holds: any answer read as the door answering, the
  # project's task that sets a client up, the state of the file that
  # task writes, and the lines a client is given. Shut, it gives nothing.
  defp for_client(_status, _c, %{"client" => nil}, _port, _path, _read), do: %{}

  defp for_client(status, c, %{"client" => lines} = d, port, path, read) when is_list(lines) do
    holds = Cartridges.holds?(status, c, d)
    address = port && "http://localhost:#{port}#{path}"

    %{
      read: answers(read),
      build: if(holds, do: build_task(status, c, d)),
      filed: if(holds && d["writes"], do: filed(status["workspace"], d["writes"], address)),
      client: given(lines, port, path, holds)
    }
  end

  defp for_client(_status, _c, _d, _port, _path, _read), do: %{}

  # A door for a client: its address is told, not opened, and the
  # cartridge's lines are filled with it — while the port is known, the
  # app up or not, since the line is kept by the client. A door shut by
  # its condition has nothing to give yet.
  defp given(_lines, port, _path, holds) when is_nil(port) or not holds, do: []

  defp given(lines, port, path, _holds) do
    for %{"label" => label, "line" => line} <- lines,
        do: {label, String.replace(line, "{url}", "http://localhost:#{port}#{path}")}
  end

  # The file a door's task writes, as the project has it now: missing;
  # up to date while it carries the door's address; behind once the
  # address moved — another port after a bake — and the file still
  # names the old one. A comparison of text: the console does not read
  # the file as anything. With no address to compare (no port known)
  # it is written, and no more is said.
  defp filed(root, file, address) when is_binary(root) do
    with {:ok, rel} when rel != "" <- Path.safe_relative(file),
         built when not is_nil(built) <-
           Reports.built(root, %{dir: Path.dirname(rel), index: Path.basename(rel)}),
         {:ok, content} <- File.read(Path.join(root, rel)) do
      {state, why} =
        cond do
          is_nil(address) ->
            {"written", nil}

          String.contains?(content, address) ->
            {"up to date", nil}

          true ->
            {"behind",
             "the address is #{String.replace_prefix(address, "http://localhost", "")} now"}
        end

      %{file: rel, written: built_when(built), state: state, why: why}
    else
      _ -> %{file: file, written: nil, state: "missing", why: nil}
    end
  end

  defp filed(_root, file, _address), do: %{file: file, written: nil, state: "missing", why: nil}

  # What a call to an endpoint says: it is called as a page is, and
  # answers a page's question with a refusal — MCP's 406 to a GET with
  # no stream accepted. The refusal is the endpoint's own, so any answer
  # is the door answering; only silence, or the app failing, is not.
  defp answers({_code, class}) when class in ["good", "warn"], do: {"answers", "good"}

  defp answers(read), do: read

  # The first command whose condition holds — coverage's `mix cover`
  # where the docs site takes the report, ExCoveralls' own task
  # otherwise.
  defp build_task(status, c, o) do
    case Enum.find(o["build"] || [], &Cartridges.holds?(status, c, &1)) do
      %{"task" => task} -> task
      nil -> nil
    end
  end

  defp shut_why(%{"when" => %{"option" => key} = w}) do
    flag = "--" <> String.replace(key, "_", "-")

    case w["value"] do
      nil ->
        "only with #{flag}"

      # Any one of them: ash's `/sign-in` takes every strategy but one.
      [value] ->
        "only with #{flag} #{value}"

      values when is_list(values) ->
        "only with #{flag} #{values |> Enum.take(3) |> Enum.join(", ")}, …"

      value ->
        "only with #{flag} #{value}"
    end
  end

  defp shut_why(d), do: "only with #{d["when"]["cartridge"]} inserted"

  # The day and the time, on the machine's own clock (`Reports.built/2`
  # reads the mtime local): a page on disk is read against what the
  # project was when it was written, and "18:18" left the reader to
  # guess which day that was. The offset went with it until 2026-09-25;
  # the reader's clock is the machine's, so it said nothing they did not
  # know. The stamp says "built" by being there; *build* is beside it
  # whether or not, since a page is written again as often as the
  # project moves.
  defp built_when(built), do: Calendar.strftime(built, "%Y-%m-%d %H:%M")

  # The services a cartridge brings to the workspace, as `docker compose
  # ps` sees them now — what they are is the cartridge's to say, in the
  # status (`compose`: each by name, with the port it listens on and the
  # ones the host publishes). Each is written as the service it is, the
  # way the rail's Services line writes it: published on the host,
  # `pgadmin localhost:5051`, a port the reader opens while its
  # container runs; not published, `database :5432`, the port inside.
  # Its reading is its container's, never a call: it was a door at its
  # root, knocked over HTTP, until 2026-09-25.
  # Every one, whichever deployment it enters (2026-09-27): a release's
  # one-shot is not something the project has running beside it, and
  # the row left it out for that until now — but ecto's migrate is a
  # container the cartridge brings, and a reader who does not see it
  # here wonders where it went. It is shut with the deployment it is in.
  defp services(c, status, _reads), do: for(b <- c["compose"] || [], do: service(status, b))

  @doc """
  One service a cartridge brings, as its row reads it: the box's Brings
  shows the same (2026-09-27; it wore a face of its own, the rail's
  Services dot in the role's colour, from the day it was drawn). Off
  the project's `compose` entry: a door on the host where the compose
  publishes it, a port inside where it does not. A service of another
  deployment than the one up — a release's one-shot while dev runs —
  has no container here, and the plate says which deployment it is in
  rather than calling the deployment down.
  """
  def service(status, b) do
    host =
      Enum.find_value(b["published"] || [], fn internal ->
        get_in(status, ["ports", "published", to_string(internal)])
      end)

    face =
      if is_integer(host),
        do: door_of(status, b["service"], host),
        else: port_of(status, b["service"], listens(b))

    up = status["deployment"]

    if is_nil(face.read) and is_binary(up) and up not in (b["deploys"] || ["dev"]),
      do: %{face | href: nil, why: "not in the #{up} deployment"},
      else: face
  end

  @doc """
  A service a cartridge would bring, as the row of a box that is not in
  draws it: shut, with `why` as the reason — "not inserted" on the
  shelf's list, the switch that brings it on the box's Brings. The
  compose's menu says whether the host would publish it (a door) or
  not (a port inside), and the port it listens on when that does not
  hang on a choice.
  """
  def offered_service(b, why) do
    %{
      label: b["service"],
      path: listens(b),
      kind: if((b["published"] || []) == [], do: "inside", else: "port"),
      port: nil,
      href: nil,
      why: why,
      read: nil,
      read_title: nil
    }
  end

  defp listens(%{"listens" => port}) when is_integer(port), do: ":#{port}"
  defp listens(_), do: ""

  @doc """
  The switches that would bring an offered service, in the words the
  reader would type — "only with --database postgres, mysql" — or nil
  for one that comes whatever is chosen.
  """
  def only_with(offer) do
    said =
      (offer["with"] || [])
      |> Enum.group_by(& &1["option"], & &1["value"])
      |> Enum.map_join(" · ", fn {option, values} ->
        "--#{String.replace(option, "_", "-")} #{Enum.join(values, ", ")}"
      end)

    if said == "", do: nil, else: "only with #{said}"
  end

  @doc """
  What a cartridge that is not in would take and open, off its catalog
  entry: its parameters as `[{flag, type, title}]` — the title says its
  doc, its default and its choices — and its addresses as the Inserted
  row draws them, every one shut: a door is read, never hidden, and
  this one is not in yet. The services are the whole menu (`offers`,
  since 2026-09-27; it read `compose`, what comes with nothing chosen,
  and ecto and db_admin showed none): one that waits on a choice says
  the switch that brings it after "not inserted", in the words the
  box's Brings uses.
  """
  def offered(e) do
    shut = fn label, path, kind ->
      %{
        label: label,
        path: path,
        kind: kind,
        port: nil,
        href: nil,
        why: "not inserted",
        read: nil
      }
    end

    %{
      params:
        for o <- e["options"] || [] do
          {"--" <> String.replace(o["name"], "_", "-"), offered_type(o), offered_title(o)}
        end,
      addresses:
        for(
          b <- e["offers"] || e["compose"] || [],
          do:
            offered_service(
              b,
              Enum.join(["not inserted", only_with(b)] |> Enum.reject(&is_nil/1), ", ")
            )
        ) ++
          (for d <- get_in(e, ["console", "doors"]) || [] do
             shut.(
               d["label"],
               Cartridges.fill_path(d["path"], e),
               if(d["output"], do: "output", else: "route")
             )
           end
           |> Enum.sort_by(&(&1.kind == "output")))
    }
  end

  # What follows the flag: its values when the cartridge declares them in
  # `choices/0` — the enum the OptionParser type cannot say — else the
  # type. An open choice takes other values too, so it ends in `…`; a
  # long one (ash's --auth, seventeen strategies) shows four and the count,
  # the whole list in the title.
  @shown 4
  defp offered_type(o) do
    case Enum.flat_map(o["choices"] || [], &choice_values/1) do
      [] ->
        o["type"]

      values ->
        {shown, rest} = Enum.split(values, @shown)

        Enum.join(shown, " | ") <>
          if(rest != [], do: " +#{length(rest)}", else: "") <>
          if(o["open"], do: " …", else: "")
    end
  end

  defp offered_title(o) do
    choices = Enum.flat_map(o["choices"] || [], &choice_values/1)

    [
      o["doc"],
      o["default"] not in [nil, "", []] && "default #{default_text(o["default"])}",
      choices != [] &&
        "#{if o["open"], do: "one of, or another", else: "one of"} #{Enum.join(choices, ", ")}"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  # A choice is a value, or a section of them.
  defp choice_values(%{"value" => v}), do: [to_string(v)]
  defp choice_values(%{"values" => vs}), do: Enum.flat_map(vs, &choice_values/1)
  defp choice_values(_), do: []

  defp default_text(list) when is_list(list), do: Enum.join(list, ",")
  defp default_text(v), do: to_string(v)

  defp port_of(status, service, listens) do
    container = Enum.find(status["containers"] || [], &(&1["Service"] == service))
    up = Cartridges.app_up?(status)

    %{
      label: service,
      svc: ConsoleWeb.Services.color(status, service),
      path: listens,
      kind: "inside",
      port: nil,
      href: nil,
      why: if(up, do: nil, else: "the deployment is down"),
      read: container && container_read(container),
      read_title: container && container["Status"]
    }
  end

  # A service's port on the host: open while its container runs, read
  # as its container reads (healthy, running).
  defp door_of(status, service, port) do
    container = Enum.find(status["containers"] || [], &(&1["Service"] == service))

    why =
      cond do
        is_nil(container) -> "the deployment is down"
        container["State"] != "running" -> "the #{service} container is #{container["State"]}"
        true -> nil
      end

    %{
      label: service,
      svc: ConsoleWeb.Services.color(status, service),
      path: "localhost:#{port}",
      kind: "port",
      port: nil,
      href: if(is_nil(why), do: "http://localhost:#{port}"),
      why: why,
      read: container && container_read(container),
      read_title: container && container["Status"]
    }
  end

  defp container_read(c), do: Cartridges.container_reading(c)

  defp read(_reads, nil), do: nil
  defp read(:asking, _href), do: {"asking…", "busy off"}
  defp read(reads, href), do: reads[href]

  # --- deployments ----------------------------------------------------------------

  @doc """
  The three deployments, off the status: each compose file baked, in
  sync with what the cartridges ask for (nil when the status is a fast
  one, without the project), up or down, and its services as ports —
  or `unavailable`, with the reason, when the project cannot have it.
  What the Record's table shows, and the rail's Deployments too.
  """
  def deployments(status), do: deployments(status, status["project"] || %{})

  defp deployments(status, project) do
    up_one = status["deployment"]
    reported = project["deployments"] || %{}

    # What each service listens on: the skeleton's two, and what every
    # cartridge of the project says of its own.
    inside =
      for c <- project["cartridges"] || [],
          b <- c["compose"] || [],
          is_integer(b["listens"]),
          into: @skeleton,
          do: {b["service"], ":#{b["listens"]}"}

    for deploy <- @deploys do
      deployment(deploy, reported[deploy] || %{}, status, up_one == deploy, inside)
    end
  end

  defp deployment(deploy, d, status, up, inside) do
    ws = status["workspace"]
    baked = d["baked"] == true or get_in(status, ["baked", deploy]) == true
    services = d["services"] || []
    containers = status["containers"] || []

    published =
      if(baked and ws, do: published(Path.join(ws, @files[deploy])), else: %{})
      |> claimed(services, inside)

    present = Enum.any?(containers, &(of_deployment(&1) == deploy))

    at = %{
      deploy: deploy,
      up: up,
      mine: mine?(up, present, status["deployment"]),
      containers: containers,
      inside: inside,
      status: status
    }

    %{
      deploy: deploy,
      file: @files[deploy],
      baked: baked,
      present: present,
      in_sync: d["in_sync"],
      stray: d["stray"] || [],
      missing: d["missing"] || [],
      # Why the project cannot have this deployment, in its cartridge's
      # words (`WorkbenchIgniter.Deployments`); nil when it can.
      unavailable: d["unavailable"],
      status: deploy_status(baked, up, present),
      services: Enum.flat_map(services, &service_doors(&1, published[&1], at))
    }
  end

  # Whose the containers of the status are: one deployment is up at a
  # time, so they are this row's while it is the one up — and, with
  # nothing up, the row whose leftovers they are, which is what makes a
  # `stopped` row able to say `exited 1` of a service.
  defp mine?(true, _present, _up_one), do: true
  defp mine?(false, present, nil), do: present
  defp mine?(false, _present, _up_one), do: false

  # up: running. stopped: its containers are there, stopped — a Stop,
  # for a fast Up again. down: no containers at all. Nothing when the
  # file is not baked.
  defp deploy_status(false, _up, _present), do: nil
  defp deploy_status(true, true, _present), do: "up"
  defp deploy_status(true, false, true), do: "stopped"
  defp deploy_status(true, false, false), do: "down"

  # A service's doors: one per port it publishes, or, published none,
  # the port it listens on inside the pod, with no door on the host.
  #
  # The reading is this row's containers', `at.mine` (2026-09-26): the
  # row that is up, or, with nothing up, the row whose leftovers they
  # are. It was `at.up` alone, which took the reading away exactly
  # where it says most — `stopped`, `exited 1`, a deployment that came
  # down badly — and the row then said only *the deployment is down*,
  # which is a word about the deployment and not about this service.
  #
  # Not the container of that name, whichever it is: the names repeat,
  # `database`, `app` and `pod` are in all three, and with `dev` up the
  # `prod` row would read `dev`'s as its own. Nor `of_deployment/1`,
  # which tells them apart by the image and so puts the scaled
  # deployment's `balancer` and `database` — nginx, postgres — in dev.
  defp service_doors(name, ports, at) do
    container = if at.mine, do: Enum.find(at.containers, &(&1["Service"] == name))
    read = container && container_read(container)
    why = if(at.up, do: nil, else: "the deployment is down")

    door = %{
      label: name,
      svc: ConsoleWeb.Services.color(at.status, name),
      port: nil,
      why: why,
      read: read,
      read_title: container && container["Status"]
    }

    case ports do
      [_ | _] ->
        for p <- ports,
            do:
              Map.merge(door, %{
                path: "localhost:#{p}",
                kind: "port",
                href: at.up && "http://localhost:#{p}"
              })

      _ ->
        [Map.merge(door, %{path: inside_path(name, at), kind: "inside", href: nil})]
    end
  end

  defp inside_path(name, %{deploy: "scaled", inside: inside}) when is_map_key(inside, name),
    do: name <> inside[name]

  defp inside_path(name, %{inside: inside}), do: inside[name] || ""

  # Which deployment a container belongs to, as `wb.sh workspace_deployment`
  # tells them apart: a replica is the scaled one, a release image the
  # prod one, the rest dev.
  defp of_deployment(c) do
    cond do
      Regex.match?(~r/^app\d+$/, c["Service"] || "") -> "scaled"
      String.ends_with?(c["Image"] || "", "-prod") -> "prod"
      true -> "dev"
    end
  end

  # A published port belongs to the service that listens on it, not to
  # the one that declares it: in the pod the `pod` container owns
  # the network namespace and so publishes every port — `- 4001:4000`
  # under its `ports:` — while `app` is what answers on 4000. The reader
  # wants the door on `app`; the pod stays in sight on Containers and
  # on the Docker screen, which is Docker's own view. The rule holds
  # whatever the topology: with a network a container, publisher and
  # listener are one. A port no service claims stays with its publisher.
  defp claimed(published, services, inside) do
    for {publisher, pairs} <- published, {host, port} <- pairs, reduce: %{} do
      acc ->
        owner = owner(services, publisher, inside, port)
        Map.update(acc, owner, [host], &(&1 ++ [host]))
    end
  end

  defp owner(services, publisher, inside, port),
    do: Enum.find(services, publisher, &(&1 != publisher and inside[&1] == ":" <> port))

  # The ports each service publishes, off the compose file: `- 4001:4000`
  # under `ports:`, as `{host, container}` pairs — read where every
  # reading of that file lives (`WorkbenchIgniter.ComposeFile`), as the
  # strings the doors are told in.
  defp published(path) do
    case File.read(path) do
      {:ok, text} ->
        text
        |> WorkbenchIgniter.ComposeFile.published()
        |> Map.new(fn {service, pairs} ->
          {service,
           Enum.map(pairs, fn {host, inside} -> {to_string(host), to_string(inside)} end)}
        end)

      _ ->
        %{}
    end
  end

  @doc """
  Whether the bell has anything to knock on: the routes, while the app
  is up; the pages on disk always — they answer with the app down, and
  a knock reads them again.
  """
  def knockable?(up, addresses), do: up or Enum.any?(addresses, &(&1.kind == "output"))

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
