defmodule ConsoleWeb.WorkbenchDrawer do
  @moduledoc """
  The workbench's own drawer: config.conf as the form it already is,
  its manual, its changelog, and Interface — how this page is arranged
  and what it is set in, kept in the browser. The values of the form are saved through
  `wb.sh config set`, as a job.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Card, only: [card: 1]
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  import ConsoleWeb.Square, only: [square: 1, mark: 1, logo: 1]

  # The drawer's top row is categories, the way the cartridge's is: what
  # the workbench is set by, what this browser is set by, and what the
  # workbench has written about itself. The papers are a group under
  # Manual — README and CHANGELOG — exactly as a box's three are, so the
  # two drawers are read the same way and the file names live where they
  # are all files.
  #
  # In that order: the two you set, then the one you read — the box's
  # drawer reads before it installs, and has Manual second. And the
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
    "NODE_VERSION" => "new",
    "GIT_IDENTITY" => "every commit",
    "JOB_NICENESS" => "every compile",
    "NGINX_IMAGE_VERSION" => "scaled deploy"
  }
  # A service's image tag, whichever service: `NAME_IMAGE_VERSION` is
  # handed to the bake as `--version name=TAG` (wb.sh version_flags),
  # and the cartridge that brings `name` takes it.
  defp effect(key) do
    cond do
      Map.has_key?(@effect, key) -> @effect[key]
      String.ends_with?(key, "_IMAGE_VERSION") -> "every bake"
      true -> "new"
    end
  end

  @stack_parts [
    {"ELIXIR_VERSION", :e, "the Elixir of the image"},
    {"ERLANG_VERSION", :o, "the Erlang/OTP of the image"},
    {"DEBIAN_VERSION", :d, "the Debian base of the image"}
  ]

  def tabs, do: @tabs

  # The Interface tab's parts, in the ribbon's order: the key the URL
  # names (`?wb=ui&part=`), the label, and — for a part not built yet —
  # why it is unlit. The ribbon across the pane under the drawer's own,
  # as a box's papers sit under a screen's tabs, settled on 2026-09-29;
  # its parts settled on 2026-09-30 (console/la-estanteria-a-la-vista.html):
  # Terminal and Code are the two themes, one a surface, each with its
  # shelf; Text — the pages' own type — is retired for now, the rest of
  # the interface not being offered to customise yet.
  @parts [
    {"overlay", "Overlay", nil},
    {"terminal", "Terminal", nil},
    {"code", "Code", nil},
    {"credits", "Credits", nil}
  ]

  def parts, do: @parts

  # Every face the console draws with, for the Credits part: whose it
  # is, where it lives, under which licence, and what it draws. The
  # three the pages are set in come from Google Fonts as the page
  # loads (root.html.heex); the three the terminal and the files can
  # be set in travel with the console, each licence beside its files
  # (priv/static/assets/fonts/, its README). This is the one place the
  # console credits them: the notes under the face selectors say what
  # a face does, not whose it is. Each is a card whose head is the
  # name set in the face itself, at a body that shows it (`spec`):
  # settled on 2026-09-29 among the list, the card and a ficha with
  # the accent edge, on the real part. A theme's credit is its file's
  # `dew.theme`, and shows where the theme is chosen, not here.
  @faces [
    %{
      name: "Barlow Condensed",
      spec: "font-family:var(--cond);font-size:22px;font-weight:700",
      by: "Jeremy Tribby",
      at: "https://github.com/jpt/barlow",
      licence: "SIL Open Font License 1.1",
      draws:
        "The display: the band's lettering, the tabs, the labels, the headings. From Google Fonts."
    },
    %{
      name: "Source Serif 4",
      spec: "font-family:var(--serif);font-size:21px;font-weight:400",
      by: "Frank Grießhammer, for Adobe",
      at: "https://github.com/adobe-fonts/source-serif",
      licence: "SIL Open Font License 1.1",
      draws:
        "The text: the prose, the papers, the hints, the backs of the boxes. From Google Fonts."
    },
    %{
      name: "IBM Plex Mono",
      spec: "font-family:var(--mono);font-size:18px;font-weight:500",
      by: "Mike Abbink and Bold Monday, for IBM",
      at: "https://github.com/IBM/plex",
      licence: "SIL Open Font License 1.1",
      draws:
        "The mono: commands, logs, ports, paths, chips; a face the terminal and the files can take. From Google Fonts."
    },
    %{
      name: "Fira Code",
      spec: "font-family:'Fira Code';font-size:18px;font-weight:400",
      by: "Nikita Prokopov and the Fira Code Project Authors",
      at: "https://github.com/tonsky/FiraCode",
      licence: "SIL Open Font License 1.1",
      draws:
        "The house's face for the files, ligatures on; one the terminal can take. Carried by the console."
    },
    %{
      name: "Flexi IBM VGA",
      spec: "font-family:'Flexi IBM VGA True';font-size:24px;font-weight:400",
      by: "VileR, The Ultimate Oldschool PC Font Pack",
      at: "https://int10h.org/oldschool-pc-fonts/",
      licence: "CC BY-SA 4.0",
      draws:
        "The PC's text mode, a bitmap, for the terminal and the files. Carried by the console, as the pack ships it."
    },
    %{
      name: "Tamzen",
      spec: "font-family:'Tamzen10x20';font-size:20px;font-weight:700",
      by: "Suraj N. Kurapati, after Tamsyn by Scott Fial",
      at: "https://github.com/sunaku/tamzen-font",
      licence: "Tamsyn's: free to use, copy, modify and distribute",
      draws:
        "The house's face for the terminal, a bitmap, one drawing a size; one the files can take. Carried by the console."
    }
  ]

  @doc "The keys of the parts that are built: what `?part=` may name."
  def part_keys, do: for({key, _, nil} <- @parts, do: key)

  attr :tab, :string, required: true, doc: "the screen under the drawer"

  attr :back, :string,
    default: nil,
    doc: "the screen's own place, where Close goes; the bare tab when not given"

  attr :wb, :string, required: true
  attr :paper, :string, default: "readme", doc: "which of the workbench's papers, under Manual"
  attr :part, :string, default: "overlay", doc: "which part of the Interface tab"
  attr :themes, :list, default: [], doc: "the themes on both shelves (Console.Themes)"

  attr :theme_files, :boolean,
    default: false,
    doc: "Download Current and Load Custom, drawn in dev alone (config :console, :theme_files)"

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
  attr :nodes, :any, default: nil
  attr :nodes_asking, :boolean, default: false
  attr :nodes_error, :string, default: nil
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
        <.link class="btn" patch={@back || "/#{@tab}"}>Close</.link>
        <.ribbon
          label="The workbench: what sets it, what draws it, what it says"
          selected={@wb}
          items={
            for {key, label} <- tabs(),
                do: %{
                  key: key,
                  label: label,
                  href:
                    ConsoleWeb.Refs.over(
                      @back || "/#{@tab}",
                      "wb=#{key}" <>
                        case key do
                          "manual" -> "&paper=#{@paper}"
                          "ui" -> "&part=#{@part}"
                          _ -> ""
                        end
                    )
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
        nodes={@nodes}
        nodes_asking={@nodes_asking}
        nodes_error={@nodes_error}
        jobs={@jobs}
      />
      <div :if={@wb == "manual"} class="papers">
        <.ribbon
          label="The workbench's own papers"
          selected={@paper}
          docked
          items={
            for {key, label, file} <- Console.Papers.workbench_papers(),
                do: %{
                  key: key,
                  label: label,
                  small: file,
                  href: ConsoleWeb.Refs.over(@back || "/#{@tab}", "wb=manual&paper=#{key}")
                }
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
      <.ui
        :if={@wb == "ui"}
        part={@part}
        back={@back || "/#{@tab}"}
        themes={@themes}
        theme_files={@theme_files}
      />
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
        <pre :if={@raw} class="raw term-box"><%= for line <- String.split(raw_text(@config, @edits), "\n") do %><.raw_line line={line} /><% end %></pre>
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
                <.node_row
                  :if={f.key == "NODE_VERSION"}
                  f={f}
                  edits={@edits}
                  nodes={@nodes}
                  asking={@nodes_asking}
                  error={@nodes_error}
                />
                <.field
                  :if={
                    f.key not in [
                      "ELIXIR_VERSION",
                      "ERLANG_VERSION",
                      "DEBIAN_VERSION",
                      "NODE_VERSION",
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
    effect = effect(f.key)

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
          <.square
            mark="reload"
            label="Ask Docker Hub for the usable images"
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
          />
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
          <.square
            mark="reload"
            label="Ask hex for the phx_new releases"
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
          />
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
        <.prose text={@f.help} /> Every release is at <.pkg_ref name="phx_new" path="versions" />.
        <span :if={@error} class="bad">hex did not answer: {@error}</span>
        <span :if={!@error and @list == [] and !@asking}>The releases are not here yet — the console asks hex only when you press the button.</span>
      </p>
    </div>
    """
  end

  # The Node row: the majors Node's own release schedule has released,
  # grouped by where each stands today — the LTS line first, since that
  # is the one to name — and whether NodeSource, where both images take
  # Node from, has a repository for it. Read in this BEAM
  # (`Console.Nodes`) when the button is pressed, like the installers.
  # A major NodeSource has not got is listed and unlit, never hidden:
  # the build would stop at apt, and the option says so.
  attr :f, :map, required: true
  attr :edits, :map, required: true
  attr :nodes, :any, default: nil
  attr :asking, :boolean, default: false
  attr :error, :string, default: nil

  defp node_row(assigns) do
    cur = Map.get(assigns.edits, "NODE_VERSION", assigns.f.value)
    list = if is_list(assigns.nodes), do: assigns.nodes, else: []

    groups =
      list
      |> Enum.group_by(&node_group/1)
      |> Enum.sort_by(fn {{rank, _}, _} -> rank end)
      |> Enum.map(fn {{_, label}, majors} -> {label, majors} end)

    # The major config.conf names, in the list NodeSource and the
    # schedule just answered. Set membership, not an opinion; until the
    # button is pressed there is no list and nothing is claimed.
    known = Enum.find(list, &(&1["major"] == cur))
    stray = cur not in [nil, ""] and list != [] and (known == nil or not known["nodesource"])

    assigns =
      assign(assigns, cur: cur, list: list, groups: groups, known: known, stray: stray)

    ~H"""
    <div class={["row", Map.has_key?(@edits, "NODE_VERSION") && "changed"]}>
      <label for="cfg-NODE_VERSION">NODE_VERSION<.chip class="new">new</.chip></label>
      <div class="stackline">
        <div class="fetch">
          <select id="cfg-NODE_VERSION" name="cfg[NODE_VERSION]">
            <option :if={@cur not in [nil, ""] and !@known} value={@cur} selected>{@cur}</option>
            <optgroup :for={{label, majors} <- @groups} label={label}>
              <option
                :for={m <- majors}
                value={m["major"]}
                selected={m["major"] == @cur}
                disabled={!m["nodesource"]}
              >
                {node_option(m)}
              </option>
            </optgroup>
          </select>
          <.square
            mark="reload"
            label="Ask Node and NodeSource for the majors"
            phx-click="nodes_ask"
            disabled={@asking}
            aria-busy={to_string(@asking)}
            aria-controls="cfg-NODE_VERSION"
            title={
              if @asking,
                do: "asking…",
                else:
                  "ask for the Node majors — the schedule from nodejs/Release, and one call per major to NodeSource, under a second"
            }
          />
        </div>
        <.chip
          :if={@stray and @known != nil}
          class="bad"
          title={"NodeSource has no node_#{@cur}.x repository: the images' build stops at apt"}
        >
          not on NodeSource
        </.chip>
        <.chip
          :if={@stray and @known == nil}
          class="bad"
          title={"Node's schedule has no major #{@cur}"}
        >
          no such major
        </.chip>
        <.chip
          :if={@known != nil and @known["nodesource"]}
          class="off"
          title="where this major stands in Node's release schedule today"
        >
          {node_standing(@known)}
        </.chip>
      </div>
      <p class="help">
        <.prose text={@f.help} />
        Every line is at https://nodejs.org/en/about/previous-releases and what NodeSource carries at https://github.com/nodesource/distributions.
        <span :if={@error} class="bad">not answered: {@error}</span>
        <span :if={!@error and @list == [] and !@asking}>The majors are not here yet — the console asks only when you press the button.</span>
      </p>
    </div>
    """
  end

  # Where a major stands, as the select groups it; the rank is the order
  # of the groups, the line to name first.
  defp node_group(%{"state" => "lts"}), do: {0, "LTS, active"}
  defp node_group(%{"state" => "current", "lts" => true}), do: {1, "current, LTS to come"}
  defp node_group(%{"state" => "current"}), do: {2, "current, never LTS"}
  defp node_group(%{"state" => "maintenance", "lts" => true}), do: {3, "LTS, maintenance"}
  defp node_group(%{"state" => "maintenance"}), do: {4, "maintenance"}
  defp node_group(_), do: {5, "end of life"}

  defp node_option(m) do
    "#{m["major"]}" <>
      if(m["codename"], do: " · #{m["codename"]}", else: "") <>
      if(m["until"], do: " — until #{m["until"]}", else: "") <>
      if(m["nodesource"], do: "", else: " (not on NodeSource)")
  end

  defp node_standing(%{"state" => "end of life", "until" => until}),
    do: "end of life since #{until}"

  defp node_standing(%{"state" => state, "until" => until}) when is_binary(until),
    do: "#{state} · until #{until}"

  defp node_standing(%{"state" => state}), do: state

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

  # --- Interface: the controls on the left, the console in miniature on the right ---
  # The controls are parts under a ribbon (`parts/0`), one in view at a
  # time — Overlay (the frame, the ground, and the theme: the whole as
  # one file, chosen off the shelf, downloaded or loaded), Text (the
  # pages' own three faces and the scale of the whole), Terminal (its
  # face, and its ground, ink, dim and the six ANSI), Files (the files'
  # face, the syntax palette and the diff's four), Credits (every face
  # and every theme, whose they are) — and the part is in the URL, so a
  # tab pressed leads back to it. They
  # folded in three from 2026-09-15 to 2026-09-29, the fold kept in the
  # browser: a column 3.5 screens tall until the reader folded two. The
  # pane is `phx-update="ignore"` (the hook owns its controls), so the
  # part is an attribute on it, `data-part`, that the ribbon's patch
  # changes and console.css reads: which part shows, and which surface
  # of the miniature lights up as the one being set.
  # Everything here is kept in this browser: the frame as classes on
  # <body> (band-bottom, rail-right, rail-off), the ground as data-theme
  # on the root, the faces and the colours as custom properties on the
  # root — hooks.js Frame reads and writes them. The miniature on the
  # right is a fifth of the console drawn from those same classes and
  # properties, so what is set on the left lands on the right where it
  # will land on the screen: the band moves, the rail changes side, the
  # terminal is set in the code face, the sheet in the files' face and
  # the language's colours. That is Overlay's miniature; a theme's part
  # shows its surface alone, the terminal or the file, with no band, no
  # rail and no tabs around it (2026-10-01, console.css). Its terminal is real lines — a warning of
  # Elixir's compiler as a terminal colours it, a Phoenix boot, a
  # request, an error of Bandit's, all off logs of 2026-09-11 — and its
  # sheet is the Files sheet's own drawing of the tab's sample with one
  # line changed, a removal and an addition, so its colours show. Decided
  # on 2026-09-12 among four compositions on the real content: the one
  # that shows the most, at the cost of a second drawing of the frame
  # that has to follow the first. The one before was a column of seven
  # rows, 1647px in a pane of 695.
  @sheet_paths %{
    elixir: "lib/arcade/room.ex",
    html: "lib/arcade_web/live/room_live.html.heex",
    css: "assets/css/app.css",
    ts: "assets/js/app.ts",
    json: "priv/static/manifest.json",
    markdown: "README.md",
    godot: "scripts/player.gd",
    shell: "bin/room.sh",
    other: "config/room.toml"
  }
  # The miniature's terminal: {service, level, cont?, time, html}. The
  # times are the lines' own, as the Logs screen formats them; the
  # services are the compose project's, and each line wears its colour
  # the way the Logs screen gives it (hooks.js svcColor: the six named
  # ones, and the network's for any other). The ANSI is each tool's own,
  # so the theme's sixteen are seen on what they colour (2026-10-01):
  # Logger paints a line by its level (debug cyan, warning yellow, error
  # red; info none), the compiler its `warning:` yellow, `dbg` a value
  # in IO.ANSI.syntax_colors/0 (atoms cyan, numbers yellow, strings
  # green, booleans and nil magenta, a variable light cyan), and ExUnit
  # its dots green, a failure red, a skip yellow, the `code:`, `left:`
  # and `right:` labels cyan, the diff's deletions red and insertions
  # green, and the count red when a test failed. What tools colour
  # leaves colours out — blue, magenta, most of the brights — so the
  # last lines are a service of the miniature's own, `color`: the
  # sixteen as a scale, a line the eight and a line their brights.
  #
  # The scale: black to white through the hues in the spectrum's order
  # (red, yellow, green, cyan, blue, magenta). Each colour comes up
  # over the one before it — `░▒▓█`, its own on the other's ground, so
  # a shade is the two mixed — the first over the terminal's ground,
  # and the last goes down to it again, `▓▒░`. It is written as a
  # terminal would be sent it and read by Console.ANSI, backgrounds and
  # all, so the line is what a tool printing it would leave here. It is
  # set in Fira Code at the size that gives its characters the cell of
  # the face in force (console.css, .scale): Tamzen, the terminal's
  # own, has no block characters, and a browser's stand-in is wider
  # than the cell.
  @scale_order [0, 1, 3, 2, 6, 4, 5, 7]
  @scales (for row <- [0, 8] do
             sgr = fn base, n -> if n < 8, do: base + n, else: base + 60 + n - 8 end

             {cells, _} =
               Enum.map_reduce(@scale_order, nil, fn n, before ->
                 n = n + row
                 ground = if before, do: ";#{sgr.(40, before)}", else: ""
                 {"\e[#{sgr.(30, n)}#{ground}m░▒▓█", n}
               end)

             ~s(<span class="scale">#{Console.ANSI.to_html(Enum.join(cells) <> "\e[49m▓▒░\e[0m")}</span>)
           end)
  @log_lines [
    {"database", "info", false, "11:04:38.442",
     "UTC [1] LOG:  database system is ready to accept connections"},
    {"pgadmin", "info", false, "11:04:38.687",
     "postfix/postlog: starting the Postfix mail system"},
    {"app", "warn", false, "21:16:30.416",
     ~s(<span class="ansi-fg-3">warning:</span> variable "valid?" is unused \(if the variable is not meant to be used, prefix it with an underscore\))},
    {"app", "warn", true, "21:16:30.416", "  3 │     valid? = length(room.players) &lt; 8"},
    {"app", "warn", true, "21:16:30.416", ~s(    │ <span class="ansi-fg-3">    ~~~~~~</span>)},
    {"app", "warn", true, "21:16:30.416", "    └─ lib/arcade/room.ex:3:5: Arcade.Room.join/2"},
    {"app", "info", false, "17:00:49.002",
     "[info] Running ConsoleWeb.Endpoint with Bandit 1.12.5 at 0.0.0.0:4000 (http)"},
    {"app", "info", false, "17:07:17.401", "[info] GET /deploy"},
    {"app", "debug", false, "17:07:17.409",
     ~s(<span class="ansi-fg-6">[debug] Processing with ConsoleWeb.ConsoleLive.__live__/0</span>)},
    {"app", "debug", false, "17:07:17.418",
     ~s(<span class="ansi-fg-6">[debug] QUERY OK source="rooms" db=1.2ms idle=1498.6ms</span>)},
    {"app", "debug", true, "17:07:17.418",
     ~s(<span class="ansi-fg-6">SELECT r0."id", r0."name", r0."max" FROM "rooms" AS r0 WHERE \(r0."id" = $1\) [12]</span>)},
    {"app", "info", false, "17:07:17.426", "[info] Sent 200 in 24ms"},
    {"app", "info", false, "17:09:02.550", "[lib/arcade/room.ex:9: Arcade.Room.join/2]"},
    {"app", "info", true, "17:09:02.550",
     ~s(<span class="ansi-fg-14">p</span> #=> %Arcade.Player{<span class="ansi-fg-6">age:</span> <span class="ansi-fg-3">7</span>, <span class="ansi-fg-6">late?:</span> <span class="ansi-fg-5">true</span>, <span class="ansi-fg-6">name:</span> <span class="ansi-fg-2">"ana"</span>, <span class="ansi-fg-6">seat:</span> <span class="ansi-fg-5">nil</span>})},
    {"app", "warn", false, "17:10:40.093",
     ~s(<span class="ansi-fg-3">[warning] Ignoring unmatched topic "room:9" in ArcadeWeb.UserSocket</span>)},
    {"app", "error", false, "17:52:13.680",
     ~s(<span class="ansi-fg-1">[error] ** \(Bandit.HTTPError\) Read timeout</span>)},
    {"app", "info", false, "18:03:11.204", "Running ExUnit with seed: 318221, max_cases: 16"},
    {"app", "info", false, "18:03:11.731",
     ~s(<span class="ansi-fg-2">...............</span><span class="ansi-fg-1">F</span><span class="ansi-fg-2">...</span><span class="ansi-fg-3">*</span><span class="ansi-fg-2">.</span>)},
    {"app", "info", false, "18:03:11.733",
     ~s(<span class="ansi-fg-1">  1\) test join/2 turns a late player away \(Arcade.RoomTest\)</span>)},
    {"app", "info", true, "18:03:11.733", "     test/arcade/room_test.exs:21"},
    {"app", "info", true, "18:03:11.733",
     ~s(     <span class="ansi-fg-1">Assertion with == failed</span>)},
    {"app", "info", true, "18:03:11.733",
     ~s(     <span class="ansi-fg-6">code:</span>  assert join\(room, late\) == {:error, :refused})},
    {"app", "info", true, "18:03:11.733",
     ~s(     <span class="ansi-fg-6">left:</span>  {<span class="ansi-fg-1">:ok</span>, <span class="ansi-fg-1">%Arcade.Room{players: [...]}</span>})},
    {"app", "info", true, "18:03:11.733",
     ~s(     <span class="ansi-fg-6">right:</span> {<span class="ansi-fg-2">:error</span>, <span class="ansi-fg-2">:refused</span>})},
    {"app", "info", false, "18:03:11.902", "Finished in 0.4 seconds (0.2s async, 0.2s sync)"},
    {"app", "info", false, "18:03:11.902",
     ~s(<span class="ansi-fg-1">20 tests, 1 failure, 1 skipped</span>)},
    {"app", "info", true, "18:03:11.902", "Randomized with seed 318221"},
    {"color", "info", false, "18:04:02.118", Enum.at(@scales, 0)},
    {"color", "info", true, "18:04:02.118", Enum.at(@scales, 1)}
  ]
  # The sample's services, by the role each would say: the preview is
  # coloured as the logs are, by role (ConsoleWeb.Services).
  @sample_roles %{
    "app" => "compute",
    "database" => "database",
    "pgadmin" => "devtools",
    "balancer" => "balancer",
    "migrate" => "job",
    # The scale's own, in the job's violet: no role is a demo's.
    "color" => "job"
  }

  # The digits of a line number, as ConsoleWeb.Box counts them for the sheet.
  defp digits(nil), do: 0
  defp digits(n), do: n |> Integer.digits() |> length()

  # The colour a service's lines wear: hooks.js svcColor, on the server.
  defp svc_var(service) do
    base = String.replace(service, ~r/\d+$/, "")
    "--svc:var(--svc-#{Map.get(@sample_roles, base, "network")})"
  end

  attr :part, :string, required: true
  attr :back, :string, required: true
  attr :themes, :list, required: true
  attr :theme_files, :boolean, required: true

  # The languages the Files sheet colours, as the Language Syntax select
  # names them, short: the long name (Elixir and its templates) is the
  # option's title.
  @lang_names %{
    elixir: {"Elixir", "Elixir and its templates"},
    html: {"HTML", "HTML and its templates"},
    css: {"CSS", "CSS and SCSS"},
    ts: {"TypeScript", "TypeScript and JavaScript"},
    json: {"JSON", "JSON"},
    markdown: {"Markdown", "Markdown"},
    godot: {"Godot", "Godot: GDScript, shaders, scenes"},
    shell: {"Shell", "Shell"},
    other: {"Other", "A file with no language: read in the sheet's foreground"}
  }

  defp ui(assigns) do
    services = @log_lines |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

    assigns =
      assign(assigns,
        sheet_paths: @sheet_paths,
        log_lines: @log_lines,
        services: services,
        faces: @faces,
        lang_names: @lang_names,
        terminal: Enum.filter(assigns.themes, &(&1.kind == :terminal)),
        code: Enum.filter(assigns.themes, &(&1.kind == :code)),
        # What the hook needs of a theme, as JSON in the pane: its shelf, its key and its file.
        themes_json:
          Jason.encode!(for(t <- assigns.themes, do: %{key: t.key, kind: t.kind, json: t.json}),
            escape: :html_safe
          )
      )

    ~H"""
    <div class="uipane">
      <.ribbon
        label="The interface: its parts"
        selected={@part}
        docked
        items={
          for {key, label, why} <- parts(),
              do: %{
                key: key,
                label: label,
                why: why,
                href: ConsoleWeb.Refs.over(@back, "wb=ui&part=#{key}")
              }
        }
      />
      <div class="ui" id="wb-ui" phx-hook="Frame" phx-update="ignore" data-part={@part}>
        <div class="ctl">
          <div class="part" data-part="overlay">
            <section class="group sets">
              <.fold_head title="The frame" />
              <%!-- The band and the rail, a card a position as the ground's
                  and the themes' are: the thumbnail is the frame the card
                  would set, in the ground in force (hooks.js Frame paints
                  it), and the pressed one is the frame in force. --%>
              <div class="set">
                <h6>The band</h6>
                <div
                  class="cards"
                  role="group"
                  aria-label="The band: on top or at the bottom"
                  data-axis="band"
                >
                  <button type="button" class="swatch" data-pick="top" aria-pressed="false">
                    <.frame_thumb />Top
                  </button>
                  <button type="button" class="swatch" data-pick="bottom" aria-pressed="false">
                    <.frame_thumb />Bottom
                  </button>
                </div>
              </div>
              <div class="set">
                <h6>The rail</h6>
                <div
                  class="cards"
                  role="group"
                  aria-label="The rail: on the left, on the right, or hidden"
                  data-axis="rail"
                >
                  <button type="button" class="swatch" data-pick="left" aria-pressed="false">
                    <.frame_thumb />Left
                  </button>
                  <button type="button" class="swatch" data-pick="right" aria-pressed="false">
                    <.frame_thumb />Right
                  </button>
                  <button type="button" class="swatch" data-pick="hidden" aria-pressed="false">
                    <.frame_thumb />Hidden
                  </button>
                </div>
              </div>
            </section>
            <section class="group">
              <.fold_head title="The ground" />
              <div
                class="cards"
                role="group"
                aria-label="The ground: light, dark, or whatever this machine says"
              >
                <button type="button" class="swatch" data-ground="light" aria-pressed="false">
                  <span class="thumb light"><i class="b"></i><i class="rl"></i><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="tm"></i></span>Light
                </button>
                <button type="button" class="swatch" data-ground="dark" aria-pressed="false">
                  <span class="thumb dark"><i class="b"></i><i class="rl"></i><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="tm"></i></span>Dark
                </button>
                <button
                  type="button"
                  class="swatch"
                  data-ground="system"
                  aria-pressed="false"
                  title="Whatever this machine says"
                >
                  <span class="thumb system"><span class="thumb light"><i class="b"></i><i class="rl"></i><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="tm"></i></span><span class="thumb dark"><i class="b"></i><i class="rl"></i><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="tm"></i></span></span>System
                </button>
              </div>
            </section>
          </div>
          <.theme_part kind="terminal" themes={@terminal} theme_files={@theme_files}>
            <:font>
              <div class="set">
                <h6>Font</h6>
                <div class="picks">
                  <label>face <select id="code-face" aria-label="The code face"></select></label>
                  <p class="hint help" id="help-code"></p>
                  <label>size <select id="code-size" aria-label="The code size"></select></label>
                  <label>leading
                  <select id="code-leading" aria-label="The code leading, as a ratio of the size"></select></label>
                </div>
              </div>
              <%!-- The terminal's opacity: the reader's, like the face, over any
                  theme — under 100 % the interface shows through its ground. --%>
              <div class="set">
                <h6>Opacity</h6>
                <div class="picks">
                  <div class="pick">
                    <span>ground</span>
                    <span class="slide">
                      <input
                        type="range"
                        id="term-alpha"
                        min="0"
                        max="100"
                        step="1"
                        value="40"
                        aria-label="The terminal ground's opacity, in percent"
                        title="Under 100 % the interface shows through the terminal's ground"
                      />
                      <input
                        type="number"
                        id="term-alpha-n"
                        min="0"
                        max="100"
                        step="1"
                        value="40"
                        aria-label="The terminal ground's opacity, as a number"
                      /><span class="unit">%</span>
                    </span>
                  </div>
                </div>
              </div>
            </:font>
            <div class="groups" id="term-swatches">
              <div class="set">
                <h6>The terminal</h6><div
                  class="roles"
                  data-term="term"
                  data-pairs="2"
                  aria-label="The terminal's colours"
                >
                </div>
              </div>
              <div class="set">
                <h6>ANSI</h6><div
                  class="roles"
                  data-term="ansi"
                  data-pairs="2"
                  aria-label="The sixteen ANSI colours, each beside its bright"
                >
                </div>
              </div>
              <div class="set">
                <h6>Highlights</h6><div
                  class="roles"
                  data-term="lines"
                  data-pairs="2"
                  aria-label="The highlights: the grounds a line wears"
                >
                </div>
              </div>
            </div>
          </.theme_part>
          <.theme_part kind="code" themes={@code} theme_files={@theme_files}>
            <:font>
              <div class="set">
                <h6>Font</h6>
                <div class="picks">
                  <label>face <select id="file-face" aria-label="The files' face"></select></label>
                  <p class="hint help" id="help-file"></p>
                  <label>size <select id="file-size" aria-label="The files' size"></select></label>
                  <label>leading
                  <select id="file-leading" aria-label="The files' leading, as a ratio of the size"></select></label>
                </div>
              </div>
              <%!-- The sheet's opacity: the reader's, like the terminal's, over
                  any theme — under 100 % the interface shows through its ground. --%>
              <div class="set">
                <h6>Opacity</h6>
                <div class="picks">
                  <div class="pick">
                    <span>ground</span>
                    <span class="slide">
                      <input
                        type="range"
                        id="sheet-alpha"
                        min="0"
                        max="100"
                        step="1"
                        value="40"
                        aria-label="The sheet ground's opacity, in percent"
                        title="Under 100 % the interface shows through the sheet's ground"
                      />
                      <input
                        type="number"
                        id="sheet-alpha-n"
                        min="0"
                        max="100"
                        step="1"
                        value="40"
                        aria-label="The sheet ground's opacity, as a number"
                      /><span class="unit">%</span>
                    </span>
                  </div>
                </div>
              </div>
            </:font>
            <div class="groups" id="sheet-swatches">
              <div class="set">
                <h6>Sheet</h6><div
                  class="roles"
                  data-sheet="sheet"
                  data-pairs="2"
                  aria-label="The sheet's colours: a line's background and foreground, and the line number's"
                >
                </div>
              </div>
            </div>
            <div class="groups" id="diff-swatches">
              <div class="set">
                <h6>Diff</h6><div
                  class="roles"
                  data-diff="diff"
                  data-pairs="2"
                  aria-label="The diff's colours: an added line's and a removed line's"
                >
                </div>
              </div>
            </div>
            <div class="set">
              <h6>Language Syntax</h6>
              <div class="picks">
                <label>
                  language
                  <select id="colours-lang" aria-label="The language whose colours these are">
                    <option
                      :for={lang <- Console.Highlight.samples()}
                      value={lang}
                      selected={lang == :elixir}
                      title={elem(@lang_names[lang], 1)}
                    >
                      {elem(@lang_names[lang], 0)}
                    </option>
                  </select>
                </label>
              </div>
              <div class="roles" id="swatches" data-pairs="2" aria-label="The colours"></div>
              <p class="hint" id="swatches-none" hidden>
                No palette: a file with no language is read in the sheet's foreground.
              </p>
            </div>
          </.theme_part>
          <div class="part" data-part="credits">
            <.credits_group
              title="Terminal themes"
              hint="The terminal themes on the shelf, console/themes/*.terminal.json, whose they are, and which is in force."
            >
              <.theme_credit :for={t <- @terminal} theme={t} />
            </.credits_group>
            <.credits_group
              title="Code themes"
              hint="The code themes on the shelf, console/themes/*.code.json, whose they are, and which is in force. Download yours from Terminal or Code and drop it there."
            >
              <.theme_credit :for={t <- @code} theme={t} />
            </.credits_group>
            <.credits_group
              title="Faces"
              hint="Every face the console draws with, whose it is and under which licence. Three come from Google Fonts as the page loads; three travel with the console, their licences beside them in priv/static/assets/fonts/."
            >
              <.card :for={f <- @faces} class="credit">
                <h3><span class="spec" style={f.spec}>{f.name}</span></h3>
                <p class="chips">
                  <span class="chip">{f.by}</span><span class="chip">{f.licence}</span>
                </p>
                <p class="site"><ConsoleWeb.Refs.site_ref url={f.at} name={f.name} /></p>
                <p class="hint">{f.draws}</p>
              </.card>
            </.credits_group>
          </div>
          <script type="application/json" id="themes">
            <%= Phoenix.HTML.raw(@themes_json) %>
          </script>
        </div>
        <div
          class="mini"
          id="mini"
          aria-label="The miniature: what is set on the left, as the console will draw it"
        >
          <%!-- The band, at a fifth: the mark, the name, the state, the
              clock and the two cells, drawn as the band draws them. The
              ground cell is a control, as the band's is: it switches
              the ground. --%>
          <div class="mband" title="The band — click to move it">
            <span class="mark"><.logo /><b>Dockerized Elixir Workbench</b></span>
            <span class="state"><i class="dot"></i>idle</span>
            <span class="right"><span class="clock">12:00</span><button
              type="button"
              class="mground"
              title="The ground — click to switch it"
              aria-label="Switch the ground"
            ><.mark name="ground" /></button><.mark name="workbench" /></span>
          </div>
          <div class="mrow">
            <div class="mrail" title="The rail — click to change its side">
              <span class="lbl">Workspace</span><i class="w"></i><i></i><i class="n"></i><i class="w"></i><i class="n"></i>
            </div>
            <div class="mmain">
              <div class="mtabs">
                <span class="tab">Deploy</span><span class="tab">Jobs</span><span
                  class="tab"
                  aria-selected="true"
                >Logs</span><span class="tab">Terminal</span><span class="tab">Project</span><span class="tab">Cartridges</span><span class="tab">Docker</span>
              </div>
              <%!-- The Logs screen's service chips, the markup its hook builds
                  (renderChips): pressed, the service's lines show. And its
                  Timestamps button, which folds the time column away. --%>
              <div class="toolbar" role="group" aria-label="The services whose lines show">
                <button
                  :for={s <- @services}
                  class="btn svc"
                  type="button"
                  data-svc={s}
                  aria-pressed="true"
                  style={svc_var(s)}
                >{s}</button>
                <span class="sep"></span>
                <button class="btn" type="button" data-ts aria-pressed="true">Timestamps</button>
              </div>
              <div
                class="lines term-box"
                aria-label="Lines of a log, as the Logs screen draws them"
                style={"--svc-w:#{@services |> Enum.map(&String.length/1) |> Enum.max()}ch"}
              >
                <div
                  :for={{service, level, cont, ts, html} <- @log_lines}
                  class={["ln", level, cont && "cont"]}
                  data-svc={service}
                  style={svc_var(service)}
                >
                  <span class="t">{ts}</span><span class="s">{service}</span><span class="m">{Phoenix.HTML.raw(
                    html
                  )}</span>
                </div>
              </div>
              <%!-- The Jobs screen's grip (.ograb), between the two panes:
                  drag, and the terminal takes the height the sheet gives up. --%>
              <div
                class="ograb"
                role="separator"
                aria-orientation="horizontal"
                tabindex="0"
                aria-label="How the screen is split between the terminal and the sheet — drag, or arrow keys; double-click for halves"
              >
              </div>
              <div class="impl" aria-label="A file, as the Files sheet draws it">
                <div class="files">
                  <div
                    :for={lang <- Console.Highlight.samples()}
                    class="f open sample"
                    data-lang={lang}
                    hidden={lang != :elixir}
                  >
                    <div class="fh">
                      <span class="ft"><span class="p">{@sheet_paths[lang]}</span></span>
                      <span class="n"><span class="a">+1</span><span class="r"> −1</span></span>
                    </div>
                    <pre
                      class="src"
                      data-lang={lang != :other && lang}
                      aria-label={"A sample of #{lang} in the chosen colours, one line changed"}
                      style={"--gut:#{Console.Diffs.gutter(Console.Highlight.sample_diff(lang))}ch"}
                    ><div class="rows"><div
                    :for={{cls, o, n, sign, html} <- Console.Highlight.sample_diff(lang)}
                    class={["dl", cls != :ctx && cls]}
                  ><span class="gut" style={"--d:#{digits(o)}"}>{o}</span><span class="gut" style={"--d:#{digits(n)}"}>{n}</span><span class="sg">{sign}</span><span class="cd">{Phoenix.HTML.raw(html)}</span></div></div></pre>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # A theme's part, Terminal or Code, under two heads as Overlay's are
  # (The frame, The ground): Style — what the reader chooses, the face,
  # the opacity and the theme — and Adjustments; each folds. The face first — Font, the
  # reader's, no theme's: a theme is colours — then the shelf, the group
  # "Color Themes", with the small square beside its name that switches
  # the ground (a theme has two, and the other is one press away), a
  # card a theme with the thumbnail the hook draws
  # from the file (the thumbnail is the preview: nothing is worn before
  # it is picked), and Custom, which the hook shows when something is
  # set on top and keeps there, put away, while another theme is worn
  # — then Download Current (what is worn, as a file) and Load Custom,
  # in dev alone, and Clear Custom, anyone's, there while there is a
  # Custom, as its card is;
  # then one fold, Adjustments, the house's fold head with the count of
  # what is yours, holding the part's colour groups. Settled 2026-09-30
  # (console/la-estanteria-a-la-vista.html), the face out of the theme
  # the same day.
  attr :kind, :string, required: true, values: ~w(terminal code)
  attr :themes, :list, required: true
  attr :theme_files, :boolean, required: true
  slot :font, required: true, doc: "the Font group: face, size and leading"
  slot :inner_block, required: true

  defp theme_part(assigns) do
    ~H"""
    <div class="part" data-part={@kind}>
      <section class="group sets">
        <.fold_head title="Style" />
        {render_slot(@font)}
        <section class="tshelf set">
          <h6>
            <span>Color Themes</span><.square
              mark="ground"
              label="The ground: light or dark"
              size="small"
              data-ground-flip
              aria-pressed="false"
            />
          </h6>
          <div
            class="grounds themes"
            role="group"
            data-shelf={@kind}
            aria-label={"The #{@kind} themes on the shelf"}
          >
            <button
              :for={t <- @themes}
              type="button"
              class="swatch ttile"
              data-theme-key={t.key}
              aria-pressed="false"
              title={"#{t.author} · #{t.licence}"}
            >
              <span class="tthumb"></span>{t.name}
            </button>
            <button
              type="button"
              class="swatch ttile custom"
              data-theme-key="custom"
              aria-pressed="false"
              hidden
            >
              <span class="tthumb"></span>Custom<small></small>
            </button>
          </div>
          <p class="acts">
            <button :if={@theme_files} class="btn" type="button" data-theme-download>
              Download Current
            </button>
            <label :if={@theme_files} class="btn">Load Custom<input
              type="file"
              data-theme-file
              accept=".json,.jsonc,application/json"
              hidden
            /></label>
            <button class="btn" type="button" data-theme-clear hidden>Clear Custom</button>
            <span class="word" data-theme-word></span>
          </p>
        </section>
      </section>
      <section class="group tsec" data-sec={@kind} data-folded>
        <h5>
          <span>Adjustments</span><span class="touch"></span><.square
            mark="chevron"
            label="Unfold the adjustments"
            size="small"
            class="foldsq"
            aria-expanded="false"
            title="Unfold"
          />
        </h5>
        <div class="tbody">{render_slot(@inner_block)}</div>
      </section>
    </div>
    """
  end

  # The frame at a thumbnail's size, as the ground's cards draw it: the
  # band, the rail, three lines and a terminal. The hook says where the
  # band and the rail are (`bottom`, `right`, `off` on the thumb).
  defp frame_thumb(assigns) do
    ~H"""
    <span class="thumb frame"><i class="b"></i><i class="rl"></i><i class="t t1"></i><i class="t t2"></i><i class="t t3"></i><i class="tm"></i></span>
    """
  end

  # A group's head: its title and the chevron that folds what is under
  # it (hooks.js, `.group>h5>.foldsq`; console.css, `.group[data-folded]`).
  # Every head of the Interface tab carries one since 2026-10-01 — The
  # frame, The ground, Style, Credits' groups — unfolded as it opens;
  # Adjustments has its own, with the count, and opens folded.
  attr :title, :string, required: true

  defp fold_head(assigns) do
    ~H"""
    <h5>
      <span>{@title}</span><.square
        mark="chevron"
        label={"Fold #{@title}"}
        size="small"
        class="foldsq"
        aria-expanded="true"
        title="Fold"
      />
    </h5>
    """
  end

  # A group of Credits: its head, centred, with the house's small fold
  # square at its end; its hint; its fichas.
  attr :title, :string, required: true
  attr :hint, :string, required: true
  slot :inner_block, required: true

  defp credits_group(assigns) do
    ~H"""
    <section class="group">
      <.fold_head title={@title} />
      <p class="hint">{@hint}</p>
      <div class="credits">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  # A theme's ficha in Credits: the one ficha faces and themes share —
  # the name as its head, whose and under which licence as chips, its
  # site with the house's mention, what it is (its file's `about`, or
  # what its blocks say) — and, from the hook, "In use" when it is
  # the one on, with nothing set on top. Everything printed is the
  # file's: a theme is credited as it credits itself.
  attr :theme, :map, required: true

  defp theme_credit(assigns) do
    t = assigns.theme

    assigns =
      assign(assigns,
        what: t.about || theme_what(t),
        chips: Enum.reject([t.author, t.licence], &is_nil/1)
      )

    ~H"""
    <.card class="credit" data-theme={@theme.key} data-kind={@theme.kind}>
      <h3><b>{@theme.name}</b></h3>
      <p class="chips"><span :for={c <- @chips} class="chip">{c}</span></p>
      <p :if={@theme.url} class="site">
        <ConsoleWeb.Refs.site_ref url={@theme.url} name={@theme.name} />
      </p>
      <p class="hint">{@what}</p>
      <p class="on" hidden></p>
    </.card>
    """
  end

  # What a theme is, read off its file when it does not say: which
  # surface its shelf is, and which grounds it carries.
  defp theme_what(%{kind: kind, json: json}) do
    surface =
      case kind do
        :terminal -> "The terminal's colours"
        :code -> "The sheet, every language's palette and the diff's"
      end

    grounds =
      case {Map.has_key?(json, "dark"), Map.has_key?(json, "light")} do
        {true, true} -> "both grounds"
        {true, false} -> "dark only: on the light ground, the house's"
        {false, true} -> "light only: on the dark ground, the house's"
        _ -> "neither ground"
      end

    "#{surface}, #{grounds}."
  end
end
