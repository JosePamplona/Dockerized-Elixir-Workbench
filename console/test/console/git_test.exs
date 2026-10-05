defmodule Console.GitTest do
  use ExUnit.Case, async: true

  alias Console.Git

  # A repository of one commit, with a change and a new file pending.
  setup do
    dir = Path.join(System.tmp_dir!(), "wb-git-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    g = fn args -> {_, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) end
    g.(["init", "-q"])
    g.(["config", "user.email", "t@t"])
    g.(["config", "user.name", "T"])
    File.write!(Path.join(dir, "a.ex"), "defmodule A do\nend\n")
    g.(["add", "-A"])
    g.(["commit", "-q", "-m", "New project: a"])
    File.write!(Path.join(dir, "a.ex"), "defmodule A do\n  def a, do: 1\nend\n")
    File.write!(Path.join(dir, "b.txt"), "b\nbb\n")
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "pending: the change as a diff, the new file whole, and the totals", %{dir: dir} do
    %{files: [a, b], added: 3, removed: 0} = Git.pending(dir)
    assert %{path: "a.ex", born: false, added: 1, removed: 0} = a
    assert Enum.any?(a.rows, &match?({:add, nil, 2, "+", _}, &1))
    assert %{path: "b.txt", born: true, added: 2, removed: 0} = b
    assert [{:add, nil, 1, "+", _}, {:add, nil, 2, "+", _}] = b.rows
  end

  test "the log, with the inserts marked off the status", %{dir: dir} do
    [c] = Git.log(dir, [])
    assert %{subject: "New project: a", author: "T", body: "", insert: nil} = c
    assert String.length(c.sha) == 40 and c.short == String.slice(c.sha, 0, 7)
    [c] = Git.log(dir, [%{"sha" => c.sha, "feature" => "new"}])
    assert c.insert == "new"
  end

  test "the message file: a title alone, or a title and a body" do
    assert File.read!(Git.message_file(" Add health ", nil)) == "Add health\n"

    assert File.read!(Git.message_file("Add health", " Because probes.\nTwo lines. ")) ==
             "Add health\n\nBecause probes.\nTwo lines.\n"
  end
end
