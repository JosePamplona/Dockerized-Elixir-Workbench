defmodule ConsoleWeb.Cluster do
  @moduledoc """
  The cluster as the box the scaled row opens: the replicas of the
  scaled deployment as nodes — who answers behind the balancer, who is
  connected to whom — off the status's containers and addresses, and
  two probes the console runs itself.

  It was a screen of its own on the rail until 2026-09-25, the only tab
  a cartridge lit (`console: [tabs: [:cluster]]`, clustering's), and so
  the only one that was dark unless a box was in. Half of what it said
  the deployments sheet already says of its `scaled` row — the
  services, their ports, up or down — and its one button was that
  row's *Up scaled* a second time. What is only here are the two
  probes: that the replicas answer one by one behind the balancer, and
  that they found each other as nodes. So it reads where the reader
  just pressed Up, under the row, in the box the eye's neighbour opens
  (`ConsoleWeb.Deployments`), and the `tabs:` contract went with it.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  attr :status, :map, default: nil
  attr :probes, :map, required: true, doc: "answers and peers: nil, :asking, or lines"

  attr :clustering, :any,
    default: false,
    doc: "the clustering cartridge is in: without it the replicas are isolated"

  def cluster_sheet(assigns) do
    cs = (assigns.status && assigns.status["containers"]) || []

    reps =
      cs
      |> Enum.filter(&(Regex.match?(~r/^app\d+$/, &1["Service"]) and &1["State"] == "running"))
      |> Enum.sort_by(& &1["Service"])

    balancer = Enum.any?(cs, &(&1["Service"] == "balancer" and &1["State"] == "running"))
    app = get_in(assigns.status, ["project", "app"]) || "app"

    assigns =
      assign(assigns,
        reps: reps,
        balancer: balancer,
        app: app,
        port: assigns.status && assigns.status["ports"]["app"],
        addresses: (assigns.status && assigns.status["addresses"]) || %{}
      )

    ~H"""
    <div class="cluster">
      <%= if @reps == [] do %>
        <p class="note">
          The cluster is this deployment up: N replicas of the release behind the balancer, booting as named nodes that find each other through Docker's DNS. Nothing is up — Up scaled, under the table, brings it.
        </p>
      <% else %>
        <div class="now">
          <.chip class="good">{length(@reps)} replicas</.chip>
          <.chip class={if @balancer, do: "good", else: "off"}>
            {if @balancer, do: "balancer on :#{@port}", else: "no balancer"}
          </.chip>
          <span class="note">addresses off the containers; peers as the nodes report them, asked below</span>
        </div>
        <table>
          <tr>
            <th>replica</th><th>address</th><th>host port</th><th>node</th><th></th>
          </tr>
          <tr :for={r <- @reps}>
            <% ip = @addresses[r["Service"]] || "" %>
            <% hp =
              Enum.find_value(
                r["Publishers"] || [],
                &(&1["PublishedPort"] != 0 && &1["PublishedPort"])
              ) %>
            <td>{r["Service"]}</td>
            <td>{ip}</td>
            <td>
              <a :if={hp} href={"http://localhost:#{hp}"} target="_blank" rel="noopener">:{hp}</a>
            </td>
            <td>{@app}@{ip}</td>
            <td>
              <button
                class="btn"
                type="button"
                phx-click="term_open"
                phx-value-target={r["Service"]}
                phx-value-shell="rpc"
                title={"bin/#{@app} rpc on this replica, one expression per line"}
              >rpc console</button>
            </td>
          </tr>
        </table>
        <.probe
          key="answers"
          title="Who answers?"
          note="Four requests to the balancer's port: the X-Served-By header names the replica each one landed on."
          empty="The four answers will land here."
          label="Ask four times"
          off={!@balancer}
          why={!@balancer && "no balancer is up: nothing spreads the requests"}
          cmd={"for i in 1 2 3 4; do curl -sI http://localhost:#{@port} | grep -i x-served-by; done"}
          result={@probes[:answers]}
        />
        <.probe
          key="peers"
          title="Who is connected?"
          note={
            if @clustering,
              do:
                "Node.list() on the first replica, through the release's rpc — the nodes DNSCluster found.",
              else:
                "Node.list() on the first replica, through the release's rpc. Without the clustering cartridge the replicas boot unnamed and isolated: the list comes back empty."
          }
          empty="The list of peers will land here."
          label="Node.list()"
          off={false}
          cmd={"docker compose exec #{hd(@reps)["Service"]} bin/#{@app} rpc \"IO.inspect(Node.list())\""}
          result={@probes[:peers]}
        />
      <% end %>
    </div>
    """
  end

  attr :key, :string, required: true
  attr :title, :string, required: true
  attr :note, :string, required: true
  attr :empty, :string, required: true
  attr :label, :string, required: true
  attr :off, :boolean, default: false
  attr :why, :any, default: nil, doc: "unlit, with the reason"
  attr :cmd, :string, required: true
  attr :result, :any, default: nil

  defp probe(assigns) do
    ~H"""
    <div class="probe">
      <h3>{@title}</h3>
      <p class="note">{@note}</p>
      <div class="acts">
        <button
          class="btn"
          type="button"
          disabled={@off or @result == :asking}
          title={@off && @why}
          phx-click="probe"
          phx-value-key={@key}
        >{if @result == :asking, do: "Asking…", else: @label}</button><span class="note">{@cmd}</span>
      </div>
      <div class="log-cap">
        <span class="label">Output</span><span class="note">run by the console itself, on the socket it holds</span>
      </div>
      <div class="log" data-empty={@empty}>
        <%= if is_list(@result) do %>
          <div :for={l <- @result}>{l}</div>
        <% end %>
      </div>
    </div>
    """
  end
end
