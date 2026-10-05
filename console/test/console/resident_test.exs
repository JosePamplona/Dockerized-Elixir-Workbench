defmodule Console.ResidentTest do
  use ExUnit.Case, async: true

  alias Console.Resident

  @moduletag :tmp_dir

  test "the stamp moves when mix.exs or mix.lock changes, and only then", %{tmp_dir: ws} do
    File.write!(Path.join(ws, "mix.exs"), "defmodule P.MixProject do end\n")
    booted = Resident.deps_stamp(ws)

    File.write!(Path.join(ws, "README.md"), "a file that is not the deps\n")
    assert Resident.deps_stamp(ws) == booted

    File.write!(Path.join(ws, "mix.lock"), "%{}\n")
    locked = Resident.deps_stamp(ws)
    refute locked == booted

    File.write!(Path.join(ws, "mix.exs"), "defmodule P.MixProject do # compilers\nend\n")
    refute Resident.deps_stamp(ws) == locked
  end
end
