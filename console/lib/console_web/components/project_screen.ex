defmodule ConsoleWeb.ProjectScreen do
  @moduledoc """
  The project's own papers: Record — what the project is, drawn off the
  status, with every address it answers to and what each answered when
  the console called — then README, CHANGELOG and the .env with its
  secrets masked.
  """
  use Phoenix.Component
  import ConsoleWeb.Ribbon, only: [ribbon: 1]
  import ConsoleWeb.RecordSheet, only: [record_sheet: 1]

  attr :carried, :list, required: true
  attr :paper, :string, required: true
  attr :page, :map, default: nil
  attr :record, :any, default: nil, doc: "ConsoleWeb.Record.page/4, when Record is the paper"
  attr :reads, :any, default: %{}, doc: "what the routes answered: a map by href, or :asking"
  attr :birth, :any, default: nil, doc: "the first commit's sha, the Record tab's sublabel"

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
                small: small(key, file, key in @carried, @birth),
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
      <.record_sheet :if={@page && @page[:record] && @record} record={@record} reads={@reads} />
      <div :if={is_nil(@page)} class="nothing">
        This workspace carries none of the project's papers.
      </div>
    </div>
    """
  end

  # The ribbon's sublabel: the file a paper is, or for Record the first
  # commit it is read off — it is drawn, not read off a file.
  defp small("record", _file, true, birth),
    do: if(birth, do: String.slice(birth, 0, 7), else: "—")

  defp small(_key, file, true, _port), do: file
  defp small(_key, _file, false, _port), do: "—"

  defp paper_why("record", _), do: "no workspace read yet: the record is drawn off its status"

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
