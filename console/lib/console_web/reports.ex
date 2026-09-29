defmodule ConsoleWeb.Reports do
  @moduledoc """
  The pages a project's tools write for its reader — ExDoc's site under
  `doc/`, ExCoveralls' HTML report under `cover/` — served off the
  workspace by the console, so the project needs no route, no
  controller and no environment to be read. Which pages there are is
  what the inserted cartridges declare, the doors of the third kind
  (`{label, {:output, dir, index}}`): each is served at `/<label>/`,
  and nothing else of the workspace is — `.env` is in it.

  **On a listener of its own, a port apart from the console's.** Those
  pages carry the project's JavaScript; on the console's origin that
  script could read the page that runs `wb.sh --yes`. Another port is
  another origin: the console's socket refuses it (`check_origin` names
  the port), its CSRF token cannot be read across, and the pages keep
  a real origin of their own — ExDoc's `localStorage`, its search, its
  theme all work as they do on HexDocs. Nothing here reads the session,
  and nothing here can change anything: GET and HEAD only.
  (console/README.md, *The architecture, as settled*: the project's pages.)
  """
  use Plug.Builder, copy_opts_to_assign: :reports

  alias Console.Bench
  alias ConsoleWeb.Cartridges

  plug :hosts
  plug :headers
  plug :route

  @doc """
  The port the browser opens the pages on: the one `wb.sh console`
  publishes (`REPORTS_PUBLIC_PORT`), else the listener's own; nil where
  no listener is configured, as in the tests.
  """
  def port do
    case System.get_env("REPORTS_PUBLIC_PORT") do
      nil -> (Application.get_env(:console, :reports) || [])[:port]
      port -> String.to_integer(port)
    end
  end

  @doc """
  The output doors of what the project carries, whose condition holds:
  `%{label, dir, index}`, the first of a label when two say the same.
  """
  def outputs(status, catalog) do
    entry = fn c -> Enum.find(catalog || [], &(&1["name"] == c["name"])) || c end

    for c <- Cartridges.installed(status),
        d <- get_in(entry.(c), ["console", "doors"]) || [],
        o = d["output"],
        Cartridges.holds?(status, c, d),
        {:ok, dir} <- [safe(Cartridges.fill_path(o["dir"], c))] do
      %{label: d["label"], dir: dir, index: o["index"]}
    end
    |> Enum.uniq_by(& &1.label)
  end

  @doc """
  When an output's index was written, in the machine's own time zone —
  the offset carried with it, since the console and whoever reads it
  need not be in the same one. `nil` while it is not on disk.
  """
  def built(root, %{dir: dir, index: index}) when is_binary(root) do
    path = Path.join([root, dir, index])

    with {:ok, %File.Stat{type: :regular, mtime: local}} <- File.stat(path, time: :local),
         {:ok, %File.Stat{mtime: posix}} <- File.stat(path, time: :posix) do
      utc = DateTime.from_unix!(posix)
      # The same moment read twice, local and UTC: their difference is
      # the offset in force then — summer time included, which a zone
      # name alone would not say.
      offset = NaiveDateTime.diff(NaiveDateTime.from_erl!(local), DateTime.to_naive(utc))

      %{
        DateTime.add(utc, offset)
        | utc_offset: offset,
          std_offset: 0,
          zone_abbr: "",
          time_zone: "Etc/Unknown"
      }
    else
      _ -> nil
    end
  end

  def built(_root, _output), do: nil

  defp safe(rel) do
    case Path.safe_relative(rel) do
      {:ok, ""} -> :error
      other -> other
    end
  end

  # A name that resolves to 127.0.0.1 but is not localhost reaches this
  # port too (DNS rebinding): any page could then read the project's
  # docs. Only the loopback names are answered.
  defp hosts(conn, _) do
    if conn.host in ["localhost", "127.0.0.1", "[::1]", "::1"],
      do: conn,
      else: conn |> send_resp(421, "not this host") |> halt()
  end

  defp headers(conn, _) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("cross-origin-opener-policy", "same-origin")
    |> put_resp_header("content-security-policy", "frame-ancestors 'none'")
  end

  # The outputs and the root come from the bench, or from the caller's
  # options (the tests): `Reports.call(conn, outputs: [...], root: dir)`.
  defp route(%{method: method} = conn, _) when method not in ["GET", "HEAD"],
    do: conn |> send_resp(405, "read only") |> halt()

  defp route(conn, _) do
    opts = conn.assigns[:reports] || []
    root = Keyword.get_lazy(opts, :root, fn -> (Bench.status() || %{})["workspace"] end)
    outputs = Keyword.get_lazy(opts, :outputs, fn -> outputs(Bench.status(), Bench.catalog()) end)

    case conn.path_info do
      [] ->
        index(conn, root, outputs)

      [label | rest] ->
        case Enum.find(outputs, &(&1.label == label)) do
          %{} = o when is_binary(root) -> serve(conn, Path.join(root, o.dir), rest, o.index)
          _ -> conn |> send_resp(404, "no such page") |> halt()
        end
    end
  end

  # `/docs` → `/docs/`, so the pages' relative links resolve inside it.
  defp serve(%{request_path: path} = conn, base, [], index) do
    if String.ends_with?(path, "/"),
      do: serve_file(conn, Path.join(base, index)),
      else: conn |> put_resp_header("location", path <> "/") |> send_resp(301, "") |> halt()
  end

  defp serve(conn, base, rest, index) do
    case safe(Path.join(rest)) do
      {:ok, rel} ->
        file = Path.join(base, rel)
        serve_file(conn, if(File.dir?(file), do: Path.join(file, index), else: file))

      :error ->
        conn |> send_resp(404, "no such page") |> halt()
    end
  end

  defp serve_file(conn, file) do
    if File.regular?(file) do
      conn
      |> put_resp_content_type(MIME.from_path(file), nil)
      |> put_resp_header("cache-control", "no-cache")
      |> send_file(200, file)
      |> halt()
    else
      conn |> send_resp(404, "no such page") |> halt()
    end
  end

  # The root names what there is, for whoever opens the port bare; the
  # console's doors link each page directly.
  defp index(conn, root, outputs) do
    rows =
      for o <- outputs, built = built(root, o) do
        ~s|<li><a href="/#{o.label}/">#{o.label}</a> — <code>#{o.dir}/</code>, built #{NaiveDateTime.to_string(built)}</li>|
      end

    body = """
    <!doctype html><meta charset="utf-8"><title>Pages</title>
    <ul>#{if rows == [], do: "<li>Nothing built yet.</li>", else: rows}</ul>
    """

    conn |> put_resp_content_type("text/html") |> send_resp(200, body) |> halt()
  end
end
