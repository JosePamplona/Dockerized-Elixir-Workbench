defmodule ConsoleWeb.NewCommandTest do
  @moduledoc """
  What the New Project card would run. The name is a field since
  2026-09-26, opening with config.conf's `PROJECT_NAME`
  (`newp.default`), and it is the one argument with a space in it — so
  the card keeps two forms of the same command: the list that runs, and
  the line the reader reads, where the name wears quotes. They are asked here together, because two
  forms of one thing are two things that can drift.
  """
  use ExUnit.Case, async: true

  alias ConsoleWeb.Deploy

  @from_config "Lorem Ipsum Dolor"

  defp newp(fields \\ []),
    do:
      Enum.into(fields, %{
        out: MapSet.new(),
        gen: %{},
        name: @from_config,
        default: @from_config
      })

  test "the name leads the line, in quotes when it has a space in it" do
    assert Deploy.new_args([], newp()) == ["new", "--name", @from_config]
    assert Deploy.new_command([], newp()) == ~s(./wb.sh new --name "Lorem Ipsum Dolor")
  end

  test "a name of one word needs none" do
    assert Deploy.new_args([], newp(name: "Bakery")) == ["new", "--name", "Bakery"]
    assert Deploy.new_command([], newp(name: "Bakery")) == "./wb.sh new --name Bakery"
  end

  # The field is the reader's to empty, and an empty field is not a
  # project called "". The card says what it would use, in its
  # placeholder, and uses exactly that.
  test "a field left blank falls back to what the card opened with" do
    for blank <- ["", "   "] do
      assert Deploy.new_args([], newp(name: blank)) == ["new", "--name", @from_config]
    end

    assert Deploy.new_args([], newp(name: "  Bakery  ")) == ["new", "--name", "Bakery"]
  end

  # config.conf names none, and the card was left alone: the console's
  # own last resort, so that what runs is never `--name ""`.
  test "with no name anywhere, the console's own default" do
    bare = %{out: MapSet.new(), gen: %{}, name: "", default: ""}
    assert Deploy.new_args([], bare) == ["new", "--name", Deploy.default_name()]
  end

  test "the flags the card sets come after the name" do
    p = newp(name: "Bakery", gen: %{"adapter" => "cowboy"})

    assert Deploy.new_args([], p) == ["new", "--name", "Bakery", "--adapter", "cowboy"]
    assert Deploy.new_command([], p) == "./wb.sh new --name Bakery --adapter cowboy"
  end

  # The line is the list, said: whatever the card carries, the two must
  # be the same command, or the reader is shown one thing and another is
  # run.
  test "the line says what the list runs, and nothing else" do
    for p <- [newp(), newp(name: "Bakery"), newp(name: "Bakery", gen: %{"adapter" => "cowboy"})] do
      said = Deploy.new_command([], p) |> String.replace(~s("), "")
      assert said == Enum.join(["./wb.sh" | Deploy.new_args([], p)], " ")
    end
  end
end
