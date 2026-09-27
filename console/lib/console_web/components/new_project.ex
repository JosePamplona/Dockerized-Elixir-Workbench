defmodule ConsoleWeb.NewProject do
  @moduledoc """
  The New Project card, on its own: where a project is created, out of
  `config.conf` and the name in its field.

  A component of its own since 2026-09-27, and for one reason — every
  tick of a checkbox goes to the server, because the server is what
  decides which of the others go dark (`--database` with ecto,
  `--live` with html). As part of the Deploy screen's template, that
  round trip re-rendered the deployments sheet and the Danger box with
  it, neither of which a flag can change. Now the form answers to the
  card and the rest of the screen is not touched.

  What it is given comes from the page and changes when a status does;
  what the reader is composing — `newp`: the name, the flags, the base
  cartridges left out — is the card's own, and never leaves it until
  Create.
  """
  use ConsoleWeb, :live_component

  import ConsoleWeb.Refs
  import ConsoleWeb.Square, only: [square: 1]
  import ConsoleWeb.Folds, only: [card_head: 1, fold_class: 2]
  alias Console.{Jobs, Verbs}
  alias ConsoleWeb.{Cartridges, Deploy}

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:newp, fn -> Deploy.newp_fresh(assigns.config) end)}
  end

  @impl true
  def handle_event("new_form", params, socket) do
    {:noreply, assign(socket, newp: newp_from(params, socket))}
  end

  # Create is the form submitted, and the line is built from what it
  # carries — never read off the button: a command rendered onto it and
  # a click in the same instant as the last change ran the command as it
  # was before that change (2026-09-07: --database mssql chosen, a bare
  # `new` run).
  #
  # As a list and not as the line, since the name may have a space in it
  # and `Verbs.parse/1` splits a line on spaces.
  def handle_event("new_submit", params, socket) do
    newp = newp_from(params, socket)
    ["new" | rest] = args = Deploy.new_args(socket.assigns.catalog, newp)
    project? = socket.assigns.status && socket.assigns.status["exists"] == true

    Jobs.run(Verbs.kind("new", rest), args, confirm: Verbs.confirm?({:new, nil}, project?))

    {:noreply, assign(socket, newp: newp)}
  end

  defp newp_from(params, socket) do
    ins = params["in"] || %{}
    catalog = socket.assigns.catalog

    out =
      for e <- Cartridges.base(catalog), ins[e["name"]] != "on", into: MapSet.new(), do: e["name"]

    %{
      out: out,
      # Merged, not replaced: a disabled field sends nothing, and the
      # card's memory of it is all there is (2026-09-27). Every switch
      # sends an "off" of its own while it is enabled, so nothing stale
      # can survive a reader turning one off.
      gen: Map.merge(socket.assigns.newp.gen, params["gen"] || %{}),
      name: params["name"] || "",
      default: socket.assigns.newp.default
    }
  end

  @impl true
  def render(assigns) do
    conf = Console.Config.values(assigns.config)
    pending = Deploy.pending(assigns.jobs, :new)
    project? = assigns.status && assigns.status["exists"] == true
    # The card's rows say what the *next* creation would use, which is
    # config.conf and nothing else: intention. What the project here is
    # has a paper of its own, the Record, and the card only links to it.
    # One crossing stays: the stack the project was built on, off its own
    # Dockerfile.local, and only when the two have come apart — which is
    # exactly when creating again would move the project off it.
    assigns =
      assign(assigns,
        conf: conf,
        pending: pending,
        project?: project?,
        busy: Deploy.busy?(assigns.jobs, [:new]),
        cmd: Deploy.new_command(assigns.catalog, assigns.newp),
        bases: Cartridges.base(assigns.catalog)
      )

    ~H"""
    <div class={["newcard", fold_class(@folded, "newproject")]}>
      <.card_head key="newproject" name="New Project" folded={@folded} />
      <form
        class="form"
        id="new-project-form"
        phx-target={@myself}
        phx-change="new_form"
        phx-submit="new_submit"
      >
        <%!-- The workspace first (2026-09-26): it is the row that says
              whether there is anything here and what Create would
              overwrite, so it is what the reader checks before they
              read a name, and the chip beside it is the card's own
              warning.

              The name is a field since 2026-09-26, and `config.conf`'s
              `PROJECT_NAME` is what it opens with. The file keeps it
              because the console needs a name before there is a
              project: it mounts `<project>_build` and `<project>_deps`,
              the volumes the compose will own, to run mix and git in
              its own process. Type another here and the project gets
              it — and the console will say it was started for the other
              one, which is true (2026-09-27). --%>
        <.given label="workspace" value={@conf["WORKSPACE_PATH"]}>
          <:mark>
            <.chip
              :if={!@project?}
              class="off"
              title="nothing to read and nothing to lose: Create makes one"
            >
              empty
            </.chip>
            <.chip :if={@project?} class="good" title="creating overwrites every file in it">
              existing project
            </.chip>
            <%!-- Beside the chip and not in the card's head (2026-09-27):
                  the two come and go together — both are there when the
                  workspace holds a project — so the chip says there is
                  one and the link opens it, on the row that is about
                  it. --%>
            <.link
              :if={@project?}
              class="lk"
              patch="/project?paper=record"
              title="the Record: what this project is — its birth, its cartridges"
            >
              Detail
            </.link>
          </:mark>
        </.given>
        <div class="frow">
          <label for="new-name">project name</label>
          <span class="ro">
            <input
              type="text"
              id="new-name"
              name="name"
              value={@newp.name}
              placeholder={@newp[:default] || Deploy.default_name()}
              autocomplete="off"
              title="the app and module derive from it, and so do this workspace's images and its compose project"
            />
          </span>
        </div>
        <.given
          label="elixir"
          value={@conf["ELIXIR_VERSION"]}
          warn={born_arg(@born, "ELIXIR", "elixir", @conf["ELIXIR_VERSION"])}
        />
        <.given
          label="erlang"
          value={@conf["ERLANG_VERSION"]}
          warn={born_arg(@born, "OTP", "erlang", @conf["ERLANG_VERSION"])}
        />
        <.given
          label="debian"
          value={@conf["DEBIAN_VERSION"]}
          warn={born_arg(@born, "DEBIAN", "debian", @conf["DEBIAN_VERSION"])}
        />
        <.given
          label="installer"
          value={installer(@conf)}
          muted="the newest phx.new that runs on this stack"
        />
        <div class="frow">
          <label>mix phx.new</label>
          <div class="flags">
            <label :for={{k, values} <- Deploy.gen_flags()}>
              --{k}
              <select name={"gen[#{k}]"}>
                <option :for={v <- values} value={v} selected={(@newp.gen[k] || hd(values)) == v}>
                  {v}
                </option>
              </select>
            </label>
          </div>
        </div>
        <div class="frow">
          <label title="In from birth; leave one out and insert it later from the shelf">base cartridges</label>
          <div class="flags bases">
            <%= for e <- @bases do %>
              <% out = Deploy.base_out?(@catalog, @newp, e["name"]) %>
              <% forced = Enum.any?(e["requires"] || [], &Deploy.base_out?(@catalog, @newp, &1)) %>
              <%!-- A cartridge that phx.new only generates with another is
                    not the reader's to leave in: it is disabled with the
                    reason in its title, which is `.unlit` and not a
                    fourth opacity written here. --%>
              <%!-- One line per cartridge (2026-09-27): the eight ran on
                    as a paragraph of boxes, wrapping where the card's
                    width happened to end, and a reader looking for one
                    of them read them all. What shares a line is what
                    belongs to it — ecto's `--database` and
                    `--binary-id`, html's `--live` — because those are
                    not cartridges, they are that cartridge's own
                    switches, and reading them apart from it would say
                    they were. --%>
              <div class="base">
                <label class={[out && "out", forced && "unlit"]}>
                  <input
                    type="checkbox"
                    name={"in[#{e["name"]}]"}
                    checked={!out}
                    disabled={forced}
                    title={
                      if forced,
                        do:
                          "goes with #{Enum.join(e["requires"], " and ")}: phx.new generates it only with them",
                        else: "in from birth; uncheck to leave it out"
                    }
                  />
                  <.cart_ref name={e["name"]} />
                </label>
                <%!-- A base cartridge's own phx.new flags: ecto's database and
                    ids, html's live. A switch is labelled with its flag and
                    checked when on, whatever its default; one on by default
                    carries an "off" before its box, since a form sends
                    nothing for an unchecked one, and the command says
                    --no-live. Every switch carries one, not only those
                    (2026-09-27): what the form does not send is what the
                    card remembers, so a switch that says nothing must
                    mean "nobody turned me off" and not "off".

                    With the cartridge left out its switches read off, and
                    not merely dim: the flag is not in the command at all,
                    and a ticked box that is going nowhere says the
                    opposite. Both the box and its hidden "off" go quiet
                    with it — disabled, so neither is sent — and what the
                    reader had set is what they find when they tick the
                    cartridge back on. --%>
                <span :if={e["options"] != []} class="subs">
                  <%= for o <- e["options"] do %>
                    <% flag = "--" <> String.replace(o["name"], "_", "-") %>
                    <label class={["sub", out && "out"]}>
                      <%= if o["choices"] do %>
                        {flag}
                        <select name={"gen[#{o["name"]}]"} disabled={out} title={o["doc"]}>
                          <option
                            :for={c <- choices(o)}
                            value={c["value"]}
                            selected={(@newp.gen[o["name"]] || o["default"]) == c["value"]}
                            title={c["doc"]}
                          >
                            {c["value"]}
                          </option>
                        </select>
                      <% else %>
                        <input
                          type="hidden"
                          name={"gen[#{o["name"]}]"}
                          value="off"
                          disabled={out}
                        />
                        <input
                          type="checkbox"
                          name={"gen[#{o["name"]}]"}
                          disabled={out}
                          checked={not out and switch_on?(o, @newp.gen[o["name"]])}
                          title={o["doc"]}
                        /> {flag}
                      <% end %>
                    </label>
                  <% end %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </form>
      <div class="foot">
        <div class="cmds">
          <div class="cmd">{@cmd}</div>
        </div>
        <span :if={@pending} class="confirm on">A project already exists in this workspace: every file in it goes.
        <button class="btn danger" phx-click="confirm" phx-value-id={@pending.id}>Yes, overwrite</button><button
          class="btn"
          phx-click="cancel"
          phx-value-id={@pending.id}
        >Keep it</button></span>
        <.job_button
          :if={!@pending}
          label={if @busy, do: "Creating…", else: "Create project"}
          class="primary"
          form="new-project"
          args={String.replace_prefix(@cmd, "./wb.sh ", "")}
          why={@busy && "a job is running"}
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :muted, :string, default: nil

  attr :title, :string,
    default: nil,
    doc: "where the value comes from, when it is not config.conf's own"

  attr :warn, :list,
    default: nil,
    doc: "[word, title]: the project here was made with something else"

  slot :mark, doc: "a reading of this given itself, chipped after the value"

  defp given(assigns) do
    ~H"""
    <div class="frow">
      <label>{@label}</label>
      <span class="ro">
        <span :if={@value} title={@title}>{@value}</span><span :if={!@value} class="nothing">{@muted}</span>
        {render_slot(@mark)}
        <.chip :if={@warn} class="warn" title={List.last(@warn)}>{List.first(@warn)}</.chip>
        <.square
          mark="cog"
          size="small"
          label={"Change #{@label} in config.conf"}
          class="cog"
          patch="/deploy?wb=config"
          title="change it in config.conf, in the workbench drawer"
        />
      </span>
    </div>
    """
  end

  # The installer row says what the next creation would generate with,
  # which is config.conf's and nothing else: the card is intention, and
  # it used to answer with the project's own stamp here, which was the
  # state slipping into the form.
  defp installer(%{"PHX_NEW_VERSION" => v}) when v not in [nil, ""], do: "phx.new #{v}"
  defp installer(_conf), do: nil

  # The stack, only where the two have come apart — the one thing on this
  # card the reader has to be told rather than left to notice, because
  # creating again would move the project off the stack it was built on.
  # A chip and not a sentence: two versions in one row is a state, and
  # the house has a face for a state. One row each, as the Record's
  # Birth reads them (2026-09-10): the row that moved is the row that
  # says so, and the elixir it was born on no longer speaks for the
  # three.
  defp born_arg(born, key, label, now) when is_map(born) do
    case born[key] do
      b when is_binary(b) and b != now ->
        [
          "born on #{b}",
          "this project was built on #{label} #{b}; config.conf now names #{now || "another"}, and creating again would move it"
        ]

      _ ->
        nil
    end
  end

  defp born_arg(_, _, _, _), do: nil

  # Whether a switch reads as on: as the card set it, else its default.
  defp switch_on?(o, nil), do: o["default"] == true
  defp switch_on?(_o, v), do: v == "on"

  # A choice's values, whether the manifest groups them or not.
  defp choices(%{"choices" => [%{"group" => _} | _] = groups}),
    do: Enum.flat_map(groups, & &1["values"])

  defp choices(%{"choices" => values}), do: values
end
