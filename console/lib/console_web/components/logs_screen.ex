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
    <div class="logs logsp" id="logs" phx-hook="Logs" phx-update="ignore">
      <div class="viewport term-box">
        <%!-- The services on top, alone: which of them show. Empty until a
              service has written a line — the strip hides itself then. --%>
        <div class="toolbar controls top" id="svc-chips" aria-label="The services whose lines show">
        </div>
        <div class="lines" id="lines" aria-live="off"></div>
        <button class="newpill" id="newpill" type="button">↓ new lines</button>
        <%!-- The controls are the box's, under the lines: the services, the
              level, the search, the following, the stamps, the clearing
              (2026-09-12). --%>
        <div class="toolbar controls">
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
      </div>
      <%!-- The meta line under the box (2026-09-27; it sat above). --%>
      <div class="logmeta">
        <span id="log-count"></span><span>docker compose logs --follow · the last 500 lines when the stream starts, then live · capped at 2 000 lines in the page</span>
      </div>
    </div>
    """
  end
end
