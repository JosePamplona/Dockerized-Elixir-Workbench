defmodule ConsoleWeb.JobButtonTest do
  @moduledoc """
  The one shape every button that asks for a `wb.sh` line has, and the
  two ways it sends it: written on the button when the line is only
  itself, and as the form it stands in when the line is composed out of
  one — where what is rendered can be a change behind what is typed.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import ConsoleWeb.Refs

  defp button(opts),
    do: render_component(&job_button/1, Keyword.put_new(opts, :label, "Bake"))

  test "on its own it carries the line" do
    html = button(args: "delete")
    assert html =~ ~s(phx-click="run")
    assert html =~ ~s(phx-value-args="delete")
    assert html =~ ~s(title="./wb.sh delete")
    assert html =~ ~s(type="button")
  end

  test "in a form it carries nothing but its name: the line is written from what travels" do
    html =
      button(
        args: "up --deploy scaled --replicas 4",
        form: "deploy-pick",
        name: "do",
        value: "up"
      )

    assert html =~ ~s(type="submit")
    assert html =~ ~s(form="deploy-pick")
    assert html =~ ~s(name="do")
    assert html =~ ~s(value="up")
    # What it says is still the line; what it does is the form's.
    assert html =~ "./wb.sh up --deploy scaled --replicas 4"
    refute html =~ "phx-value-args"
    refute html =~ ~s(phx-click)
  end

  test "unlit it sends nothing, by either road, and says why" do
    html = button(args: "delete", why: "the workspace is empty: nothing to delete")
    assert html =~ "unlit"
    assert html =~ ~s(aria-disabled="true")
    assert html =~ "the workspace is empty: nothing to delete"
    refute html =~ "phx-click"
    refute html =~ "phx-value-args"

    # A submit that cannot be pressed is a plain button: the form
    # cannot travel by it either.
    html = button(form: "deploy-pick", name: "do", value: "up", why: "a job is running")
    assert html =~ ~s(type="button")
    refute html =~ ~s(form="deploy-pick")
  end

  test "a reason that arrives as false is no reason" do
    html = button(args: "delete", why: false)
    refute html =~ "unlit"
    assert html =~ ~s(phx-click="run")
  end

  test "the verbs that are not wb.sh lines bring their own event and values" do
    html =
      button(
        label: "Remove the untagged",
        event: "dk_prune",
        title: "asks first",
        "phx-value-what": "images"
      )

    assert html =~ ~s(phx-click="dk_prune")
    assert html =~ ~s(phx-value-what="images")
    assert html =~ ~s(title="asks first")
  end

  # The one door that does something other than open: a page on disk
  # that is not there yet offers the command that writes it, in the
  # reading's own place.
  test "a page not built yet wears its build command where the reading goes" do
    html =
      render_component(&door_ref/1,
        label: "docs",
        path: "doc/",
        kind: "output",
        why: "nothing built in doc/ yet",
        build: "docs"
      )

    assert html =~ ~s(class="read build")
    assert html =~ ~s(phx-click="run")
    assert html =~ ~s(phx-value-args="mix docs")
    assert html =~ "./wb.sh mix docs"
    assert html =~ ">build</button>"
  end

  # Built, the door opens on its name and address, wears the stamp, and
  # keeps the command beside it: a page is written again as often as
  # the project moves, so build is the rebuild too (2026-09-25).
  test "a page that is built wears its stamp, and its command after it" do
    html =
      render_component(&door_ref/1,
        label: "docs",
        path: "doc/",
        kind: "output",
        href: "http://localhost:4101/docs/",
        read: {"2026-09-22 18:18", ""},
        build: "docs"
      )

    assert html =~ ~s(<a href="http://localhost:4101/docs/" target="_blank"><b>docs</b>)
    assert html =~ "2026-09-22 18:18"
    assert html =~ ~s(phx-value-args="mix docs")
    # The page is there, so the button offers the second press, not the
    # first (2026-09-26): `ConsoleWeb.DoorRefTest` holds the two words.
    assert html =~ ">rebuild</button>"
    refute html =~ "unlit"
  end
end
