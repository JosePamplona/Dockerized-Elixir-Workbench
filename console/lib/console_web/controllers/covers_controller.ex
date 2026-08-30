defmodule ConsoleWeb.CoversController do
  @moduledoc "Serves the box covers straight from the workbench's assets/covers."
  use ConsoleWeb, :controller

  def show(conn, %{"path" => parts}) do
    root = Console.Workbench.covers_dir()
    path = Path.expand(Path.join(parts), root)

    if String.starts_with?(path, root <> "/") and File.regular?(path) do
      conn
      |> put_resp_content_type(MIME.from_path(path))
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> send_file(200, path)
    else
      send_resp(conn, 404, "no such cover")
    end
  end
end
