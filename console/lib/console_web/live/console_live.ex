defmodule ConsoleWeb.ConsoleLive do
  @moduledoc """
  The console: the workspace on the left, the screens on the right —
  Deploy, Logs, Project, Cartridges — and the jobs tray at the bottom.
  Everything it shows comes from `wb.sh status --json` and `catalog
  --json`; everything it does is `wb.sh` as a job.
  """
  use ConsoleWeb, :live_view

  alias Console.{Jobs, Workbench}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Jobs.subscribe()

    socket =
      socket
      |> assign(tab: "deploy", status: nil, catalog: [], box: nil, jobs: Jobs.list(), tray: false, error: nil, filter: "all", reading: true)
      |> start_async(:status, &Workbench.status/0)
      |> start_async(:catalog, &Workbench.catalog/0)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_async(:status, {:ok, {:ok, status}}, socket), do: {:noreply, assign(socket, status: status, reading: false, error: nil)}
  def handle_async(:catalog, {:ok, {:ok, catalog}}, socket), do: {:noreply, assign(socket, catalog: catalog)}
  def handle_async(_, {:ok, {:error, why}}, socket), do: {:noreply, assign(socket, error: why, reading: false)}
  def handle_async(_, {:exit, why}, socket), do: {:noreply, assign(socket, error: inspect(why), reading: false)}

  @impl true
  def handle_event("tab", %{"tab" => tab}, socket), do: {:noreply, assign(socket, tab: tab)}
  def handle_event("refresh", _, socket), do: {:noreply, read_status(socket)}
  def handle_event("filter", %{"filter" => f}, socket), do: {:noreply, assign(socket, filter: f)}
  def handle_event("tray", _, socket), do: {:noreply, assign(socket, tray: not socket.assigns.tray)}
  def handle_event("open", %{"name" => name}, socket), do: {:noreply, assign(socket, box: Enum.find(socket.assigns.catalog, &(&1["name"] == name)))}
  def handle_event("close", _, socket), do: {:noreply, assign(socket, box: nil)}

  def handle_event("run", %{"args" => args}, socket) do
    Jobs.run(String.split(args))
    {:noreply, assign(socket, tray: true)}
  end

  def handle_event("insert", params, socket) do
    box = socket.assigns.box
    Jobs.run(["add", box["name"] | insert_args(box, params)])
    {:noreply, assign(socket, tray: true, box: nil)}
  end

  def handle_event("eject", %{"name" => name}, socket) do
    Jobs.run(["eject", name])
    {:noreply, assign(socket, tray: true, box: nil)}
  end

  @impl true
  def handle_info({:job, job}, socket) do
    jobs = if Enum.any?(socket.assigns.jobs, &(&1.id == job.id)), do: Enum.map(socket.assigns.jobs, &if(&1.id == job.id, do: job, else: &1)), else: [job | socket.assigns.jobs]
    socket = assign(socket, jobs: jobs)
    # The workspace changed when a job ended: read it again.
    socket = if job.state in [:done, :failed], do: read_status(socket), else: socket
    {:noreply, socket}
  end

  # The board is read again in the background; what is on it stays
  # until the new one arrives (wb.sh status starts a container: seconds).
  defp read_status(%{assigns: %{reading: true}} = socket), do: socket
  defp read_status(socket), do: socket |> assign(reading: true) |> start_async(:status, &Workbench.status/0)

  # The installer's argv from the form: `--flag` for a checked boolean,
  # `--name value` for a filled text, `--name a,b` for chosen values.
  defp insert_args(box, params) do
    Enum.flat_map(box["options"], fn o ->
      flag = "--" <> String.replace(o["name"], "_", "-")
      value = params[o["name"]]

      cond do
        o["type"] == "boolean" -> if value == "on", do: [flag], else: []
        is_list(value) -> if value == [], do: [], else: [flag, Enum.join(value, ",")]
        is_binary(value) and String.trim(value) != "" and value != to_string(o["default"]) -> [flag, String.trim(value)]
        true -> []
      end
    end)
  end

  # --- the page -------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <header class="band">
      <h1>Dockerized Elixir Workbench <small>Console</small></h1>
      <div class="right">
        <span class="mono">{Workbench.dir()}</span>
        <button class="ver" phx-click="refresh" disabled={@reading} title="./wb.sh status --json">{if @reading, do: "reading…", else: "refresh"}</button>
      </div>
    </header>

    <div class="app">
      <aside class="console" aria-label="The console: the configured workspace">
        <%= if @status do %>
          <.board status={@status} doors={doors(@status, @catalog)} up={app_up?(@status)} />
        <% else %>
          <section class="ws"><span class="label">Workspace</span><p class="name">{if @reading, do: "reading…", else: "unread"}</p>
            <p class="note">./wb.sh status --json — a container start and a Mix boot: seconds, more on a busy host.</p></section>
        <% end %>
        <p :if={@error} class="note">{@error}</p>
      </aside>

      <main class="screen">
        <div class="tabs" role="tablist">
          <button :for={{t, label} <- [{"deploy", "Deploy"}, {"logs", "Logs"}, {"project", "Project"}, {"shelf", "Cartridges"}]}
            class="tab" role="tab" phx-click="tab" phx-value-tab={t} aria-selected={to_string(@tab == t)}>
            {label}<span :if={t == "shelf" and @status} class="badge">{length(installed(@status))}</span>
          </button>
        </div>

        <section class={"panel #{if @tab == "deploy", do: "on"}"} role="tabpanel">
          <.deploy status={@status} />
        </section>

        <section class={"panel #{if @tab == "logs", do: "on"}"} role="tabpanel">
          <p class="note">Live logs come next: <code>docker compose logs --follow</code> through the socket.</p>
        </section>

        <section class={"panel #{if @tab == "project", do: "on"}"} role="tabpanel">
          <p class="note">The project's own README, CHANGELOG and .env come next.</p>
        </section>

        <section class={"panel #{if @tab == "shelf", do: "on"}"} role="tabpanel">
          <.shelf catalog={@catalog} status={@status} filter={@filter} />
        </section>

        <.tray jobs={@jobs} open={@tray} />
      </main>
    </div>

    <div class={"scrim #{if @box, do: "on"}"} phx-click="close"></div>
    <.box :if={@box} box={@box} status={@status} catalog={@catalog} />
    """
  end

  # --- the board -------------------------------------------------------------

  defp board(assigns) do
    ~H"""
    <section class="ws">
      <span class="label">Workspace</span>
      <p class="name">{@status["compose_project"] || "no project"}</p>
      <div class="path mono">{@status["workspace"]}</div>
      <div class="urls">
        <a :if={@status["ports"]["app"]} href={"http://localhost:#{@status["ports"]["app"]}"} target="_blank"><b>app</b>localhost:{@status["ports"]["app"]}</a>
        <a :if={@status["ports"]["pgadmin"]} href={"http://localhost:#{@status["ports"]["pgadmin"]}"} target="_blank"><b>pgAdmin</b>localhost:{@status["ports"]["pgadmin"]}</a>
      </div>
    </section>
    <section>
      <h2>Doors <span class="label">{if @doors == [], do: "none yet", else: "#{length(@doors)} open by cartridges"}</span></h2>
      <div class="urls">
        <p :if={@doors == []} class="note">Cartridges open doors here: docs, dashboard, mailbox, swagger, graphiql, admin…</p>
        <a :for={{name, label, path} <- @doors} href={"http://localhost:#{@status["ports"]["app"]}#{path}"} target="_blank" class={if @up, do: "", else: "off"} title={"#{name}: #{path}#{if @up, do: "", else: " — the app is down"}"}><b>{label}</b>{path}<small>{name}</small></a>
      </div>
    </section>
    <section>
      <h2>Containers <span class="label">{containers_sum(@status["containers"])}</span></h2>
      <table class="rows">
        <tr :if={@status["containers"] == []}><td class="muted">No containers: the project is down. Deploy → Up.</td></tr>
        <tr :for={c <- @status["containers"]}>
          <td class="k">{c["Service"]}</td>
          <td><span class={"chip #{container_class(c)}"}>{if c["Health"] != "", do: c["Health"], else: c["State"]}</span></td>
          <td class="muted">{c["Image"]}</td>
        </tr>
      </table>
    </section>
    <section>
      <h2>Deployments <span class="label">baked · running</span></h2>
      <table class="rows">
        <tr :for={name <- ~w(dev prod scaled)}>
          <td class="k">{name}</td>
          <td>
            <span class={"chip #{if deployment_up?(@status, name), do: "good", else: "off"}"}>
              {cond do
                deployment_up?(@status, name) -> "running"
                @status["baked"][name] -> "baked · down"
                true -> "not baked"
              end}
            </span>
          </td>
        </tr>
      </table>
    </section>
    <section>
      <h2>Git <span class="label">{git_sum(@status["git"])}</span></h2>
      <div class="git">
        <%= if @status["git"]["repo"] do %>
          <div class="row"><span class="k">tree</span><span class={"chip #{if @status["git"]["clean"], do: "good", else: "warn"}"}>{if @status["git"]["clean"], do: "clean", else: "dirty"}</span></div>
          <div class="row"><span class="k">head</span><span>{@status["git"]["head"] || "no commits yet"}</span></div>
          <div class="row"><span class="k">signs as</span><span title={@status["git"]["identity"]}>{String.replace(@status["git"]["identity"] || "", ~r/ <.*/, "")}</span></div>
          <div class="row"><span class="k">inserts</span>
            <span :if={@status["git"]["inserts"] == []} class="note">none yet</span>
            <div :if={@status["git"]["inserts"] != []} class="ins"><span :for={i <- @status["git"]["inserts"]} class="chip" title={"#{String.slice(i["sha"], 0, 7)} · #{i["date"]}"}>{i["feature"]}</span></div>
          </div>
          <button :if={not @status["git"]["clean"]} class="btn" phx-click="run" phx-value-args="commit">Commit pending changes</button>
        <% else %>
          <p class="note">phx.new initialises the repository; new2 makes the first commit.</p>
        <% end %>
      </div>
    </section>
    <section>
      <h2>Inserted <span class="label">{length(installed(@status))} cartridges</span></h2>
      <div class="slots"><span :for={c <- installed(@status)} class="chip" phx-click="open" phx-value-name={c["name"]}>{c["name"]}</span></div>
    </section>
    """
  end

  defp deploy(assigns) do
    ~H"""
    <div class="targets">
      <div :for={{name, cmd} <- [{"dev", "up"}, {"prod", "up --deploy prod"}, {"scaled", "up --deploy scaled"}]} class="target">
        <h3>{name} <span class={"chip #{if @status && deployment_up?(@status, name), do: "good", else: "off"}"}>{if @status && deployment_up?(@status, name), do: "running", else: "down"}</span></h3>
        <div class="acts">
          <button class="btn primary" phx-click="run" phx-value-args={cmd}>Up</button>
          <button class="btn" phx-click="run" phx-value-args={"down #{if name != "dev", do: "--deploy #{name}"}"}>Down</button>
          <span class="mono">./wb.sh {cmd}</span>
        </div>
      </div>
    </div>
    <div class="dangerzone">
      <h3>Database and workspace</h3>
      <div class="acts">
        <button class="btn" phx-click="run" phx-value-args="setup">Setup the database</button>
        <span class="note">drops it, creates it, seeds it</span>
      </div>
      <div class="acts">
        <button class="btn" phx-click="run" phx-value-args="bake">Bake the compose again</button>
        <span class="note">for the project as it is now — after inserting ecto</span>
      </div>
    </div>
    """
  end

  # --- the shelf ---------------------------------------------------------------

  defp shelf(assigns) do
    entries =
      Enum.filter(assigns.catalog, fn e ->
        case assigns.filter do
          "standalone" -> e["standalone"]
          "composed" -> not e["standalone"]
          "covered" -> e["covers"]["front"] != nil
          _ -> true
        end
      end)

    assigns = assign(assigns, entries: entries)

    ~H"""
    <div class="shelf-head">
      <h2>Cartridges <span class="label">{length(@catalog)} on the shelf</span></h2>
      <div class="filters" role="group">
        <button :for={{f, label} <- [{"all", "All"}, {"standalone", "Standalone"}, {"composed", "Composed by setup"}, {"covered", "With a box"}]}
          class="btn" phx-click="filter" phx-value-filter={f} aria-pressed={to_string(@filter == f)}>{label}</button>
      </div>
    </div>
    <div class="shelf">
      <button :for={e <- @entries} class={"box #{if e["pending"], do: "pending"}"} type="button" phx-click="open" phx-value-name={e["name"]} aria-label={e["name"]}>
        <%= if e["covers"]["front"] do %>
          <img src={"/covers/#{e["covers"]["front"]}"} alt={e["name"]} draggable="false" />
        <% else %>
          <div class="face plain"><b>{e["name"]}</b><small>{(e["need"] && e["need"]["line"]) || e["summary"]}</small></div>
        <% end %>
        <span :if={@status && installed?(@status, e["name"])} class="chip good">inserted</span>
      </button>
    </div>
    """
  end

  defp box(assigns) do
    installed = assigns.status && installed?(assigns.status, assigns.box["name"])
    insert = assigns.status && Enum.find(assigns.status["git"]["inserts"] || [], &(&1["feature"] == assigns.box["name"]))
    locked = installed && assigns.box["rerun"] != "adds"
    missing = Enum.reject(assigns.box["requires"] || [], &(assigns.status && installed?(assigns.status, &1)))
    assigns = assign(assigns, installed: installed, insert: insert, locked: locked, missing: missing)

    ~H"""
    <aside class="drawer on" role="dialog" aria-modal="true">
      <div class="top">
        <h3>{@box["name"]}</h3>
        <button class="btn" phx-click="close">Put back</button>
      </div>
      <div class="body">
        <div class="hand">
          <div class="face">
            <div class="card">
              <div class="side front">
                <img :if={@box["covers"]["front"]} src={"/covers/#{@box["covers"]["front"]}"} alt={@box["name"]} draggable="false" />
                <div :if={is_nil(@box["covers"]["front"])} class="typeset"><h4>{@box["name"]}</h4><p>{(@box["need"] && @box["need"]["line"]) || @box["summary"]}</p><span class="nocover">no cover yet</span></div>
              </div>
            </div>
          </div>
        </div>
        <div class="sheet">
          <div class="head">
            <div class="kicker">
              <span class="chip">{if @box["standalone"], do: "standalone", else: "composed"}</span>
              <span :if={@box["version"]} class="chip">v{@box["version"]["version"]}</span>
              <span :if={@box["pending"]} class="chip warn">pending</span>
              <span :if={@installed} class="chip good">inserted</span>
            </div>
            <h4>{@box["name"]}</h4>
            <p>{(@box["need"] && @box["need"]["line"]) || @box["summary"]}</p>
          </div>

          <form class={"insert #{if @locked, do: "locked"}"} phx-submit="insert">
            <span class="label">Options</span>
            <div class="fields">
              <p :if={@box["options"] == []} class="note">This cartridge takes no options.</p>
              <div :for={o <- @box["options"]} class={"field #{if o["choices"], do: "stack"}"}>
                <label>--{String.replace(o["name"], "_", "-")}<span :if={o["multiple"]}> (several)</span></label>
                <div>
                  <%= cond do %>
                    <% o["choices"] -> %>
                      <div class="choices">
                        <label :for={c <- choice_values(o)}>
                          <input type={if o["multiple"], do: "checkbox", else: "radio"} name={if o["multiple"], do: o["name"] <> "[]", else: o["name"]} value={c["value"]}
                            checked={not o["multiple"] and c["value"] == o["default"]} disabled={@locked or (c["requires"] || []) |> Enum.any?(&(not (@status && installed?(@status, &1))))} />
                          <span>{c["value"]}</span><span class="doc">{c["doc"]}</span>
                        </label>
                      </div>
                    <% o["type"] == "boolean" -> %>
                      <input type="checkbox" name={o["name"]} checked={o["default"] == true} disabled={@locked} />
                    <% true -> %>
                      <input type="text" name={o["name"]} value={o["default"]} placeholder={o["type"]} disabled={@locked} />
                  <% end %>
                  <p :if={o["doc"]} class="help">{o["doc"]}</p>
                </div>
              </div>
            </div>
            <div :if={@box["requires"] != [] or @box["implies"] != [] or @box["afterwards"]} class="deps">
              <span :if={@box["requires"] != []} class="k">Builds on</span>
              <span :if={@box["requires"] != []} class="v"><span :for={r <- @box["requires"]} class={"chip #{if r in @missing, do: "warn", else: "good"}"}>{r} {if r in @missing, do: "✗", else: "✓"}</span></span>
              <span :if={@box["implies"] != []} class="k">Comes with</span>
              <span :if={@box["implies"] != []} class="v"><span :for={i <- @box["implies"]} class="chip">{i}</span></span>
              <span :if={@box["afterwards"] && not @locked} class="k">Afterwards</span>
              <span :if={@box["afterwards"] && not @locked} class="v after">{@box["afterwards"]}</span>
            </div>
            <div class="acts">
              <button class={"go #{if @locked, do: "done"}"} type="submit" disabled={@box["pending"] or @locked or @missing != [] or (@status && not @status["git"]["clean"])}>
                {cond do
                  @box["pending"] -> "Not ported yet"
                  @locked -> "Already inserted"
                  @missing != [] -> "Insert #{hd(@missing)} first"
                  @installed -> "Add to cartridge"
                  true -> "Insert cartridge"
                end}
              </button>
              <button :if={@installed} class="eject" type="button" phx-click="eject" phx-value-name={@box["name"]} disabled={is_nil(@insert)}
                title={if @insert, do: "git revert #{String.slice(@insert["sha"], 0, 7)} — #{@insert["subject"]}", else: "no commit to revert"}>Eject</button>
              <span class="note">{cond do
                @status && not @status["git"]["clean"] -> "the tree has changes git does not have — commit first"
                @installed && is_nil(@insert) -> "came with the project or by hand: no commit to eject"
                @locked -> "inserted once; eject to change its options"
                true -> ""
              end}</span>
            </div>
          </form>
        </div>
      </div>
    </aside>
    """
  end

  defp tray(assigns) do
    running = Enum.count(assigns.jobs, &(&1.state == :running))
    assigns = assign(assigns, running: running, last: List.first(assigns.jobs))

    ~H"""
    <div class={"tray #{if @open, do: "open"}"}>
      <div class="bar" phx-click="tray">
        <h4>Jobs</h4>
        <span class={"chip #{if @running > 0, do: "warn busy", else: "off"}"}>{if @running > 0, do: "running", else: "idle"}</span>
        <span class="last">{if @last, do: @last.cmdline, else: "Every command the console runs is a job: its output, its exit code, how long it took."}</span>
        <span class="caret">{if @open, do: "▾", else: "▴"}</span>
      </div>
      <div class="list">
        <div :for={j <- @jobs} class={"job #{j.state}"}>
          <div class="head">
            <span class="mono">{j.cmdline}</span>
            <span class={"chip #{job_class(j)}"}>{j.state}{if j.exit, do: " · exit #{j.exit}"}</span>
            <span :if={j.started_at && j.finished_at} class="muted">{DateTime.diff(j.finished_at, j.started_at, :millisecond) / 1000}s</span>
          </div>
          <pre class="out">{j.lines |> Enum.reverse() |> Enum.join("\n")}</pre>
        </div>
      </div>
    </div>
    """
  end

  # --- helpers -----------------------------------------------------------------

  defp installed(status), do: Enum.filter(get_in(status, ["project", "cartridges"]) || [], & &1["installed"])
  defp app_up?(status), do: Enum.any?(status["containers"] || [], &(&1["State"] == "running" and &1["Service"] =~ ~r/^app\d*$/))

  # The doors the inserted cartridges open, as the catalog says
  # (`console.doors`), when their condition holds; `{option}` in a path
  # is the option's value as the project reports it, or its default.
  defp doors(status, catalog) do
    ins = installed(status)

    for entry <- catalog,
        c = Enum.find(ins, &(&1["name"] == entry["name"])),
        door <- entry["console"]["doors"] || [],
        holds?(door["when"], c, ins) do
      {entry["name"], door["label"], fill_path(door["path"], c, entry)}
    end
  end

  defp holds?(nil, _c, _ins), do: true
  defp holds?(%{"with" => value}, c, _ins), do: value in (get_in(c, ["state", "with"]) || [])
  defp holds?(%{"cartridge" => name}, _c, ins), do: Enum.any?(ins, &(&1["name"] == name))

  defp fill_path(path, c, entry) do
    Regex.replace(~r/\{(\w+)\}/, path, fn _, o ->
      to_string(get_in(c, ["state", o]) || (Enum.find(entry["options"] || [], &(&1["name"] == o)) || %{})["default"] || "")
    end)
  end
  defp installed?(status, name), do: Enum.any?(installed(status), &(&1["name"] == name))

  defp choice_values(%{"choices" => [%{"group" => _} | _] = groups}), do: Enum.flat_map(groups, & &1["values"])
  defp choice_values(%{"choices" => values}), do: values

  defp containers_sum([]), do: "none"
  defp containers_sum(cs), do: "#{Enum.count(cs, &(&1["State"] == "running"))} of #{length(cs)} running"

  defp container_class(c) do
    cond do
      c["Health"] == "healthy" or (c["Health"] == "" and c["State"] == "running") -> "good"
      c["State"] == "running" or c["Health"] == "starting" -> "warn busy"
      true -> "bad"
    end
  end

  # dev and prod share their service names: the image tells them apart.
  defp deployment_up?(status, name) do
    Enum.any?(status["containers"] || [], fn c ->
      c["State"] == "running" and c["Service"] == "app" and
        case name do
          "dev" -> String.ends_with?(c["Image"], ":local")
          "prod" -> String.contains?(c["Image"], "-prod")
          "scaled" -> c["Labels"] =~ ~r/replica|scaled/
        end
    end)
  end

  defp git_sum(%{"repo" => false}), do: "no repository"
  defp git_sum(g), do: if(g["clean"], do: "clean", else: "changes git does not have")

  defp job_class(%{state: :done}), do: "good"
  defp job_class(%{state: :failed}), do: "bad"
  defp job_class(%{state: :running}), do: "warn busy"
  defp job_class(_), do: "off"
end
