defmodule ConsoleWeb.GitScreen do
  @moduledoc """
  The workspace's git as two papers of the Project tab — *Pending*,
  what a commit would take, file by file on the sheet the box's Files
  screen draws, with the commit's title and body above it; and
  *History*, the log with the cartridge inserts marked, each commit
  opening its diff on the same sheet (`/project?paper=history&commit=SHA`,
  where a `.commit-ref` lands). The rail said `dirty` and offered a
  commit it could not name; this is where it is named and seen. They
  were a tab of their own, Git, until 2026-09-09: the repository is the
  project's, so these are its papers.

  Narrow on purpose: no branches, no remotes, no discarding by file —
  `wb.sh` alone writes the workspace, the commit is its job, and the
  house's undo is `eject`. What the screen does say, and nobody did: a
  dirty tree stops `add` and `eject`, which want a clean one, so the
  commit is not tidiness, it is what lets the next cartridge in.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Box, only: [file: 1]

  @docs [{"pending", "Pending"}, {"history", "History"}]
  def docs, do: @docs
  def doc_names, do: Enum.map(@docs, &elem(&1, 0))

  @doc "The screen's state as the page opens."
  def initial, do: %{doc: "pending", pending: nil, log: nil, pick: nil, files: nil}

  @doc "The title the form opens with: the one `wb.sh commit` uses when nobody names the commit."
  def default_title, do: "Workbench: commit pending changes"

  @doc "The ribbon's sublabel for a paper: Pending's tree, History's HEAD."
  def doc_sum("history", _gt, status) do
    case status && get_in(status, ["git", "head"]) do
      head when is_binary(head) -> head |> String.split(" ") |> List.first()
      _ -> nil
    end
  end

  def doc_sum("pending", %{pending: %{files: fs}}, _),
    do:
      if(fs == [],
        do: "clean",
        else: "#{length(fs)} file#{if length(fs) == 1, do: "", else: "s"}"
      )

  def doc_sum("pending", _, status),
    do: if(status && status["git"]["clean"], do: "clean", else: "dirty")

  def doc_sum(_, _, _), do: nil

  # --- Pending --------------------------------------------------------------------

  attr :gt, :map, required: true
  attr :status, :map, default: nil
  attr :jobs, :list, required: true

  @doc "Pending: what a commit would take, and the commit."
  def git_pending(assigns) do
    busy =
      Enum.any?(
        assigns.jobs,
        &(&1.state in [:running, :queued, :pending] and elem(&1.kind, 0) == :commit)
      )

    p = assigns.gt.pending
    clean = p && p.files == []

    why =
      cond do
        is_nil(p) -> "reading the tree…"
        clean -> "nothing to commit: the tree is clean"
        busy -> "a commit is running"
        true -> nil
      end

    assigns =
      assign(assigns,
        p: p,
        clean: clean,
        why: why,
        identity: assigns.status && get_in(assigns.status, ["git", "identity"])
      )

    ~H"""
    <p :if={is_nil(@p)} class="note">Reading the tree…</p>
    <%= if @p do %>
      <form class="commit" phx-submit="git_commit">
        <div class="head">
          <h3>Commit</h3>
          <span :if={!@clean} class="note">{length(@p.files)} file{if length(@p.files) == 1,
            do: "",
            else: "s"} ·
          <span class="a">+{@p.added}</span><span :if={@p.removed > 0} class="r"> −{@p.removed}</span></span>
          <span :if={@clean} class="note">the tree is clean: nothing to commit</span>
        </div>
        <input
          type="text"
          name="title"
          value={default_title()}
          placeholder="What this commit does, in a line"
          aria-label="Title"
          maxlength="72"
          disabled={@why != nil}
          title="the line wb.sh commit uses when nobody names it: keep it, or say what this one does"
        />
        <textarea
          name="body"
          rows="3"
          placeholder="Why, if it is not obvious from the line above (optional)"
          aria-label="Description"
          disabled={@why != nil}
        ></textarea>
        <div class="acts">
          <button
            class={["btn primary", @why && "unlit"]}
            type="submit"
            aria-disabled={@why && "true"}
            title={
              @why || "./wb.sh commit --message-file … · signed as #{@identity || "the workbench"}"
            }
          >Commit</button>
          <span class="note">signed as {@identity || "the workbench"} · a dirty tree stops add and eject, which want a clean one: this is what lets the next cartridge in</span>
        </div>
      </form>
      <div :if={@p.files != []} class="impl">
        <span class="label">Files</span>
        <div class={["files", length(@p.files) > 12 && "many"]}>
          <.file :for={{f, i} <- Enum.with_index(@p.files)} f={f} i={i} status={@status} />
        </div>
      </div>
    <% end %>
    """
  end

  # --- History --------------------------------------------------------------------

  attr :gt, :map, required: true
  attr :status, :map, default: nil

  @doc "History: the log, and the picked commit's diff."
  def git_history(assigns) do
    ~H"""
    <p :if={is_nil(@gt.log)} class="note">Reading the log…</p>
    <p :if={@gt.log == []} class="note">No commits yet: new makes the first.</p>
    <div :if={@gt.log not in [nil, []]} class="tbl">
      <table class="wide commits">
        <tr>
          <th></th><th>commit</th><th class="dim">when</th><th class="dim">who</th>
        </tr>
        <tr
          :for={c <- @gt.log}
          class={@gt.pick == c.sha && "on"}
          phx-click="git_pick"
          phx-value-sha={c.sha}
          title="its diff, below"
        >
          <td class="dim mono">{c.short}</td>
          <td class="wrap">
            <span class="sj">{c.subject}</span><.cart_ref
              :if={c.insert}
              name={c.insert}
              installed={true}
            /><span :if={c.body != ""} class="hint">{c.body}</span>
          </td>
          <td class="dim">{String.slice(c.date, 0, 10)}</td>
          <td class="dim">{c.author}</td>
        </tr>
      </table>
    </div>
    <p :if={@gt.pick && is_nil(@gt.files)} class="note">Reading {String.slice(@gt.pick, 0, 7)}…</p>
    <div :if={@gt.pick && is_list(@gt.files)} class="impl">
      <span class="label">{String.slice(@gt.pick, 0, 7)} · {files_word(@gt.files)}</span>
      <div :if={@gt.files == []} class="note">Nothing in this commit but its message.</div>
      <div :if={@gt.files != []} class={["files", length(@gt.files) > 12 && "many"]}>
        <.file :for={{f, i} <- Enum.with_index(@gt.files)} f={f} i={i} status={@status} />
      </div>
    </div>
    """
  end

  # "1 file", "12 files": the count and its noun.
  defp files_word([_]), do: "1 file"
  defp files_word(files), do: "#{length(files)} files"
end
