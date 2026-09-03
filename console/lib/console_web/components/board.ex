defmodule ConsoleWeb.Board do
  @moduledoc "The rail: the configured workspace, as the status says it."
  use Phoenix.Component
  import ConsoleWeb.Refs
  alias ConsoleWeb.Cartridges

  attr :status, :map, default: nil
  attr :catalog, :list, default: []
  attr :reading, :boolean, default: false
  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"
  attr :error, :string, default: nil

  def board(assigns) do
    ~H"""
    <section :if={is_nil(@status)} class="ws">
      <span class="label">Workspace</span>
      <p class="name">{if @reading, do: "reading…", else: "unread"}</p>
      <p :if={@error} class="note">{@error}</p>
      <p :if={!@error} class="note">./wb.sh status --json — a container start and a Mix boot: seconds, more on a busy host.</p>
    </section>
    <%= if @status do %>
      <.workspace status={@status} />
      <.doors status={@status} catalog={@catalog} />
      <.deployments status={@status} busy={@busy} />
      <.containers status={@status} />
      <.git status={@status} />
      <.inserted status={@status} catalog={@catalog} />
      <p :if={@error} class="note">{@error}</p>
    <% end %>
    """
  end

  defp workspace(assigns) do
    ~H"""
    <section class="ws">
      <span class="label">Workspace</span>
      <p class="name">{@status["compose_project"] || "no project"}</p>
      <div class="path mono">{@status["workspace"]}</div>
      <div class="urls">
        <.door_ref :if={@status["ports"]["app"]} label="app" path={"localhost:#{@status["ports"]["app"]}"} href={"http://localhost:#{@status["ports"]["app"]}"} />
        <.door_ref :if={@status["ports"]["pgadmin"]} label="pgAdmin" path={"localhost:#{@status["ports"]["pgadmin"]}"} href={"http://localhost:#{@status["ports"]["pgadmin"]}"} />
      </div>
    </section>
    """
  end

  defp doors(assigns) do
    doors = Cartridges.contributions(assigns.status, assigns.catalog, "doors")
    assigns = assign(assigns, doors: doors, up: Cartridges.app_up?(assigns.status))

    ~H"""
    <section>
      <h2>Doors <span class="label">{if @doors == [], do: "none yet", else: "#{length(@doors)} open by cartridges"}</span></h2>
      <div class="urls">
        <p :if={@doors == []} class="note">Cartridges open doors here: docs, dashboard, mailbox, swagger, graphiql, admin…</p>
        <.door_ref
          :for={{c, d} <- @doors}
          label={d["label"]}
          path={Cartridges.fill_path(d["path"], c)}
          href={"http://localhost:#{@status["ports"]["app"]}#{Cartridges.fill_path(d["path"], c)}"}
          who={c["name"]}
          why={!@up && "the app is down"}
        />
      </div>
    </section>
    """
  end

  defp deployments(assigns) do
    ~H"""
    <section>
      <h2>Deployments <span class="label">baked · running</span></h2>
      <table class="rows">
        <tr :for={name <- ~w(dev prod scaled)}>
          <td class="k">{name}</td>
          <td class="st"><.chip class={!@status["baked"][name] && "off"}>{if @status["baked"][name], do: "baked", else: "not baked"}</.chip></td>
          <td><.chip class={if @status["deployment"] == name, do: "good", else: "off"}>{if @status["deployment"] == name, do: "running", else: "down"}</.chip></td>
          <td class="act">
            <.deploy_button :if={@status["deployment"] == name} verb="down" name={name} status={@status} busy={@busy} />
            <.deploy_button :if={@status["deployment"] != name and @status["baked"][name]} verb="up" name={name} status={@status} busy={@busy} />
          </td>
        </tr>
      </table>
    </section>
    """
  end

  # The row's one action, in the row's own words. Only two things stop
  # it — nothing to deploy into, a job in flight. Another deployment up
  # is the ordinary case: Up replaces it, and the title says so.
  defp deploy_button(assigns) do
    running = assigns.status["deployment"]
    cmd = ConsoleWeb.Deploy.cmdline(assigns.verb, assigns.name, "")

    why =
      cond do
        assigns.status["exists"] != true -> "the workspace is empty: Deploy → New project starts one"
        assigns.busy -> "a job is running"
        true -> nil
      end

    replaces = assigns.verb == "up" && running && running != assigns.name
    title = why || cmd <> if(replaces, do: " — #{running} is running and goes down: one deployment at a time", else: "")
    assigns = assign(assigns, why: why, title: title, cmd: cmd)

    ~H"""
    <button class={["btn mini", @why && "unlit"]} aria-disabled={@why && "true"} title={@title} phx-click={!@why && "run"} phx-value-args={String.replace_prefix(@cmd, "./wb.sh ", "")}>
      {if @verb == "up", do: "Up", else: "Down"}
    </button>
    """
  end

  defp containers(assigns) do
    cs = assigns.status["containers"] || []
    running = Enum.count(cs, &(&1["State"] == "running"))
    assigns = assign(assigns, cs: cs, sum: if(cs == [], do: "none", else: "#{running} of #{length(cs)} running"))

    ~H"""
    <section>
      <h2>Containers <span class="label">{@sum}</span></h2>
      <table class="rows">
        <tr :if={@cs == []}><td class="muted">{if @status["exists"], do: "No containers: the project is down. Deploy → Up.", else: "The workspace is empty: Deploy → New project."}</td></tr>
        <tr :for={c <- @cs}>
          <td class="k">{c["Service"]}</td>
          <td class="st"><.chip class={container_class(c)}>{if c["Health"] not in [nil, ""], do: c["Health"], else: c["State"]}</.chip></td>
          <td class="muted">{c["Image"]}</td>
        </tr>
      </table>
    </section>
    """
  end

  defp container_class(c) do
    cond do
      c["Health"] == "healthy" or (c["Health"] in [nil, ""] and c["State"] == "running") -> "good"
      c["State"] == "running" or c["Health"] == "starting" -> "warn busy"
      true -> "bad"
    end
  end

  defp git(assigns) do
    ~H"""
    <section>
      <h2>Git <span class="label">{git_sum(@status["git"])}</span></h2>
      <div class="git">
        <%= if @status["git"]["repo"] do %>
          <div class="row"><span class="k">tree</span><.chip class={if @status["git"]["clean"], do: "good", else: "warn"}>{if @status["git"]["clean"], do: "clean", else: "dirty"}</.chip></div>
          <div class="row"><span class="k">head</span><span>{@status["git"]["head"] || "no commits yet"}</span></div>
          <div class="row"><span class="k">signs as</span><span title={@status["git"]["identity"]}>{String.replace(@status["git"]["identity"] || "", ~r/ <.*/, "")}</span></div>
          <button :if={not @status["git"]["clean"]} class="btn" phx-click="run" phx-value-args="commit">Commit pending changes</button>
        <% else %>
          <p class="note">phx.new initialises the repository; new makes the first commit.</p>
        <% end %>
      </div>
    </section>
    """
  end

  defp git_sum(%{"repo" => false}), do: "no repository"
  defp git_sum(g), do: if(g["clean"], do: "clean", else: "changes git does not have")

  defp inserted(assigns) do
    ins = Cartridges.installed(assigns.status)
    revertible = Enum.count(ins, &Cartridges.insert(assigns.status, &1["name"]))

    sum =
      if ins == [],
        do: "none",
        else: "#{length(ins)} cartridge#{if length(ins) == 1, do: "", else: "s"} · #{revertible} the workbench can eject"

    assigns = assign(assigns, ins: ins, sum: sum)

    ~H"""
    <section>
      <h2>Inserted <span class="label">{@sum}</span></h2>
      <table class="rows">
        <tr :if={@ins == []}><td class="muted">Nothing inserted yet: the shelf is in Cartridges.</td></tr>
        <tr :for={c <- @ins}>
          <td><.cart_ref name={c["name"]} installed={true} version={c["version"] && c["version"]["version"]} /></td>
          <td class="muted ver" title={if c["version"], do: "#{c["version"]["date"]} in its CHANGELOG", else: "no CHANGELOG to read a version from"}>{if c["version"], do: "v#{c["version"]["version"]}", else: "unversioned"}</td>
          <td class="og"><.origin status={@status} c={c} /></td>
        </tr>
      </table>
    </section>
    """
  end

  defp origin(assigns) do
    {word, cls, why} = Cartridges.origin(assigns.status, assigns.c)
    assigns = assign(assigns, word: word, cls: cls, why: why)

    ~H"""
    <.chip class={@cls} title={@why}>{@word}</.chip>
    """
  end
end
