defmodule ConsoleWeb.Deployments do
  @moduledoc """
  The deployments as a sheet: the table — one row per deployment, the
  radio that picks it and what it is, its compose file baked or not, in
  sync or with its drift, up, stopped or down, its services as ports,
  and Bake, Build, Stop and Down — under a row the file itself, when its eye
  is pressed, in a code box that wears its name, and under the table Up
  of the row picked, with the wb.sh line it is. It was two
  cards until 2026-09-09, a picker of three boxes over a table of the
  same three rows, and Up twice on one screen. The plan is `ConsoleWeb.Record.deployments/1`; the Deploy
  tab places this under its two cards (it was the Record paper's third
  section until 2026-09-09: the Record says what the project is, this
  says what is baked and running), and the rail draws its own short
  row off the same plan in `ConsoleWeb.Board`.

  The row's four buttons keep their slots — Bake, Build, Stop, Down,
  in the order the columns before them are read: Bake answers the
  file, Build the image the file names, Stop and Down answer the
  status, the one that keeps the containers before the one that
  removes them (2026-09-17; Down stood first until then). A verb the
  row cannot do now is unlit with the reason, not
  hidden (2026-09-10, when the order turned and Stop and Down stopped
  coming and going). Build was the foot's until 2026-09-10 and the
  CLI's the day after; since 2026-09-11 it is the row's, the image
  built with nothing going down (`ConsoleWeb.Board.build_button/1`).

  The head carries no word of its own: it said *Topology* until
  2026-09-10, which named the section and not what it holds — and the
  rows under it say what there is, line by line.

  The eye is on every row: unlit with the remedy while the file is not
  baked, pressed on the one whose box is open under its row — one at a
  time, none until pressed, and pressed again it closes. It patches the
  URL (`/deploy?compose=prod`), so the box holds no state of its own
  and a status arriving reads the files again under the same choice.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Square, only: [square: 1]
  import ConsoleWeb.Board, only: [bake_button: 1, build_button: 1, deploy_button: 1]
  import ConsoleWeb.Cluster, only: [cluster_sheet: 1]

  # What comes off the project — in sync or not, the drift — is the last
  # full reading's until the next lands, and a fast status meanwhile
  # carries it as it was. While a full one is in flight it is dimmed,
  # with this on it: unlit, not asserted (a row said "baked" for the
  # seconds between an insert and the reading that knew of it).
  @stale_why "reading the project again: this is the last reading's, until the new one lands"

  # What each deployment is, under its name on the row.
  @targets %{
    "dev" =>
      "The dev toolchain image with the source mounted. Recompiles on boot; iex attaches to its node.",
    "prod" =>
      "The release image, built from the project's Dockerfile on each up. No source, no Mix. A one-shot migrate runs first, and the app waits for it.",
    "scaled" =>
      "N production replicas behind an nginx balancer, on a bridge network. A BEAM cluster if clustering is inserted."
  }

  attr :rows, :list, required: true, doc: "ConsoleWeb.Record.deployments/1"
  attr :status, :map, default: nil
  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"

  attr :composes, :list,
    default: [],
    doc: "the three compose files as Console.Docker.composes/1 reads them"

  attr :deploy, :any, default: nil, doc: "the file the box shows; nil when none is baked"

  attr :stale, :boolean,
    default: false,
    doc: "a full status is in flight: what comes off the project is the last reading's"

  attr :pick, :map, required: true, doc: "target, replicas, balancer — the reader's choice"
  attr :pickname, :string, required: true, doc: "the deployment picked: the row with the radio on"
  attr :running, :any, default: nil, doc: "the deployment that is up, if one"
  attr :extra, :string, default: "", doc: "--replicas N --no-balancer, when they differ"

  attr :scaled_extra, :string,
    default: "",
    doc: "the same for the scaled row's Bake, whichever row is picked"

  attr :clustering, :any, default: false, doc: "the clustering cartridge is in"

  attr :cluster, :boolean,
    default: false,
    doc: "the cluster box is open under the scaled row, one box at a time with the files'"

  attr :probes, :map, default: %{}, doc: "the cluster's two probes: nil, :asking, or lines"

  def deployments_sheet(assigns) do
    # Without a project the three rows are there, not baked, every
    # button unlit with the same reason: the table is the tab's, not
    # the project's.
    empty = is_nil(assigns.status) or assigns.status["exists"] != true

    assigns =
      assign(assigns,
        why: @stale_why,
        targets: @targets,
        empty: empty,
        not_baked:
          if(empty,
            do: "the workspace is empty: Deploy → Project creates one",
            else: "Bake, or Up, writes it"
          )
      )

    ~H"""
    <section class="deployments">
      <h3 title="the compose files baked into the workspace, one per deployment: the topology each brings up — pick one on its row, and Up it under the table">
        Deployments
      </h3>
      <form id="deploy-pick" phx-change="pick" phx-submit="deploy_run">
        <table class="rows deps">
          <thead>
            <tr>
              <th title="the deployment: pick it here, and Up it under the table">target</th>
              <th title="the deployment's compose file, baked into the workspace, out of sync with the project, or not baked yet">
                compose file
              </th>
              <th title="what the file declares that no cartridge asks for any more (+), and what a cartridge asks for that the file lacks (−); nothing when the file says what the cartridges ask">
                sync diff
              </th>
              <th>status</th>
              <th title="the services the compose file declares; with the deployment up, what docker compose ps says of each">
                services
              </th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for d <- @rows do %>
              <tr class={d.deploy == @pickname && "on"}>
                <td class="k">
                  <label class="pickt">
                    <input
                      type="radio"
                      name="target"
                      value={d.deploy}
                      checked={d.deploy == @pickname}
                    />
                    <b>{d.deploy}</b>
                  </label>
                  <p class="what">{@targets[d.deploy]}</p>
                  <.chip :if={d.deploy == "scaled" and !@clustering} class="warn">
                    no clustering: replicas run isolated
                  </.chip>
                  <div :if={d.deploy == "scaled"} class="opts">
                    --replicas <input type="number" name="replicas" min="1" value={@pick.replicas} />
                    <label><input type="checkbox" name="balancer" checked={@pick.balancer} /> balancer</label>
                  </div>
                  <div :if={d.deploy == "scaled"} class="opts">
                    <.nodes open={@cluster} up={d.status == "up"} />
                  </div>
                </td>
                <td class="file">
                  <span class="fl">
                    <.eye
                      deploy={d.deploy}
                      file={d.file}
                      baked={d.baked}
                      open={@deploy == d.deploy}
                      why={
                        !d.baked &&
                          if(@empty,
                            do: @not_baked,
                            else: "not baked: no #{d.file} in this workspace — #{@not_baked}"
                          )
                      }
                    />
                    <span class={@stale && "stale"} title={@stale && @why}>
                      <.chip :if={!d.baked} class="off" title={@not_baked}>
                        not baked
                      </.chip>
                      <.chip
                        :if={d.baked && d.in_sync == false}
                        class="warn"
                        title="the file no longer says what the cartridges ask for: bake writes it again"
                      >
                        out of sync
                      </.chip>
                      <.chip :if={d.baked && d.in_sync != false} class="good">baked</.chip>
                    </span>
                  </span>
                </td>
                <td class={["sync", @stale && "stale"]} title={@stale && @why}>
                  <span :if={d.stray != [] or d.missing != []} class="drift" title={sync_title(d)}>
                    <.chip
                      :for={s <- d.stray}
                      class="warn"
                      title="declared in the file, but no cartridge asks for it any more"
                    >
                      +{s}
                    </.chip>
                    <.chip
                      :for={m <- d.missing}
                      class="warn"
                      title="asked for by a cartridge, not in the file"
                    >
                      −{m}
                    </.chip>
                  </span>
                </td>
                <td class="st">
                  <.chip :if={d.status == "up"} class="good">up</.chip>
                  <.chip
                    :if={d.status == "stopped"}
                    class="off"
                    title="its containers are there, stopped: Up brings them back fast"
                  >
                    stopped
                  </.chip>
                  <.chip :if={d.status == "down"} class="off" title="no containers: Up creates them">
                    down
                  </.chip>
                </td>
                <td>
                  <span class="pairs">
                    <.door_ref
                      :for={a <- d.services}
                      label={a.label}
                      path={a.path}
                      href={a.href}
                      why={a.why}
                      kind={a.kind}
                      port={a.kind == "route" && a.port}
                      read={a.read}
                    />
                  </span>
                </td>
                <td class="act">
                  <.bake_button
                    name={d.deploy}
                    status={@status}
                    busy={@busy}
                    baked={d.baked}
                    extra={(d.deploy == "scaled" && @scaled_extra) || ""}
                    form="deploy-pick"
                  />
                  <.build_button
                    name={d.deploy}
                    status={@status}
                    busy={@busy}
                    extra={(d.deploy == "scaled" && @scaled_extra) || ""}
                    form="deploy-pick"
                  />
                  <.deploy_button
                    verb="stop"
                    name={d.deploy}
                    status={@status}
                    busy={@busy}
                    baked={d.baked}
                  />
                  <.deploy_button
                    verb="down"
                    name={d.deploy}
                    status={@status}
                    busy={@busy}
                    baked={d.baked}
                    present={d.present}
                  />
                </td>
              </tr>
              <tr :if={@deploy == d.deploy} class="fbox">
                <td colspan="6"><.file_sheet composes={@composes} deploy={d.deploy} /></td>
              </tr>
              <tr :if={@cluster and d.deploy == "scaled"} class="fbox">
                <td colspan="6">
                  <.cluster_sheet status={@status} probes={@probes} clustering={@clustering} />
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </form>
      <div class="foot">
        <div class="cmds">
          <div class="cmd">./wb.sh up --deploy {@pickname}{@extra}</div>
        </div>
        <%!-- The verb of the row picked: what it runs is composed out of
              the picker above — the radio, --replicas, balancer — so it
              sends that form and the server writes the line from what is
              in it. What it carries is only what it says.

              Build stood beside it until 2026-09-10, when it went to the
              CLI, and since 2026-09-11 it is each row's, beside Bake:
              the image built with nothing going down. The flags
              `docker compose build` takes — `--no-cache` and the rest —
              stay the CLI's, where Tab completes them from the catalog. --%>
        <.job_button
          label={
            if @running && @running != @pickname,
              do: "Replace #{@running} with #{@pickname}",
              else: "Up #{@pickname}"
          }
          class="primary"
          form="deploy-pick"
          name="do"
          value="up"
          args={"up --deploy #{@pickname}#{@extra}"}
          why={
            cond do
              @busy -> "a job is running"
              @empty -> "the workspace is empty: create a project first"
              @running == @pickname -> "#{@running} is up: its row stops it, or takes it down"
              true -> nil
            end
          }
          title={
            if @running,
              do:
                "./wb.sh up --deploy #{@pickname}#{@extra} — one deployment at a time: #{@running} goes down",
              else: nil
          }
        />
      </div>
    </section>
    """
  end

  attr :deploy, :string, required: true
  attr :file, :string, required: true
  attr :baked, :boolean, required: true
  attr :open, :boolean, required: true
  attr :why, :any, default: nil, doc: "unlit, with the reason, while the file is not baked"

  # The eye: read this file in a box under its row; pressed again, it
  # closes. The square icon button the knock bell wears, with an eye.
  defp eye(assigns) do
    ~H"""
    <.square
      :if={@baked}
      mark="eye"
      label={"Read #{@file}"}
      class="eye"
      patch={if @open, do: "/deploy", else: "/deploy?compose=#{@deploy}"}
      aria-pressed={to_string(@open)}
      title={if @open, do: "close #{@file}", else: "read #{@file} under its row"}
    />
    <.square
      :if={!@baked}
      mark="eye"
      label={"Read #{@file}"}
      class="eye unlit"
      aria-disabled="true"
      title={@why}
    />
    """
  end

  attr :open, :boolean, required: true
  attr :up, :boolean, required: true

  # The scaled row's second reading, the eye's idiom on the row's own
  # cell: the replicas as nodes, and the two probes that they answer one
  # by one and found each other — the Cluster tab until 2026-09-25
  # (`ConsoleWeb.Cluster`). One box at a time under the table, so it
  # patches the bare tab and a file's eye closes it. Unlit, with the
  # reason, while scaled is not up: there are no nodes to read.
  defp nodes(assigns) do
    ~H"""
    <.square
      :if={@up}
      mark="chevron"
      label="Read the cluster: the replicas as nodes"
      class="eye"
      patch={if @open, do: "/deploy", else: "/deploy?cluster=1"}
      aria-pressed={to_string(@open)}
      title={if @open, do: "close the cluster", else: "read the replicas as nodes under this row"}
    />
    <.square
      :if={!@up}
      mark="chevron"
      label="Read the cluster: the replicas as nodes"
      class="eye unlit"
      aria-disabled="true"
      title="scaled is not up: Up it, under the table, and its replicas read here"
    />
    <span class="note">the replicas as nodes</span>
    """
  end

  # The file under its row, in a code box with a strip that names it:
  # the file whose eye is pressed, one at a time and none until pressed,
  # read only — wb.sh alone writes the workspace — and the secrets
  # masked. The box is as tall as the reader left it: the jobs' grip
  # under it, the JobOut hook, kept in this browser. It read under
  # Docker's Deploys until 2026-09-09; the files are the workspace's,
  # so they read here.
  attr :composes, :list, required: true
  attr :deploy, :any, required: true

  defp file_sheet(assigns) do
    chosen = Enum.find(assigns.composes, &(&1.key == assigns.deploy))
    assigns = assign(assigns, chosen: chosen)

    ~H"""
    <div class="fsheet" id="compose-sheet" phx-hook="JobOut" data-tall="compose">
      <div class="strip">
        <span class="label">filename</span>
        <span :if={@chosen} class="fname" title={"the #{@chosen.key} deployment's compose file"}>
          {@chosen.file}
        </span>
        <span :if={@chosen} class="note">read only: wb.sh alone writes the workspace · secrets masked</span>
      </div>
      <pre :if={@chosen} class="env yaml out"><.yaml_line :for={line <- @chosen.lines} line={line} /></pre>
      <div
        :if={@chosen}
        class="ograb"
        role="separator"
        aria-orientation="horizontal"
        tabindex="0"
        aria-label="How tall the file's box is — drag, or arrow keys; double-click for the default"
      >
      </div>
    </div>
    """
  end

  attr :line, :string, required: true

  defp yaml_line(assigns) do
    assigns =
      assign(assigns,
        parts:
          cond do
            String.match?(assigns.line, ~r/^\s*#/) or String.trim(assigns.line) == "" ->
              [{"c", assigns.line}]

            m = Regex.run(~r/^(\s*-?\s*[\w.-]+:)(.*)$/, assigns.line) ->
              [
                {"k", Enum.at(m, 1)},
                {if(String.contains?(Enum.at(m, 2), "•"), do: "m"), Enum.at(m, 2)}
              ]

            true ->
              [{nil, assigns.line}]
          end
      )

    ~H"""
    <div class="ln"><span :for={{cls, text} <- @parts} class={cls}>{text}</span></div>
    """
  end

  defp sync_title(%{in_sync: true}),
    do: "every service the cartridges ask for is in the file, and nothing else"

  defp sync_title(d),
    do:
      Enum.join(
        Enum.reject(
          [
            d.stray != [] &&
              "declares " <> Enum.join(d.stray, ", ") <> ", which no cartridge asks for any more",
            d.missing != [] && "lacks " <> Enum.join(d.missing, ", ")
          ],
          &(!&1)
        ),
        " · "
      ) <> " — bake writes it again"
end
