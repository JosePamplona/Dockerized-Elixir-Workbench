defmodule ConsoleWeb.ConfigFormTest do
  @moduledoc """
  The config drawer's stack row: four selects over one list of tags, and
  every one of them travels on every change. Which is the bug this pins.
  """
  # The bench is one process for the whole console, and these drive it:
  # not async, or two of them would be talking to it at once.
  use ConsoleWeb.ConnCase

  import Phoenix.LiveViewTest

  @tags [
    "1.19.2-erlang-28.1-debian-trixie-20251103-slim",
    "1.19.2-erlang-27.3.4.17-debian-trixie-20251103-slim",
    "1.18.5-erlang-27.3.4.17-debian-trixie-20260824-slim"
  ]

  setup %{conn: conn} do
    # The list is Bench's, and nobody has pressed the button in a test:
    # hand it the tags the way the reading would have arrived.
    Console.Bench.subscribe()
    send(Process.whereis(Console.Bench), {make_ref(), {:stacks, {:ok, @tags}}})
    assert_receive {:bench, :stacks, _}

    {:ok, view, _html} = live(conn, "/deploy?wb=config")
    {:ok, view: view}
  end

  defp change(view, target, values) do
    render_change(view, "cfg_change", %{
      "_target" => target,
      "cfg" => values,
      "stack" => stack_of(view)
    })
  end

  defp stack_of(view) do
    case Regex.run(
           ~r/<option[^>]*value="([^"]+)"[^>]*selected[^>]*>/,
           render(view) |> String.replace("\n", "")
         ) do
      [_, tag] -> tag
      _ -> ""
    end
  end

  test "moving one of the three does not get overwritten by the stack that is still showing", %{
    view: view
  } do
    html =
      change(view, ["cfg", "ERLANG_VERSION"], %{
        "ELIXIR_VERSION" => "1.19.2",
        "ERLANG_VERSION" => "27.3.4.17",
        "DEBIAN_VERSION" => "trixie-20251103-slim"
      })

    # The row judges the other two against what was just picked, not
    # against what the stack select had not caught up with yet.
    assert html =~ "no image with erlang 27.3.4.17"
    refute html =~ "no image with erlang 28.1"
  end

  test "a combination with no image leaves the stack picking nothing", %{view: view} do
    html =
      change(view, ["cfg", "DEBIAN_VERSION"], %{
        "ELIXIR_VERSION" => "1.19.2",
        "ERLANG_VERSION" => "28.1",
        "DEBIAN_VERSION" => "trixie-20260824-slim"
      })

    # One state for the four fields, not a sentence inside every option.
    assert html =~ ~s(class="chip bad")
    assert html =~ "no image"
    assert html =~ "no hexpm/elixir image with elixir 1.19.2 · erlang 28.1 · trixie-20260824-slim"
  end

  test "a list that could not be read says so, and does not read as nobody having asked", %{
    view: view
  } do
    send(
      Process.whereis(Console.Bench),
      {make_ref(), {:stacks, {:error, "Docker Hub did not answer."}}}
    )

    assert_receive {:bench, :error, :stacks, _}

    html = render(view)
    assert html =~ "not answered"
    assert html =~ "Docker Hub did not answer."
    refute html =~ "not asked"
  end

  # --- the installer row ---------------------------------------------------

  @releases [
    %{"version" => "1.8.13", "elixir" => "~> 1.17"},
    %{"version" => "1.8.12", "elixir" => "~> 1.17"},
    %{"version" => "1.8.8", "elixir" => "~> 1.15"},
    %{"version" => "1.7.14", "elixir" => "~> 1.14"}
  ]

  defp installers_arrive(view) do
    send(Process.whereis(Console.Bench), {make_ref(), {:installers, {:ok, @releases}}})
    assert_receive {:bench, :installers, _}
    render(view)
  end

  test "the releases are grouped by the Elixir each one declares, newest requirement first", %{
    view: view
  } do
    html = installers_arrive(view)

    # `~>` travels escaped, as everything the templates print does.
    assert ["needs elixir ~&gt; 1.17", "needs elixir ~&gt; 1.15", "needs elixir ~&gt; 1.14"] ==
             Regex.scan(~r/<optgroup label="(needs elixir [^"]+)"/, html)
             |> Enum.map(&List.last/1)
  end

  test "the empty value keeps an option of its own: it is a policy, not a blank", %{view: view} do
    assert installers_arrive(view) =~ "— the newest that runs on this stack"
  end

  test "a version hex has not got is marked; one it has is not", %{view: view} do
    installers_arrive(view)

    # Driven through the form and not read off config.conf, which is the
    # workbench's own and says whatever the reader last set.
    assert pick_installer(view, "1.2") =~ "not on hex"
    assert pick_installer(view, "1.2") =~ "hex has no phx_new 1.2"
    refute pick_installer(view, "1.8.13") =~ "not on hex"
  end

  defp pick_installer(view, version) do
    render_change(view, "cfg_change", %{
      "_target" => ["cfg", "PHX_NEW_VERSION"],
      "cfg" => %{"PHX_NEW_VERSION" => version},
      "stack" => ""
    })
  end

  # --- the Node row ----------------------------------------------------------

  @majors [
    %{
      "major" => "26",
      "state" => "current",
      "lts" => true,
      "codename" => nil,
      "until" => "2029-04-30",
      "nodesource" => true
    },
    %{
      "major" => "25",
      "state" => "end of life",
      "lts" => false,
      "codename" => nil,
      "until" => "2026-06-01",
      "nodesource" => true
    },
    %{
      "major" => "24",
      "state" => "lts",
      "lts" => true,
      "codename" => "Krypton",
      "until" => "2028-04-30",
      "nodesource" => true
    },
    %{
      "major" => "22",
      "state" => "maintenance",
      "lts" => true,
      "codename" => "Jod",
      "until" => "2027-04-30",
      "nodesource" => false
    }
  ]

  defp nodes_arrive(view) do
    send(Process.whereis(Console.Bench), {make_ref(), {:nodes, {:ok, @majors}}})
    assert_receive {:bench, :nodes, _}
    render(view)
  end

  test "the majors are grouped by where each stands, the LTS line first", %{view: view} do
    html = nodes_arrive(view)

    assert ["LTS, active", "current, LTS to come", "LTS, maintenance", "end of life"] ==
             Regex.scan(~r/<optgroup label="([^"]+)"/, html)
             |> Enum.map(&List.last/1)
             |> Enum.filter(
               &(&1 in [
                   "LTS, active",
                   "current, LTS to come",
                   "current, never LTS",
                   "LTS, maintenance",
                   "maintenance",
                   "end of life"
                 ])
             )

    assert html =~ "24 · Krypton — until 2028-04-30"
    # A major NodeSource has not got is there, unlit, and says so.
    assert html =~ "22 · Jod — until 2027-04-30 (not on NodeSource)"
  end

  test "a major NodeSource has not got is marked, one the schedule has not got too, and one it has is not",
       %{view: view} do
    nodes_arrive(view)

    # The chip's title, not its label: the option for 22 says "not on
    # NodeSource" whichever major is picked.
    assert pick_node(view, "22") =~ "NodeSource has no node_22.x repository"
    assert pick_node(view, "99") =~ "no such major"
    html = pick_node(view, "24")
    refute html =~ "NodeSource has no node_"
    refute html =~ "no such major"
    assert html =~ "lts · until 2028-04-30"
  end

  defp pick_node(view, major) do
    render_change(view, "cfg_change", %{
      "_target" => ["cfg", "NODE_VERSION"],
      "cfg" => %{"NODE_VERSION" => major},
      "stack" => ""
    })
  end

  test "picking a stack still sets the three at once", %{view: view} do
    html =
      render_change(view, "cfg_change", %{
        "_target" => ["stack"],
        "cfg" => %{},
        "stack" => "1.18.5-erlang-27.3.4.17-debian-trixie-20260824-slim"
      })

    assert html =~ ~s(value="1.18.5" selected)
    assert html =~ ~s(value="27.3.4.17" selected)
    assert html =~ ~s(value="trixie-20260824-slim" selected)
  end

  # The one field with a rule to break: a name `wb.sh new` refuses is
  # marked where it is edited, with its line under it (`.field-error`).
  test "a project name ending in Web is the field's own error, in a line under it", %{view: view} do
    name = fn value ->
      html = change(view, ["cfg", "PROJECT_NAME"], %{"PROJECT_NAME" => value})

      [row] =
        Regex.run(
          ~r{<div[^>]*class="row[^"]*"[^>]*>\s*<label[^>]*for="cfg-PROJECT_NAME".*?</div>}s,
          html
        )

      row
    end

    row = name.("Bakery Web")
    assert [input] = Regex.run(~r{<input[^>]*id="cfg-PROJECT_NAME"[^>]*>}, row)
    assert input =~ ~s(aria-invalid="true")
    assert input =~ ~s(aria-describedby="cfg-PROJECT_NAME-error")

    assert [line] = Regex.run(~r{<p[^>]*class="field-error"[^>]*>.*?</p>}s, row)
    assert line =~ ~s(id="cfg-PROJECT_NAME-error")
    assert line =~ ~s(<use href="/images/icons.svg#x")

    assert line =~
             "Ends in &#39;Web&#39;: Phoenix&#39;s own generators would not find its web module."

    # Before the help, which is the field's aside and stays.
    assert row =~ ~r{class="field-error".*class="help"}s

    row = name.("Bakery")
    refute row =~ "aria-invalid"
    refute row =~ "field-error"
  end
end
