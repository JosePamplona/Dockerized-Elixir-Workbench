defmodule ConsoleWeb.ProjectScreen do
  @moduledoc "The project's own papers: README, CHANGELOG, and the .env with its secrets masked."
  use Phoenix.Component
  import ConsoleWeb.Ribbon, only: [ribbon: 1]

  attr :carried, :list, required: true
  attr :paper, :string, required: true
  attr :page, :map, default: nil

  def project_screen(assigns) do
    ~H"""
    <div class="pdocs">
      <.ribbon
        label="The project's own documents"
        selected={@paper}
        docked
        items={for {key, label, file} <- Console.Project.papers(), do: %{key: key, label: label, small: if(key in @carried, do: file, else: "—"), why: key not in @carried && paper_why(key, file), href: "/project?paper=#{key}"}}
      />
      <div :if={@page && @page[:html]} class={["booklet", @page.toc == [] && "notoc"]} id="p-booklet" phx-hook="Booklet">
        <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
        <nav :if={@page.toc != []} class="toc"><a class="doctitle" href="#top">{@page.title}</a><a :for={{id, text} <- @page.toc} href={"##{id}"}>{text}</a></nav>
      </div>
      <pre :if={@page && @page[:env]} class="env"><%= for line <- @page.env do %><.env_line line={line} /><% end %></pre>
      <div :if={is_nil(@page)} class="nothing">This workspace carries none of the project's papers.</div>
    </div>
    """
  end

  defp paper_why("changelog", _), do: "this workspace has no CHANGELOG.md: new generates none — the project is born stock, and what it carries is its own to write. The cartridges keep theirs."
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
