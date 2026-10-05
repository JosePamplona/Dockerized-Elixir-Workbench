defmodule Console.ConfigTest do
  use ExUnit.Case, async: true

  alias Console.Config

  @text """
  # config.conf
  # Edit this file.

  # Where the project goes.
  export WORKSPACE_PATH="./_workspaces/test"

  # --- Project creation. ------------------------------------------------
  # Read by 'new'.
  # Two lines of intro.

  # The project's name.
  export PROJECT_NAME="Lorem Ipsum"
  # 1.19.2-erlang-28.1-debian-trixie-slim
  export ELIXIR_VERSION="1.19.2"

  # --- Git ----------------------------------------------------------------
  # Who signs.
  export GIT_IDENTITY="user"
  # export GIT_IDENTITY="workbench"

  # A closing note.
  """

  test "reads sections, fields with their help, alternatives and stacks" do
    conf = Config.parse(@text)
    assert [ws, creation, git] = conf.sections
    assert ws.title == "Workspace" and ws.intro == []

    assert [
             %{
               key: "WORKSPACE_PATH",
               value: "./_workspaces/test",
               help: "Where the project goes.",
               quoted: true
             }
           ] = ws.fields

    assert creation.title == "Project creation" and
             creation.intro == ["Read by 'new'.", "Two lines of intro."]

    assert Enum.map(creation.fields, & &1.key) == ["PROJECT_NAME", "ELIXIR_VERSION"]
    assert git.fields |> hd() |> Map.get(:help) == "Who signs."
    assert git.outro == ["A closing note."]
    assert conf.alts == %{"GIT_IDENTITY" => ["workbench"]}
    assert conf.stacks == ["1.19.2-erlang-28.1-debian-trixie-slim"]
    assert Config.values(conf)["PROJECT_NAME"] == "Lorem Ipsum"
  end

  test "reads the workbench's own config.conf" do
    values = Console.Workbench.config() |> Config.values()
    assert Map.has_key?(values, "WORKSPACE_PATH")
    assert Map.has_key?(values, "ELIXIR_VERSION")
  end

  describe "linkify/1" do
    test "an address in a comment comes out as one, and the prose around it as prose" do
      assert Console.Config.linkify("Available versions: https://hub.docker.com/_/postgres/tags") ==
               [
                 "Available versions: ",
                 {"https://hub.docker.com/_/postgres/tags",
                  "https://hub.docker.com/_/postgres/tags"},
                 ""
               ]
    end

    test "the full stop a sentence ends with is the sentence's, not the address's" do
      assert [_, {url, text}, ".", " And more."] =
               Console.Config.linkify("See https://hub.docker.com/r/hexpm/elixir/tags. And more.")

      assert url == "https://hub.docker.com/r/hexpm/elixir/tags"
      assert text == url
    end

    test "a line with no address is one piece of prose" do
      assert Console.Config.linkify("no address here") == ["no address here"]
    end

    test "only http and https: a word with a colon in it is not an address" do
      assert Console.Config.linkify("see docker:latest or ftp://x.example") ==
               ["see docker:latest or ftp://x.example"]
    end
  end
end
