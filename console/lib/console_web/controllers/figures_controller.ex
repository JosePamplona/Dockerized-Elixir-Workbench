defmodule ConsoleWeb.FiguresController do
  @moduledoc """
  Serves what a cartridge's papers show — the diagrams under
  `assets/diagrams/`, an image beside a paper — off the mounted
  workbench, by a path relative to its root, so a drawing goes in an
  `<img>` and never inline (console/README.md). Only images, and only
  from where a paper may point.
  """
  use ConsoleWeb, :controller

  @shown ~w(.svg .png .jpg .jpeg .gif .webp)
  @from ["assets/", "igniter/lib/workbench_igniter/features/"]

  def show(conn, %{"path" => parts}) do
    root = Console.Workbench.dir()
    path = Path.expand(Path.join(parts), root)
    rel = Path.relative_to(path, root)

    if String.starts_with?(path, root <> "/") and Enum.any?(@from, &String.starts_with?(rel, &1)) and
         File.regular?(path) and String.downcase(Path.extname(path)) in @shown do
      conn
      |> put_resp_content_type(MIME.from_path(path))
      |> put_resp_header("cache-control", "public, max-age=3600")
      # An SVG opened as a document could run script; this policy holds
      # even where it is opened on its own, outside an <img>.
      |> put_resp_header(
        "content-security-policy",
        "default-src 'none'; style-src 'unsafe-inline'; img-src data:"
      )
      |> send_file(200, path)
    else
      send_resp(conn, 404, "no such figure")
    end
  end
end
