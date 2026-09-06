defmodule ConsoleWeb.ConsoleLive.Hand do
  @moduledoc """
  The box in hand, off the page: which box the URL names and which of
  its screens, its options as filled, a collection's recipe, what it
  wrote, and the insert or eject the reader asks for.
  """
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_patch: 2, start_async: 3]

  alias Console.{Bench, Diffs, Jobs, Papers}
  alias ConsoleWeb.{Box, Cartridges}

  # The box in hand, and which of its screens, from the query: a box
  # named anywhere opens over whatever screen the reader is on, and the
  # browser's back is the trail back. A collection asks the project
  # what its recipe leaves to insert (expand: seconds) when it is picked
  # up, never again per keystroke.
  def take(socket, %{"box" => name} = params) do
    box = Enum.find(socket.assigns.catalog, &(&1["name"] == name))
    same = socket.assigns.box && socket.assigns.box["name"] == name

    cond do
      is_nil(box) and socket.assigns.catalog == [] ->
        assign(socket, pending_box: params)

      is_nil(box) ->
        socket |> assign(box: nil) |> push_patch(to: "/#{socket.assigns.tab}")

      true ->
        open(socket, box, params, same)
    end
  end

  def take(socket, _params), do: assign(socket, box: nil, page: nil, pending_box: nil)

  # The box opened on the screen the query names; a box just picked up
  # starts with its form blank and its recipe asked.
  defp open(socket, box, params, same) do
    name = box["name"]

    screen =
      if params["screen"] in ~w(box install files manual), do: params["screen"], else: "box"

    papers = Papers.carried(name)

    paper =
      if params["paper"] in papers, do: params["paper"], else: List.first(papers) || "readme"

    page = if screen == "manual", do: Papers.render(name, paper)

    socket =
      if same,
        do: socket,
        else: socket |> assign(args: %{}, face: "front", recipe: nil) |> ask_recipe(box, %{})

    socket =
      assign(socket,
        box: box,
        screen: screen,
        papers: papers,
        paper: paper,
        page: page,
        pending_box: nil
      )

    if screen == "files", do: ask_diff(socket, box), else: socket
  end

  # What the cartridge wrote, read off the workspace's git in the
  # background: a collection reads every pick's commit and the range.
  def ask_diff(socket, box) do
    status = socket.assigns.status
    ws = status && status["workspace"]

    cond do
      is_nil(ws) or Box.files_unlit(box, status) ->
        assign(socket, diff: nil)

      box["collection"] ->
        inserts = Box.member_inserts(box, status)

        socket
        |> assign(diff: :loading)
        |> start_async({:diff, box["name"]}, fn -> Diffs.collection(ws, inserts) end)

      true ->
        insert = Cartridges.insert(status, box["name"])

        socket
        |> assign(diff: :loading)
        |> start_async({:diff, box["name"]}, fn -> Diffs.cartridge(ws, insert) end)
    end
  end

  defp ask_recipe(socket, %{"collection" => true} = box, args) do
    case Bench.expand(box["name"], Box.argv(box, args)) do
      {:ok, plan} -> assign(socket, recipe: plan)
      :asking -> assign(socket, recipe: :asking)
    end
  end

  defp ask_recipe(socket, _box, _args), do: socket

  # --- what the reader does ---------------------------------------------------

  def event("flip", _, socket),
    do:
      {:noreply,
       assign(socket, face: if(socket.assigns.face == "front", do: "back", else: "front"))}

  # The form as filled, kept as option name to value; a collection's
  # recipe is asked again when a choice moved, since that is what
  # chooses its members.
  def event("options", params, socket) do
    args =
      Map.merge(
        params["opt"] || %{},
        Map.new(params["other"] || %{}, fn {k, v} -> {"other:" <> k, v} end)
      )

    box = socket.assigns.box
    moved = box["collection"] and Box.argv(box, args) != Box.argv(box, socket.assigns.args)
    socket = assign(socket, args: args)
    {:noreply, if(moved, do: ask_recipe(socket, box, args), else: socket)}
  end

  def event("insert", _params, socket) do
    box = socket.assigns.box
    Jobs.run({:insert, box["name"]}, ["add", box["name"] | Box.argv(box, socket.assigns.args)])
    {:noreply, socket}
  end

  # A collection leaves no commit of its own: its Eject is its members',
  # newest first — one job each, in the queue's order. One that refuses
  # (files changed since, a dependent) leaves the tree clean, and the
  # next either goes or refuses on its own.
  def event("eject", %{"name" => name}, socket) do
    box = socket.assigns.box

    if box && box["collection"] do
      names =
        if(is_list(socket.assigns.recipe), do: socket.assigns.recipe, else: []) ++
          (box["members"] || [])

      names = names |> Enum.map(& &1["name"]) |> MapSet.new()

      for i <- get_in(socket.assigns.status, ["git", "inserts"]) || [],
          MapSet.member?(names, i["feature"]),
          do: Jobs.run({:eject, i["feature"]}, ["eject", i["feature"]])
    else
      Jobs.run({:eject, name}, ["eject", name])
    end

    {:noreply, socket}
  end

  # --- what arrives ---------------------------------------------------------

  # The recipe expand answered, if it is still the box in hand with these options.
  def info({:bench, :expand, name, argv, plan}, socket) do
    box = socket.assigns.box

    if box && box["name"] == name && Box.argv(box, socket.assigns.args) == argv,
      do: {:noreply, assign(socket, recipe: plan)},
      else: {:noreply, socket}
  end

  def info({:bench, :error, {:expand, _, _}, _why}, socket),
    do: {:noreply, assign(socket, recipe: nil)}

  def async({:diff, name}, {:ok, diff}, socket) do
    if socket.assigns.box && socket.assigns.box["name"] == name,
      do: {:noreply, assign(socket, diff: diff)},
      else: {:noreply, socket}
  end

  def async({:diff, _}, {:exit, why}, socket),
    do:
      {:noreply, assign(socket, diff: nil, error: "the diff could not be read: " <> inspect(why))}
end
