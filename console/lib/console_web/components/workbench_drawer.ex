defmodule ConsoleWeb.WorkbenchDrawer do
  @moduledoc """
  The workbench's own drawer: config.conf as the form it already is,
  its manual, its changelog, and Console — how this page is arranged,
  kept in the browser. The values of the form are saved through
  `wb.sh config set`, as a job.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Ribbon, only: [ribbon: 1]

  # The drawer's top row is categories, the way the cartridge's is: what
  # the workbench is set by, what this browser is set by, and what the
  # workbench has written about itself. The papers are a group under
  # Manual — README and CHANGELOG — exactly as a box's three are, so the
  # two drawers are read the same way and the file names live where they
  # are all files.
  #
  # In that order: the two you set, then the one you read — which also
  # puts Manual last, where the box's drawer already has it. And the
  # third is Interface and no longer Console: it lost the `this browser`
  # under it when the row became categories, and a tab called Console
  # inside the console named everything. Its key stays `ui`, which is
  # short and which nothing but the URL ever says.
  @tabs [{"config", "Config"}, {"ui", "Interface"}, {"manual", "Manual"}]
  @choices %{"GIT_IDENTITY" => ["user", "workbench"]}
  # When each setting takes effect — most of the file is not 'new only'.
  @effect %{
    "WORKSPACE_PATH" => nil,
    "PROJECT_NAME" => "new",
    "PHX_NEW_VERSION" => "new",
    "ELIXIR_VERSION" => "new",
    "ERLANG_VERSION" => "new",
    "DEBIAN_VERSION" => "new",
    "GIT_IDENTITY" => "every commit",
    "POSTGRES_IMAGE_VERSION" => "every bake",
    "PGADMIN_IMAGE_VERSION" => "every bake",
    "NGINX_IMAGE_VERSION" => "scaled deploy"
  }
  @stack_parts [
    {"ELIXIR_VERSION", :e, "the Elixir of the image"},
    {"ERLANG_VERSION", :o, "the Erlang/OTP of the image"},
    {"DEBIAN_VERSION", :d, "the Debian base of the image"}
  ]

  def tabs, do: @tabs

  attr :tab, :string, required: true, doc: "the screen under the drawer"
  attr :wb, :string, required: true
  attr :paper, :string, default: "readme", doc: "which of the workbench's papers, under Manual"
  attr :version, :string, default: nil
  attr :config, :map, required: true
  attr :edits, :map, required: true
  attr :raw, :boolean, default: false
  attr :stacks, :any, default: nil
  attr :asking, :boolean, default: false
  attr :stacks_error, :string, default: nil
  attr :installers, :any, default: nil
  attr :installers_asking, :boolean, default: false
  attr :installers_error, :string, default: nil
  attr :page, :map, default: nil
  attr :jobs, :list, default: []

  def workbench_drawer(assigns) do
    ~H"""
    <aside class="drawer on" role="dialog" aria-modal="true" aria-label="The workbench">
      <div class="top">
        <h3>
          Dockerized Elixir Workbench
          <.chip :if={@version}>v{@version}</.chip>
        </h3>
        <.link class="btn" patch={"/#{@tab}"}>Close</.link>
        <.ribbon
          label="The workbench: what sets it, what draws it, what it says"
          selected={@wb}
          items={
            for {key, label} <- tabs(),
                do: %{
                  key: key,
                  label: label,
                  href: "/#{@tab}?wb=#{key}#{if key == "manual", do: "&paper=#{@paper}"}"
                }
          }
        />
      </div>
      <.config
        :if={@wb == "config"}
        config={@config}
        edits={@edits}
        raw={@raw}
        stacks={@stacks}
        asking={@asking}
        stacks_error={@stacks_error}
        installers={@installers}
        installers_asking={@installers_asking}
        installers_error={@installers_error}
        jobs={@jobs}
      />
      <div :if={@wb == "manual"} class="papers">
        <.ribbon
          label="The workbench's own papers"
          selected={@paper}
          docked
          items={
            for {key, label, file} <- Console.Papers.workbench_papers(),
                do: %{key: key, label: label, small: file, href: "/#{@tab}?wb=manual&paper=#{key}"}
          }
        />
        <div
          :if={@page}
          class={["booklet", @page.toc == [] && "notoc"]}
          id="wb-booklet"
          phx-hook="Booklet"
        >
          <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
          <nav :if={@page.toc != []} class="toc" aria-label="In this document">
            <a class="doctitle" href="#top">{@page.title}</a><a
              :for={{id, text} <- @page.toc}
              href={"##{id}"}
            >{text}</a>
          </nav>
        </div>
      </div>
      <.ui :if={@wb == "ui"} />
    </aside>
    """
  end

  # --- config.conf as a form ----------------------------------------------------

  defp config(assigns) do
    changed = map_size(assigns.edits)

    busy =
      Enum.any?(assigns.jobs, &(&1.state in [:running, :queued] and elem(&1.kind, 0) == :config))

    assigns = assign(assigns, changed: changed, busy: busy)

    ~H"""
    <div class="cfg">
      <div class="bar docked">
        <button
          class="btn primary"
          type="button"
          disabled={@changed == 0 or @busy}
          phx-click="cfg_save"
        >{cond do
          @busy -> "Saving…"
          @changed > 0 -> "Save #{@changed} change#{if @changed == 1, do: "", else: "s"}"
          true -> "Save"
        end}</button>
        <button class="btn" type="button" disabled={@changed == 0} phx-click="cfg_reload">Reload</button>
        <button class="btn" type="button" aria-pressed={to_string(@raw)} phx-click="cfg_raw">Raw</button>
        <span class="note">Values are written back in place by ./wb.sh config set; comments and order stay. Each field's tag says when it takes effect.</span>
      </div>
      <div class="cfgbody">
        <pre :if={@raw} class="raw"><%= for line <- String.split(raw_text(@config, @edits), "\n") do %><.raw_line line={line} /><% end %></pre>
        <%!-- The id is what lets LiveView put the form back after a
            reconnect: without it the edits staged in the drawer would be
            gone the first time the socket blinked. --%>
        <form :if={!@raw} id="cfg-form" phx-change="cfg_change">
          <%= for sec <- @config.sections, sec.fields != [] do %>
            <div class="sec">
              <h4>{sec.title}</h4>
              <p :if={sec.intro != []} class="intro"><.prose text={Enum.join(sec.intro, " ")} /></p>
              <%= for {f, i} <- Enum.with_index(sec.fields) do %>
                <h5
                  :if={f.group != "" and (i == 0 or Enum.at(sec.fields, i - 1).group != f.group)}
                  class="grp"
                >
                  {f.group}
                </h5>
                <.stack_rows
                  :if={f.key == "ELIXIR_VERSION"}
                  sec={sec}
                  edits={@edits}
                  stacks={@stacks}
                  asking={@asking}
                  stacks_error={@stacks_error}
                />
                <.installer_row
                  :if={f.key == "PHX_NEW_VERSION"}
                  f={f}
                  edits={@edits}
                  installers={@installers}
                  asking={@installers_asking}
                  error={@installers_error}
                  elixir={Console.Config.values(@config)["ELIXIR_VERSION"]}
                />
                <.field
                  :if={
                    f.key not in [
                      "ELIXIR_VERSION",
                      "ERLANG_VERSION",
                      "DEBIAN_VERSION",
                      "PHX_NEW_VERSION"
                    ]
                  }
                  f={f}
                  config={@config}
                  edits={@edits}
                />
              <% end %>
              <p :for={note <- sec.outro} class="intro outro"><.prose text={note} /></p>
            </div>
          <% end %>
        </form>
      </div>
    </div>
    """
  end

  attr :line, :string, required: true

  # One element per line, and the line's own text inside it — never a
  # "\n" of its own. A `cond` in the template puts its indentation
  # between the branches, and in a <pre> that indentation is text: every
  # line came out followed by a blank one and two spaces. The parts are
  # worked out in Elixir and the markup is one element repeated, which
  # has no whitespace to leave behind.
  defp raw_line(assigns) do
    assigns = assign(assigns, parts: raw_parts(assigns.line))

    ~H"""
    <div class="ln"><span :for={{cls, text} <- @parts} class={cls}>{text}</span></div>
    """
  end

  defp raw_parts(line) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "#") or trimmed == "" ->
        [{"c", line}]

      m = Regex.run(~r/^(export\s+\w+=)(.*?)(\s*#.*)?$/, line) ->
        [{"k", Enum.at(m, 1)}, {"v", Enum.at(m, 2)}] ++
          case Enum.at(m, 3) do
            comment when comment in [nil, ""] -> []
            comment -> [{"c", comment}]
          end

      true ->
        [{nil, line}]
    end
  end

  @doc "config.conf's text with the edits written in, as `config set` will write them."
  def raw_text(config, edits) do
    Enum.reduce(edits, config.text || "", fn {key, v}, text ->
      Regex.replace(~r/^(export\s+#{key}=)("?)[^"#\n]*\2/m, text, fn _, a, q ->
        a <> q <> v <> q
      end)
    end)
  end

  attr :f, :map, required: true
  attr :config, :map, required: true
  attr :edits, :map, required: true

  defp field(assigns) do
    f = assigns.f
    v = Map.get(assigns.edits, f.key, f.value)
    effect = Map.get(@effect, f.key, "new")

    choices =
      if f.key == "WORKSPACE_PATH",
        do: nil,
        else:
          @choices[f.key] ||
            (assigns.config.alts[f.key] && [f.value | assigns.config.alts[f.key]])

    help =
      if f.key == "WORKSPACE_PATH",
        do: String.trim(f.help <> " A path that does not exist yet is created on new."),
        else: f.help

    help = String.trim(help <> if(f.inline != "", do: " — " <> f.inline, else: ""))

    assigns =
      assign(assigns,
        v: v,
        effect: effect,
        choices: choices,
        help: help,
        edited: Map.has_key?(assigns.edits, f.key)
      )

    ~H"""
    <div class={["row", @edited && "changed", @v == "false" && "off"]}>
      <label for={"cfg-#{@f.key}"}>{@f.key}
      <.chip :if={@effect} class="new">{@effect}</.chip></label>
      <%= cond do %>
        <% @v in ["true", "false"] -> %>
          <input type="hidden" name={"cfg[#{@f.key}]"} value="false" /><input
            type="checkbox"
            id={"cfg-#{@f.key}"}
            name={"cfg[#{@f.key}]"}
            value="true"
            checked={@v == "true"}
          />
        <% @choices -> %>
          <select id={"cfg-#{@f.key}"} name={"cfg[#{@f.key}]"}><option
            :for={c <- Enum.uniq(@choices ++ [@v])}
            value={c}
            selected={c == @v}
          >
            {c}
          </option></select>
        <% true -> %>
          <input
            type="text"
            id={"cfg-#{@f.key}"}
            name={"cfg[#{@f.key}]"}
            value={@v}
            spellcheck="false"
            placeholder={@f.key == "WORKSPACE_PATH" && "./_workspaces/…"}
          />
      <% end %>
      <p :if={@help != ""} class="help"><.prose text={@help} /></p>
    </div>
    """
  end

  # The stack and its three versions are four views of one list: the
  # hexpm/elixir tags. The stack sets the three; editing one looks the
  # exact tag back up, and a combination with no published image among
  # the recent ones leaves the stack unpicked.
  attr :sec, :map, required: true
  attr :edits, :map, required: true
  attr :stacks, :any, default: nil
  attr :asking, :boolean, default: false
  attr :stacks_error, :string, default: nil

  defp stack_rows(assigns) do
    val = fn key ->
      Map.get(
        assigns.edits,
        key,
        (Enum.find(assigns.sec.fields, &(&1.key == key)) || %{value: ""}).value
      )
    end

    cur = %{e: val.("ELIXIR_VERSION"), o: val.("ERLANG_VERSION"), d: val.("DEBIAN_VERSION")}
    list = if is_list(assigns.stacks), do: Enum.flat_map(assigns.stacks, &parse_tag/1), else: []
    match = Enum.find(list, &(&1.e == cur.e and &1.o == cur.o and &1.d == cur.d))

    groups =
      Enum.group_by(list, &(&1.e |> String.split(".") |> Enum.take(2) |> Enum.join(".")))
      |> Enum.sort_by(fn {k, _} -> version_key(k) end, :desc)

    # One state for the four, because that is what it is a state of: the
    # combination is published, or it is not, or nobody has asked yet.
    # It used to be said inside every option of every field — the same
    # sentence fifty times over, about the row and not about the option
    # it was written on.
    # `not asked` is a claim, and it was being made about a reading that
    # had been asked for and failed: the chip only saw an empty list. A
    # failure is its own state and says so.
    state =
      cond do
        assigns.stacks_error -> :failed
        list == [] -> :unknown
        match -> :ok
        true -> :none
      end

    assigns =
      assign(assigns,
        cur: cur,
        list: list,
        match: match,
        groups: groups,
        parts: @stack_parts,
        val: val,
        state: state
      )

    ~H"""
    <div class="row">
      <label for="cfg-stack">DOCKER_IMAGE<.chip class="new">new</.chip></label>
      <div class="stackline">
        <div class="fetch">
          <select id="cfg-stack" name="stack" disabled={@list == []}>
            <option :if={@asking} value="">— asking Docker Hub for the usable images…</option>
            <option :if={!@asking and @list == []} value="" selected>
              {@cur.e}-erlang-{@cur.o}-debian-{@cur.d}
            </option>
            <option :if={!@asking and @list != [] and is_nil(@match)} value="" selected>—</option>
            <optgroup :for={{minor, tags} <- @groups} label={"elixir " <> minor}>
              <option :for={x <- tags} value={x.tag} selected={@match && @match.tag == x.tag}>
                {x.tag}
              </option>
            </optgroup>
          </select>
          <button
            class="go"
            type="button"
            phx-click="stacks_ask"
            disabled={@asking}
            aria-busy={to_string(@asking)}
            aria-controls="cfg-stack"
            title={
              if @asking,
                do: "asking Docker Hub…",
                else:
                  "ask Docker Hub for the usable images — five pages of its API, seconds, over your own connection"
            }
          >
            <svg viewBox="0 0 24 24" aria-hidden="true"><path
              d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            /></svg>
            <span class="sr">Ask Docker Hub for the usable images</span>
          </button>
        </div>
        <.chip class={state_class(@state)} title={state_why(@state, @cur)}>
          {state_word(@state)}
        </.chip>
      </div>
      <p class="help">
        <.prose text="One hexpm/elixir image, straight from Docker Hub (./wb.sh stacks), whose every published tag is at https://hub.docker.com/r/hexpm/elixir/tags — picking one here sets the three versions below, and the three look it back up." />
        <span :if={@stacks_error} class="bad">Docker Hub did not answer: {@stacks_error}</span>
        <span :if={!@stacks_error and @list == [] and !@asking}>The list is not here yet — it costs five calls to Docker Hub, so the console goes only when you press the button.</span>
      </p>
    </div>
    <%= for {key, part, help} <- @parts do %>
      <% values =
        @list |> Enum.map(& &1[part]) |> Kernel.++([@cur[part]]) |> Enum.uniq() |> in_order(part) %>
      <div class={["row", Map.has_key?(@edits, key) && "changed"]}>
        <label for={"cfg-#{key}"}>{key}
        <.chip class="new">new</.chip></label>
        <select id={"cfg-#{key}"} name={"cfg[#{key}]"}>
          <option
            :for={v <- values}
            value={v}
            selected={v == @cur[part]}
            class={!combines?(@list, part, v, @cur) && "dim"}
            title={!combines?(@list, part, v, @cur) && "no image with #{others(part, @cur)}"}
          >
            {v}
          </option>
        </select>
        <p class="help"><.prose text={help} /></p>
      </div>
    <% end %>
    """
  end

  def parse_tag(tag) do
    case Regex.run(~r/^(.+?)-erlang-(.+?)-debian-(.+)$/, tag) do
      [_, e, o, d] -> [%{tag: tag, e: e, o: o, d: d}]
      _ -> []
    end
  end

  # What an option that cannot be picked is being judged against: the
  # other two, named and set to what they are set to. "no image with the
  # other two" made the reader work out which two and then go and read
  # them; this says what is in the way, so the option is worth reading on
  # its own. Written the way the house writes a stack everywhere else —
  # elixir and erlang named, the Debian codename standing for itself.
  defp others(part, cur) do
    ([:e, :o, :d] -- [part]) |> Enum.map_join(" · ", &"#{stack_word(&1)}#{cur[&1]}")
  end

  defp stack_word(:e), do: "elixir "
  defp stack_word(:o), do: "erlang "
  defp stack_word(:d), do: ""

  # Green, red, or nothing yet — the house's chip, which is the dot with
  # the word that saves the reader guessing what the colour meant. The
  # third state is not a failure: with no list nobody can say whether the
  # combination is published, and saying `no image` there would be a
  # claim the console has not earned.
  defp state_class(:ok), do: "good"
  defp state_class(:none), do: "bad"
  defp state_class(:failed), do: "bad"
  defp state_class(:unknown), do: "off"

  defp state_word(:ok), do: "published image"
  defp state_word(:none), do: "no image"
  defp state_word(:failed), do: "not answered"
  defp state_word(:unknown), do: "not asked"

  defp state_why(:ok, cur),
    do: "hexpm/elixir:#{cur.e}-erlang-#{cur.o}-debian-#{cur.d} is on Docker Hub"

  defp state_why(:none, cur),
    do: "no hexpm/elixir image with elixir #{cur.e} · erlang #{cur.o} · #{cur.d}"

  defp state_why(:failed, _cur), do: "the list could not be read; the reason is under the field"

  defp state_why(:unknown, _cur),
    do: "press the button to ask Docker Hub which combinations are published"

  # The Phoenix installer: which phx_new generates the project, and the
  # empty value that is the ordinary one — not a version but a policy,
  # `the newest that runs on this stack`, which is why the field keeps an
  # option for it rather than a blank.
  #
  # The releases are grouped by the Elixir each one declares, and the
  # group says it. That is the whole design: there are twenty-five
  # releases and three requirements between them, so the reader compares
  # three groups against one version instead of reading twenty-five
  # rows — and the console never has to hold an opinion about whether a
  # stack runs a release. That opinion is `stack_satisfies` in `wb.sh`,
  # `new` refuses on it, and one rule in one place cannot come apart
  # from itself.
  attr :f, :map, required: true
  attr :edits, :map, required: true
  attr :installers, :any, default: nil
  attr :asking, :boolean, default: false
  attr :error, :string, default: nil
  attr :elixir, :string, default: nil

  defp installer_row(assigns) do
    cur = Map.get(assigns.edits, "PHX_NEW_VERSION", assigns.f.value)
    list = if is_list(assigns.installers), do: assigns.installers, else: []
    # Newest requirement first; the releases inside a group are already
    # newest first, which is the order hex answered in.
    groups =
      list
      |> Enum.group_by(&(&1["elixir"] || "no elixir declared"))
      |> Enum.sort_by(fn {requirement, _} -> version_key(requirement) end, :desc)

    # A version config.conf names that hex has not got. This is not the
    # console holding a second opinion — it is set membership in the very
    # list hex just handed over, the same question `check_phx_new_exists`
    # asks before `new` builds anything. Until the button is pressed
    # there is no list and nothing is claimed.
    known = Enum.any?(list, &(&1["version"] == cur))
    stray = cur not in [nil, ""] and list != [] and not known
    assigns = assign(assigns, cur: cur, list: list, groups: groups, known: known, stray: stray)

    ~H"""
    <div class={["row", Map.has_key?(@edits, "PHX_NEW_VERSION") && "changed"]}>
      <label for="cfg-PHX_NEW_VERSION">PHX_NEW_VERSION<.chip class="new">new</.chip></label>
      <div class="stackline">
        <div class="fetch">
          <select id="cfg-PHX_NEW_VERSION" name="cfg[PHX_NEW_VERSION]">
            <option value="" selected={@cur in [nil, ""]}>
              — the newest that runs on this stack
            </option>
            <option :if={@cur not in [nil, ""] and !@known} value={@cur} selected>{@cur}</option>
            <optgroup :for={{requirement, releases} <- @groups} label={"needs elixir #{requirement}"}>
              <option :for={r <- releases} value={r["version"]} selected={r["version"] == @cur}>
                {r["version"]}
              </option>
            </optgroup>
          </select>
          <button
            class="go"
            type="button"
            phx-click="installers_ask"
            disabled={@asking}
            aria-busy={to_string(@asking)}
            aria-controls="cfg-PHX_NEW_VERSION"
            title={
              if @asking,
                do: "asking hex…",
                else:
                  "ask hex for the phx_new releases — one call for the list and one per release, under a second"
            }
          >
            <svg viewBox="0 0 24 24" aria-hidden="true"><path
              d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="2.2"
              stroke-linecap="round"
              stroke-linejoin="round"
            /></svg>
            <span class="sr">Ask hex for the phx_new releases</span>
          </button>
        </div>
        <.chip
          :if={@stray}
          class="bad"
          title={"hex has no phx_new #{@cur}: 'new' refuses before it builds anything (check_phx_new_exists)"}
        >
          not on hex
        </.chip>
        <.chip
          :if={@elixir}
          class="off"
          title="the Elixir config.conf names, which is what every group above is asking for"
        >
          this stack: elixir {@elixir}
        </.chip>
      </div>
      <p class="help">
        <.prose text={@f.help} />
        <.prose text=" Every release is at https://hex.pm/packages/phx_new/versions." />
        <span :if={@error} class="bad">hex did not answer: {@error}</span>
        <span :if={!@error and @list == [] and !@asking}>The releases are not here yet — the console asks hex only when you press the button.</span>
      </p>
    </div>
    """
  end

  # A line of config.conf as a page reads it: its addresses are links and
  # the rest is what it says. The file is the workbench's own, but the
  # text still travels escaped — every part of it is interpolated, never
  # raw — so a URL that is not one cannot become markup.
  attr :text, :string, required: true

  defp prose(assigns) do
    assigns = assign(assigns, parts: Console.Config.linkify(assigns.text))

    ~H"""
    <%= for part <- @parts do %>
      <a :if={is_tuple(part)} href={elem(part, 0)} target="_blank" rel="noopener noreferrer">
        {elem(part, 1)}
      </a>
      {if is_binary(part), do: part}
    <% end %>
    """
  end

  @doc """
  A field's values, newest first. Each field carries its own order: the
  tag list arrives sorted by the whole tag — `sort -urV` on
  `ELIXIR-erlang-OTP-debian-DEBIAN` — so Elixir comes out descending by
  the luck of being first in the string, and the other two came out in
  order of first appearance. Erlang read `27.0.1, 29.0.4, 26.2.5.21`,
  and Debian was not sorted at all.
  """
  def in_order(values, :d), do: Enum.sort_by(values, &debian_key/1, :desc)
  def in_order(values, _), do: Enum.sort_by(values, &version_key/1, :desc)

  # A dotted version of any length, compared number by number: 28.5.0.6
  # over 28.4.3, and 28.1 under 28.1.1, which is what a list that is a
  # prefix of another already means to Elixir. A part that is not a
  # number keeps its place rather than raising — config.conf can name
  # anything, and the field must still draw.
  defp version_key(v) do
    for part <- String.split(v, ".") do
      case Integer.parse(part) do
        {n, ""} -> n
        _ -> part
      end
    end
  end

  # Debian's own name says nothing about how new it is — bookworm came
  # after bullseye, and the alphabet disagrees — but the snapshot date
  # in the tag does, and it is the same date across the codenames of one
  # day. So: the date, and then the name, in one key. The name's order is
  # the alphabet's and claims nothing; the date is what means something.
  defp debian_key(v) do
    date = Regex.run(~r/-(\d{6,8})(?:-|$)/, v)
    {(date && Enum.at(date, 1)) || "", v}
  end

  defp combines?([], _, _, _), do: true

  defp combines?(list, part, v, cur),
    do:
      Enum.any?(list, fn x ->
        x[part] == v and Enum.all?([:e, :o, :d] -- [part], &(x[&1] == cur[&1]))
      end)

  # --- Console: the frame and the ground, kept in this browser -------------------

  defp ui(assigns) do
    ~H"""
    <div class="ui" id="wb-ui" phx-hook="Frame" phx-update="ignore">
      <p class="lede">
        How this console is arranged, the ground it is read on, and the face its code is set in. Kept in this browser, not in <code>config.conf</code>: it is what you are looking at, not what the workbench builds.
      </p>
      <div class="row">
        <button
          class="frame"
          type="button"
          data-frame="band-bottom"
          data-axis="band"
          aria-label="The band: top or bottom"
        ></button><b>The band</b><p class="help" data-help="band-bottom"></p>
      </div>
      <div class="row">
        <button
          class="frame"
          type="button"
          data-frame="rail-right"
          data-axis="rail"
          aria-label="The rail: left or right"
        ></button><b>The rail's side</b><p class="help" data-help="rail-right"></p>
      </div>
      <div class="row">
        <button
          class="frame"
          type="button"
          data-frame="rail-off"
          data-axis="off"
          aria-label="The rail: shown or hidden"
        ></button><b>The rail</b><p class="help" data-help="rail-off"></p>
      </div>
      <div class="row">
        <button class="ground" type="button" id="theme" aria-label="The ground: light or dark">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle
            cx="12"
            cy="12"
            r="9"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          /><path d="M12 3a9 9 0 010 18z" fill="currentColor" /></svg>
        </button>
        <b>The ground</b><p class="help" id="help-theme"></p>
      </div>
      <div class="row">
        <span class="glyph" aria-hidden="true">Aa</span>
        <b>The code</b>
        <p class="help">
          What runs: the terminals, the jobs' output, the logs, Docker's events.
          <span id="help-code"></span>
        </p>
        <p class="help picks">
          <label>face <select id="code-face" aria-label="The code face"></select></label><label>size
          <select id="code-size" aria-label="The code size"></select></label><label>leading
          <select id="code-leading" aria-label="The code leading, as a ratio of the size"></select></label>
        </p>
        <%!-- The sample is set in the same properties the surfaces read,
              so it changes with the selects and nothing has to repaint it:
              a log line with a bold name, a line of code with the pairs a
              face can confuse, and the glyphs ligatures like to join. --%>
        <pre class="sample" aria-label="A sample in the chosen face and size"><span class="dim">app-1  | 02:04:44.962 [info] Running <b>GalacticArcadeWeb.Endpoint</b> with Bandit 1.12.5 at :::4000 (http)</span>
    &#123;:ok, pid&#125; = Task.start(fn -&gt; Repo.all(from u in User, where: u.age &gt;= 18) end)
    0O 1lI| ~r/[a-z]+/ != &lt;= -&gt; |&gt; =&gt; &amp;&amp; :: "quoted" 'single' `tick`</pre>
      </div>
      <div class="row">
        <span class="glyph files" aria-hidden="true">Aa</span>
        <b>The files</b>
        <p class="help">
          What is read: the Files sheet, the diffs, <code>.env</code>
          and <code>config.conf</code>, the papers' code blocks. <span id="help-file"></span>
        </p>
        <p class="help picks">
          <label>face <select id="file-face" aria-label="The files' face"></select></label><label>size
          <select id="file-size" aria-label="The files' size"></select></label><label>leading
          <select id="file-leading" aria-label="The files' leading, as a ratio of the size"></select></label>
        </p>
        <pre class="sample files" aria-label="A sample in the chosen face and size"><span class="dim">@@ -12,7 +12,8 @@ defmodule GalacticArcadeWeb.Router do</span>
       pipe_through :browser
    <span class="del">-    get "/", PageController, :home</span>
    <span class="add">+    get "/", PageController, :home, as: :root</span>
    <span class="add">+    get "/about", PageController, :about</span>
       live "/rooms/:id", RoomLive, :show</pre>
      </div>
      <div class="row colours">
        <span class="glyph files" aria-hidden="true">#</span>
        <b>The colours</b>
        <p class="help">
          What a file's tokens are set in, on the Files sheet: the rules of <code>console/elixir_color_theme.jsonc</code>, One Dark as VS Code reads
          it and One Light on the light ground, a palette a ground and a language — Elixir, HTML and its templates, CSS, TypeScript and JavaScript, JSON, Markdown, Godot.
          This one is <span id="colours-ground"></span>.
        </p>
        <p class="help picks">
          <label>language
          <select id="colours-lang" aria-label="The language whose colours these are"></select></label>
        </p>
        <p class="swatches" id="swatches" aria-label="The colours"></p>
        <pre
          :for={lang <- Console.Highlight.languages()}
          class="sample src"
          data-lang={lang}
          hidden={lang != :elixir}
          aria-label={"A sample of #{lang} in the chosen colours"}
        >{Phoenix.HTML.raw(Console.Highlight.sample(lang))}</pre>
        <div class="jsonc">
          <textarea
            id="jsonc"
            aria-label="A VS Code colour theme, as jsonc"
            placeholder={
              ~s(Paste a VS Code jsonc here — editor.tokenColorCustomizations with its textMateRules, or a theme's tokenColors — and apply it; or read this palette back as one.)
            }
            spellcheck="false"
          ></textarea>
          <p class="acts">
            <button class="btn" type="button" id="jsonc-apply">Apply the jsonc</button>
            <button class="btn" type="button" id="jsonc-show">Read mine as jsonc</button>
            <button class="btn" type="button" id="jsonc-reset">Back to the house's</button>
            <span class="word" id="jsonc-word"></span>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
