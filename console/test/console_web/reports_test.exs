defmodule ConsoleWeb.ReportsTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias ConsoleWeb.Reports

  @moduletag :tmp_dir

  @docs %{label: "docs", dir: "doc", index: "index.html"}
  @coverage %{label: "coverage", dir: "cover", index: "excoveralls.html"}

  setup %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "doc/dist"))
    File.write!(Path.join(root, "doc/index.html"), "<p>docs</p>")
    File.write!(Path.join(root, "doc/dist/app.js"), "1")
    File.write!(Path.join(root, ".env"), "SECRET=1")
    :ok
  end

  defp get(root, path, opts \\ []) do
    {host, opts} = Keyword.pop(opts, :host, "localhost")

    conn(:get, path)
    |> Map.put(:host, host)
    |> Reports.call(Keyword.merge([root: root, outputs: [@docs, @coverage]], opts))
  end

  test "a page is served at its label, off the dir its door names", %{tmp_dir: root} do
    assert %{status: 301} = conn = get(root, "/docs")
    assert Plug.Conn.get_resp_header(conn, "location") == ["/docs/"]
    assert %{status: 200, resp_body: "<p>docs</p>"} = get(root, "/docs/")
    assert %{status: 200} = conn = get(root, "/docs/dist/app.js")
    assert ["text/javascript" <> _] = Plug.Conn.get_resp_header(conn, "content-type")
  end

  test "an output not built yet is not there, and one no door names never is", %{tmp_dir: root} do
    assert %{status: 404} = get(root, "/coverage/")
    File.mkdir_p!(Path.join(root, "cover"))
    File.write!(Path.join(root, "cover/excoveralls.html"), "cov")
    assert %{status: 200, resp_body: "cov"} = get(root, "/coverage/")
    assert %{status: 404} = get(root, "/coverage/", outputs: [@docs])
  end

  test "nothing outside a page's dir is named", %{tmp_dir: root} do
    assert %{status: 404} = get(root, "/docs/../.env")
    assert %{status: 404} = get(root, "/.env")
    assert %{status: 404} = get(root, "/docs/%2e%2e/.env")
    assert %{status: 404} = get(nil, "/docs/")
  end

  test "read only, loopback names only, never framed", %{tmp_dir: root} do
    assert %{status: 405} =
             conn(:post, "/docs/")
             |> Map.put(:host, "localhost")
             |> Reports.call(root: root, outputs: [@docs])

    assert %{status: 421} = get(root, "/docs/", host: "rebound.example")

    assert Plug.Conn.get_resp_header(get(root, "/docs/"), "content-security-policy") ==
             ["frame-ancestors 'none'"]
  end

  test "the bare port lists what is built", %{tmp_dir: root} do
    assert %{status: 200, resp_body: body} = get(root, "/")
    assert body =~ ~s|href="/docs/"|
    refute body =~ "coverage"
  end

  test "the outputs are the inserted cartridges' output doors, whose condition holds" do
    status = %{
      "project" => %{
        "cartridges" => [
          %{"name" => "exdoc", "installed" => true},
          %{"name" => "coverage", "installed" => true},
          %{"name" => "mailer", "installed" => true},
          %{"name" => "gone", "installed" => false}
        ]
      }
    }

    output = fn label, dir, index, extra ->
      Map.merge(
        %{"label" => label, "path" => dir <> "/", "output" => %{"dir" => dir, "index" => index}},
        extra
      )
    end

    catalog = [
      %{
        "name" => "exdoc",
        "console" => %{"doors" => [output.("docs", "doc", "index.html", %{})]}
      },
      %{
        "name" => "coverage",
        "console" => %{
          "doors" => [
            output.("coverage", "cover", "excoveralls.html", %{
              "when" => %{"cartridge" => "gone"}
            }),
            output.("escape", "../etc", "passwd", %{})
          ]
        }
      },
      %{
        "name" => "mailer",
        "console" => %{"doors" => [%{"label" => "mailbox", "path" => "/dev/mailbox"}]}
      },
      %{"name" => "gone", "console" => %{"doors" => [output.("gone", "gone", "index.html", %{})]}}
    ]

    assert Reports.outputs(status, catalog) == [@docs]
  end
end
