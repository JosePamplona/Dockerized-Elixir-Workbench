defmodule ConsoleWeb.ProjectScreen do
  @moduledoc """
  The project's own papers: README, CHANGELOG, the .env with its secrets
  masked, and Doors — the plan of every address the project answers to,
  drawn off the status, with what each answered when the console called.
  """
  use Phoenix.Component
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  import ConsoleWeb.Refs, only: [door_ref: 1, probe_ref: 1, chip: 1]

  attr :carried, :list, required: true
  attr :paper, :string, required: true
  attr :page, :map, default: nil
  attr :doors, :any, default: nil, doc: "ConsoleWeb.Doors.page/2, when Doors is the paper"
  attr :reads, :any, default: %{}, doc: "what the addresses answered: a map by href, or :asking"
  attr :port, :any, default: nil, doc: "the app's port, the Doors tab's sublabel"

  def project_screen(assigns) do
    ~H"""
    <div class="pdocs">
      <.ribbon
        label="The project's own documents"
        selected={@paper}
        docked
        items={
          for {key, label, file} <- Console.Project.papers(),
              do: %{
                key: key,
                label: label,
                small: small(key, file, key in @carried, @port),
                why: key not in @carried && paper_why(key, file),
                href: "/project?paper=#{key}"
              }
        }
      />
      <div
        :if={@page && @page[:html]}
        class={["booklet", @page.toc == [] && "notoc"]}
        id="p-booklet"
        phx-hook="Booklet"
      >
        <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
        <nav :if={@page.toc != []} class="toc">
          <a class="doctitle" href="#top">{@page.title}</a><a
            :for={{id, text} <- @page.toc}
            href={"##{id}"}
          >{text}</a>
        </nav>
      </div>
      <pre :if={@page && @page[:env]} class="env"><%= for line <- @page.env do %><.env_line line={line} /><% end %></pre>
      <.doors_sheet :if={@page && @page[:doors] && @doors} doors={@doors} reads={@reads} />
      <div :if={is_nil(@page)} class="nothing">
        This workspace carries none of the project's papers.
      </div>
    </div>
    """
  end

  # The ribbon's sublabel: the file a paper is, or for Doors the port the
  # addresses sit on — it is drawn, not read off a file.
  defp small("doors", _file, true, port), do: if(port, do: "localhost:#{port}", else: "no port")
  defp small(_key, file, true, _port), do: file
  defp small(_key, _file, false, _port), do: "—"

  defp paper_why("doors", _), do: "no workspace read yet: the doors are drawn off its status"

  defp paper_why("changelog", _),
    do:
      "this workspace has no CHANGELOG.md: new generates none — the project is born stock, and what it carries is its own to write. The cartridges keep theirs."

  defp paper_why(_, file), do: "no #{file} in this workspace"

  attr :doors, :map, required: true
  attr :reads, :any, required: true

  # The plan. Five rows: the workbench's own addresses, the doors open,
  # the doors shut with their reasons, the probes, and the doors of the
  # cartridges not in. Beside each address the console could call, what
  # it answered — a chip — and a way to ask again.
  defp doors_sheet(assigns) do
    ~H"""
    <div class="doors" id="p-doors">
      <p class="lede">
        <span :if={@doors.up}>
          <b>{@doors.deployment}</b>
          is up on <span class="mono">localhost:{@doors.port}</span>: every open door and probe was called once, and answered as the chips say.
        </span>
        <span :if={!@doors.up}>
          No deployment is up: the doors are drawn shut. Deploy, and they open on <span class="mono">localhost:{@doors.port || "the port"}</span>.
        </span>
        <button :if={@doors.up} class="btn" type="button" phx-click="doors_read">Ask again</button>
      </p>
      <section>
        <h3>
          The workbench's
          <span class="label">the app, and pgAdmin and Grafana when they have a port</span>
        </h3>
        <div class="urls">
          <span :for={d <- @doors.own} class="call">
            <.door_ref label={d.label} path={d.path} href={d.href} why={!d.href && "the app is down"} />
            <.reading reads={@reads} href={d.href} />
          </span>
        </div>
      </section>
      <section>
        <h3>
          Open
          <span class="label">{count(@doors.open, "door")} by cartridges, on the app's port</span>
        </h3>
        <p :if={@doors.open == []} class="nothing">None right now.</p>
        <div class="urls">
          <span :for={d <- @doors.open} class="call">
            <.door_ref label={d.label} path={d.path} href={d.href} who={d.who} />
            <.reading reads={@reads} href={d.href} />
          </span>
        </div>
      </section>
      <section>
        <h3>
          Shut
          <span :if={@doors.up} class="label">{count(@doors.shut, "door")} an inserted cartridge keeps closed, and what opens each</span>
          <span :if={!@doors.up} class="label">{count(@doors.shut, "door")} of the inserted cartridges: the app is down, and each says what else it needs</span>
        </h3>
        <p :if={@doors.shut == []} class="nothing">
          None: every door the inserted cartridges declare is open.
        </p>
        <div class="urls">
          <.door_ref :for={d <- @doors.shut} label={d.label} path={d.path} who={d.who} why={d.why} />
        </div>
      </section>
      <section>
        <h3>
          Probes
          <span class="label">{count(@doors.probes, "path")} the cartridges have the console call</span>
        </h3>
        <p :if={@doors.probes == []} class="nothing">
          None declared: healthcheck and healthcheck2 each bring some.
        </p>
        <div class="urls">
          <.probe_ref
            :for={p <- @doors.probes}
            label={p.label}
            path={p.path}
            who={p.who}
            read={read(@reads, p.href)}
          />
        </div>
      </section>
      <section>
        <h3>
          Not in yet
          <span class="label">{count(@doors.waiting, "door")} a cartridge would open once inserted</span>
        </h3>
        <p :if={@doors.waiting == []} class="nothing">Every cartridge with a door is in.</p>
        <div class="urls">
          <.door_ref
            :for={d <- @doors.waiting}
            label={d.label}
            path={d.path}
            who={d.who}
            who_installed={false}
            why={d.why}
          />
        </div>
      </section>
    </div>
    """
  end

  attr :reads, :any, required: true
  attr :href, :any, required: true

  defp reading(assigns) do
    assigns = assign(assigns, read: read(assigns.reads, assigns.href))

    ~H"""
    <.chip :if={@read} class={elem(@read, 1)}>{elem(@read, 0)}</.chip>
    """
  end

  # A reading, or the word that it is being asked for; nothing for an
  # address the console never called.
  defp read(_reads, nil), do: nil
  defp read(:asking, _href), do: {"asking…", "busy off"}
  defp read(reads, href), do: reads[href]

  defp count(list, word), do: "#{length(list)} #{word}#{if length(list) == 1, do: "", else: "s"}"

  attr :line, :string, required: true

  # One element per line, with no "\n" of its own: see the same note on
  # the drawer's raw view. A `cond` in a template leaves its indentation
  # between the branches, and inside a <pre> that indentation is text.
  defp env_line(assigns) do
    assigns = assign(assigns, parts: env_parts(assigns.line))

    ~H"""
    <div class="ln"><span :for={{cls, text} <- @parts} class={cls}>{text}</span></div>
    """
  end

  defp env_parts(line) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "#") or trimmed == "" ->
        [{"c", line}]

      m = Regex.run(~r/^(\w+=)(.*)$/, line) ->
        value = Enum.at(m, 2)
        [{"k", Enum.at(m, 1)}, {if(String.contains?(value, "•"), do: "m"), value}]

      true ->
        [{nil, line}]
    end
  end
end
