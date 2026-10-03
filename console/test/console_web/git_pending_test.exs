defmodule ConsoleWeb.GitPendingTest do
  @moduledoc """
  The Changes paper's two ways out of a dirty tree, in the one card:
  the commit, and the discard that cannot be taken back — unlit on a
  clean tree, asking for the reader's word while its job waits.
  """
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import ConsoleWeb.GitScreen

  defp paper(pending, jobs \\ []),
    do: render_component(&git_pending/1, gt: %{initial() | pending: pending}, jobs: jobs)

  defp dirty do
    file = %{
      path: "mix.exs",
      added: 2,
      removed: 1,
      born: false,
      gone: false,
      binary: false,
      treatment: :elixir,
      tip: "HEAD",
      base: "HEAD",
      rows: []
    }

    %{files: [file], added: 2, removed: 1}
  end

  test "a dirty tree offers both the commit and the discard" do
    html = paper(dirty())
    assert html =~ ~s(phx-value-args="discard")
    assert html =~ ">Discard<"
    assert html =~ ">Commit<"
    # One card, two lines of one foot: the second is not a box of its own.
    assert html |> String.split(~s(class="card)) |> length() == 2
    refute html =~ "unlit"
  end

  test "a clean tree lights neither, and says why of each" do
    html = paper(%{files: [], added: 0, removed: 0})
    assert html =~ "nothing to commit: the tree is clean"
    assert html =~ "nothing to discard: the tree is clean"
    assert html =~ "unlit"
  end

  test "no button of the card submits the commit but Commit" do
    # The card is the commit's form: a button with no type inside a form
    # is a submit, and the discard's confirmation committed behind it.
    html = paper(dirty(), [%{id: "j1", kind: {:discard, nil}, state: :pending}])

    submits =
      Regex.scan(~r/<button(?:(?!>)[\s\S])*>/, html)
      |> Enum.map(&hd/1)
      |> Enum.reject(&String.contains?(&1, ~s(type="button")))

    assert length(submits) == 1
    assert hd(submits) =~ ~s(type="submit")
  end

  test "the discard waiting for a word is asked, not sent again" do
    waiting = %{id: "j1", kind: {:discard, nil}, state: :pending}
    html = paper(dirty(), [waiting])
    assert html =~ "Yes, discard"
    assert html =~ ~s(phx-value-id="j1")
    assert html =~ "Keep them"
    refute html =~ ~s(phx-value-args="discard")
  end
end
