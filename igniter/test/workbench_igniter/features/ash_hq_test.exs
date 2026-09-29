defmodule WorkbenchIgniter.Features.Ash.HqTest do
  @moduledoc false

  # The ash cartridge against ash-hq.org as it is today. `mix test`
  # leaves it out (test_helper, `:network`); it runs by name, with the
  # network — `mix test --only network:ash_hq` — and every Monday from
  # `.github/workflows/ash-site.yml`. A failure is a list of what to
  # update by hand in the cartridge's tables (README, *Keeping up with
  # the site*), not a broken build. What the tests compare is read off
  # fixtures in ash_site_test.exs; here the site is the fixture.
  use ExUnit.Case, async: false

  @moduletag network: :ash_hq

  alias WorkbenchIgniter.Features.Ash.Site

  setup_all do
    case Site.fetch() do
      {:ok, home, js} -> %{home: home, js: js, site: Site.parse(js)}
      {:error, why} -> raise why
    end
  end

  test "each feature of the installer: its packages, arguments and tooltip", %{site: site} do
    {oks, waiting, diffs} = Site.compare(site)
    IO.puts(report(oks, waiting, diffs))

    assert diffs == [], "#{length(diffs)} to look at:\n" <> marked("!!", diffs)
  end

  test "each section of the home page, and each strategy of --auth", context do
    {oks, diffs} = context.home |> Site.sections() |> Site.compare_sections(context.site)
    IO.puts(report(oks, [], diffs))

    assert diffs == [], "#{length(diffs)} to look at:\n" <> marked("!!", diffs)
  end

  # The map says nothing about cardinality; the command builder does.
  test "the data layers are still independent checkboxes, as --data-layer takes several",
       %{js: js} do
    assert Site.data_layers_independent?(js),
           "the site's command builder changed — are the layers still independent checkboxes?"
  end

  # The report the task used to print, each line marked: `ok` as the
  # site, `..` waiting for an installer, `!!` to look at.
  defp report(oks, waiting, diffs) do
    marked("ok", oks) <>
      marked("..", waiting) <>
      marked("!!", diffs) <>
      "#{length(oks)} as the site, #{length(waiting)} waiting for an installer, #{length(diffs)} to look at.\n"
  end

  defp marked(mark, lines), do: Enum.map_join(lines, "", &"  #{mark}  #{&1}\n")
end
