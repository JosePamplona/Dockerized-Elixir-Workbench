defmodule Console.DiffsPackagesTest do
  @moduledoc """
  What an insert put in the project's `mix.exs`, read off its own
  commit — the only reading there is for a box that declares none, a
  base cartridge's packages arriving inside the `phx.new` delta — with
  where each came from, in the cartridge's own words.
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
        {:heroicons,
         github: "tailwindlabs/heroicons",
         tag: "v2.2.0",
         app: false}
      ]
    end
    """)

    File.write!(dir <> "/Dockerfile.local", ~s(ARG PHX_NEW="1.8.14"\n))
    git(dir, ["add", "."])
    git(dir, ["commit", "--quiet", "-am", "Insert mailer"])
    sha = dir |> git(["rev-parse", "HEAD"]) |> String.trim()

    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir, sha: sha}
  end

  defp insert(sha), do: %{"sha" => sha, "feature" => "mailer", "argv" => []}

  defp git(dir, args), do: elem(System.cmd("git", ["-C", dir | args], stderr_to_stdout: true), 0)

  @mailer "The cartridge does not install this package itself: it comes with phx.new 1.8.14 — the difference between the project generated with the flag and without it — and the version is the one that installer writes."

  test "the packages the insert added, with the requirement it wrote and where they came from",
       %{dir: dir, sha: sha} do
    assert Console.Diffs.packages_of(dir, [insert(sha)]) == [
             %{name: "swoosh", requirement: "~> 1.16", git: nil, note: @mailer},
             %{name: "req", requirement: "~> 0.5", git: nil, note: @mailer},
             %{
               name: "heroicons",
               requirement: nil,
               git: %{
                 url: "https://github.com/tailwindlabs/heroicons.git",
                 repo: "tailwindlabs/heroicons",
                 tag: "v2.2.0",
                 branch: nil,
                 ref: nil
               },
               note: @mailer
             }
           ]
  end

  test "the phx.new stamped at the insert, not today's", %{dir: dir, sha: sha} do
    File.write!(dir <> "/Dockerfile.local", ~s(ARG PHX_NEW="1.9.0"\n))
    git(dir, ["commit", "--quiet", "-am", "Upgrade phx.new"])

    assert [%{note: @mailer} | _] = Console.Diffs.packages_of(dir, [insert(sha)])
  end

  test "ash's packages: the ones its command named, and the ones their installers added",
       %{dir: dir, sha: sha} do
    ash = %{"sha" => sha, "feature" => "ash", "argv" => []}
    notes = Map.new(Console.Diffs.packages_of(dir, [ash]), &{&1.name, &1.note})

    # None of these three is ash's own: its command named none of them.
    assert notes["swoosh"] =~ "at the request of the installer of a package that command named"
  end

  test "no insert commit, nothing read: a project born with the flag", %{dir: dir} do
    assert Console.Diffs.packages_of(dir, []) == []
  end
end
