defmodule WorkbenchIgniter.Features.Ash.Site do
  @moduledoc """
  Reads ash-hq.org's installer widget and compares it with the cartridge.

  The site's *Get Your Installer* is driven by a feature map in its app
  bundle (`/assets/app-*.js`): one entry per option with `adds` (the
  packages it puts in the command), `requires`, `args` and `tooltip`.
  The cartridge's tables — data layers, APIs, authentication packages,
  the advanced packages and their companions, the tooltips the catalog
  shows — were read off that map (DESIGN.md [17]) and go stale the day
  the site changes. `mix workbench.ash.site` fetches the map and says
  what differs; `parse/1` and `compare/1` do the work on text, so a
  test can run them without the network.
  """

  alias WorkbenchIgniter.Features.Ash

  @site "https://ash-hq.org/"

  @doc "Fetches the site's app bundle and returns its feature map (`parse/1`)."
  def fetch do
    with {:ok, js} <- fetch_bundle(), do: {:ok, parse(js)}
  end

  @doc "Fetches the site's app bundle, as text."
  def fetch_bundle do
    home = Req.get!(@site).body

    case Regex.run(~r{/assets/app-[^"]+\.js[^"]*}, home) do
      [path] -> {:ok, Req.get!(@site <> String.trim_leading(path, "/")).body}
      nil -> {:error, "no app bundle linked from #{@site}"}
    end
  end

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
  against what the site does. Returns `{oks, differences}`, each a
  list of one-line reports; an empty second list means the cartridge
  is current.
  """
  def compare(site) do
    tooltips = Ash.tooltips()

    Enum.sort_by(site, fn {key, f} -> {f.adds == [], key} end)
    |> Enum.reduce({[], []}, fn {key, f}, acc -> judge(key, f, acc, site, tooltips) end)
  end

  # One site feature against the cartridge, onto the two lists.
  defp judge(key, f, {oks, diffs}, site, tooltips) do
    case ours(key, f) do
      :skip ->
        {oks, diffs}

      {:not_offered, _} ->
        soon =
          if(Enum.any?(f.tooltip, &(&1 =~ "Installer coming soon")),
            do: " — its installer: coming soon, the site says",
            else: ""
          )

        {oks,
         diffs ++
           [
             "#{key}: the site offers it (adds #{Enum.join(f.adds, ", ")}), the cartridge does not#{soon}"
           ]}

      {value, adds, args, tipkey} ->
        case problems(f, adds, args, tipkey, site, tooltips) do
          [] -> {oks ++ ["#{key} (#{value}): as the site"], diffs}
          problems -> {oks, diffs ++ Enum.map(problems, &"#{key} (#{value}): the site #{&1}")}
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

  Fetches the feature map that drives the site's *Get Your Installer*
  (its app bundle) and reports, per option, whether the cartridge would
  put the same packages and arguments in the command and shows the same
  tooltip — and which options the site has that the cartridge does not.
  Nothing is written: the report is what to update by hand, with the
  cartridge's tables and its DESIGN.md reference [17].
  """

  @impl Mix.Task
  def run(_argv) do
    Application.ensure_all_started(:req)

    alias WorkbenchIgniter.Features.Ash.Site

    case Site.fetch_bundle() do
      {:ok, js} ->
        {oks, diffs} = js |> Site.parse() |> Site.compare()

        # The map says nothing about cardinality; the command builder does.
        {oks, diffs} =
          if Site.data_layers_independent?(js),
            do:
              {oks ++
                 [
                   "data layers: independent checkboxes on the site, as the cartridge's --data-layer (several)"
                 ], diffs},
            else:
              {oks,
               diffs ++
                 [
                   "data layers: the site's command builder changed — are the layers still independent checkboxes? The cartridge's --data-layer takes several"
                 ]}

        Enum.each(oks, &Mix.shell().info("  ok  " <> &1))
        Enum.each(diffs, &Mix.shell().info("  !!  " <> &1))
        Mix.shell().info("#{length(oks)} as the site, #{length(diffs)} to look at.")
        if diffs != [], do: exit({:shutdown, 1})

      {:error, why} ->
        Mix.raise(why)
    end
  end
end
