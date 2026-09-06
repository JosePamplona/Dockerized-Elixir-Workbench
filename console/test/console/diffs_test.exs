defmodule Console.DiffsTest do
  use ExUnit.Case, async: true

  alias Console.Diffs

  @ws Console.Workbench.workspace()

  # These read the real workspace's git — the only honest source for a
  # diff. With no workspace, or one without a repository, there are no
  # inserts to read and every test below falls through.
  defp inserts do
    if is_nil(@ws) or not File.dir?(Path.join(@ws, ".git")) do
      []
    else
      read_inserts()
    end
  end

  defp read_inserts do
    Console.Workbench.dir()
    |> then(&System.cmd("git", ["-C", @ws, "log", "--format=%H%x1f%s%x1f%ci"], cd: &1))
    |> elem(0)
    |> String.split("\n", trim: true)
    |> Enum.map(&String.split(&1, "\x1f"))
    |> Enum.filter(fn [_, s, _] -> String.starts_with?(s, "Insert ") end)
    |> Enum.map(fn [sha, s, d] ->
      %{"sha" => sha, "subject" => s, "date" => d, "feature" => s |> String.split() |> Enum.at(1)}
    end)
  end

  test "one cartridge's commit: files with counts, faces and rows" do
    case inserts() do
      [] ->
        :ok

      [insert | _] ->
        d = Diffs.cartridge(@ws, insert)
        assert d.sha == insert["sha"] and d.files != []
        f = hd(d.files)
        assert is_binary(f.path) and is_list(f.rows)
        assert Enum.any?(f.rows, fn {cls, _, _, _, _} -> cls == :hunk end)
        # An added line of an Elixir file comes coloured off the new face.
        case Enum.find(d.files, &(Path.extname(&1.path) in [".ex", ".exs"] and &1.added > 0)) do
          nil ->
            :ok

          ex ->
            assert Enum.any?(ex.rows, fn {cls, _, _, _, html} ->
                     cls == :add and html =~ "<span class="
                   end)
        end
    end
  end

  test "a collection's range is honest only when contiguous, and says who touched what" do
    ins = inserts()

    if length(ins) >= 2 do
      c = Diffs.collection(@ws, Enum.take(ins, 2))
      assert is_boolean(c.contiguous) and length(c.picks) == 2
      if c.contiguous, do: assert(Enum.all?(c.files, &is_list(&1.by)) and c.range =~ "..")
    end
  end
end
