defmodule WorkbenchIgniter.Features.Ash.Site do
  @moduledoc """
  Reads ash-hq.org's installer widget and compares it with the cartridge.

  The site's *Get Your Installer* is driven by a feature map in its app
  bundle (`/assets/app-*.js`): one entry per option with `adds` (the
  packages it puts in the command), `requires`, `args` and `tooltip`.
  The cartridge's tables — data layers, APIs, authentication packages,
  the advanced packages and their companions, the tooltips the catalog
  shows — were read off that map (DESIGN.md [17]) and go stale the day
  the site changes. The sections the options are named after are not in
  the map but in the home page, each a `data-category` with its
  features' labels inside. `mix workbench.ash.site` fetches both and
  says what differs; `parse/1`, `sections/1` and the two comparisons
  work on text, so a test can run them without the network.
  """

  alias WorkbenchIgniter.Features.Ash

  @site "https://ash-hq.org/"

  @doc "Fetches the site's home page and the app bundle it links, as text: `{:ok, home, js}`."
  def fetch do
    home = Req.get!(@site).body

    case Regex.run(~r{/assets/app-[^"]+\.js[^"]*}, home) do
      [path] -> {:ok, home, Req.get!(@site <> String.trim_leading(path, "/")).body}
      nil -> {:error, "no app bundle linked from #{@site}"}
    end
  end

  @doc """
  The sections of the installer widget, off the home page, in its
  order: `[{title, [feature key]}]`, each feature in the order the page
  lists it. A section is a `<div data-category="…">`; a feature, a
  `<label id="feature-KEY">` inside it (read 2026-09-24).
  """
  def sections(html) do
    html
    |> String.split(~r/<div data-category="/)
    |> tl()
    |> Enum.map(fn chunk ->
      [title | _] = String.split(chunk, "\"", parts: 2)
      keys = for [_, key] <- Regex.scan(~r/<label id="feature-(\w+)"/, chunk), do: key
      {unescape(title), keys}
    end)
  end

  defp unescape(text),
    do:
      String.replace(
        text,
        ["&amp;", "&#39;", "&quot;"],
        &%{"&amp;" => "&", "&#39;" => "'", "&quot;" => "\""}[&1]
      )

  @doc """
  Whether the site still treats the data layers as independent
  checkboxes — each with its own `checked`, several at once — which is
  why the cartridge's `--data-layer` takes several. Read off the
  bundle's command builder (`K.postgres.checked||(K.sqlite.checked?…`,
  2026-08-30); the map says nothing about cardinality.
  """
  def data_layers_independent?(js),
    do: Regex.match?(~r/\w+\.postgres\.checked\|\|\(\w+\.sqlite\.checked\?/, js)

  @doc """
  The feature map out of the bundle's text: `%{key => %{adds, requires,
  args, tooltip}}`, tooltip as its paragraphs, tags stripped.
  """
  def parse(js) do
    ~r/(\w+):\{((?:(?!tooltip:`)[^`])*?)tooltip:`(.*?)`/s
    |> Regex.scan(js)
    |> Map.new(fn [_, key, meta, tip] ->
      {key,
       %{
         adds: strings(meta, "adds"),
         requires: strings(meta, "requires"),
         args: strings(meta, "args"),
         tooltip: paragraphs(tip)
       }}
    end)
  end

  defp strings(meta, field) do
    case Regex.run(~r/#{field}:\[([^\]]*)\]/, meta) do
      [_, list] -> Regex.scan(~r/"([^"]+)"/, list) |> Enum.map(fn [_, s] -> s end)
      nil -> []
    end
  end

  defp paragraphs(tip) do
    ~r{<p[^>]*>(.*?)</p>}s
    |> Regex.scan(tip)
    |> Enum.map(fn [_, p] ->
      p
      |> String.replace(~r/<[^>]+>/, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.replace(["&amp;", "&#39;", "&quot;", "\\u2014"], fn
        "&amp;" -> "&"
        "&#39;" -> "'"
        "&quot;" -> "\""
        "\\u2014" -> "—"
      end)
      |> String.trim()
    end)
  end

  @doc """
  The line of a tooltip the catalog quotes: its first paragraph longer
  than a bare name (the site opens some with just "PostgreSQL").
  """
  def line(paragraphs), do: Enum.find(paragraphs, &(String.length(&1) > 20))

  @doc """
  The site's map against the cartridge: for every feature, what the
  cartridge would put in the command for it and the tooltip it shows,
  against what the site does. Returns `{oks, waiting, differences}`,
  each a list of one-line reports: `waiting` is what the site offers
  and marks "Installer coming soon" — nothing to install yet, so
  nothing to follow; the day its installer lands the tooltip changes and
  it becomes a difference. An empty `differences` means the cartridge
  is current.
  """
  def compare(site) do
    tooltips = Ash.tooltips()

    Enum.sort_by(site, fn {key, f} -> {f.adds == [], key} end)
    |> Enum.reduce({[], [], []}, fn {key, f}, acc -> judge(key, f, acc, site, tooltips) end)
  end

  @doc """
  The site's sections against the cartridge's: `{oks, differences}`, as
  `compare/1`. Web, Data Layers and each *Advanced Options* section
  against the packages of the option that stands for it — a package the
  site added there, one it no longer lists or moved to another section,
  a section it opened or closed. Authentication: every strategy the site
  offers is one `--auth` knows (the rest of `--auth`'s list is
  `ash_authentication.add_strategy`'s, not the site's). `sections` is
  `sections/1`, `site` is `parse/1`.
  """
  def compare_sections(sections, site) do
    ours = our_sections()
    by_title = Map.new(sections)
    known = Map.keys(ours) ++ ["Authentication"]

    reports =
      Enum.flat_map(ours, fn {title, {option, packages}} ->
        section_reports(title, option, packages, by_title, site)
      end) ++
        auth_reports(by_title["Authentication"] || [], site) ++
        for {title, keys} <- sections, title not in known do
          {:diff,
           "section «#{title}»: new on the site (#{Enum.join(keys, ", ")}), no option of the cartridge stands for it"}
        end

    {for({:ok, line} <- reports, do: line), for({:diff, line} <- reports, do: line)}
  end

  # The sections the cartridge follows, by the site's title: the option
  # and the packages it offers there.
  defp our_sections do
    Map.new(
      [
        {"Web", {"--api", Enum.map(Ash.apis(), &elem(&1, 1))}},
        {"Data Layers", {"--data-layer", for({_name, pkg} <- Ash.data_layers(), pkg, do: pkg)}}
      ] ++
        for {section, title} <- Ash.section_titles() do
          {title, {"--" <> String.replace(to_string(section), "_", "-"), Ash.advanced()[section]}}
        end
    )
  end

  defp section_reports(title, option, packages, by_title, site) do
    case by_title[title] do
      nil ->
        [{:diff, "section «#{title}» (#{option}): no longer on the site"}]

      keys ->
        # ash_phoenix is always in: the Web section's Phoenix is no choice.
        features =
          for key <- keys, adds = site[key][:adds] || [], adds != ["ash_phoenix"], do: {key, adds}

        listed = features |> Enum.flat_map(&elem(&1, 1))

        gone =
          for pkg <- packages, pkg not in listed do
            case Enum.find(by_title, fn {t, ks} ->
                   t != title and Enum.any?(ks, &(pkg in (site[&1][:adds] || [])))
                 end) do
              {other, _} ->
                {:diff, "section «#{title}» (#{option}): #{pkg} moved to «#{other}» on the site"}

              nil ->
                {:diff, "section «#{title}» (#{option}): the site no longer lists #{pkg}"}
            end
          end

        added =
          for {key, adds} <- features, not Enum.any?(adds, &(&1 in packages)) do
            {:diff,
             "section «#{title}» (#{option}): the site added #{key} (adds #{Enum.join(adds, ", ")}), the option does not offer it"}
          end

        case gone ++ added do
          [] -> [{:ok, "section «#{title}» (#{option}): as the site"}]
          diffs -> diffs
        end
    end
  end

  # The strategies the site offers, each one `--auth` must know.
  defp auth_reports(keys, site) do
    for key <- keys, f = site[key], f do
      strategy = strategy(f.args)

      if strategy in Ash.auth_strategies(),
        do: {:ok, "section «Authentication»: #{strategy} as the site"},
        else:
          {:diff,
           "section «Authentication»: the site offers #{strategy} (#{key}), --auth does not list it"}
    end
  end

  # One site feature against the cartridge, onto the two lists.
  defp judge(key, f, {oks, waiting, diffs}, site, tooltips) do
    case ours(key, f) do
      :skip ->
        {oks, waiting, diffs}

      {:not_offered, _} ->
        line =
          "#{key}: the site offers it (adds #{Enum.join(f.adds, ", ")}), the cartridge does not"

        if Enum.any?(f.tooltip, &(&1 =~ "Installer coming soon")),
          do: {oks, waiting ++ [line <> " — its installer: coming soon, the site says"], diffs},
          else: {oks, waiting, diffs ++ [line]}

      {value, adds, args, tipkey} ->
        case problems(f, adds, args, tipkey, site, tooltips) do
          [] ->
            {oks ++ ["#{key} (#{value}): as the site"], waiting, diffs}

          problems ->
            {oks, waiting, diffs ++ Enum.map(problems, &"#{key} (#{value}): the site #{&1}")}
        end
    end
  end

  # Where the cartridge and the site part on one feature: the packages
  # the command gets, its args, the tooltip.
  defp problems(f, adds, args, tipkey, site, tooltips) do
    line = line(f.tooltip)
    # What the site's command gets for the option: what the options it
    # requires add (phoenix is always in), then its own packages.
    site_adds = Enum.flat_map(f.requires -- ["phoenix"], &(site[&1][:adds] || [])) ++ f.adds

    [
      if(adds != site_adds, do: "adds #{inspect(site_adds)}, the cartridge #{inspect(adds)}"),
      if(args != f.args, do: "args #{inspect(f.args)}, the cartridge #{inspect(args)}"),
      if(line && tooltips[tipkey] != line,
        do: "says #{inspect(line)}, the cartridge #{inspect(tooltips[tipkey])}"
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  # What the cartridge would do for a site feature: {our value, the
  # packages the command gets, the args, the key of the tooltip the
  # catalog shows for it}, :skip for what is always in or a preset,
  # :not_offered for what the cartridge has no option for.
  defp ours(key, f) do
    layers = Ash.data_layers() |> Enum.reject(&is_nil(elem(&1, 1)))
    apis = Ash.apis()
    advanced = Ash.advanced() |> Keyword.values() |> List.flatten()

    cond do
      key == "phoenix" or f.adds == [] ->
        :skip

      layer = List.keyfind(layers, hd(f.adds), 1) ->
        {elem(layer, 0), [elem(layer, 1)], [], elem(layer, 1)}

      api = List.keyfind(apis, hd(f.adds), 1) ->
        {elem(api, 0), [elem(api, 1)], api_args(elem(api, 0)), elem(api, 1)}

      String.starts_with?(hd(f.adds), "ash_authentication") ->
        strategy = strategy(f.args)
        {strategy, Ash.auth_packages([strategy]), f.args, strategy}

      main = Enum.find(f.adds, &(&1 in advanced)) ->
        {main, Ash.expand(main), [], main}

      true ->
        {:not_offered, f.adds}
    end
  end

  # typescript is the one API the command takes a framework for.
  defp api_args("typescript"), do: ["--framework react"]
  defp api_args(_api), do: []

  # The site's --auth-strategy; oauth2 when it names none.
  defp strategy(["--auth-strategy " <> s]), do: s
  defp strategy(_args), do: "oauth2"
end

defmodule Mix.Tasks.Workbench.Ash.Site do
  use Mix.Task

  @shortdoc "Compares the ash cartridge with ash-hq.org's installer, as it is today"

  @moduledoc """
  #{@shortdoc}

      mix workbench.ash.site

  Fetches the home page and the feature map that drives the site's
  *Get Your Installer* (its app bundle) and reports, one line each:

    * `ok` — a feature the cartridge puts in the command with the same
      packages, arguments and tooltip as the site; a section whose
      packages are the ones its option offers; a strategy of the site
      that `--auth` knows.
    * `..` — what the site offers with its installer "coming soon":
      nothing to follow yet.
    * `!!` — a difference: a feature whose packages, arguments or
      tooltip changed, one the site offers and the cartridge does not,
      a package the site added to a section, stopped listing or moved,
      a section opened or closed, a strategy `--auth` does not list.

  Exits 1 when there is a `!!`, 0 otherwise, so a scheduled job can
  run it. Nothing is written: the report is what to update by hand, in
  the cartridge's tables and its DESIGN.md reference [17].
  """

  @impl Mix.Task
  def run(_argv) do
    Application.ensure_all_started(:req)

    alias WorkbenchIgniter.Features.Ash.Site

    case Site.fetch() do
      {:ok, home, js} ->
        site = Site.parse(js)
        {oks, waiting, diffs} = Site.compare(site)
        {section_oks, section_diffs} = home |> Site.sections() |> Site.compare_sections(site)

        # The map says nothing about cardinality; the command builder does.
        {layers_ok, layers_diff} =
          if Site.data_layers_independent?(js),
            do:
              {[
                 "data layers: independent checkboxes on the site, as the cartridge's --data-layer (several)"
               ], []},
            else:
              {[],
               [
                 "data layers: the site's command builder changed — are the layers still independent checkboxes? The cartridge's --data-layer takes several"
               ]}

        oks = oks ++ section_oks ++ layers_ok
        diffs = diffs ++ section_diffs ++ layers_diff

        Enum.each(oks, &Mix.shell().info("  ok  " <> &1))
        Enum.each(waiting, &Mix.shell().info("  ..  " <> &1))
        Enum.each(diffs, &Mix.shell().info("  !!  " <> &1))

        Mix.shell().info(
          "#{length(oks)} as the site, #{length(waiting)} waiting for an installer, #{length(diffs)} to look at."
        )

        if diffs != [], do: exit({:shutdown, 1})

      {:error, why} ->
        Mix.raise(why)
    end
  end
end
