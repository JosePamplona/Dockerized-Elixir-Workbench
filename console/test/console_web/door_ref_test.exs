defmodule ConsoleWeb.DoorRefTest do
  @moduledoc """
  The one way the console writes an address: the plate of a service, a
  route or a page on disk. What is asked here is the page's own button —
  the only thing on a plate that does something other than open it — and
  that the plate is pressable where it looks pressable.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import ConsoleWeb.Refs

  defp page(opts) do
    render_component(
      &door_ref/1,
      Keyword.merge(
        [label: "docs", path: "doc/", kind: "output", build: "docs", href: nil],
        opts
      )
    )
  end

  # The button is named as the project runs it (2026-10-07). It read
  # *build* and *rebuild*, which said the page's state and hid the
  # command — two of them, on a coverage page. The state is the stamp's.
  test "the button wears its command, whether the page is written or not" do
    for read <- [nil, {"2026-09-26 11:20", ""}] do
      html = page(read: read)

      assert html =~ ~r{<button[^>]*class="read build"[^>]*>\s*mix docs\s*</button>}
      refute html =~ ">build</button>"
      refute html =~ ">rebuild</button>"
    end

    assert page(read: nil) =~ "writes this page in the workspace, as a job"
    assert page(read: {"2026-09-26 11:20", ""}) =~ "workspace again, as a job"
  end

  # A page is a plate of two rows: the address, and under it its file.
  test "a page's file is a row of its own under the address" do
    html = page(read: {"2026-09-26 11:20", ""}, href: "http://localhost:4101/docs/")

    assert html =~ ~r{class="door-ref door-output two"}
    assert html =~ ~r{<span class="row1">.*<b>docs</b>.*</span>\s*<span class="row2">}s
    # The stamp and the command are the second row's, in that order.
    assert html =~
             ~r{<span class="row2">\s*<i[^>]*class="read file written"[^>]*>\s*2026-09-26 11:20\s*</i>\s*<button}s

    # Nothing of the file is left in the first.
    [row1, _] = String.split(html, ~s(<span class="row2">), parts: 2)
    refute row1 =~ "2026-09-26 11:20"
    refute row1 =~ "read build"
  end

  test "the stamp says the file and when it was written, and without one that it is missing" do
    there = %{file: "doc/index.html", written: "2026-09-26 11:20", state: "written", why: nil}
    written = page(read: {"2026-09-26 11:20", ""}, filed: there)
    assert written =~ ~s(title="doc/index.html · written 2026-09-26 11:20")
    assert written =~ ~r{class="read file written"}

    gone = %{file: "doc/index.html", written: nil, state: "missing", why: nil}
    missing = page(read: nil, filed: gone, why: "nothing built in doc/ yet")

    assert missing =~
             ~r{<i[^>]*class="read file missing"[^>]*title="missing · doc/index.html · mix docs writes it"[^>]*>\s*</i>}

    # A page nobody says how to write is missing, and that is all.
    bare = render_component(&door_ref/1, label: "docs", path: "doc/", kind: "output", href: nil)
    assert bare =~ ~s(title="missing · doc/")
    refute bare =~ "read build"
  end

  # One title for every door with a file, in one order: the state, the
  # file, when it was written, and why it is behind.
  test "a file known to be up to date or behind says so, in the mark, the ink and the title" do
    door = fn filed ->
      render_component(&door_ref/1,
        label: "mcp",
        path: "/x/mcp",
        port: 4011,
        kind: "route",
        href: "http://localhost:4011/x/mcp",
        client: [],
        build: "mcp.json",
        filed: filed
      )
    end

    up = door.(%{file: ".mcp.json", written: "2026-10-07 00:08", state: "up to date", why: nil})
    assert up =~ ~r{class="read file written good"}
    assert up =~ ~s(title="up to date · .mcp.json · written 2026-10-07 00:08")

    behind =
      door.(%{
        file: ".mcp.json",
        written: "2026-10-05 18:40",
        state: "behind",
        why: "the address is :4011/x/mcp now"
      })

    assert behind =~ ~r{class="read file behind warn"}

    assert behind =~
             ~s(title="behind · .mcp.json · written 2026-10-05 18:40 · the address is :4011/x/mcp now")

    missing = door.(%{file: ".mcp.json", written: nil, state: "missing", why: nil})
    assert missing =~ ~s(title="missing · .mcp.json · mix mcp.json writes it")
    # The stamp comes before the command, in the second row.
    assert missing =~
             ~r{<span class="row2">\s*<i[^>]*class="read file missing"[^>]*>\s*</i>\s*<button}s
  end

  # With no page the address is what is unlit; the plate says so, and
  # the stylesheet dims its first row alone, the command still to press.
  test "a page that is not written is unlit by its address, and keeps its command" do
    html = page(read: nil, why: "nothing built in doc/ yet")

    assert html =~ ~r{class="door-ref door-output two unlit"}
    assert html =~ ~s(phx-click="run")
    refute html =~ ~r{<button[^>]*disabled}
  end

  # The command is the project's own.
  test "it runs the cartridge's own Mix task, and nothing else" do
    for read <- [nil, {"2026-09-26 11:20", ""}] do
      html = page(read: read)
      assert html =~ ~s(phx-value-args="mix docs")
      assert html =~ "./wb.sh mix docs"
    end
  end

  # A plate with nothing to build has no button at all: a service and a
  # route are opened, never written.
  test "a plate that writes nothing carries no button" do
    html =
      render_component(&door_ref/1,
        label: "app",
        path: "localhost:4001",
        kind: "port",
        href: "http://localhost:4001",
        read: {"running", "good"}
      )

    refute html =~ "read build"
    # It is a plate of one row, as it always was.
    refute html =~ ~s(class="row1")
    assert html =~ ~r{class="door-ref door-port"}
  end

  # The layer is a drawing from the sprite, one a kind (2026-10-02): it
  # was a square in the layer's colour, the logs' service swatch, and
  # was taken for it.
  test "each layer wears its own drawing" do
    for {kind, mark} <- [
          {"port", "rack-net"},
          {"inside", "rack"},
          {"route", "globe"},
          {"output", "page"}
        ] do
      html = render_component(&door_ref/1, label: "app", path: "localhost:4001", kind: kind)

      assert html =~
               ~r{<svg[^>]*class="layer"[^>]*><use href="/images/icons.svg##{mark}"}
    end
  end

  test "every drawing a layer names is in the sprite" do
    sprite = File.read!(Path.join(:code.priv_dir(:console), "static/images/icons.svg"))

    for mark <- ~w(rack-net rack globe page) do
      assert sprite =~ ~s(<symbol id="#{mark}")
    end
  end
end
