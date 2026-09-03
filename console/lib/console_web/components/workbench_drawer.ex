defmodule ConsoleWeb.WorkbenchDrawer do
  @moduledoc """
  The workbench's own drawer: config.conf as the form it already is,
  its manual, its changelog, and Console — how this page is arranged,
  kept in the browser. The values of the form are saved through
  `wb.sh config set`, as a job.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs

  @tabs [{"config", "Config", "config.conf"}, {"readme", "Manual", "README.md"}, {"changelog", "Changelog", "CHANGELOG.md"}, {"ui", "Console", "this browser"}]
  @choices %{"GIT_IDENTITY" => ["user", "workbench"]}
  # When each setting takes effect — most of the file is not 'new only'.
  @effect %{"WORKSPACE_PATH" => nil, "PROJECT_NAME" => "new", "PHX_NEW_VERSION" => "new", "ELIXIR_VERSION" => "new", "ERLANG_VERSION" => "new", "DEBIAN_VERSION" => "new", "GIT_IDENTITY" => "every commit", "POSTGRES_IMAGE_VERSION" => "every bake", "PGADMIN_IMAGE_VERSION" => "every bake", "NGINX_IMAGE_VERSION" => "scaled deploy"}
  @stack_parts [{"ELIXIR_VERSION", :e, "the Elixir of the image"}, {"ERLANG_VERSION", :o, "the Erlang/OTP of the image"}, {"DEBIAN_VERSION", :d, "the Debian base of the image"}]

  def tabs, do: @tabs

  attr :tab, :string, required: true, doc: "the screen under the drawer"
  attr :wb, :string, required: true
  attr :version, :string, default: nil
  attr :config, :map, required: true
  attr :edits, :map, required: true
  attr :raw, :boolean, default: false
  attr :stacks, :any, default: nil
  attr :page, :map, default: nil
  attr :jobs, :list, default: []

  def workbench_drawer(assigns) do
    ~H"""
    <aside class="drawer on" role="dialog" aria-modal="true" aria-label="The workbench">
      <div class="top">
        <h3>Dockerized Elixir Workbench <.chip :if={@version}>v{@version}</.chip></h3>
        <.link class="btn" patch={"/#{@tab}"}>Close</.link>
        <div class="dtabs" role="tablist" aria-label="The workbench's documents">
          <.link :for={{key, label, file} <- tabs()} class="dtab" role="tab" patch={"/#{@tab}?wb=#{key}"} aria-selected={to_string(@wb == key)}>{label}<small>{file}</small></.link>
        </div>
      </div>
      <.config :if={@wb == "config"} config={@config} edits={@edits} raw={@raw} stacks={@stacks} jobs={@jobs} />
      <div :if={@wb in ["readme", "changelog"] and @page} class={["booklet", @page.toc == [] && "notoc"]} id="wb-booklet" phx-hook="Booklet">
        <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
        <nav :if={@page.toc != []} class="toc"><a class="doctitle" href="#top">{@page.title}</a><a :for={{id, text} <- @page.toc} href={"##{id}"}>{text}</a></nav>
      </div>
      <.ui :if={@wb == "ui"} />
    </aside>
    """
  end

  # --- config.conf as a form ----------------------------------------------------

  defp config(assigns) do
    changed = map_size(assigns.edits)
    busy = Enum.any?(assigns.jobs, &(&1.state in [:running, :queued] and elem(&1.kind, 0) == :config))
    assigns = assign(assigns, changed: changed, busy: busy)

    ~H"""
    <div class="cfg">
      <div class="bar">
        <button class="btn primary" type="button" disabled={@changed == 0 or @busy} phx-click="cfg_save">{cond do @busy -> "Saving…"; @changed > 0 -> "Save #{@changed} change#{if @changed == 1, do: "", else: "s"}"; true -> "Save" end}</button>
        <button class="btn" type="button" disabled={@changed == 0} phx-click="cfg_reload">Reload</button>
        <button class="btn" type="button" aria-pressed={to_string(@raw)} phx-click="cfg_raw">Raw</button>
        <span class="note">Values are written back in place by ./wb.sh config set; comments and order stay. Each field's tag says when it takes effect.</span>
      </div>
      <pre :if={@raw} class="raw"><%= for line <- String.split(raw_text(@config, @edits), "\n") do %><.raw_line line={line} /><% end %></pre>
      <form :if={!@raw} phx-change="cfg_change">
        <%= for sec <- @config.sections, sec.fields != [] do %>
          <div class="sec">
            <h4>{sec.title}</h4>
            <p :if={sec.intro != []} class="intro">{Enum.join(sec.intro, " ")}</p>
            <%= for {f, i} <- Enum.with_index(sec.fields) do %>
              <h5 :if={f.group != "" and (i == 0 or Enum.at(sec.fields, i - 1).group != f.group)} class="grp">{f.group}</h5>
              <.stack_rows :if={f.key == "ELIXIR_VERSION"} sec={sec} edits={@edits} stacks={@stacks} />
              <.field :if={f.key not in ["ELIXIR_VERSION", "ERLANG_VERSION", "DEBIAN_VERSION"]} f={f} config={@config} edits={@edits} />
            <% end %>
            <p :for={note <- sec.outro} class="intro outro">{note}</p>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  attr :line, :string, required: true

  defp raw_line(assigns) do
    ~H"""
    <%= cond do %>
      <% String.starts_with?(String.trim(@line), "#") or String.trim(@line) == "" -> %><span class="c">{@line <> "\n"}</span>
      <% m = Regex.run(~r/^(export\s+\w+=)(.*?)(\s*#.*)?$/, @line) -> %><span class="k">{Enum.at(m, 1)}</span><span class="v">{Enum.at(m, 2)}</span><span class="c">{(Enum.at(m, 3) || "") <> "\n"}</span>
      <% true -> %>{@line <> "\n"}
    <% end %>
    """
  end

  @doc "config.conf's text with the edits written in, as `config set` will write them."
  def raw_text(config, edits) do
    Enum.reduce(edits, config.text || "", fn {key, v}, text ->
      Regex.replace(~r/^(export\s+#{key}=)("?)[^"#\n]*\2/m, text, fn _, a, q -> a <> q <> v <> q end)
    end)
  end

  attr :f, :map, required: true
  attr :config, :map, required: true
  attr :edits, :map, required: true

  defp field(assigns) do
    f = assigns.f
    v = Map.get(assigns.edits, f.key, f.value)
    effect = Map.get(@effect, f.key, "new")
    choices = if f.key == "WORKSPACE_PATH", do: nil, else: @choices[f.key] || (assigns.config.alts[f.key] && [f.value | assigns.config.alts[f.key]])
    help = if f.key == "WORKSPACE_PATH", do: String.trim(f.help <> " A path that does not exist yet is created on new."), else: f.help
    help = String.trim(help <> if(f.inline != "", do: " — " <> f.inline, else: ""))
    assigns = assign(assigns, v: v, effect: effect, choices: choices, help: help, edited: Map.has_key?(assigns.edits, f.key))

    ~H"""
    <div class={["row", @edited && "changed", @v == "false" && "off"]}>
      <label for={"cfg-#{@f.key}"}>{@f.key}<.chip :if={@effect} class="new">{@effect}</.chip></label>
      <%= cond do %>
        <% @v in ["true", "false"] -> %>
          <input type="hidden" name={"cfg[#{@f.key}]"} value="false" /><input type="checkbox" id={"cfg-#{@f.key}"} name={"cfg[#{@f.key}]"} value="true" checked={@v == "true"} />
        <% @choices -> %>
          <select id={"cfg-#{@f.key}"} name={"cfg[#{@f.key}]"}><option :for={c <- Enum.uniq(@choices ++ [@v])} value={c} selected={c == @v}>{c}</option></select>
        <% true -> %>
          <input type="text" id={"cfg-#{@f.key}"} name={"cfg[#{@f.key}]"} value={@v} spellcheck="false" placeholder={@f.key == "WORKSPACE_PATH" && "./_workspaces/…"} />
      <% end %>
      <p :if={@help != ""} class="help">{@help}</p>
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

  defp stack_rows(assigns) do
    val = fn key -> Map.get(assigns.edits, key, (Enum.find(assigns.sec.fields, &(&1.key == key)) || %{value: ""}).value) end
    cur = %{e: val.("ELIXIR_VERSION"), o: val.("ERLANG_VERSION"), d: val.("DEBIAN_VERSION")}
    list = if is_list(assigns.stacks), do: Enum.flat_map(assigns.stacks, &parse_tag/1), else: []
    match = Enum.find(list, &(&1.e == cur.e and &1.o == cur.o and &1.d == cur.d))
    groups = Enum.group_by(list, &(&1.e |> String.split(".") |> Enum.take(2) |> Enum.join("."))) |> Enum.sort_by(fn {k, _} -> k end, :desc)
    assigns = assign(assigns, cur: cur, list: list, match: match, groups: groups, parts: @stack_parts, val: val)

    ~H"""
    <div class="row">
      <label for="cfg-stack">DOCKER_IMAGE<.chip class="new">new</.chip></label>
      <select id="cfg-stack" name="stack" disabled={@list == []}>
        <option :if={@stacks == :asking} value="">— asking Docker Hub for the usable images…</option>
        <option :if={@stacks != :asking and is_nil(@match)} value="" selected>— no published image for this combination (of the {length(@list)} usable)</option>
        <optgroup :for={{minor, tags} <- @groups} label={"elixir " <> minor}><option :for={x <- tags} value={x.tag} selected={@match && @match.tag == x.tag}>{x.tag}</option></optgroup>
      </select>
      <p class="help">One hexpm/elixir image, straight from Docker Hub (./wb.sh stacks). Picking it sets the three versions below; the three look it back up.</p>
    </div>
    <%= for {key, part, help} <- @parts do %>
      <% values = Enum.uniq(Enum.map(@list, & &1[part]) ++ [@cur[part]]) %>
      <div class={["row", Map.has_key?(@edits, key) && "changed"]}>
        <label for={"cfg-#{key}"}>{key}<.chip class="new">new</.chip></label>
        <select id={"cfg-#{key}"} name={"cfg[#{key}]"}>
          <option :for={v <- values} value={v} selected={v == @cur[part]} class={!combines?(@list, part, v, @cur) && "dim"}>{v}{if combines?(@list, part, v, @cur), do: "", else: " — no image with the other two"}</option>
        </select>
        <p class="help">{help}</p>
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

  defp combines?([], _, _, _), do: true
  defp combines?(list, part, v, cur), do: Enum.any?(list, fn x -> x[part] == v and Enum.all?([:e, :o, :d] -- [part], &(x[&1] == cur[&1])) end)

  # --- Console: the frame and the ground, kept in this browser -------------------

  defp ui(assigns) do
    ~H"""
    <div class="ui" id="wb-ui" phx-hook="Frame" phx-update="ignore">
      <p class="lede">How this console is arranged, and the ground it is read on. Kept in this browser, not in <code>config.conf</code>: it is what you are looking at, not what the workbench builds.</p>
      <div class="row"><button class="frame" type="button" data-frame="band-bottom" data-axis="band" aria-label="The band: top or bottom"></button><b>The band</b><p class="help" data-help="band-bottom"></p></div>
      <div class="row"><button class="frame" type="button" data-frame="rail-right" data-axis="rail" aria-label="The rail: left or right"></button><b>The rail's side</b><p class="help" data-help="rail-right"></p></div>
      <div class="row"><button class="frame" type="button" data-frame="rail-off" data-axis="off" aria-label="The rail: shown or hidden"></button><b>The rail</b><p class="help" data-help="rail-off"></p></div>
      <div class="row">
        <button class="ground" type="button" id="theme" aria-label="The ground: light or dark">
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2" /><path d="M12 3a9 9 0 010 18z" fill="currentColor" /></svg>
        </button>
        <b>The ground</b><p class="help" id="help-theme"></p>
      </div>
    </div>
    """
  end
end
