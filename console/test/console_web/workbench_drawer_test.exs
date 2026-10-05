defmodule ConsoleWeb.WorkbenchDrawerTest do
  use ExUnit.Case, async: true

  alias ConsoleWeb.WorkbenchDrawer, as: Drawer

  test "erlang's dotted versions, of any length, newest first" do
    # What the field read before, in the order the tag list gave it.
    was = ~w(29.0.6 29.0.5 28.2 28.1.1 28.0.4 27.0.1 29.0.4 26.0.2 28.1 25.3.2.21)

    assert Drawer.in_order(was, :o) ==
             ~w(29.0.6 29.0.5 29.0.4 28.2 28.1.1 28.1 28.0.4 27.0.1 26.0.2 25.3.2.21)
  end

  test "a version that is a prefix of another is the older of the two" do
    assert Drawer.in_order(~w(28.1 28.1.1), :o) == ~w(28.1.1 28.1)
    assert Drawer.in_order(~w(1.20.2 1.20.10), :e) == ~w(1.20.10 1.20.2)
  end

  test "debian by the snapshot date, which is the only part that says how new it is" do
    was =
      ~w(trixie-20260824-slim bookworm-20260803-slim trixie-20260713-slim bookworm-20260824-slim trixie-20251103-slim)

    assert Drawer.in_order(was, :d) ==
             ~w(trixie-20260824-slim bookworm-20260824-slim bookworm-20260803-slim trixie-20260713-slim trixie-20251103-slim)
  end

  test "a value config.conf names that is no version at all still draws" do
    assert Drawer.in_order(~w(28.1 nightly 27.0), :o) == ~w(nightly 28.1 27.0)

    assert Drawer.in_order(~w(trixie-slim trixie-20260824-slim), :d) ==
             ~w(trixie-20260824-slim trixie-slim)
  end
end
