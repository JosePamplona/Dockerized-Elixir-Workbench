defmodule ConsoleWeb.Cartridges do
  @moduledoc """
  What the page works out of the status and the catalog about a
  cartridge: whether the project carries it, what it opened in the
  console, how it got here. All read off the two contracts; nothing
  here is a second opinion about what is installed.
  """

  @doc "The catalog entries the project carries (status's, with `installed` and `state`)."
  def installed(nil), do: []

  def installed(status),
    do: Enum.filter(get_in(status, ["project", "cartridges"]) || [], & &1["installed"])

  def installed?(status, name), do: Enum.any?(installed(status), &(&1["name"] == name))

  @doc "The status's entry for a cartridge, installed or not."
  def carried(status, name),
    do: Enum.find(get_in(status, ["project", "cartridges"]) || [], &(&1["name"] == name))

  @doc "The insert commit of a cartridge, when it went in by commit."
  def insert(nil, _name), do: nil

  def insert(status, name),
    do: Enum.find(get_in(status, ["git", "inserts"]) || [], &(&1["feature"] == name))

  @doc """
  What a container is doing, as a chip's words and class, off what
  `docker compose ps` says: `healthy`, `running` without a healthcheck,
  good; `starting`, a warn that pulses; `unhealthy`, bad. Exited with
  code 0 is an absence — a Stop, a `migrate` that did its job — and
  wears `.off`; exited otherwise is bad, with the code on the chip, so
  the number says what to look at. The title is Docker's own line.
  """
  def container_reading(c) do
    health = if(c["Health"] in [nil, ""], do: nil, else: c["Health"])
    state = c["State"] || ""
    code = c["ExitCode"]

    # Health is read only while the container runs: Docker stops probing
    # a stopped one and keeps the last answer, so an app that crashed
    # reads `unhealthy` next to its `Exited (1)`.
    cond do
      state == "running" and health == "healthy" -> {"healthy", "good"}
      state == "running" and health == "starting" -> {"starting", "warn busy"}
      state == "running" and health == "unhealthy" -> {"unhealthy", "bad"}
      state == "running" -> {"running", "good"}
      state == "exited" and code in [0, nil] -> {"exited", "off"}
      state == "exited" -> {"exited #{code}", "bad"}
      state in ["created", "paused", "restarting"] -> {state, "warn"}
      true -> {state, "bad"}
    end
  end

  @doc "Whether the app is up: an app container running, whichever deployment."
  def app_up?(nil), do: false
  def app_up?(status), do: status["deployment"] != nil

  @doc """
  What each inserted cartridge adds to the console, off the manifest's
  `console/0` as the catalog carries it: `[{entry, item}]` for `kind`
  in doors, tabs — only the items whose condition holds.
  """
  def contributions(status, catalog, kind) do
    for c <- installed(status),
        entry = Enum.find(catalog, &(&1["name"] == c["name"])) || c,
        item <- get_in(entry, ["console", kind]) || [],
        holds?(status, c, item),
        do: {c, item}
  end

  # A door's `when`: with an option value, or with another cartridge in.
  # The item is unwrapped once — only a map that carries a `when` — and
  # the condition itself is read by its key; an item without one holds.
  def holds?(status, c, %{"when" => condition}), do: holds?(status, c, condition)
  def holds?(_status, c, %{"with" => value}), do: value in (get_in(c, ["state", "with"]) || [])
  def holds?(status, _c, %{"cartridge" => name}), do: installed?(status, name)
  def holds?(_, _, _), do: true

  @doc "`{option}` in a path: the option's value as the project reports it, or its default."
  def fill_path(path, c) do
    Regex.replace(~r/\{(\w+)\}/, path, fn _, o ->
      to_string(
        get_in(c, ["state", o]) ||
          (Enum.find(c["options"] || [], &(&1["name"] == o)) || %{})["default"] || ""
      )
    end)
  end

  @doc """
  How a cartridge got here, which is also whether the workbench can
  take it back: `{word, chip class, why}`.
  """
  def origin(status, c) do
    cond do
      i = insert(status, c["name"]) ->
        {"by commit", "",
         "git revert #{String.slice(i["sha"], 0, 7)} — #{i["subject"]} · #{i["date"]}"}

      c["collection"] ->
        {"collection", "off",
         "the box leaves no commit of its own: eject its cartridges, not the collection"}

      get_in(status, ["project", "phx", c["name"]]) == true ->
        {"from birth", "off", "came with the project: phx.new generated it — nothing to eject"}

      true ->
        {"by hand", "off", "inserted by hand: no commit to eject"}
    end
  end

  @doc "What is true of a box: not done, a collection of N, base."
  def facts(e) do
    [
      e["pending"] && "not done",
      e["collection"] && "inserts #{length(e["members"] || [])}",
      e["base"] && "base"
    ]
    |> Enum.filter(&is_binary/1)
  end

  @doc "The catalog entries phx.new decides: the base cartridges."
  def base(catalog), do: Enum.filter(catalog, & &1["base"])
end
