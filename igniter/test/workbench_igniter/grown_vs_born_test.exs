defmodule WorkbenchIgniter.GrownVsBornTest do
  @moduledoc """
  A project born bare and grown cartridge by cartridge is the project
  born whole.

      ./wb.sh new --no-mailer --no-gettext --no-ecto --no-esbuild \\
                  --no-tailwind --no-html --no-live --no-dashboard
      ./wb.sh add mailer … ./wb.sh add live        against        ./wb.sh new

  The experiment that found, by hand on 2026-09-17, a production
  Dockerfile without assets, a release without `bin/migrate` and a
  compose without its database — and, run here for the first time, a
  dashboard that conflicted on a formatted router. phx.new's own
  generator makes both projects, the installers run as `wb.sh add` runs
  them, one applied before the next, and the two trees are compared
  file by file.

  What may differ is said here and nowhere else: the secrets phx.new
  draws on every run; how a file ends (Igniter writes one newline);
  the order of `mix.exs`'s lists and of `.gitignore`'s patterns, where
  order means nothing — a cartridge appends where phx.new interleaves;
  and the files a birth writes that this one does not go through
  (`.env`, by `workbench.setup`) or that Igniter leaves on its first run.

  ## In which orders

  Eight cartridges go in in 13 440 orders — live and the dashboard
  build on html. Not every run can walk them all, so four layers, each
  at its own price:

    * **every triple, in every order** — a conflict is born where
      cartridges write into the same stretch of a file, so what has to
      be seen is each pair going in both ways round, and each three
      that may meet in one block (the router's dev routes) in all six.
      A covering set of orders is worked out when this file compiles
      (`covering/0`), and a test proves it covers. Always;
    * **a few orders drawn by the run's seed** — "for any valid order"
      is the property, and every run looks somewhere new. One that
      fails prints the order, to be pinned in `@pinned`. Always;
    * **one step from a shape** — phx.new can make any subset of the
      eight outright: a cartridge is added to a shape that lacks it,
      against the next shape born. Sixty of the 560 steps by the seed,
      always; all of them with the next;
    * **all of them** — the whole tree of orders, a shared beginning
      grown once. Minutes on every core: `mix test --only exhaustive`,
      before a release or after touching `PhxDelta`.
  """

  use ExUnit.Case, async: true

  import WorkbenchIgniter.Grown, only: [born: 1, add: 2, grow: 2, differences: 2]

  alias WorkbenchIgniter.Compose
  alias WorkbenchIgniter.Features
  alias WorkbenchIgniter.PhxDelta

  @cartridges ~w(mailer gettext ecto esbuild tailwind html live dashboard)
  # What a cartridge builds on, as its `requires/0` says.
  @after_html ~w(live dashboard)

  # Orders that failed once, kept: as it was done by hand, and the two
  # that first met the formatted router.
  @pinned [
    ~w(mailer gettext ecto esbuild tailwind html dashboard live),
    ~w(html live dashboard tailwind esbuild ecto gettext mailer),
    ~w(gettext html tailwind esbuild dashboard ecto live mailer)
  ]

  # --- the orders -------------------------------------------------------------

  defp valid?(order) do
    html = Enum.find_index(order, &(&1 == "html"))

    Enum.all?(@after_html, fn c ->
      (i = Enum.find_index(order, &(&1 == c))) == nil or (html != nil and html < i)
    end)
  end

  defp permutations([]), do: [[]]
  defp permutations(list), do: for(x <- list, rest <- permutations(list -- [x]), do: [x | rest])

  defp triples(order) do
    for {a, i} <- Enum.with_index(order),
        {b, j} <- Enum.with_index(order),
        {c, k} <- Enum.with_index(order),
        i < j and j < k,
        do: {a, b, c}
  end

  # Every ordered triple some valid order can hold.
  defp every_triple do
    for a <- @cartridges,
        b <- @cartridges,
        c <- @cartridges,
        a != b and b != c and a != c,
        valid?([a, b, c]),
        into: MapSet.new() do
      {a, b, c}
    end
  end

  # A covering set, greedily: the order that holds the most triples not
  # seen yet, until none is left. Deterministic — the same orders on
  # every machine — and small: each order holds 56 of the 296.
  defp covering do
    case :persistent_term.get({__MODULE__, :covering}, nil) do
      nil ->
        candidates =
          @cartridges
          |> permutations()
          |> Enum.filter(&valid?/1)
          |> Enum.map(&{&1, MapSet.new(triples(&1))})

        orders = cover(candidates, every_triple(), [])
        :persistent_term.put({__MODULE__, :covering}, orders)
        orders

      orders ->
        orders
    end
  end

  defp cover(_candidates, left, acc) when map_size(left.map) == 0, do: Enum.reverse(acc)

  defp cover(candidates, left, acc) do
    {order, held} =
      Enum.max_by(candidates, fn {_, held} -> MapSet.size(MapSet.intersection(held, left)) end)

    cover(candidates, MapSet.difference(left, held), [order | acc])
  end

  # --- growing and comparing: WorkbenchIgniter.Grown (test_helper.exs) ---------

  # Born bare, grown in this order: what is wrong with it, or nothing.
  defp wrong(order, whole) do
    case grow(born([]), order) do
      {:ok, grown} -> differences(whole, grown)
      {:error, reason} -> [reason]
    end
  end

  defp assert_whole(orders) do
    whole = born(@cartridges)

    # Each order on a core of its own: a test module runs its tests one
    # after another, and an order is eight inserts.
    failed =
      orders
      |> Task.async_stream(&{&1, wrong(&1, whole)}, timeout: :infinity, ordered: false)
      |> Enum.flat_map(fn
        {:ok, {_order, []}} ->
          []

        {:ok, {order, wrong}} ->
          ["  #{Enum.join(order, " ")}\n" <> Enum.map_join(wrong, "\n", &"      #{&1}")]
      end)

    assert failed == [],
           "born bare and grown is not born whole, in #{length(failed)} of #{length(orders)} orders " <>
             "(pin one in @pinned):\n" <> Enum.join(failed, "\n")
  end

  # --- the layers -------------------------------------------------------------

  test "the covering set holds every triple of cartridges, in every order it can go in" do
    orders = covering()
    held = orders |> Enum.flat_map(&triples/1) |> MapSet.new()

    assert Enum.all?(orders, &valid?/1)
    assert MapSet.subset?(every_triple(), held)
    # Small enough to run always: each order is eight inserts.
    assert length(orders) <= 16, "#{length(orders)} orders"
  end

  test "born bare and grown, in every order of the covering set and the pinned ones: born whole" do
    assert_whole(Enum.uniq(@pinned ++ covering()))
  end

  test "born bare and grown, in five orders drawn by this run's seed: born whole" do
    :rand.seed(:exsss, {ExUnit.configuration()[:seed], 0, 0})

    orders =
      Stream.repeatedly(fn -> Enum.shuffle(@cartridges) end)
      |> Stream.filter(&valid?/1)
      |> Enum.take(5)

    assert_whole(orders)
  end

  test "to the workbench, the grown project is the born one: shape, services, composes" do
    whole = born(@cartridges)
    {:ok, grown} = grow(born([]), hd(@pinned))

    {born_facts, _} = PhxDelta.facts(whole)
    {grown_facts, _} = PhxDelta.facts(grown)
    assert grown_facts == born_facts

    {born_services, _} = Features.services(whole)
    {grown_services, _} = Features.services(grown)
    assert grown_services == born_services

    for deploy <- ~w(dev prod) do
      argv =
        ~w(--deploy #{deploy} --app-name test --image test:local --dockerfile Dockerfile
           --uid 1000 --gid 1000 --app-port 4000)

      {:ok, born_plan} = Compose.plan_from_argv(argv, fn -> born_services end)
      {:ok, grown_plan} = Compose.plan_from_argv(argv, fn -> grown_services end)
      assert Compose.render(grown_plan) == Compose.render(born_plan)
    end
  end

  # Every project phx.new can make of the eight, and every cartridge
  # that can go onto it next.
  defp steps do
    shapes =
      for mask <- 0..(2 ** length(@cartridges) - 1),
          shape =
            for(
              {c, i} <- Enum.with_index(@cartridges),
              Bitwise.band(mask, Bitwise.bsl(1, i)) != 0,
              do: c
            ),
          "html" in shape or not Enum.any?(@after_html, &(&1 in shape)),
          do: shape

    for shape <- shapes,
        c <- @cartridges -- shape,
        c not in @after_html or "html" in shape,
        do: {shape, c}
  end

  defp assert_steps(steps) do
    failed =
      steps
      |> Task.async_stream(
        fn {shape, cartridge} ->
          case add(born(shape), cartridge) do
            {:ok, grown} -> {shape, cartridge, differences(born(shape ++ [cartridge]), grown)}
            {:error, reason} -> {shape, cartridge, [reason]}
          end
        end,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.flat_map(fn
        {:ok, {_, _, []}} ->
          []

        {:ok, {shape, c, wrong}} ->
          ["  #{c} onto [#{Enum.join(shape, " ")}]: #{Enum.join(wrong, " · ")}"]
      end)

    assert failed == [],
           "#{length(failed)} of #{length(steps)} steps:\n" <> Enum.join(Enum.sort(failed), "\n")
  end

  test "one step from a shape: a cartridge added to a project phx.new can make is the next one born (sixty, by the seed)" do
    :rand.seed(:exsss, {ExUnit.configuration()[:seed], 1, 0})
    assert_steps(Enum.take_random(steps(), 60))
  end

  @tag :exhaustive
  @tag timeout: :infinity
  test "one step from every shape, all 560 of them" do
    steps = steps()
    assert length(steps) == 560
    assert_steps(steps)
  end

  @tag :exhaustive
  @tag timeout: :infinity
  test "born bare and grown, in every one of the 13 440 orders: born whole" do
    whole = born(@cartridges)

    # The tree of orders, walked: a shared beginning is grown once. The
    # first two cartridges split the work among the cores.
    starts = for a <- @cartridges, b <- @cartridges -- [a], valid?([a, b]), do: [a, b]

    {count, failed} =
      starts
      |> Task.async_stream(
        fn start ->
          case grow(born([]), start) do
            {:ok, grown} -> walk(grown, start, whole)
            {:error, reason} -> {0, ["  #{Enum.join(start, " ")} …: #{reason}"]}
          end
        end,
        timeout: :infinity,
        ordered: false
      )
      |> Enum.reduce({0, []}, fn {:ok, {n, failed}}, {count, acc} ->
        {count + n, failed ++ acc}
      end)

    assert failed == [],
           "#{length(failed)} of #{count} orders:\n" <>
             Enum.join(Enum.take(Enum.sort(failed), 40), "\n")

    assert count == 13_440
  end

  # Every order that begins as `done` does: how many, and the ones that are wrong.
  defp walk(grown, done, whole) do
    case for(c <- @cartridges -- done, valid?(done ++ [c]), do: c) do
      [] -> leaf(grown, done, whole)
      next -> Enum.reduce(next, {0, []}, &step(&1, &2, grown, done, whole))
    end
  end

  defp leaf(grown, done, whole) do
    case differences(whole, grown) do
      [] -> {1, []}
      wrong -> {1, ["  #{Enum.join(done, " ")}: #{Enum.join(wrong, " · ")}"]}
    end
  end

  defp step(cartridge, {count, failed}, grown, done, whole) do
    case add(grown, cartridge) do
      {:ok, grown} ->
        {n, wrong} = walk(grown, done ++ [cartridge], whole)
        {count + n, wrong ++ failed}

      {:error, reason} ->
        # Every order below this one fails with it; said once.
        {count, ["  #{Enum.join(done ++ [cartridge], " ")} …: #{reason}" | failed]}
    end
  end

  test "a project that was formatted takes the dashboard: layout is not an edit" do
    # phx.new's router opens its dev routes with a blank line after `do`,
    # which the formatter — the `precommit` alias phx.new gives the
    # project — takes out, right where the dashboard writes.
    formatted =
      born(@cartridges -- ["dashboard"])
      |> Igniter.update_file("lib/test_web/router.ex", fn source ->
        Rewrite.Source.update(source, :content, fn router ->
          assert router =~ "dev_routes) do\n\n"
          String.replace(router, "dev_routes) do\n\n", "dev_routes) do\n")
        end)
      end)
      |> Igniter.Test.apply_igniter!()
      |> Igniter.compose_task("workbench.install.dashboard", [])

    assert formatted.issues == []
    router = Igniter.Test.apply_igniter!(formatted).assigns[:test_files]["lib/test_web/router.ex"]
    assert router =~ ~s|live_dashboard "/dashboard", metrics: TestWeb.Telemetry|
  end

  test "what a birth writes and this does not go through is the environment, and nothing else" do
    {:ok, grown} = grow(born([]), hd(@pinned))

    extra =
      Map.keys(grown.assigns[:test_files]) -- Map.keys(born(@cartridges).assigns[:test_files])

    assert Enum.sort(extra) == Enum.sort(WorkbenchIgniter.Grown.not_phx_news())

    assert grown.assigns[:test_files][".env"] =~
             ~s|DATABASE_URL="ecto://postgres:postgres@localhost:5432/test_prod"|
  end
end
