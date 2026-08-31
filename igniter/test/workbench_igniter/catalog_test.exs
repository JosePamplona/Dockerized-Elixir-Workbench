defmodule WorkbenchIgniter.CatalogTest do
  @moduledoc false

  use ExUnit.Case, async: true

  # A cartridge-shaped module with a boolean on by default, for the
  # rendering rule no cartridge exercises any more.
  defmodule Toggle do
    def name, do: "toggle"
    def info(_argv, _composing), do: %Igniter.Mix.Task.Info{schema: [thing: :boolean], defaults: [thing: true]}
    def option_docs, do: [thing: "Something on by default."]
    def choices, do: []
  end

  import ExUnit.CaptureIO
  import Igniter.Test

  alias WorkbenchIgniter.Features

  # Every cartridge there is, by directory name, in shelf order: the
  # collection first, then the cartridges, then the base ones.
  @cartridges ~w(chiefs_setup ansi toolchain versioning
                 osmon psql_extras credo mock exdebug rest graphql
                 coveralls exdoc guidelines enhancements auth0 openai healthcheck stripe
                 githooks exmachina clustering healthcheck2 ash
                 mailer gettext ecto esbuild tailwind html live dashboard)
  # The chiefs_setup recipe with its default choices, in insertion order.
  @picks ~w(ansi toolchain versioning osmon psql_extras credo mock exdebug rest
            coveralls exdoc enhancements healthcheck)
  # Base cartridges a default phx.new project already carries.
  @in_by_default ~w(mailer gettext ecto esbuild tailwind html live dashboard)

  describe "the catalog" do
    test "names every cartridge, in shelf order" do
      assert Enum.map(Features.catalog(), & &1.name()) == @cartridges
      assert for(e <- Enum.map(Features.catalog(), &Features.entry/1), e.base, do: e.name) == @in_by_default
      assert Features.entry(Features.Ecto).afterwards =~ "./wb.sh bake"
      assert Features.entry(Features.Mailer).afterwards == nil
      assert Features.named("credo") == Features.Credo
      assert Features.named("nope") == nil
    end

    test "marks the collection and carries its default recipe" do
      assert %{collection: true, members: members} = Features.entry(Features.ChiefsSetup)
      assert Enum.map(members, & &1.name) == @picks
      # Each member with the argv its installer gets — the recipe.
      assert %{name: "rest", argv: ["--health"]} = Enum.find(members, &(&1.name == "rest"))
      assert %{name: "ansi", argv: []} = hd(members)
      assert %{collection: false, members: []} = Features.entry(Features.Clustering)

      # The recipe follows the collection's choice.
      members = for {name, _argv} <- Features.ChiefsSetup.members(interface: "graphql"), do: name
      assert "graphql" in members and "rest" not in members
    end

    test "each entry carries the manifest" do
      for feature <- Features.catalog(), entry = Features.entry(feature) do
        assert entry.name == feature.name()
        assert entry.task == "workbench.install." <> entry.name
        assert is_boolean(entry.collection)
        assert is_list(entry.requires)
        assert is_list(entry.options)

        unless entry.pending do
          assert is_binary(entry.summary), "#{entry.name} has no @shortdoc"
          assert is_binary(entry.example)
        end

        # The developer's need is part of the anatomy: one line the shelf
        # shows, off the cartridge's NEED.md, pending cartridges included.
        assert %{line: line, body: body} = entry.need, "#{entry.name} has no NEED.md"
        assert line =~ ~r/\S/ and not String.starts_with?(line, "**")
        assert body =~ "**Before:**" and body =~ "**After:**" and body =~ "**Not for:**"
      end
    end

    test "reads the version off the cartridge changelog" do
      assert %{version: %{version: "0.1.0", date: "2026-08-28"}} =
               Features.entry(Features.Healthcheck2)

      assert %{version: nil} = Features.entry(Features.Credo)
    end

    test "lists the installer's options with their defaults" do
      assert %{options: [%{name: :path, type: :string, default: "/health", choices: nil}]} =
               Features.entry(Features.Healthcheck2)

      assert %{pending: true, options: [], example: nil, requires: ["auth0"]} =
               Features.entry(Features.Stripe)
    end

    test "carries the values an option takes, closed or open, flat or in sections" do
      options = Features.entry(Features.Ash).options
      by = fn name -> Enum.find(options, &(&1.name == name)) end

      values = fn o -> Enum.map(o.choices, & &1.value) end

      assert %{open: false, multiple: true} = by.(:data_layer)
      assert values.(by.(:data_layer)) == ~w(postgres sqlite csv none)
      assert %{value: "postgres", doc: "ash_postgres · The swiss army knife" <> _} = hd(by.(:data_layer).choices)
      assert %{value: "none", doc: "no data layer — alone"} = List.last(by.(:data_layer).choices)
      assert %{open: false, multiple: true} = by.(:api)
      assert values.(by.(:api)) == ~w(json_api graphql typescript)
      assert %{choices: [%{value: "password", doc: "Allow users to log in" <> _} | _], open: true, multiple: true} = by.(:auth)
      assert %{doc: nil} = Enum.find(by.(:auth).choices, &(&1.value == "webauthn"))
      assert %{choices: [%{group: :ai, values: [%{value: "tidewave", doc: "Speed up development" <> _}, %{value: "ash_ai", doc: "First class support" <> _} | _]} | _], open: true} = by.(:with)
      assert %{choices: nil, multiple: false} = by.(:example)

      theme = Enum.find(Features.entry(Features.Coveralls).options, &(&1.name == :theme))
      assert %{open: false} = theme
      assert [%{value: "exdoc-ish", doc: "mimics" <> _}, %{value: "custom", doc: _}] = theme.choices
    end

    test "documents its options from the cartridge, into the task's moduledoc" do
      for feature <- Features.catalog(), not feature.pending?() do
        keys = Keyword.keys(feature.info([], nil).schema || [])

        for {key, doc} <- feature.option_docs() do
          assert key in keys, "#{feature.name()} documents --#{key}, which its schema lacks"
          assert is_binary(doc) and doc != ""
        end
      end

      # Rendered: --no- for a boolean that defaults to true, wrapped bullets.
      assert WorkbenchIgniter.Feature.options_doc(Toggle) =~ ~r/^\* `--no-thing` - Something on/m
      assert WorkbenchIgniter.Feature.options_doc(Features.Healthcheck2) =~ ~r/^\* `--path` - Prefix/

      # And in the task's own docs, interpolations resolved.
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} = Code.fetch_docs(Mix.Tasks.Workbench.Install.Coveralls)
      assert doc =~ "* `--theme` - HTML report theme, one of `custom`, `exdoc-ish`:"

      assert %{options: [%{name: :path, doc: "Prefix of the two probe routes" <> _}]} =
               Features.entry(Features.Healthcheck2)
    end

    test "says whether a second run adds or is a no-op, and what an adding one carries" do
      assert Features.Ash.rerun() == :adds
      assert Features.Healthcheck2.rerun() == :noop
      assert %{rerun: :adds} = Features.entry(Features.Ash)

      # A project with Ash, its Postgres layer, one API and one advanced
      # package: the state reads them off mix.exs, and nothing else.
      project =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:ash, "~> 3.0"})
        |> Igniter.Project.Deps.add_dep({:ash_postgres, "~> 2.0"})
        |> Igniter.Project.Deps.add_dep({:ash_json_api, "~> 1.0"})
        |> Igniter.Project.Deps.add_dep({:ash_admin, "~> 0.13"})
        |> apply_igniter!()

      assert {%{data_layer: ["postgres"], api: ["json_api"], with: ["ash_admin"]}, _} =
               Features.Ash.state(project)

      assert {state, _} = Features.Ash.state(phx_test_project())
      assert state == %{}

      {status, _} = Features.status(project)
      assert %{installed: true, state: %{data_layer: ["postgres"]}} = Enum.find(status, &(&1.name == "ash"))
      assert %{installed: false, state: %{}} = Enum.find(status, &(&1.name == "credo"))
    end

    test "mix workbench.catalog --json prints it, with the covers when asked" do
      covers = Path.join(System.tmp_dir!(), "wb-catalog-#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(covers, "credo/sealed"))
      File.write!(Path.join(covers, "credo/sealed/cover.jpg"), "")

      output =
        capture_io(fn -> Mix.Tasks.Workbench.Catalog.run(["--json", "--covers", covers]) end)

      entries = Jason.decode!(output)

      assert Enum.map(entries, & &1["name"]) == @cartridges

      assert %{"covers" => %{"front" => "credo/sealed/cover.jpg", "back" => nil}} =
               Enum.find(entries, &(&1["name"] == "credo"))

      assert %{"covers" => %{"front" => nil, "back" => nil}} =
               Enum.find(entries, &(&1["name"] == "healthcheck2"))
    after
      :ok
    end

    test "mix workbench.catalog prints a table" do
      output = capture_io(fn -> Mix.Tasks.Workbench.Catalog.run([]) end)

      # The facts column says what is true of the box, and nothing when
      # nothing is — there is no kind to print.
      assert output =~ ~r/^chiefs_setup +v\d+\.\d+\.\d+ +inserts 13 +Your project is vanilla/m
      assert output =~ ~r/^mailer +\S+ +base +You want to see the mail/m
      assert output =~ ~r/^stripe +- +pending +Your users should be able to pay/m
      assert output =~ ~r/^healthcheck2 +v0\.1\.0 +Your platform polls/m
      assert output =~ ~r/^osmon +- +You want the machine's/m
    end
  end

  describe "installed?/1" do
    test "is false on a fresh project, for every cartridge phx.new does not bring" do
      {status, _igniter} = Features.status(phx_test_project())

      assert Enum.map(status, & &1.name) == @cartridges
      assert Enum.filter(status, & &1.installed) |> Enum.map(& &1.name) == @in_by_default
    end

    # The mark each installer's guard reads is what installed?/1 reads:
    # after applying the cartridge, the project carries it and nothing
    # else — the check of one cartridge never lights up another's.
    # ash is the exception: its mark (the `ash` dependency) is put by
    # the `mix igniter.install` command it queues, which runs after the
    # patch set and never in test mode; its own test covers the read.
    for feature <- Features.catalog(), not feature.pending?(), feature != Features.Ash do
      @feature feature
      test "flips for #{feature.name()} once it is installed, and for it alone" do
        igniter =
          Enum.reduce(
            prereqs(@feature.name()) ++ [@feature.task()],
            phx_test_project(),
            fn task, igniter -> Igniter.compose_task(igniter, task, args(task)) end
          )

        installed =
          igniter
          |> apply_igniter!()
          |> Features.status()
          |> elem(0)
          |> Enum.filter(& &1.installed)
          |> Enum.map(& &1.name)

        assert @feature.name() in installed
        assert (installed -- [@feature.name()]) -- @in_by_default == others_installed(@feature.name())
      end
    end

    # What a cartridge builds on must be in first (the installer
    # refuses otherwise): auth0 on enhancements, openai on both,
    # guidelines on the docs site it appends its page to.
    defp prereqs("auth0"), do: ["workbench.install.enhancements"]
    defp prereqs("openai"), do: ["workbench.install.enhancements", "workbench.install.auth0"]
    defp prereqs("guidelines"), do: ["workbench.install.exdoc"]
    defp prereqs(_name), do: []

    # The arguments an installer cannot do without. guidelines takes the
    # URL of the page it installs, and gets an unreachable one: the
    # download fails fast, offline, and its placeholder is planted —
    # which is the file the mark reads either way.
    defp args("workbench.install.guidelines"), do: ["--url", "http://localhost:1/guide.md"]
    defp args(_task), do: []

    # What else lights up beside the cartridge, in catalog order: the
    # prerequisites composed above, the cartridges an installer composes
    # itself (mock rides along with healthcheck and enhancements), and
    # — for the collection — every member of its recipe.
    defp others_installed(name) when name in ~w(healthcheck enhancements), do: ["mock"]
    defp others_installed("auth0"), do: ["mock", "enhancements"]
    defp others_installed("openai"), do: ["mock", "enhancements", "auth0"]
    defp others_installed("guidelines"), do: ["exdoc"]
    defp others_installed("chiefs_setup"), do: @picks
    defp others_installed(_name), do: []
  end
end
