defmodule ConsoleWeb.ConsoleLive.Drawer do
  @moduledoc """
  The workbench's drawer, off the page: which of its papers the URL
  opens, the config as a form with its edits, and the three fields that
  go out to the internet — the stacks, the installers and the Node
  majors.
  """
  import Phoenix.Component, only: [assign: 2]

  alias Console.{Bench, Jobs, Papers}

  # The workbench's drawer, over whatever screen: ?wb=config|manual|ui,
  # under Manual which paper — the same shape as a box's
  # ?screen=manual&paper=readme, because it is the same thing — and
  # under Interface which part (2026-09-29), kept the same way.
  # The papers used to be flat tabs of their own. A link that still names
  # one — a bookmark, or the README's own "see the CHANGELOG" — is the
  # paper it asks for, under Manual.
  def take(socket, %{"wb" => key} = params) when key in ~w(readme changelog),
    do: take(socket, %{params | "wb" => "manual"} |> Map.put("paper", key))

  def take(socket, %{"wb" => key} = params) when key in ~w(config manual ui) do
    papers = Papers.workbench_papers() |> Enum.map(&elem(&1, 0))
    # With a box open over the drawer, `paper` in the address is the
    # box's manual's: the drawer stays on the one it was on.
    named = if is_binary(params["box"]), do: nil, else: params["paper"]
    paper = kept(named, socket, :wbpaper, papers)
    part = kept(params["part"], socket, :wbpart, ConsoleWeb.WorkbenchDrawer.part_keys())

    assign(socket,
      wb: key,
      wbpaper: paper,
      wbpart: part,
      wbpage: if(key == "manual", do: Papers.render_workbench(paper))
    )
  end

  def take(socket, _params), do: assign(socket, wb: nil, wbpage: nil)

  # What the URL names, if it is one; else, with the drawer already
  # open, what it was on — Config's link carries none, and Manual came
  # back on README (2026-09-29); else the first.
  defp kept(named, socket, key, allowed) do
    cond do
      named in allowed -> named
      socket.assigns.wb && socket.assigns[key] in allowed -> socket.assigns[key]
      true -> hd(allowed)
    end
  end

  # --- the workbench's config, as a form ---
  def event("cfg_change", params, socket) do
    values = Console.Config.values(socket.assigns.config)
    edits = params["cfg"] || %{}

    # The stack sets the three versions at once — but only when the stack
    # is what was touched. The whole form travels on every change, so the
    # stack's own value came along when the reader moved one of the three
    # and overwrote it with the tag the stack still showed: picking an
    # Erlang put the old Erlang straight back, and nothing on the row
    # ever moved. `_target` is which field fired, and it is the answer.
    edits =
      with ["stack"] <- params["_target"],
           tag when is_binary(tag) and tag != "" <- params["stack"],
           [%{e: e, o: o, d: d}] <- ConsoleWeb.WorkbenchDrawer.parse_tag(tag) do
        edits
        |> Map.put("ELIXIR_VERSION", e)
        |> Map.put("ERLANG_VERSION", o)
        |> Map.put("DEBIAN_VERSION", d)
      else
        _ -> edits
      end

    edits = for {k, v} <- edits, Map.has_key?(values, k), v != values[k], into: %{}, do: {k, v}
    {:noreply, assign(socket, cfg_edits: edits)}
  end

  # The one place in the console where a page reaches the internet, and
  # it only does it here: five pages of Docker Hub's API, because the
  # reader pressed the button that says so.
  def event("stacks_ask", _, socket) do
    Bench.refresh(:stacks)
    {:noreply, assign(socket, stacks_asking: true, stacks_error: nil)}
  end

  def event("installers_ask", _, socket) do
    Bench.refresh(:installers)
    {:noreply, assign(socket, installers_asking: true, installers_error: nil)}
  end

  def event("nodes_ask", _, socket) do
    Bench.refresh(:nodes)
    {:noreply, assign(socket, nodes_asking: true, nodes_error: nil)}
  end

  def event("cfg_reload", _, socket), do: {:noreply, assign(socket, cfg_edits: %{})}

  def event("cfg_raw", _, socket),
    do: {:noreply, assign(socket, cfg_raw: not socket.assigns.cfg_raw)}

  def event("cfg_save", _, socket) do
    if socket.assigns.cfg_edits != %{} do
      Jobs.run({:config, nil}, [
        "config",
        "set" | Enum.map(socket.assigns.cfg_edits, fn {k, v} -> "#{k}=#{v}" end)
      ])
    end

    {:noreply, socket}
  end

  # --- what arrives ---------------------------------------------------------

  # The stacks, the installers and the Node majors, asked for by
  # pressing the button beside their field.
  def info({:bench, :stacks, tags}, socket),
    do: {:noreply, assign(socket, stacks: tags, stacks_asking: false, stacks_error: nil)}

  def info({:bench, :error, :stacks, why}, socket),
    do: {:noreply, assign(socket, stacks_asking: false, stacks_error: why)}

  def info({:bench, :installers, releases}, socket),
    do:
      {:noreply,
       assign(socket, installers: releases, installers_asking: false, installers_error: nil)}

  def info({:bench, :error, :installers, why}, socket),
    do: {:noreply, assign(socket, installers_asking: false, installers_error: why)}

  def info({:bench, :nodes, majors}, socket),
    do: {:noreply, assign(socket, nodes: majors, nodes_asking: false, nodes_error: nil)}

  def info({:bench, :error, :nodes, why}, socket),
    do: {:noreply, assign(socket, nodes_asking: false, nodes_error: why)}
end
