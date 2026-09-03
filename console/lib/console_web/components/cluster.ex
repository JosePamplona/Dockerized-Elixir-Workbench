defmodule ConsoleWeb.Cluster do
  @moduledoc """
  Lit by the clustering cartridge: the replicas of the scaled deployment
  as nodes — who answers behind the balancer, who is connected to whom
  — off the status's containers and addresses, and two probes the
  console runs itself.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  attr :status, :map, default: nil
  attr :probes, :map, required: true, doc: "answers and peers: nil, :asking, or lines"
  attr :pick, :map, required: true

  def cluster(assigns) do
    cs = (assigns.status && assigns.status["containers"]) || []
    reps = cs |> Enum.filter(&(Regex.match?(~r/^app\d+$/, &1["Service"]) and &1["State"] == "running")) |> Enum.sort_by(& &1["Service"])
    balancer = Enum.any?(cs, &(&1["Service"] == "balancer" and &1["State"] == "running"))
    app = get_in(assigns.status, ["project", "app"]) || "app"
    assigns = assign(assigns, reps: reps, balancer: balancer, app: app, port: assigns.status && assigns.status["ports"]["app"], addresses: (assigns.status && assigns.status["addresses"]) || %{})

    ~H"""
    <div class="cluster">
      <%= if @reps == [] do %>
        <p class="note">The cluster is the scaled deployment: N replicas of the release behind the balancer, booting as named nodes that find each other through Docker's DNS. Nothing is up.</p>
        <div class="acts"><button class="btn primary" phx-click="run" phx-value-args={"up --deploy scaled" <> ConsoleWeb.Deploy.scaled_extra(@pick)}>Up scaled</button><span class="note">./wb.sh up --deploy scaled{ConsoleWeb.Deploy.scaled_extra(@pick)}</span></div>
      <% else %>
        <div class="now">
          <.chip class="good">{length(@reps)} replicas</.chip>
          <.chip class={if @balancer, do: "good", else: "off"}>{if @balancer, do: "balancer on :#{@port}", else: "no balancer"}</.chip>
          <span class="note">addresses off the containers; peers as the nodes report them, asked below</span>
        </div>
        <table>
          <tr><th>replica</th><th>address</th><th>host port</th><th>node</th><th></th></tr>
          <tr :for={r <- @reps}>
            <% ip = @addresses[r["Service"]] || "" %>
            <% hp = Enum.find_value(r["Publishers"] || [], &(&1["PublishedPort"] != 0 && &1["PublishedPort"])) %>
            <td>{r["Service"]}</td>
            <td>{ip}</td>
            <td><a :if={hp} href={"http://localhost:#{hp}"} target="_blank" rel="noopener">:{hp}</a></td>
            <td>{@app}@{ip}</td>
            <td><button class="btn" type="button" phx-click="term_open" phx-value-target={r["Service"]} phx-value-shell="rpc" title={"bin/#{@app} rpc on this replica, one expression per line"}>rpc console</button></td>
          </tr>
        </table>
        <.probe key="answers" title="Who answers?" note="Four requests to the balancer's port: the X-Served-By header names the replica each one landed on." empty="The four answers will land here." label="Ask four times" off={!@balancer} cmd={"for i in 1 2 3 4; do curl -sI http://localhost:#{@port} | grep -i x-served-by; done"} result={@probes[:answers]} />
        <.probe key="peers" title="Who is connected?" note="Node.list() on the first replica, through the release's rpc — the nodes DNSCluster found." empty="The list of peers will land here." label="Node.list()" off={false} cmd={"docker compose exec #{hd(@reps)["Service"]} bin/#{@app} rpc \"IO.inspect(Node.list())\""} result={@probes[:peers]} />
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
  attr :cmd, :string, required: true
  attr :result, :any, default: nil

  defp probe(assigns) do
    ~H"""
    <div class="probe">
      <h3>{@title}</h3>
      <p class="note">{@note}</p>
      <div class="acts"><button class="btn" type="button" disabled={@off or @result == :asking} phx-click="probe" phx-value-key={@key}>{if @result == :asking, do: "Asking…", else: @label}</button><span class="note">{@cmd}</span></div>
      <div class="log-cap"><span class="label">Output</span><span class="note">run by the console itself, on the socket it holds</span></div>
      <div class="log" data-empty={@empty}><%= if is_list(@result) do %><div :for={l <- @result}>{l}</div><% end %></div>
    </div>
    """
  end
end
