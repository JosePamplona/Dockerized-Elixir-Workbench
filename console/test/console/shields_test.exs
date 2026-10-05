defmodule Console.ShieldsTest do
  @moduledoc """
  The badges against the service's own answers: every address in
  `test/fixtures/shields/urls.txt` was asked of img.shields.io on
  2026-09-19 and its SVG kept beside it, and what `Console.Shields`
  draws for the same address is that, to the byte. Pixel-perfect is
  not an eye's judgement here: the same bytes are the same picture.

  To refresh them after a change at shields: `curl -s -o NAME.svg URL`
  for each line, and read the diff.
  """
  use ExUnit.Case, async: true

  alias Console.Shields

  @fixtures Path.expand("../fixtures/shields", __DIR__)

  # What the module says it does not draw: the social style (another
  # table, another layout), a logo (a request to simple-icons), and an
  # address the service itself answers with its 404 badge.
  @undrawn ~w(social logo triple_dash)

  @cases (for line <-
                @fixtures
                |> Path.join("urls.txt")
                |> File.read!()
                |> String.split("\n", trim: true) do
            [name, url] = String.split(line, " ", parts: 2)
            {name, url}
          end)

  for {name, url} <- @cases, name not in @undrawn do
    test "#{name}: the service's SVG, to the byte" do
      real = File.read!(Path.join(@fixtures, unquote(name) <> ".svg"))
      assert {:ok, %{svg: svg}} = Shields.badge(unquote(url))
      assert svg == real
    end
  end

  test "what it does not draw, it says so" do
    for {name, url} <- @cases, name in @undrawn, do: assert(Shields.badge(url) == :error)

    # Not shields, not a static badge, not an image.
    assert Shields.badge("https://example.com/badge/a-b-blue") == :error
    assert Shields.badge("https://img.shields.io/github/stars/a/b") == :error
    assert Shields.badge("https://img.shields.io/badge/a-b-blue.json") == :error
    assert Shields.badge("not an address") == :error
  end

  test "the size and the words come with the picture" do
    assert {:ok, %{width: 90, height: 20, alt: "version: 1.4.2"}} =
             Shields.badge("https://img.shields.io/badge/version-1.4.2-white.svg")

    assert {:ok, %{height: 28, alt: "VERSION: 1.4.2"}} =
             Shields.badge("https://img.shields.io/badge/version-1.4.2-blue?style=for-the-badge")
  end
end
