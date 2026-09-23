defmodule Console.DiffsPackagesTest do
  @moduledoc """
  What an insert put in the project's `mix.exs`, read off its own
  commit — the only reading there is for a base cartridge, whose
  packages arrive inside the `phx.new` delta and which declares none.
  """
  use ExUnit.Case, async: true

  setup do
    dir = Path.join(System.tmp_dir!(), "diffs-pkgs-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    git(dir, ["init", "--quiet"])
    git(dir, ["config", "user.email", "t@example.com"])
    git(dir, ["config", "user.name", "T"])

    File.write!(dir <> "/mix.exs", """
    defp deps do
      [
        {:phoenix, "~> 1.8.0"}
      ]
    end
    """)

    git(dir, ["add", "."])
    git(dir, ["commit", "--quiet", "-m", "Born"])

    File.write!(dir <> "/mix.exs", """
    defp deps do
      [
        {:phoenix, "~> 1.8.0"},
        {:swoosh, "~> 1.16"},
        {:req, "~> 0.5"},
        {:heroicons, github: "tailwindlabs/heroicons", tag: "v2.2.0"}
      ]
    end
    """)

    git(dir, ["commit", "--quiet", "-am", "Insert mailer"])
    sha = dir |> git(["rev-parse", "HEAD"]) |> String.trim()

    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir, sha: sha}
  end

  defp git(dir, args), do: elem(System.cmd("git", ["-C", dir | args], stderr_to_stdout: true), 0)

  test "the packages the insert added, with the requirement it wrote", %{dir: dir, sha: sha} do
    assert Console.Diffs.packages_of(dir, [%{"sha" => sha}]) == [
             %{name: "swoosh", requirement: "~> 1.16"},
             %{name: "req", requirement: "~> 0.5"},
             %{name: "heroicons", requirement: nil}
           ]
  end

  test "no insert commit, nothing read: a project born with the flag", %{dir: dir} do
    assert Console.Diffs.packages_of(dir, []) == []
  end
end
