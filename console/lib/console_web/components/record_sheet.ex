defmodule ConsoleWeb.RecordSheet do
  @moduledoc """
  The Record paper drawn: the project's name, its birth in two tables
  and the command between them, the cartridges it carries on the
  shelf's own row with their parameters and addresses, and the
  deployments. The plan is `ConsoleWeb.Record`; this only lays it out.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Shelf, only: [front: 1]

  attr :record, :map, required: true
  attr :reads, :any, required: true

  def record_sheet(assigns) do
    ~H"""
    <div class="record" id="p-record">
      <p class="name" title="the compose project: the name every container of the workspace wears">
        {@record.name}
      </p>

      <.birth :if={@record.birth} birth={@record.birth} />
      <section :if={!@record.birth}>
        <h3>Birth</h3>
        <p class="nothing">
          No first commit to read: this project was not born in a workspace, or its repository has no history.
        </p>
      </section>

      <section>
        <h3 title="what the project carries, on the shelf's own row">
          Cartridges <span class="label">{length(@record.cartridges)} in</span>
        </h3>
        <div class="list wide">
          <div class="lrow head">
            <span></span>
            <span class="label">cartridge</span>
            <span class="label">origin</span>
            <span class="label">edition</span>
            <span class="label">installation parameters</span>
            <span
              class="label addr"
              title="the ports the compose publishes for the cartridge's services, and the routes the project offers on the app's port"
            >
              addresses
              <button
                :if={@record.up}
                class="go"
                type="button"
                phx-click="record_read"
                aria-busy={to_string(@reads == :asking)}
                title="call every route again, and read what each answers"
              >
                <.reload /><span class="sr">Call every route again</span>
              </button>
              <button
                :if={!@record.up}
                class="go unlit"
                type="button"
                aria-disabled="true"
                title="nothing is up: deploy, and every route is called once and answers in a chip"
              >
                <.reload /><span class="sr">Call every route</span>
              </button>
            </span>
          </div>
          <div :for={row <- @record.cartridges} class="lrow in">
            <span class="th"><img src={"/covers/#{front(row.entry)}"} alt="" draggable="false" /></span>
            <span class="nm"><.cart_ref name={row.c["name"]} installed={true} /></span>
            <span class="fx">
              <.chip :for={f <- row.facts}>{f}</.chip>
              <.chip class={elem(row.origin, 1)} title={elem(row.origin, 2)}>
                {elem(row.origin, 0)}
              </.chip>
            </span>
            <span class="vr" title={version_title(row.entry)}>{version(row.entry)}</span>
            <span class="col argv">
              <span
                :for={{flag, default?} <- row.params}
                class={default? && "dflt"}
                title={default? && "the default"}
              >{flag}</span>
            </span>
            <span class="col"><span class="pairs"><.address :for={a <- row.addresses} a={a} /></span></span>
          </div>
        </div>
      </section>

      <section>
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
              <th title="whether the file says what the cartridges ask for now">in sync</th>
              <th>status</th>
              <th title="the services the compose file declares; with the deployment up, what docker compose ps says of each">
                services
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={d <- @record.deployments}>
              <td class="k">{d.deploy}</td>
              <td>
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
                <span :if={d.baked} class="fact" title={sync_title(d)}>
                  <input
                    type="checkbox"
                    checked={d.in_sync == true}
                    aria-readonly="true"
                    tabindex="-1"
                  />
                </span>
                <span :if={d.stray != [] or d.missing != []} class="drift">
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
              <td>
                <.chip :if={d.status == "up"} class="good">up</.chip>
                <.chip :if={d.status == "down"} class="off">down</.chip>
              </td>
              <td><span class="pairs"><.address :for={a <- d.services} a={a} /></span></td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>
    """
  end

  attr :birth, :map, required: true

  defp birth(assigns) do
    ~H"""
    <section>
      <h3 title="how the project was made, read off the files as its first commit left them">
        Birth
        <span class="label">
          {String.slice(@birth.date, 0, 16)} at
          <.commit_ref sha={@birth.sha} subject={@birth.subject} date={@birth.date} />
        </span>
        <.chip
          :if={@birth.moved == 0}
          class="off"
          title="nothing the first commit decided has moved since"
        >
          unchanged since
        </.chip>
        <.chip :if={@birth.moved > 0} class="warn" title="marked on their rows">
          {@birth.moved} facts moved since
        </.chip>
      </h3>
      <table class="rows shape">
        <colgroup><col class="c1" /><col class="c2" /><col class="c3" /></colgroup>
        <thead>
          <tr>
            <th colspan="2" title="the toolchain it was born on, as the first commit left the file">
              Dockerfile.local
            </th>
            <th>line</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={row <- @birth.dockerfile}>
            <td class="k">{row.key}</td>
            <td>
              {row.born}
              <.chip
                :if={row.now}
                class="warn"
                title="bake rewrote Dockerfile.local from a newer seed"
              >
                now {row.now}
              </.chip>
            </td>
            <td><span class="argv">{row.line}</span></td>
          </tr>
          <tr>
            <td class="k">toolchain image</td>
            <td>{@birth.image}</td>
            <td>
              <span class="argv">{~S(ARG TOOLCHAIN_IMAGE="hexpm/elixir:${ELIXIR}-erlang-${OTP}-debian-${DEBIAN}")}</span>
            </td>
          </tr>
          <tr>
            <td class="k">installer</td>
            <td>
              phx.new {@birth.installer.born}
              <.chip
                :if={@birth.installer.now}
                class="warn"
                title="ARG PHX_NEW in Dockerfile.local changed since birth: bake keeps it, so a hand moved it"
              >
                now {@birth.installer.now}
              </.chip>
              <.chip
                :if={!@birth.installer.in_sync}
                class="warn"
                title={"the phx_new at hand in the toolchain is #{@birth.installer.at_hand}, not the #{@birth.installer.born} that generated the project: the base cartridges will refuse until ./wb.sh build rebuilds the toolchain from Dockerfile.local"}
              >
                installer now {@birth.installer.at_hand}
              </.chip>
            </td>
            <td><span class="argv">ARG PHX_NEW="{@birth.installer.born}"</span></td>
          </tr>
        </tbody>
      </table>

      <div class="cmdblock">
        <span
          class="thead"
          title="the command that generated it, reconstructed from mix.exs, config/config.exs and AGENTS.md as the first commit left them"
        >mix phx.new</span>
        <pre class="cmd">{@birth.command}</pre>
      </div>

      <table class="rows shape flags">
        <colgroup>
          <col class="f0" /><col class="f1" /><col class="f2" /><col class="f3" /><col class="f4" />
        </colgroup>
        <thead>
          <tr>
            <th
              class="used"
              title="whether the flag was given to phx.new, read off the files as the first commit left them"
            >
              used
            </th>
            <th>flag</th>
            <th>args</th>
            <th>in phx.new's words</th>
            <th>cartridge</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={f <- @birth.flags} class={f.moot && "unlit"} title={f.moot}>
            <td class="used">
              <span
                class="fact"
                title={f.moot || if(f.used, do: "given to phx.new", else: "not given")}
              >
                <input type="checkbox" checked={f.used} aria-readonly="true" tabindex="-1" />
              </span>
            </td>
            <td><span class="argv">--{f.name}</span></td>
            <td>
              <span
                :if={f.arg}
                class={["argv", f.default && "dflt"]}
                title={
                  f.default && "phx.new's default — written or left to fall, the tree reads the same"
                }
              >{f.arg}</span>
              <.chip
                :if={f.now}
                class="warn"
                title="changed since birth: a base cartridge, a bake, or a hand"
              >
                now {f.now}
              </.chip>
            </td>
            <td class="doc">{f.doc}</td>
            <td><.cart_ref :if={f.cartridge} name={f.cartridge} installed={f.installed} /></td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  attr :a, :map, required: true
  attr :title, :string, default: nil

  # One address, the house's face: the layer, the reading, the route's port.
  defp address(assigns) do
    ~H"""
    <.door_ref
      label={@a.label}
      path={@a.path}
      href={@a.href}
      why={@a.why}
      kind={@a.kind}
      port={@a.kind == "route" && @a.port}
      read={@a.read}
    />
    """
  end

  defp reload(assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" aria-hidden="true"><path
      d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4"
      fill="none"
      stroke="currentColor"
      stroke-width="2.2"
      stroke-linecap="round"
      stroke-linejoin="round"
    /></svg>
    """
  end

  defp version(%{"version" => %{"version" => v}}), do: "v" <> v
  defp version(_), do: "—"
  defp version_title(%{"version" => %{"date" => d}}), do: "#{d} in its CHANGELOG"
  defp version_title(_), do: "no CHANGELOG to read a version from"

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
