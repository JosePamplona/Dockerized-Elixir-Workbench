defmodule Console.VerbsTest do
  use ExUnit.Case, async: true

  alias Console.Verbs

  describe "parse/1" do
    test "a verb the console knows, with its argv and kind" do
      assert {:ok, {:up, "scaled"}, ["up", "--deploy", "scaled", "--replicas", "3"]} =
               Verbs.parse("up --deploy scaled --replicas 3")

      assert {:ok, {:insert, "rest"}, ["add", "rest", "--health"]} = Verbs.parse("add rest --health")
      assert {:ok, {:eject, "rest"}, ["eject", "rest"]} = Verbs.parse("eject rest")
      assert {:ok, {:down, "dev"}, ["down"]} = Verbs.parse("  down  ")
      assert {:ok, {:status, nil}, ["status", "--json"]} = Verbs.parse("status --json")
      assert {:ok, {:expand, "chiefs_setup"}, _} = Verbs.parse("expand --json chiefs_setup --interface graphql")
      assert {:ok, {:restart, "app2"}, ["restart", "--deploy", "scaled", "app2"]} = Verbs.parse("restart --deploy scaled app2")
      assert {:ok, {:prune, nil}, ["prune", "--images"]} = Verbs.parse("prune --images")
    end

    test "refuses what is not a verb, and an empty line" do
      assert {:error, _} = Verbs.parse("")
      assert {:error, why} = Verbs.parse("rm -rf /")
      assert why =~ "rm is not a verb"
      # The streams and the dialogues are not jobs. `console` is: run
      # from in here it starts the console again (see the moduledoc).
      for verb <- ~w(login logs iex bash), do: assert({:error, _} = Verbs.parse(verb))
    end
  end

  test "confirm?/2: delete and prune always, new only over a project" do
    assert Verbs.confirm?({:delete, nil}, false)
    assert Verbs.confirm?({:prune, nil}, false)
    assert Verbs.confirm?({:delete, nil}, true)
    refute Verbs.confirm?({:new, nil}, false)
    assert Verbs.confirm?({:new, nil}, true)
    refute Verbs.confirm?({:up, "dev"}, true)
  end

  test "reread/1: what each verb could have changed" do
    assert Verbs.reread({:up, "dev"}) == :fast
    assert Verbs.reread({:restart, "app"}) == :fast
    assert Verbs.reread({:prune, nil}) == :fast
    assert Verbs.reread({:insert, "rest"}) == :full
    assert Verbs.reread({:new, nil}) == :all
    assert Verbs.reread({:catalog, nil}) == :none
  end
end
