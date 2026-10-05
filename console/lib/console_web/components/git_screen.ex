defmodule ConsoleWeb.GitScreen do
  @moduledoc """
  The workspace's git as two papers of the Project tab — *Changes*,
  what a commit would take, file by file on the sheet the box's Files
  screen draws, with the commit's title and body above it; and
  *History*, the log with the cartridge inserts marked, each commit
  opening its diff under its own row (`/project?paper=history&commit=SHA`,
  where a `.commit-ref` lands). The rail said `dirty` and offered a
  commit it could not name; this is where it is named and seen. They
  were a tab of their own, Git, until 2026-09-09: the repository is the
  project's, so these are its papers.

  Narrow on purpose: no branches, no remotes, no discarding by file —
  `wb.sh` alone writes the workspace, the commit is its job, and the
  house's undo is `eject`. What the screen does say, and nobody did: a
  dirty tree stops `add` and `eject`, which want a clean one, so the
  commit is not tidiness, it is what lets the next cartridge in. Which
  is why Changes grew a second way out of a dirty tree (2026-10-03):
  `discard`, every change git does not have thrown away at once. Both
  live in the one card, whose foot reads down and presses across — the
  Deployments card's shape — because one dirty tree is one thing, and
  what it can become is a choice between two, not two boxes. The verb
  that cannot be taken back is marked, not hidden, and asks for the
  reader's word before it runs.
  """
  use Phoenix.Component
  import ConsoleWeb.Refs
  import ConsoleWeb.Box, only: [file: 1]
  import ConsoleWeb.Card, only: [card: 1]

  @docs [{"pending", "Changes"}, {"history", "History"}]
  def docs, do: @docs
  def doc_names, do: Enum.map(@docs, &elem(&1, 0))

  @doc "The screen's state as the page opens."
  def initial, do: %{doc: "pending", pending: nil, log: nil, pick: nil, files: nil}

  @doc "The title the form opens with: the one `wb.sh commit` uses when nobody names the commit."
  def default_title, do: "Workbench: commit pending changes"

  @doc "The ribbon's sublabel for a paper: Changes' tree, History's HEAD."
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

  # --- Changes --------------------------------------------------------------------

  attr :gt, :map, required: true
  attr :status, :map, default: nil
  attr :jobs, :list, required: true

  @doc "Changes: what a commit would take, and the two things that can become of it."
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
        busy: busy,
        why: why,
        identity: assigns.status && get_in(assigns.status, ["git", "identity"])
      )

    ~H"""
    <p :if={is_nil(@p)} class="note">Reading the tree…</p>
    <%= if @p do %>
      <.card tag="form" name="Changes" class="commit" phx-submit="git_commit">
        <:head>
          <span :if={!@clean} class="note">{length(@p.files)} file{if length(@p.files) == 1,
            do: "",
            else: "s"} ·
          <span class="a">+{@p.added}</span><span :if={@p.removed > 0} class="r"> −{@p.removed}</span></span>
          <span :if={@clean} class="note">the tree is clean: nothing to commit</span>
        </:head>
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
        <div class="foot">
          <div class="fline">
            <div class="cmd">./wb.sh commit --message-file …</div>
            <button
              class={["btn primary", @why && "unlit"]}
              type="submit"
              aria-disabled={@why && "true"}
              title={@why || "signed as #{@identity || "the workbench"}"}
            >Commit</button>
            <p class="note">
              signed as {@identity || "the workbench"} · a dirty tree stops add and eject, which want a clean one: this is what lets the next cartridge in
            </p>
          </div>
          <.discard clean={@clean} busy={@busy} jobs={@jobs} />
        </div>
      </.card>
      <div :if={@p.files != []} class="impl">
        <span class="label">Files</span>
        <div class={["files", length(@p.files) > 12 && "many"]}>
          <.file :for={{f, i} <- Enum.with_index(@p.files)} f={f} i={i} status={@status} />
        </div>
      </div>
    <% end %>
    """
  end

  attr :clean, :boolean, required: true
  attr :busy, :boolean, required: true
  attr :jobs, :list, required: true

  # The second line of the foot, and the one that cannot be taken back:
  # the Deployments card's shape for a box with more than one verb — the
  # commands read down, the buttons press across. It stood in a danger
  # card of its own under the files for an afternoon; one dirty tree is
  # one thing, and its two ways out belong in one box. What the red edge
  # of that card said, this says with the button, filled as `delete` is:
  # in this house the fill is what the verb costs, not how often it is
  # pressed — `eject` is outlined because it can be inserted again, and
  # this, like `delete`, cannot be taken back. Its two confirmation
  # buttons carry `type="button"`: the card is the Commit form, and a
  # button with no type inside a form is a submit — bare, "Yes, discard"
  # confirmed the discard and committed behind it.
  defp discard(assigns) do
    waiting = ConsoleWeb.Deploy.pending(assigns.jobs, :discard)

    assigns =
      assign(assigns,
        waiting: waiting,
        why:
          cond do
            assigns.clean -> "nothing to discard: the tree is clean"
            assigns.busy -> "a commit is running"
            true -> nil
          end
      )

    ~H"""
    <div class="fline">
      <div class="cmd">./wb.sh discard</div>
      <.job_button
        :if={!@waiting}
        label="Discard"
        class="primary danger"
        args="discard"
        why={@why}
        title="./wb.sh discard · asks first"
      />
      <span :if={@waiting} class="confirm on">The changes go, and no commit holds them.
      <button
        type="button"
        class="btn primary danger"
        phx-click="confirm"
        phx-value-id={@waiting.id}
      >Yes, discard</button><button
        type="button"
        class="btn"
        phx-click="cancel"
        phx-value-id={@waiting.id}
      >Keep them</button></span>
      <p class="note">
        every change git does not have — the files listed below back to the last commit, the new ones gone · what git ignores (deps, _build) stays · cannot be undone
      </p>
    </div>
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
        <%= for c <- @gt.log do %>
          <tr class={picked?(@gt.pick, c.sha) && "on"}>
            <td>
              <.commit_ref
                sha={c.sha}
                subject={c.subject}
                date={c.date}
                open={picked?(@gt.pick, c.sha)}
              />
            </td>
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
          <tr :if={picked?(@gt.pick, c.sha)} class="fbox">
            <td colspan="4">
              <div class="fit"><.commit_diff gt={@gt} status={@status} /></div>
            </td>
          </tr>
        <% end %>
      </table>
    </div>
    """
  end

  attr :gt, :map, required: true
  attr :status, :map, default: nil

  # The picked commit's diff, under its own row as the Deployments' compose
  # file reads under its: picked far up a long log it read under the whole
  # table, off the screen and away from the row that asked for it.
  defp commit_diff(assigns) do
    ~H"""
    <p :if={is_nil(@gt.files)} class="note">Reading {String.slice(@gt.pick, 0, 7)}…</p>
    <div :if={is_list(@gt.files)} class="impl">
      <span class="label">{String.slice(@gt.pick, 0, 7)} · {files_word(@gt.files)}</span>
      <div :if={@gt.files == []} class="note">Nothing in this commit but its message.</div>
      <div :if={@gt.files != []} class={["files", length(@gt.files) > 12 && "many"]}>
        <.file :for={{f, i} <- Enum.with_index(@gt.files)} f={f} i={i} status={@status} />
      </div>
    </div>
    """
  end

  # The picked commit, by any prefix of its sha: a mention carries seven characters.
  defp picked?(pick, sha), do: is_binary(pick) and pick != "" and String.starts_with?(sha, pick)

  # "1 file", "12 files": the count and its noun.
  defp files_word([_]), do: "1 file"
  defp files_word(files), do: "#{length(files)} files"
end
