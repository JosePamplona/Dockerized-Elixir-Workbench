defmodule ConsoleWeb.HooksTest do
  @moduledoc """
  A hook is wired in two places — the `phx-hook` on the element and the
  map `app.js` hands the socket — and a name in one and not the other
  fails silently: the element renders, the browser runs nothing, and
  esbuild drops the unused import so even the bundle does not carry it.
  That is how the url field's scheme went missing on 2026-09-22.
  """
  use ExUnit.Case, async: true

  @app "assets/js/app.js"
  @bundle "priv/static/assets/js/app.js"

  # The names the components ask for: a literal `phx-hook="Name"`, and
  # the one written as a condition (`&& "UrlField"`).
  defp asked do
    "lib"
    |> Path.join("**/*.ex")
    |> Path.wildcard()
    |> Enum.flat_map(fn path ->
      Regex.scan(~r/phx-hook=(?:"(\w+)"|\{[^}]*"(\w+)"\})/, File.read!(path))
    end)
    |> Enum.map(fn match -> match |> Enum.reject(&(&1 == "")) |> List.last() end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp registered do
    [_, names] = Regex.run(~r/hooks: \{\.\.\.colocatedHooks,([^}]*)\}/, File.read!(@app))
    names |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.sort()
  end

  test "every hook a component asks for is handed to the socket" do
    assert asked() -- registered() == []
  end

  test "and is in the bundle the browser gets" do
    bundle = File.read!(@bundle)

    for name <- asked() do
      assert bundle =~ name, "#{name} is not in #{@bundle}: run `mix esbuild console`"
    end
  end
end
