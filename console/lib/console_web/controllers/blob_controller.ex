defmodule ConsoleWeb.BlobController do
  @moduledoc """
  A file as a commit of the workspace has it — `git show REV:PATH` — for
  the drawings and images a cartridge wrote, shown in an `<img>` on the
  Files screen. The workspace is the status's; nothing outside its
  repository can be named, and only images are served.
  """
  use ConsoleWeb, :controller

  @shown ~w(.svg .png .jpg .jpeg .gif .webp)

  def show(conn, %{"rev" => rev, "path" => parts}) do
    path = Path.join(parts)
    workspace = Console.Workbench.workspace()

    cond do
      not Regex.match?(~r/^[0-9a-f]{7,40}$/, rev) -> send_resp(conn, 404, "no such revision")
      not is_binary(workspace) -> send_resp(conn, 404, "no workspace")
      String.contains?(path, "..") or String.downcase(Path.extname(path)) not in @shown -> send_resp(conn, 404, "no such blob")
      true ->
        case System.cmd("git", ["-C", workspace, "show", rev <> ":" <> path], stderr_to_stdout: true) do
          {data, 0} ->
            conn
            |> put_resp_content_type(MIME.from_path(path))
            |> put_resp_header("cache-control", "public, max-age=86400")
            |> put_resp_header("content-security-policy", "default-src 'none'; style-src 'unsafe-inline'; img-src data:")
            |> send_resp(200, data)

          _ -> send_resp(conn, 404, "no such blob")
        end
    end
  end
end
