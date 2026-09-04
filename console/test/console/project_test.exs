defmodule Console.ProjectTest do
  use ExUnit.Case, async: true

  alias Console.Project

  @dockerfile """
  ARG ELIXIR="1.19.2"
  ARG    OTP="28.1"
  ARG DEBIAN="trixie-20251103-slim"

  ARG TOOLCHAIN_IMAGE="hexpm/elixir:${ELIXIR}-erlang-${OTP}-debian-${DEBIAN}"
  FROM ${TOOLCHAIN_IMAGE}
  ARG UID=1000
  ARG PHX_NEW="1.8.13"
  """

  setup do
    dir = Path.join(System.tmp_dir!(), "wb-project-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "what the project was made with, off its own Dockerfile", %{dir: dir} do
    File.write!(Path.join(dir, "Dockerfile.local"), @dockerfile)

    assert Project.born(dir) == %{
             "ELIXIR" => "1.19.2",
             # `ARG    OTP` is padded to line the three up in the file.
             "OTP" => "28.1",
             "DEBIAN" => "trixie-20251103-slim",
             "PHX_NEW" => "1.8.13"
           }
  end

  test "the build arguments that are not the stack stay out of it", %{dir: dir} do
    File.write!(Path.join(dir, "Dockerfile.local"), @dockerfile)
    refute Map.has_key?(Project.born(dir), "UID")
    refute Map.has_key?(Project.born(dir), "TOOLCHAIN_IMAGE")
  end

  test "no workspace, or one with no Dockerfile, answers nothing", %{dir: dir} do
    assert Project.born(nil) == nil
    assert Project.born(dir) == nil
  end
end
