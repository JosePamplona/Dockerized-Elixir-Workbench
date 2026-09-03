defmodule ConsoleWeb.ProjectScreen do
  @moduledoc "The project's own papers: README, CHANGELOG, and the .env with its secrets masked."
  use Phoenix.Component

  attr :carried, :list, required: true
  attr :paper, :string, required: true
  attr :page, :map, default: nil

  def project_screen(assigns) do
    ~H"""
    <div class="pdocs">
      <div class="dtabs" role="tablist" aria-label="The project's own documents">
        <%= for {key, label, file} <- Console.Project.papers() do %>
          <.link :if={key in @carried} class="dtab" role="tab" patch={"/project?paper=#{key}"} aria-selected={to_string(@paper == key)}>{label}<small>{file}</small></.link>
          <button :if={key not in @carried} class="dtab unlit" role="tab" type="button" aria-disabled="true" title={paper_why(key, file)}>{label}<small>—</small></button>
        <% end %>
      </div>
      <div :if={@page && @page[:html]} class={["booklet", @page.toc == [] && "notoc"]} id="p-booklet" phx-hook="Booklet">
        <article class="md">{Phoenix.HTML.raw(@page.html)}</article>
        <nav :if={@page.toc != []} class="toc"><a class="doctitle" href="#top">{@page.title}</a><a :for={{id, text} <- @page.toc} href={"##{id}"}>{text}</a></nav>
      </div>
      <pre :if={@page && @page[:env]} class="env"><%= for line <- @page.env do %><.env_line line={line} /><% end %></pre>
      <div :if={is_nil(@page)} class="missing">This workspace carries none of the project's papers.</div>
    </div>
    """
  end

  defp paper_why("changelog", _), do: "this workspace has no CHANGELOG.md: new generates none — the project is born stock, and what it carries is its own to write. The cartridges keep theirs."
  defp paper_why(_, file), do: "no #{file} in this workspace"

  attr :line, :string, required: true

  defp env_line(assigns) do
    ~H"""
    <%= cond do %>
      <% String.starts_with?(String.trim(@line), "#") or String.trim(@line) == "" -> %><span class="c">{@line <> "\n"}</span>
      <% m = Regex.run(~r/^(\w+=)(.*)$/, @line) -> %><span class="k">{Enum.at(m, 1)}</span><span class={String.contains?(Enum.at(m, 2), "•") && "m"}>{Enum.at(m, 2) <> "\n"}</span>
      <% true -> %>{@line <> "\n"}
    <% end %>
    """
  end
end
