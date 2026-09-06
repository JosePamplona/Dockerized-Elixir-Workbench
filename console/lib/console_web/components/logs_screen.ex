defmodule ConsoleWeb.LogsScreen do
  @moduledoc """
  The Logs screen: the toolbar and the viewport the `Logs` hook fills.
  Built once and left alone — the lines never pass through the server.
  """
  use Phoenix.Component

  # The Logs screen is the hook's: the lines never pass through the
  # server's render — two thousand of them and a search box would
  # re-render across the socket on every keystroke — so the whole
  # screen is built once and left alone (phx-update="ignore").
  def logs_screen(assigns) do
    ~H"""
    <div class="logs" id="logs" phx-hook="Logs" phx-update="ignore">
      <div class="toolbar">
        <span id="svc-chips" style="display:inline-flex;gap:6px;flex-wrap:wrap"></span>
        <span class="sep"></span>
        <select id="level" aria-label="Level">
          <option value="error">Errors only</option>
          <option value="warn">Warnings and up</option>
          <option value="info">Info and up</option>
          <option value="debug" selected>All levels</option>
        </select>
        <input type="search" id="q" placeholder="Search the lines…" aria-label="Search" />
        <span class="sep"></span>
        <button class="btn" id="follow" type="button" aria-pressed="true">Following</button>
        <button class="btn" id="ts" type="button" aria-pressed="true">Timestamps</button>
        <button class="btn" id="clear" type="button">Clear</button>
      </div>
      <div class="logmeta">
        <span id="log-count"></span><span>docker compose logs --follow · the last 500 lines when the stream starts, then live · capped at 2 000 lines in the page</span>
      </div>
      <div class="viewport">
        <div class="lines" id="lines" aria-live="off"></div>
        <button class="newpill" id="newpill" type="button">↓ new lines</button>
      </div>
    </div>
    """
  end
end
