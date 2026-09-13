defmodule ConsoleWeb.ConsoleLive.Git do
  @moduledoc """
  The git papers' state, off the page: which of the two the URL names
  and which commit, the tree and the log read off the workspace, and
  the commit the reader writes. Changes and History are papers of the
  Project tab: `/project?paper=history&commit=SHA` is where a
  `.commit-ref` lands — the Record's birth, the rail's HEAD, an
  insert's chip, a row of History itself — the commit picked and its
  diff open. Any prefix of the sha will do: a mention carries seven.
  """
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [connected?: 1, start_async: 3]

  alias Console.{Diffs, Git, Jobs}
  alias ConsoleWeb.GitScreen

  # Which paper and which commit: /project?paper=history&commit=SHA.
  def take(%{assigns: %{tab: "project", ppaper: doc}} = socket, params)
      when doc in ["pending", "history"] do
    gt = socket.assigns.gt
    pick = params["commit"]
    gt = %{gt | doc: doc, pick: pick, files: if(pick == gt.pick, do: gt.files, else: nil)}
    socket |> assign(gt: gt) |> read(false)
  end

  def take(socket, _params), do: socket

  # The tree and the log, read off the page. `again` is a status having
  # arrived: what was read is read again, since a job may have moved it.
  def read(%{assigns: %{tab: "project", ppaper: doc, gt: gt, status: status}} = socket, again)
      when doc in ["pending", "history"] do
    ws = status && status["workspace"]

    if connected?(socket) and is_binary(ws) and get_in(status, ["git", "repo"]) == true and
         Application.get_env(:console, :docker_reads, true) do
      socket
      |> ask_pending(gt, ws, again)
      |> ask_log(gt, ws, status, again)
      |> ask_files(gt, ws)
    else
      socket
    end
  end

  def read(socket, _again), do: socket

  # The working tree, for the Changes paper.
  defp ask_pending(socket, %{doc: "pending"} = gt, ws, again) do
    if again or is_nil(gt.pending),
      do: start_async(socket, {:gt, :pending}, fn -> Git.pending(ws) end),
      else: socket
  end

  defp ask_pending(socket, _gt, _ws, _again), do: socket

  # The log, for the History document.
  defp ask_log(socket, %{doc: "history"} = gt, ws, status, again) do
    inserts = get_in(status, ["git", "inserts"]) || []

    if again or is_nil(gt.log),
      do: start_async(socket, {:gt, :log}, fn -> Git.log(ws, inserts) end),
      else: socket
  end

  defp ask_log(socket, _gt, _ws, _status, _again), do: socket

  # The picked commit's files, once.
  defp ask_files(socket, %{doc: "history", pick: pick, files: nil}, ws) when is_binary(pick),
    do: start_async(socket, {:gt, :files}, fn -> Diffs.files_of(ws, pick) end)

  defp ask_files(socket, _gt, _ws), do: socket

  # --- what the reader does ---------------------------------------------------

  # The message goes to wb.sh through a file: a body has lines, and a
  # job's argv cannot carry one.
  def event("git_commit", params, socket) do
    # A title left blank is the default one, as on the command line.
    title =
      if String.trim(params["title"] || "") == "",
        do: GitScreen.default_title(),
        else: params["title"]

    path = Git.message_file(title, params["body"])
    Jobs.run({:commit, nil}, ["commit", "--message-file", path])
    {:noreply, socket}
  end

  # --- what arrives ---------------------------------------------------------

  def async({:gt, key}, {:ok, value}, socket),
    do: {:noreply, assign(socket, gt: Map.put(socket.assigns.gt, key, value))}

  def async({:gt, _key}, {:exit, why}, socket),
    do: {:noreply, assign(socket, error: "git could not be read: " <> inspect(why))}
end
