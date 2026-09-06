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
end
