defmodule WorkbenchIgniter.DockerfileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias WorkbenchIgniter.Dockerfile
  alias WorkbenchIgniter.PhxDelta

  @flags ~w(--app test --module Test --database postgres --adapter bandit)
  @docker WorkbenchIgniter.TestProject.docker()

  describe "stack/1" do
    test "reads the stack back off a generated Dockerfile, and nothing off another's" do
      assert Dockerfile.stack(PhxDelta.generate(@flags, @docker)["Dockerfile"]) ==
               @docker

      assert Dockerfile.stack("FROM elixir:1.19\n") == nil
      assert Dockerfile.stack(nil) == nil
    end
  end

  describe "binding/2" do
    @tag :tmp_dir
    test "names the Debian image as the template at hand does", %{tmp_dir: dir} do
      older = Path.join(dir, "older.eex")
      newer = Path.join(dir, "newer.eex")
      File.write!(older, "ARG DEBIAN_VERSION=<%= debian %>-<%= debian_vsn %>-slim\n")
      File.write!(newer, "ARG DEBIAN_VERSION=<%= debian_vsn %>\n")

      # Up to Phoenix 1.8.13: the name and the date apart.
      assert Dockerfile.binding(@docker, older) ==
               [
                 elixir_vsn: "1.19.6",
                 otp_vsn: "28.5.0.6",
                 debian: "trixie",
                 debian_vsn: "20260824"
               ]

      # From 1.8.14: the whole of it.
      assert Dockerfile.binding(@docker, newer) ==
               [elixir_vsn: "1.19.6", otp_vsn: "28.5.0.6", debian_vsn: "trixie-20260824-slim"]

      assert Dockerfile.binding(nil, newer) == []
    end
  end
end
