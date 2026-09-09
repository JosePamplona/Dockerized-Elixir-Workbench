defmodule ConsoleWeb.Doors do
  @moduledoc """
  The project's doors as a paper: the plan of every address the project
  answers to, and what each answered when the console called.

  The rail's Doors section is the bell — the doors open right now,
  pressable. This is the map, and it says what the rail cannot afford
  to: the doors a cartridge keeps shut and what would open them, the
  doors of the cartridges not yet in, the workbench's own two addresses,
  and the port they all sit on for the deployment that is up. Nothing
  here is hidden for being shut: a shut door is drawn unlit, with its
  reason. A health endpoint is a door like the rest: the project's
  route, read and called, never a probe kept for the workbench.
  """

  alias ConsoleWeb.Cartridges

  @doc """
  The plan, off the status and the catalog: `own` (the workbench's app,
  pgAdmin and Grafana), `open` and `shut` (every door of every inserted
  cartridge, sorted by whether it can be pressed), `waiting` (the doors
  of the cartridges not in, each saying which insert opens it). Nil
  without a status.
  """
  def page(nil, _catalog), do: nil

  def page(status, catalog) do
    port = get_in(status, ["ports", "app"])
    up = Cartridges.app_up?(status)
    base = port && "http://localhost:#{port}"
    installed = Cartridges.installed(status)
    entry = fn c -> Enum.find(catalog, &(&1["name"] == c["name"])) || c end

    doors =
      for c <- installed,
          d <- get_in(entry.(c), ["console", "doors"]) || [],
          do: door(status, c, d, base, up)

    %{
      port: port,
      up: up,
      deployment: status["deployment"],
      own: own(status, base, up),
      open: Enum.reject(doors, & &1.why),
      shut: Enum.filter(doors, & &1.why),
      waiting: waiting(status, catalog)
    }
  end

  # The doors of the cartridges not in: each says which insert opens it.
  defp waiting(status, catalog) do
    for e <- catalog,
        !Cartridges.installed?(status, e["name"]),
        d <- get_in(e, ["console", "doors"]) || [] do
      %{
        label: d["label"],
        path: Cartridges.fill_path(d["path"], e),
        href: nil,
        who: e["name"],
        why: "insert #{e["name"]} first"
      }
    end
  end

  # The workbench's own addresses: the app, and pgAdmin and Grafana when
  # they have a port. All ride the deployment: with nothing up, none
  # answers.
  defp own(status, base, up) do
    [%{label: "app", path: "localhost:#{get_in(status, ["ports", "app"])}", href: up && base}] ++
      for {label, key} <- [{"pgAdmin", "pgadmin"}, {"Grafana", "grafana"}],
          port = get_in(status, ["ports", key]) do
        %{label: label, path: "localhost:#{port}", href: up && "http://localhost:#{port}"}
      end
  end

  # One door of an inserted cartridge: shut by its condition, or by the
  # app being down, or open with its address.
  defp door(status, c, d, base, up) do
    path = Cartridges.fill_path(d["path"], c)

    why =
      cond do
        !Cartridges.holds?(status, c, d) ->
          if d["when"]["with"],
            do: "only with --with #{d["when"]["with"]}",
            else: "only with #{d["when"]["cartridge"]} inserted"

        !up ->
          "the app is down"

        true ->
          nil
      end

    %{
      label: d["label"],
      path: path,
      href: is_nil(why) && base && base <> path,
      who: c["name"],
      why: why
    }
  end

  @doc "The addresses of a plan the console can call: the open doors' and its own."
  def hrefs(page),
    do: for(x <- page.own ++ page.open, is_binary(x.href), uniq: true, do: x.href)

  @doc """
  What each address answered, called once: the status code as a chip's
  words and class — 2xx and 3xx good, 4xx warn, 5xx bad — or `no answer`.
  Every call has a short leash; the whole round waits for none of them
  past four seconds.

  The addresses are the reader's — `localhost` and the published port,
  what their browser opens — and the console calls the same door by the
  name it has for the host (`Console.Cluster.host/0`: `APP_HOST`, which
  is `host.docker.internal` inside its container, where `localhost` is
  the console itself), naming `localhost` in the request as the browser
  would, so a `force_ssl` endpoint answers as it answers the reader.
  """
  def read(hrefs) do
    Application.ensure_all_started(:inets)

    hrefs
    |> Task.async_stream(&{&1, call(&1)}, timeout: 4_000, on_timeout: :kill_task, ordered: false)
    |> Enum.map(fn
      {:ok, {href, read}} -> {href, read}
      {:exit, _} -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp call(href) do
    url = String.replace_prefix(href, "http://localhost:", "http://#{Console.Cluster.host()}:")

    case :httpc.request(
           :get,
           {String.to_charlist(url), [{~c"host", ~c"localhost"}]},
           [timeout: 2_500, connect_timeout: 1_500, autoredirect: false],
           body_format: :binary
         ) do
      {:ok, {{_, code, _}, _, _}} -> {Integer.to_string(code), class(code)}
      {:error, _} -> {"no answer", "bad"}
    end
  end

  defp class(code) when code < 400, do: "good"
  defp class(code) when code < 500, do: "warn"
  defp class(_), do: "bad"
end
