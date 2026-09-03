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
    assert [%{key: "WORKSPACE_PATH", value: "./_workspaces/test", help: "Where the project goes.", quoted: true}] = ws.fields
    assert creation.title == "Project creation" and creation.intro == ["Read by 'new'.", "Two lines of intro."]
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
end
