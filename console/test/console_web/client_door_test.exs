defmodule ConsoleWeb.ClientDoorTest do
  @moduledoc """
  A door for a client: a route a program talks to, which a browser
  opens onto a refusal. Its address is told and not linked, any answer
  to the bell is the door answering, and the cartridge's lines are
  given with the address the app is published on.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias ConsoleWeb.Box
  alias ConsoleWeb.Record

  @door %{
    "label" => "mcp",
    "path" => "/mcp",
    "when" => %{"option" => "mcp"},
    "client" => [
      %{"label" => "Claude Code", "line" => "claude mcp add --transport http pieces {url}"}
    ]
  }

  @box %{
    "name" => "pieces",
    "summary" => "A box of pieces",
    "pending" => false,
    "base" => false,
    "collection" => false,
    "covers" => %{"front" => nil},
    "requires" => [],
    "version" => nil,
    "options" => [%{"name" => "mcp", "type" => "boolean", "default" => false}],
    "console" => %{"doors" => [@door]}
  }

  defp cartridge(state), do: %{"name" => "pieces", "installed" => true, "state" => state}

  defp status(c, deployment \\ "dev") do
    %{
      "exists" => true,
      "deployment" => deployment,
      "ports" => %{"app" => 4011},
      "git" => %{"repo" => true, "clean" => true, "inserts" => []},
      "containers" => [],
      "project" => %{"cartridges" => [c]}
    }
  end

  @href "http://localhost:4011/mcp"

  describe "its row" do
    test "has the address the app is published on, and the lines filled with it" do
      c = cartridge(%{"mcp" => true})
      door = Record.door(status(c), c, @door)

      assert door.href == @href
      assert door.client == [{"Claude Code", "claude mcp add --transport http pieces #{@href}"}]
    end

    test "offers the project's task for it, where the cartridge planted one" do
      c = cartridge(%{"mcp" => true})
      door = Map.put(@door, "build", [%{"task" => "mcp.json", "when" => nil}])

      assert Record.door(status(c), c, door).build == "mcp.json"
      assert Record.door(status(c), c, @door).build == nil
      # Shut by its option, there is nothing to set up.
      shut = cartridge(%{"mcp" => false})
      assert Record.door(status(shut), shut, door).build == nil
    end

    test "any answer to the bell is the door answering; silence is not" do
      c = cartridge(%{"mcp" => true})
      read = fn answer -> Record.door(status(c), c, @door, %{@href => answer}).read end

      # MCP refuses a GET that accepts no stream: the refusal is its own.
      assert read.({"406", "warn"}) == {"answers", "good"}
      assert read.({"200", "good"}) == {"answers", "good"}
      assert read.({"500", "bad"}) == {"500", "bad"}
      assert read.({"no answer", "bad"}) == {"no answer", "bad"}
      assert Record.door(status(c), c, @door, :asking).read == {"asking…", "busy off"}
    end

    test "a page's reading is the code it answered, as it was" do
      c = cartridge(%{"mcp" => true})
      page = Map.delete(@door, "client")

      assert Record.door(status(c), c, page, %{@href => {"406", "warn"}}).read == {"406", "warn"}
      refute Record.door(status(c), c, page).client
    end

    test "with the app down it keeps its lines: the client keeps them, and the port is known" do
      c = cartridge(%{"mcp" => true})
      door = Record.door(status(c, nil), c, @door)

      assert door.why == "the app is down"
      assert [{"Claude Code", line}] = door.client
      assert line =~ @href
    end

    test "shut by its option, it has nothing to give" do
      c = cartridge(%{"mcp" => false})
      door = Record.door(status(c), c, @door)

      assert door.why == "only with --mcp"
      assert door.client == []
    end
  end

  describe "drawn" do
    defp plate(assigns), do: render_component(&ConsoleWeb.Refs.door_ref/1, assigns)

    test "its address is told, never linked" do
      html =
        plate(label: "mcp", path: "/mcp", href: @href, port: 4011, kind: "route", client: [])

      refute html =~ "<a "
      assert html =~ "<b>mcp</b>"
      assert html =~ "an address for a client, not a page to open"
    end

    test "its task is a button named for what it runs" do
      html =
        plate(
          label: "mcp",
          path: "/mcp",
          href: @href,
          port: 4011,
          kind: "route",
          client: [],
          build: "mcp.json"
        )

      assert html =~
               ~r{<button[^>]*phx-click="run"[^>]*phx-value-args="mix mcp.json"[^>]*>\s*mix mcp.json\s*</button>}

      assert html =~ "sets a client up for this address"
    end

    test "a page with the same address is a link, as it was" do
      html = plate(label: "docs", path: "/docs", href: @href, port: 4011, kind: "route")

      assert html =~ ~s(<a href="#{@href}")
    end
  end

  describe "in its box" do
    defp screen(status) do
      render_component(&Box.box/1,
        box: @box,
        status: status,
        catalog: [@box],
        screen: "box",
        paper: "readme",
        papers: [],
        args: %{},
        recipe: nil
      )
    end

    test "Opens gives each line with the address, and a button that takes it away" do
      html = screen(status(cartridge(%{"mcp" => true})))

      assert html =~ "claude mcp add --transport http pieces #{@href}"

      assert html =~
               ~r{<button[^>]*class="copy"[^>]*phx-hook="Copy"[^>]*data-copy="claude mcp add --transport http pieces http://localhost:4011/mcp"}
    end

    test "on the shelf, not inserted, the door is named and gives nothing yet" do
      html = screen(%{"exists" => true, "git" => %{"repo" => true, "clean" => true}})

      assert html =~ "insert pieces first"
      refute html =~ ~s(class="copy")
    end
  end
end
