defmodule ConsoleWeb.RecordPagesTest do
  @moduledoc """
  A page on disk and the sources it is made from: up to date, or behind
  by so many files. The dates say which files to look at, and git says
  whether they changed — a file touched and not edited leaves the page
  where it was.
  """
  use ExUnit.Case, async: true

  alias ConsoleWeb.Record

  @door %{
    "label" => "docs",
    "path" => "doc/",
    "when" => nil,
    "output" => %{
      "dir" => "doc",
      "index" => "index.html",
      "build" => [%{"task" => "docs", "when" => nil}],
      "from" => ["lib", "mix.exs", "guides"]
    }
  }

  @c %{"name" => "exdoc", "installed" => true, "state" => %{}}

  # The page was written at @then; a source is older or newer by its date.
  @then 1_800_000_000

  setup do
    root = Path.join(System.tmp_dir!(), "record_pages_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "lib/app"))
    File.mkdir_p!(Path.join(root, "doc"))
    on_exit(fn -> File.rm_rf!(root) end)

    write(root, "lib/app/a.ex", "a", @then - 100)
    write(root, "lib/app/b.ex", "b", @then - 100)
    write(root, "mix.exs", "m", @then - 100)
    write(root, "doc/index.html", "<html>", @then)
    %{root: root}
  end

  defp write(root, rel, content, mtime) do
    path = Path.join(root, rel)
    File.write!(path, content)
    File.touch!(path, mtime)
  end

  defp git(root, args) do
    {_, 0} =
      System.cmd(
        "git",
        [
          "-C",
          root,
          "-c",
          "user.name=t",
          "-c",
          "user.email=t@t",
          "-c",
          "commit.gpgsign=false" | args
        ],
        stderr_to_stdout: true,
        env: [
          {"GIT_COMMITTER_DATE", "@#{@then - 50} +0000"},
          {"GIT_AUTHOR_DATE", "@#{@then - 50} +0000"}
        ]
      )
  end

  # A repository whose one commit, of every source, is older than the page.
  defp committed(root) do
    git(root, ~w(init -q))
    git(root, ~w(add lib mix.exs))
    git(root, ~w(commit -q -m sources))
    root
  end

  defp filed(root, door \\ @door) do
    status = %{"workspace" => root, "project" => %{"cartridges" => [@c]}}
    Record.door(status, @c, door).filed
  end

  test "a page newer than everything it is made from is up to date", %{root: root} do
    assert %{file: "doc/index.html", state: "up to date", why: nil} = filed(committed(root))
  end

  test "a page with no file is missing, whatever its sources", %{root: root} do
    File.rm!(Path.join(root, "doc/index.html"))
    assert %{state: "missing", written: nil} = filed(committed(root))
  end

  test "a source edited since leaves it behind, and it says by how many", %{root: root} do
    committed(root)
    write(root, "lib/app/a.ex", "a, edited", @then + 60)
    assert %{state: "behind", why: "1 file changed since"} = filed(root)

    write(root, "mix.exs", "m, edited", @then + 60)
    assert %{state: "behind", why: "2 files changed since"} = filed(root)
  end

  test "a source written since and not yet in git counts too", %{root: root} do
    committed(root)
    write(root, "lib/app/new.ex", "new", @then + 60)
    assert %{state: "behind", why: "1 file changed since"} = filed(root)
  end

  # What happened on 2026-10-07: a tool touched a source while it ran.
  test "a source touched and not changed leaves the page where it was", %{root: root} do
    committed(root)
    File.touch!(Path.join(root, "lib/app/a.ex"), @then + 60)

    assert %{state: "up to date", why: nil} = filed(root)
  end

  test "a file outside what the page is made from does not move it", %{root: root} do
    committed(root)
    File.mkdir_p!(Path.join(root, "test"))
    write(root, "test/a_test.exs", "t", @then + 60)

    assert %{state: "up to date"} = filed(root)
  end

  test "without a repository the dates are all there is", %{root: root} do
    File.touch!(Path.join(root, "lib/app/a.ex"), @then + 60)
    assert %{state: "behind", why: "1 file changed since"} = filed(root)
  end

  test "a page that does not say what it is made from is written, and no more", %{root: root} do
    plain = update_in(@door, ["output"], &Map.delete(&1, "from"))
    write(root, "lib/app/a.ex", "a, edited", @then + 60)

    assert %{state: "written", why: nil} = filed(committed(root), plain)
  end

  test "a source that climbs out of the project is not read", %{root: root} do
    out = put_in(@door, ["output", "from"], ["../elsewhere"])
    assert %{state: "up to date"} = filed(committed(root), out)
  end
end
