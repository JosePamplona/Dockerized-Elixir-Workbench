defmodule ConsoleWeb.RecordSheet do
  @moduledoc """
  The Birth paper drawn (the ribbon called it Record until 2026-09-12,
  when the name had outgrown what was left): the project's name and its
  birth, in two tables with the command between them. The plan is `ConsoleWeb.Record`;
  this only lays it out. The paper had two more sections and gave both
  away, each to where its reader already was: the deployments to the
  Deploy tab (2026-09-09, `ConsoleWeb.Deployments`) and the cartridges
  it carries to the shelf's *Inserted* (2026-09-10, `ConsoleWeb.Shelf`).
  What is left is what the project IS, which is what it was born as.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  attr :record, :map, required: true
  attr :reads, :any, required: true
  attr :status, :map, default: nil
  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"

  attr :stale, :boolean,
    default: false,
    doc: "a full status is in flight: the cartridges are the last reading's"

  def record_sheet(assigns) do
    ~H"""
    <div class="record" id="p-record">
      <p class="name" title="the compose project: the name every container of the workspace wears">
        {@record.name}
      </p>

      <.birth :if={@record.birth} birth={@record.birth} />
      <section :if={!@record.birth}>
        <p class="nothing">
          No first commit to read: this project was not born in a workspace, or its repository has no history.
        </p>
      </section>
    </div>
    """
  end

  attr :birth, :map, required: true

  defp birth(assigns) do
    ~H"""
    <section>
      <h3 title="how the project was made, read off the files as its first commit left them">
        Born
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
              <.pkg_ref name="phx_new" label={"phx.new #{@birth.installer.born}"} />
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
                title={"the phx_new at hand in the toolchain is #{@birth.installer.at_hand}, not the #{@birth.installer.born} that generated the project: the base cartridges will refuse until ./wb.sh console build rebuilds the workbench's image with the stamped installer"}
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
            <th>
              <a
                class="src"
                href={@birth.docs}
                target="_blank"
                rel="noopener noreferrer"
                title={
                  "mix phx.new's options, as its documentation says them" <>
                    if(@birth.installer.born,
                      do: " — for the #{@birth.installer.born} that generated this project",
                      else: ""
                    )
                }
              >in phx.new's words</a>
            </th>
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
                class="argv val"
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
end
