defmodule ConsoleWeb.Deployments do
  @moduledoc """
  The deployments as a sheet: the table — one row per compose file,
  baked or not, in sync or with its drift, up, stopped or down, its
  services as ports, and Up or Stop, Down and Bake — and under it the
  file itself, the one whose eye is pressed, in a code box that wears
  its name. The plan is `ConsoleWeb.Record.deployments/1`; the Record
  paper places this, and the rail draws its own short row off the same
  plan in `ConsoleWeb.Board`.

  The eye is on every row: unlit with the remedy while the file is not
  baked, pressed on the one the box shows. It patches the URL
  (`?deploy=prod`), so the box holds no state of its own and a status
  arriving reads the files again under the same choice.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Board, only: [bake_button: 1, deploy_button: 1]

  attr :rows, :list, required: true, doc: "ConsoleWeb.Record.deployments/1"
  attr :status, :map, default: nil
  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"

  attr :composes, :list,
    default: [],
    doc: "the three compose files as Console.Docker.composes/1 reads them"

  attr :deploy, :any, default: nil, doc: "the file the box shows; nil when none is baked"

  def deployments_sheet(assigns) do
    ~H"""
    <section class="deployments">
      <h3 title="the Docker Compose files baked into the workspace, one per deployment">
        Deployments <span class="label">Docker Compose</span>
      </h3>
      <table class="rows deps">
        <thead>
          <tr>
            <th></th>
            <th title="the deployment's compose file, baked into the workspace, out of sync with the project, or not baked yet">
              file
            </th>
            <th title="what the file declares that no cartridge asks for any more (+), and what a cartridge asks for that the file lacks (−); nothing when the file says what the cartridges ask">
              sync differences
            </th>
            <th>status</th>
            <th title="the services the compose file declares; with the deployment up, what docker compose ps says of each">
              services
            </th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={d <- @rows}>
            <td class="k">{d.deploy}</td>
            <td class="file">
              <.eye deploy={d.deploy} file={d.file} baked={d.baked} open={@deploy == d.deploy} />
              <.chip :if={!d.baked} class="off" title={"up --deploy #{d.deploy} bakes it"}>
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
            </td>
            <td class="sync">
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
              <.deploy_button
                :if={d.status == "up"}
                verb="stop"
                name={d.deploy}
                status={@status}
                busy={@busy}
              />
              <.deploy_button
                :if={d.status != "up" and d.baked}
                verb="up"
                name={d.deploy}
                status={@status}
                busy={@busy}
              />
              <.deploy_button
                :if={d.baked}
                verb="down"
                name={d.deploy}
                status={@status}
                busy={@busy}
                present={d.present}
              />
              <.bake_button name={d.deploy} status={@status} busy={@busy} baked={d.baked} />
            </td>
          </tr>
        </tbody>
      </table>
      <.file_sheet composes={@composes} deploy={@deploy} />
    </section>
    """
  end

  attr :deploy, :string, required: true
  attr :file, :string, required: true
  attr :baked, :boolean, required: true
  attr :open, :boolean, required: true

  # The eye: read this file in the box under the table. The square
  # icon button the knock bell wears, with an eye.
  defp eye(assigns) do
    ~H"""
    <.link
      :if={@baked}
      class="go eye"
      patch={"/project?paper=record&deploy=#{@deploy}"}
      aria-pressed={to_string(@open)}
      title={"read #{@file} under the table"}
    >
      <.eye_mark /><span class="sr">Read {@file}</span>
    </.link>
    <button
      :if={!@baked}
      class="go eye unlit"
      type="button"
      aria-disabled="true"
      title={"not baked: no #{@file} in this workspace — Bake, or Up"}
    >
      <.eye_mark /><span class="sr">Read {@file}</span>
    </button>
    """
  end

  defp eye_mark(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" aria-hidden="true"><path
      d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z"
      fill="none"
      stroke="currentColor"
      stroke-width="2.2"
      stroke-linejoin="round"
    /><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="2.2" /></svg>
    """
  end

  # The file under the table, in a code box with a strip that names it:
  # the file whose eye is pressed, read only — wb.sh alone writes the
  # workspace — and the secrets masked. With none baked the box is one
  # line saying so, not gone. It read under Docker's Deploys until
  # 2026-09-09; the files are the workspace's, so they read here.
  attr :composes, :list, required: true
  attr :deploy, :any, required: true

  defp file_sheet(assigns) do
    chosen = Enum.find(assigns.composes, &(&1.key == assigns.deploy))
    assigns = assign(assigns, chosen: chosen)

    ~H"""
    <div class="fsheet">
      <div class="strip">
        <span class="label">the file</span>
        <span :if={@chosen} class="fname" title={"the #{@chosen.key} deployment's compose file"}>
          {@chosen.file}
        </span>
        <span :if={@chosen} class="note">read only: wb.sh alone writes the workspace · secrets masked</span>
        <span :if={is_nil(@chosen)} class="note">
          none baked yet: Bake, or Up, writes the deployment's
        </span>
      </div>
      <pre :if={@chosen} class="env yaml"><.yaml_line :for={line <- @chosen.lines} line={line} /></pre>
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
