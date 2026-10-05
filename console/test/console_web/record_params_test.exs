defmodule ConsoleWeb.RecordParamsTest do
  @moduledoc """
  The Inserted list's parameters: what the project reports of the
  cartridge wins, and when it reports nothing its Insert commit still
  says what it went in with.
  """
  use ExUnit.Case, async: true
  alias ConsoleWeb.Record

  @entry %{
    "options" => [
      %{"name" => "endpoint", "type" => "string", "default" => "/health"},
      %{"name" => "open_api", "type" => "boolean", "default" => false}
    ]
  }

  test "a cartridge that reports nothing is read off its Insert commit" do
    insert = %{"argv" => ["--endpoint", "/health3", "--open-api"]}

    assert Record.params(%{"state" => %{}}, @entry, insert) ==
             [{"--endpoint /health3", false}, {"--open-api", false}]
  end

  test "the commit's default values are marked, as the project's are" do
    insert = %{"argv" => ["--endpoint", "/health"]}
    assert Record.params(%{"state" => %{}}, @entry, insert) == [{"--endpoint /health", true}]
  end

  test "what the project reports wins over the commit" do
    insert = %{"argv" => ["--endpoint", "/old"]}

    assert Record.params(%{"state" => %{"endpoint" => "/health3"}}, @entry, insert) ==
             [{"--endpoint /health3", false}]
  end

  test "with neither there is nothing to say" do
    assert Record.params(%{"state" => %{}}, @entry, nil) == []
    assert Record.params(%{}, @entry) == []
  end
end
