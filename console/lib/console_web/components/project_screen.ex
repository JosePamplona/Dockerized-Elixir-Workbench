defmodule ConsoleWeb.ProjectScreen do
  @moduledoc """
  The project's own papers: Birth — what the project is, which is what
  it was born as, drawn off the status — then Mix, what `mix.exs` says
  and every package the project carries, the .env with its secrets
  masked, README, CHANGELOG, and the workspace's git as Changes and
  History.
  """
  use Phoenix.Component
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  import ConsoleWeb.RecordSheet, only: [record_sheet: 1]
  import ConsoleWeb.GitScreen, only: [git_pending: 1, git_history: 1]
  alias ConsoleWeb.GitScreen
  alias ConsoleWeb.Packages

  attr :carried, :list, required: true
  attr :paper, :string, required: true
  attr :page, :map, default: nil
  attr :record, :any, default: nil, doc: "ConsoleWeb.Record.page/4, when Record is the paper"
  attr :reads, :any, default: %{}, doc: "what the routes answered: a map by href, or :asking"
  attr :birth, :any, default: nil, doc: "the first commit's sha, the Record tab's sublabel"
  attr :status, :map, default: nil
  attr :gt, :map, default: nil, doc: "the git papers' state, ConsoleWeb.ConsoleLive.Git"
  attr :jobs, :list, default: []
  attr :busy, :boolean, default: false, doc: "a deploy job is in flight"
  attr :reading, :any, default: false, doc: "a status in flight: :fast, :full, or false"
  attr :hex, :map, default: %{}, doc: "what hex said of each package, by name"
  attr :hex_asking, :boolean, default: false
  attr :hex_error, :any, default: nil

  attr :by, :map,
    default: %{},
    doc: "who put each package in mix.exs, Console.Project.brought_by/1"

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
                small: small(key, file, key in @carried, @birth, @gt, @status),
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
      <.record_sheet
        :if={@page && @page[:record] && @record}
        record={@record}
        reads={@reads}
        status={@status}
        busy={@busy}
        stale={@reading == :full}
      />
      <div :if={@page && @page[:mix]} class="dkdoc mix">
        <%!-- def project, a line a keyword, set as the Docker screen sets
              what the daemon says of itself: a code box, the key dim and
              the value coloured as the Elixir it is. --%>
        <div class="log-cap"><span class="label">Specs</span></div>
        <code class="code-box spec"><span :for={{key, html} <- @page.mix.spec} class="ln"><span class="k">{key}</span><span
          class="v src"
          data-lang="elixir"
        >{Phoenix.HTML.raw(html)}</span></span></code>
        <Packages.table
          rows={mix_rows(@status, @hex, @by)}
          brought
          options={@page.mix.options}
          nothing="mix.exs lists no package"
          hex_asking={@hex_asking}
          hex_error={@hex_error}
        />
      </div>
      <div :if={@page && @page[:git] && @gt} class="dkdoc git">
        <.git_pending :if={@page[:git] == "pending"} gt={@gt} status={@status} jobs={@jobs} />
        <.git_history :if={@page[:git] == "history"} gt={@gt} status={@status} />
      </div>
      <div :if={is_nil(@page)} class="nothing">
        This workspace carries none of the project's papers.
      </div>
    </div>
    """
  end

  # Every package the project carries, as the status read mix.exs and
  # mix.lock, with who brought it and what that cartridge asks for — read
  # off git apart from the page, `:reading` until it answers.
  defp mix_rows(status, hex, by) do
    now = DateTime.utc_now()

    for dep <- get_in(status || %{}, ["project", "deps"]) || [] do
      dep
      |> Map.merge(by[dep["name"]] || %{"by" => :reading})
      |> Packages.row(hex, now, true)
    end
  end

  # The ribbon's sublabel: the file a paper is; for the drawn ones what
  # they are read off — Birth the first commit, Changes the tree,
  # History the HEAD.
  defp small("record", _file, true, birth, _gt, _status),
    do: if(birth, do: String.slice(birth, 0, 7), else: "—")

  defp small(key, _file, true, _birth, gt, status) when key in ["pending", "history"],
    do: GitScreen.doc_sum(key, gt || %{}, status)

  defp small(_key, file, true, _birth, _gt, _status), do: file
  defp small(_key, _file, false, _birth, _gt, _status), do: "—"

  defp paper_why("record", _), do: "no workspace read yet: the record is drawn off its status"

  defp paper_why(key, _) when key in ["pending", "history"],
    do: "this workspace has no repository — phx.new initialises one, new makes the first commit"

  defp paper_why("changelog", _),
    do:
      "this workspace has no CHANGELOG.md: new generates none — the project is born stock, and what it carries is its own to write. The cartridges keep theirs."

  defp paper_why(_, file), do: "no #{file} in this workspace"

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
