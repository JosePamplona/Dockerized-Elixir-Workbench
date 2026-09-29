defmodule ConsoleWeb.Plugs.CSP do
  @moduledoc """
  The content security policy, on every page. What it holds: a script
  runs only from this origin or with this response's nonce, so an
  `onload=` that gets through a renderer — a cartridge's README, an
  option's doc — does not run even then. Styles allow inline
  attributes (`style="--svc:…"` is how a log line takes its service's
  colour) and the type comes from Google Fonts. Images
  may be `data:` (a drawing put in an `<img>` as its own text) and
  `blob:`. Nothing may frame the console.

  The nonce is assigned as `:csp_nonce` for the root layout's script tag.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    policy =
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        "font-src 'self' https://fonts.gstatic.com data:",
        "img-src 'self' data: blob:",
        "connect-src 'self'",
        "frame-src 'self'",
        "frame-ancestors 'none'",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy)
  end
end
