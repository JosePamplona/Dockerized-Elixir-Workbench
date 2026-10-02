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

  # The word says which of the two presses it is (2026-09-26). It read
  # `build` either way, and a reader who had the page in front of them
  # was offered a verb for a page that is not there.
  test "a page that is not written yet offers to build it" do
    html = page(read: nil)

    assert html =~ ">build</button>"
    refute html =~ ">rebuild</button>"
    assert html =~ "writes this page in the workspace, as a job"
    refute html =~ "workspace again"
  end

  test "a page that is there offers to write it again" do
    html = page(read: {"2026-09-26 11:20", ""}, href: "http://localhost:4101/docs/")

    assert html =~ ">rebuild</button>"
    assert html =~ "writes this page in the workspace again, as a job"

    # The stamp is what says it is there, and the two are read off the
    # one `built` in `Record`: a page with a stamp is a page on disk.
    assert html =~ "2026-09-26 11:20"
  end

  # The command is the project's own, whichever word the button wears.
  test "either way it runs the cartridge's own Mix task, and nothing else" do
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
    refute html =~ ">build</button>"
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
