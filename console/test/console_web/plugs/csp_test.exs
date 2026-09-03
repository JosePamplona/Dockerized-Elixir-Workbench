defmodule ConsoleWeb.Plugs.CSPTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  test "sets a policy with a nonce, and assigns the nonce for the layout" do
    conn = ConsoleWeb.Plugs.CSP.call(conn(:get, "/"), [])
    [policy] = get_resp_header(conn, "content-security-policy")
    nonce = conn.assigns.csp_nonce
    assert policy =~ "script-src 'self' 'nonce-#{nonce}'"
    assert policy =~ "frame-ancestors 'none'"
    refute policy =~ "script-src 'self' 'unsafe-inline'"
  end

  test "every response gets its own nonce" do
    a = ConsoleWeb.Plugs.CSP.call(conn(:get, "/"), []).assigns.csp_nonce
    b = ConsoleWeb.Plugs.CSP.call(conn(:get, "/"), []).assigns.csp_nonce
    assert a != b
  end
end
